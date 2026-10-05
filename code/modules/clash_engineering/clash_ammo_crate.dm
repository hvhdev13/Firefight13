#define CLASH_CRATE_STOCK 10
#define CLASH_CRATE_STOCK_BIG 15
#define CLASH_CRATE_RESTOCK (15 SECONDS)
#define CLASH_CRATE_RESTOCK_BIG (10 SECONDS)
#define CLASH_CRATE_TAKE_GAP (5 SECONDS)
#define CLASH_CRATE_DEPLOY_TIME (1 SECONDS)
#define CLASH_CRATE_PACK_TIME (1 SECONDS)

GLOBAL_LIST_EMPTY(clash_engineer_crates)

/obj/item/clash_ammo_crate
	name = "packed ammo crate"
	desc = "A folded ammo crate. Use it in hand to set it down in front of you. Teammates take magazines from it."
	icon = 'icons/obj/items/weapons/guns/ammo_boxes/boxes_and_lids.dmi'
	icon_state = "base_m41"
	w_class = SIZE_MEDIUM
	var/box_state = "base_m41"
	var/magazine_state = "magaz_reg"
	var/owner_ckey
	var/obj/structure/clash_ammo_crate/deployed

/obj/item/clash_ammo_crate/upp
	icon_state = "base_type71"
	box_state = "base_type71"
	magazine_state = "magaz_type71_reg"

/obj/item/clash_ammo_crate/Initialize(mapload, ...)
	. = ..()
	overlays += image(icon, icon_state = "[box_state]_lid")

/obj/item/clash_ammo_crate/Destroy()
	if(owner_ckey)
		clash_forget_build(GLOB.clash_engineer_crates, owner_ckey, src)
	QDEL_NULL(deployed)
	return ..()

/obj/item/clash_ammo_crate/attack_hand(mob/user)
	if(owner_ckey && user.ckey != owner_ckey)
		to_chat(user, SPAN_WARNING("That belongs to another engineer."))
		return
	return ..()

/obj/item/clash_ammo_crate/attack_self(mob/living/carbon/human/user)
	..()
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can set up ammo crates."))
		return
	if(owner_ckey && owner_ckey != user.ckey)
		to_chat(user, SPAN_WARNING("This is not your ammo crate."))
		return
	var/turf/spot = get_step(user, user.dir)
	if(!isturf(spot) || spot.density || (locate(/obj/structure/clash_ammo_crate) in spot))
		to_chat(user, SPAN_WARNING("You need a clear spot in front of you."))
		return
	var/deploy_time = CLASH_CRATE_DEPLOY_TIME * (clash_engineer_perk(user, CLASH_PERK_QUICK_BUILD) ? 0.5 : 1)
	if(!do_after(user, deploy_time, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD) || QDELETED(src) || spot.density)
		return
	if(!deployed)
		deployed = new(src)
		deployed.packed = src
	deployed.icon_state = box_state
	deployed.magazine_state = magazine_state
	deployed.owner_ckey = user.ckey
	deployed.faction = user.faction
	deployed.max_stock = clash_engineer_perk(user, CLASH_PERK_BIG_CRATE) ? CLASH_CRATE_STOCK_BIG : CLASH_CRATE_STOCK
	deployed.restock_time = clash_engineer_perk(user, CLASH_PERK_BIG_CRATE) ? CLASH_CRATE_RESTOCK_BIG : CLASH_CRATE_RESTOCK
	if(isnull(deployed.stock))
		deployed.stock = deployed.max_stock
	owner_ckey = user.ckey
	var/list/owned = GLOB.clash_engineer_crates[user.ckey]
	for(var/obj/item/clash_ammo_crate/other as anything in owned?.Copy())
		if(other != src && other.deployed && other.loc == other.deployed)
			to_chat(user, SPAN_NOTICE("Your older ammo crate is taken down."))
			qdel(other)
	user.drop_inv_item_to_loc(src, deployed)
	deployed.forceMove(spot)
	deployed.update_icon()
	deployed.restock()
	playsound(spot, 'sound/items/Deconstruct.ogg', 25, 1)

/obj/structure/clash_ammo_crate
	name = "ammo crate"
	desc = "An engineer's ammo crate. Click it with your gun or an empty hand to take a magazine for that gun. It restocks over time."
	icon = 'icons/obj/items/weapons/guns/ammo_boxes/boxes_and_lids.dmi'
	icon_state = "base_m41"
	anchored = TRUE
	density = FALSE
	layer = LOWER_ITEM_LAYER
	var/magazine_state = "magaz_reg"
	var/obj/item/clash_ammo_crate/packed
	var/owner_ckey
	var/faction
	var/stock
	var/max_stock = CLASH_CRATE_STOCK
	var/restock_time = CLASH_CRATE_RESTOCK
	var/restock_timer
	var/list/next_take = list()
	var/list/next_pay = list()

/obj/structure/clash_ammo_crate/Destroy()
	deltimer(restock_timer)
	if(packed)
		packed.deployed = null
		QDEL_NULL(packed)
	return ..()

/obj/structure/clash_ammo_crate/update_icon()
	overlays.Cut()
	if(stock >= max_stock)
		overlays += image('icons/obj/items/weapons/guns/ammo_boxes/magazines.dmi', icon_state = magazine_state)
	else if(stock > max_stock / 2)
		overlays += image('icons/obj/items/weapons/guns/ammo_boxes/magazines.dmi', icon_state = "[magazine_state]_3")
	else if(stock > max_stock / 4)
		overlays += image('icons/obj/items/weapons/guns/ammo_boxes/magazines.dmi', icon_state = "[magazine_state]_2")
	else if(stock > 0)
		overlays += image('icons/obj/items/weapons/guns/ammo_boxes/magazines.dmi', icon_state = "[magazine_state]_1")

/obj/structure/clash_ammo_crate/get_examine_text(mob/user)
	. = ..()
	. += SPAN_INFO("It holds [stock] of [max_stock] magazines.")

/obj/structure/clash_ammo_crate/proc/restock()
	if(stock >= max_stock || restock_timer)
		return
	restock_timer = addtimer(CALLBACK(src, PROC_REF(restock_one)), restock_time, TIMER_STOPPABLE)

/obj/structure/clash_ammo_crate/proc/restock_one()
	restock_timer = null
	stock = min(max_stock, stock + 1)
	update_icon()
	restock()

/obj/structure/clash_ammo_crate/attack_hand(mob/living/carbon/human/user)
	clash_take(user)

/obj/structure/clash_ammo_crate/proc/clash_take(mob/living/carbon/human/user, obj/item/weapon/gun/held)
	if(!ishuman(user) || user.faction != faction)
		return
	if(world.time < next_take[user.ckey])
		to_chat(user, SPAN_WARNING("You just took one. Wait a few seconds."))
		return
	if(stock <= 0)
		to_chat(user, SPAN_WARNING("The ammo crate is empty. It restocks over time."))
		return
	var/obj/item/ammo = clash_crate_ammo_for(user, held)
	if(!ammo)
		to_chat(user, SPAN_WARNING("No ammo here for that gun."))
		return
	user.put_in_hands(ammo)
	stock--
	next_take[user.ckey] = world.time + CLASH_CRATE_TAKE_GAP
	update_icon()
	restock()
	playsound(loc, 'sound/weapons/handling/gun_m16_unload.ogg', 25, 1)
	if(user.ckey != owner_ckey && world.time >= next_pay[user.ckey])
		next_pay[user.ckey] = world.time + CLASH_RESUPPLY_PAY_GAP
		clash_progress_resupply(owner_ckey, faction)

/obj/structure/clash_ammo_crate/attackby(obj/item/tool, mob/living/carbon/human/user)
	if(isgun(tool) || istype(tool, /obj/item/ammo_magazine))
		clash_take(user, isgun(tool) ? tool : null)
		return
	if(!HAS_TRAIT(tool, TRAIT_TOOL_WRENCH))
		return ..()
	if(user.ckey != owner_ckey)
		to_chat(user, SPAN_WARNING("Only the engineer who set it up can pack it up."))
		return
	var/pack_time = CLASH_CRATE_PACK_TIME * (clash_engineer_perk(user, CLASH_PERK_QUICK_BUILD) ? 0.5 : 1)
	if(!do_after(user, pack_time, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src))
		return
	deltimer(restock_timer)
	restock_timer = null
	packed.forceMove(get_turf(src))
	forceMove(packed)
	user.put_in_hands(packed)
	to_chat(user, SPAN_NOTICE("You pack up the ammo crate."))

/obj/structure/clash_ammo_crate/ex_act(severity)
	if(severity >= EXPLOSION_THRESHOLD_LOW)
		qdel(src)

/proc/clash_crate_ammo_for(mob/living/carbon/human/user, obj/item/weapon/gun/gun)
	if(!gun)
		gun = user.get_inactive_hand()
	if(!istype(gun))
		gun = clash_kit_primary_of(user)
	if(!istype(gun) || istype(gun, /obj/item/weapon/gun/launcher) || istype(gun, /obj/item/weapon/gun/flamer) || istype(gun, /obj/item/weapon/gun/smartgun) || istype(gun, /obj/item/weapon/gun/minigun))
		return null
	var/obj/item/ammo_magazine/loaded = gun.current_mag
	if(istype(loaded, /obj/item/ammo_magazine/internal))
		var/obj/item/ammo_magazine/handful/shells = new
		shells.generate_handful(loaded.default_ammo, loaded.caliber, 5, gun.type)
		return shells
	var/mag_type = loaded ? loaded.type : initial(gun.current_mag)
	if(!ispath(mag_type, /obj/item/ammo_magazine) || GLOB.faction_clash_restricted_items[mag_type])
		mag_type = initial(gun.current_mag)
	if(!ispath(mag_type, /obj/item/ammo_magazine))
		return null
	return new mag_type

#undef CLASH_CRATE_STOCK
#undef CLASH_CRATE_STOCK_BIG
#undef CLASH_CRATE_RESTOCK
#undef CLASH_CRATE_RESTOCK_BIG
#undef CLASH_CRATE_TAKE_GAP
#undef CLASH_CRATE_DEPLOY_TIME
#undef CLASH_CRATE_PACK_TIME

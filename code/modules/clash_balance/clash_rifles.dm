/proc/clash_hvh_rules()
	return istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh)

GLOBAL_LIST_INIT(clash_issued_gun_swaps, list(
	/obj/item/weapon/gun/rifle/type71/rifleman = /obj/item/weapon/gun/rifle/type71,
	/obj/item/weapon/gun/rifle/type71/sapper = /obj/item/weapon/gun/rifle/type71,
	/obj/item/weapon/gun/rifle/type71/flamer = /obj/item/weapon/gun/rifle/type71,
	/obj/item/weapon/gun/smg/bizon/upp = /obj/item/weapon/gun/rifle/type71,
))

/proc/clash_standard_issue_guns(mob/living/carbon/human/fighter)
	var/list/swaps = list()
	var/list/restricted = list()
	for(var/obj/item/thing in fighter.get_contents())
		if(GLOB.clash_issued_gun_swaps[thing.type])
			swaps += thing
		else if(istype(thing, /obj/item/ammo_magazine) && GLOB.faction_clash_restricted_items[thing.type])
			restricted += thing
	for(var/obj/item/weapon/gun/gun as anything in swaps)
		var/swap_type = GLOB.clash_issued_gun_swaps[gun.type]
		var/slot = fighter.get_slot_by_item(gun)
		if(slot)
			clash_kit_replace_worn(fighter, slot, swap_type)
		else
			var/atom/holder = gun.loc
			qdel(gun)
			new swap_type(holder)
	for(var/obj/item/ammo_magazine/magazine as anything in restricted)
		var/standard_type = type2parent(magazine.type)
		var/atom/holder = magazine.loc
		qdel(magazine)
		new standard_type(holder)
	if(length(swaps))
		clash_kit_purge_stray_magazines(fighter)

/datum/ammo/bullet/rifle/m41a/heavy

/obj/item/ammo_magazine/rifle/lmg
	default_ammo = /datum/ammo/bullet/rifle/m41a/heavy

/datum/ammo/bullet/rifle/m41a/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 58 * DAMAGE_MULT
	accurate_range = 10
	accuracy_falloff_per_tile = 2
	effective_range_max = 10
	damage_falloff = 1.5

/datum/ammo/bullet/rifle/m41a/heavy/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = initial(damage) * DAMAGE_MULT
	accurate_range = min(initial(accurate_range), 10 - penetration / 5)
	accuracy_falloff_per_tile = initial(accuracy_falloff_per_tile)
	effective_range_max = initial(effective_range_max)
	damage_falloff = initial(damage_falloff)

/datum/ammo/bullet/rifle/type71/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	if(type == /datum/ammo/bullet/rifle/type71)
		damage = 68 * DAMAGE_MULT
		penetration = 8
	effective_range_max = 8
	damage_falloff = 1.5
	accuracy_falloff_per_tile = 3

/datum/ammo/bullet/rifle/type71/carbine/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 79 * DAMAGE_MULT
	effective_range_max = 3
	damage_falloff = 3
	accurate_range = 3
	accuracy_falloff_per_tile = 6

/datum/ammo/bullet/rifle/ak4047/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage_falloff = 2.5
	accuracy_falloff_per_tile = 5

/datum/ammo/bullet/rifle/marksman/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	accurate_range = 12
	accuracy_falloff_per_tile = 1

/datum/ammo/bullet/sniper/upp/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 65 * DAMAGE_MULT

/datum/ammo/bullet/lever_action/xm88/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 48

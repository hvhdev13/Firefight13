#define CLASH_SPENT_SHELL_LIFETIME (1 MINUTES)
#define CLASH_SPENT_SHELL_FALL (3 DECISECONDS)
#define CLASH_PUMP_HEARD_RANGE 7

/obj/item/weapon/gun/shotgun/pump/var/clash_pump_recovery = 1.2 SECONDS
/obj/item/weapon/gun/shotgun/pump/var/clash_pump_back_sound
/obj/item/weapon/gun/shotgun/pump/var/clash_pump_volume = 10
/obj/item/weapon/gun/shotgun/pump/var/clash_pump_heard_volume = 10
/obj/item/weapon/gun/shotgun/pump/var/clash_pump_recoil = 0
/obj/item/weapon/gun/shotgun/pump/var/clash_pump_stroke = 0
/obj/item/weapon/gun/shotgun/pump/var/clash_racking = FALSE
/obj/item/weapon/gun/shotgun/pump/var/clash_spent_shell = FALSE

/obj/item/weapon/gun/shotgun/pump/Initialize(mapload, spawn_empty)
	. = ..()
	if(clash_hvh_rules())
		pump_delay = 0

/obj/item/weapon/gun/shotgun/pump/set_gun_config_values()
	..()
	if(clash_hvh_rules())
		set_fire_delay(clash_pump_recovery)

/obj/item/weapon/gun/shotgun/pump/unique_action(mob/user)
	if(!clash_hvh_rules() || pumped)
		return ..()
	if(clash_pump_back_sound)
		clash_rack_back(user)
		return
	var/wait = last_fired + clash_pump_recovery - world.time
	if(wait <= 0)
		return ..()
	addtimer(CALLBACK(src, PROC_REF(clash_queued_pump), user), wait, TIMER_UNIQUE|TIMER_OVERRIDE)

/obj/item/weapon/gun/shotgun/pump/proc/clash_queued_pump(mob/user)
	if(QDELETED(user) || loc != user || pumped)
		return
	pump_shotgun(user)

/obj/item/weapon/gun/shotgun/pump/proc/clash_rack_back(mob/user)
	if(clash_racking)
		return
	clash_racking = TRUE
	var/wait = last_fired + clash_pump_recoil - world.time
	if(wait > 0)
		addtimer(CALLBACK(src, PROC_REF(clash_rack_start), user), wait)
	else
		clash_rack_start(user)

/obj/item/weapon/gun/shotgun/pump/proc/clash_rack_start(mob/user)
	if(QDELETED(user) || loc != user || pumped)
		clash_racking = FALSE
		return
	clash_pump_sound(user, clash_pump_back_sound)
	if(clash_spent_shell)
		clash_eject_shell(user)
	addtimer(CALLBACK(src, PROC_REF(clash_rack_forward), user), clash_pump_stroke)

/obj/item/weapon/gun/shotgun/pump/proc/clash_rack_forward(mob/user)
	clash_racking = FALSE
	if(QDELETED(user) || loc != user || pumped)
		return
	clash_pump_sound(user, pump_sound)
	ready_shotgun_tube()
	pumped = !!in_chamber
	recent_pump = world.time

/obj/item/weapon/gun/shotgun/pump/proc/clash_pump_sound(mob/user, sound_file)
	var/turf/source = get_turf(user)
	for(var/client/listener as anything in GLOB.clients)
		var/mob/hearer = listener.mob
		if(hearer == user)
			playsound_client(listener, sound_file, user, clash_pump_volume)
		else if(hearer?.z == source?.z && get_dist(hearer, source) <= CLASH_PUMP_HEARD_RANGE)
			playsound_client(listener, sound_file, user, clash_pump_heard_volume)

/obj/item/weapon/gun/shotgun/pump/pump_shotgun(mob/user)
	. = ..()
	if(clash_spent_shell && recent_pump == world.time)
		clash_eject_shell(user)

/obj/item/weapon/gun/shotgun/pump/reload_into_chamber(mob/user)
	. = ..()
	if(clash_hvh_rules() && !active_attachable)
		clash_spent_shell = TRUE

/obj/item/weapon/gun/shotgun/pump/proc/clash_eject_shell(mob/user)
	clash_spent_shell = FALSE
	var/turf/floor = get_turf(user)
	if(!floor)
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), floor, "gun_casing_shotgun", 20, TRUE), CLASH_SPENT_SHELL_FALL)
	var/obj/item/ammo_casing/shell/spent = locate() in floor
	if(spent)
		if(spent.current_casings < spent.max_casings)
			spent.current_casings++
			spent.update_icon()
		return
	spent = new(floor)
	QDEL_IN(spent, CLASH_SPENT_SHELL_LIFETIME)

/obj/item/ammo_magazine/internal/shotgun/type23/pump
	max_rounds = 9

/obj/item/weapon/gun/shotgun/pump/type23
	name = /obj/item/weapon/gun/shotgun/type23::name
	desc = "As UPP soldiers frequently reported being outmatched by enemy combatants, UPP High Command commissioned a large amount of Type 23 shotguns, originally used for quelling defector colony riots. This heavy pump-action shotgun chambers 8 gauge, and packs a mean punch."
	icon = /obj/item/weapon/gun/shotgun/type23::icon
	icon_state = /obj/item/weapon/gun/shotgun/type23::icon_state
	item_state = /obj/item/weapon/gun/shotgun/type23::item_state
	fire_sound = 'sound/weapons/gun_type23_heavy.ogg'
	pump_sound = 'sound/weapons/shotgunpump_forward_heavy.ogg'
	clash_pump_back_sound = 'sound/weapons/shotgunpump_back_heavy.ogg'
	clash_pump_volume = 22
	clash_pump_heard_volume = 12
	clash_pump_recoil = 0.8 SECONDS
	clash_pump_stroke = 0.45 SECONDS
	reload_sound = 'sound/weapons/shell_load1_heavy.ogg'
	current_mag = /obj/item/ammo_magazine/internal/shotgun/type23/pump
	flags_gun_features = /obj/item/weapon/gun/shotgun/type23::flags_gun_features
	map_specific_decoration = FALSE
	gauge = /obj/item/weapon/gun/shotgun/type23::gauge
	starting_attachment_types = list(/obj/item/attachable/stock/type23)
	clash_pump_recovery = 1.35 SECONDS

/obj/item/weapon/gun/shotgun/pump/type23/Initialize(mapload, spawn_empty)
	attachable_allowed = get_clash_gun_attachables(/obj/item/weapon/gun/shotgun/type23).Copy()
	. = ..()
	RemoveElement(/datum/element/corp_label/armat)
	AddElement(/datum/element/corp_label/norcomm)

/obj/item/weapon/gun/shotgun/pump/type23/set_gun_attachment_offsets()
	attachable_offset = list("muzzle_x" = 33, "muzzle_y" = 19,"rail_x" = 13, "rail_y" = 21, "under_x" = 24, "under_y" = 15, "stock_x" = -1, "stock_y" = 17)

/obj/item/weapon/gun/shotgun/pump/type23/set_gun_config_values()
	..()
	accuracy_mult = BASE_ACCURACY_MULT
	accuracy_mult_unwielded = BASE_ACCURACY_MULT - HIT_ACCURACY_MULT_TIER_10
	scatter = SCATTER_AMOUNT_TIER_4
	scatter_unwielded = SCATTER_AMOUNT_TIER_1
	recoil = RECOIL_AMOUNT_TIER_1
	recoil_unwielded = RECOIL_AMOUNT_TIER_1

#undef CLASH_SPENT_SHELL_LIFETIME
#undef CLASH_SPENT_SHELL_FALL
#undef CLASH_PUMP_HEARD_RANGE

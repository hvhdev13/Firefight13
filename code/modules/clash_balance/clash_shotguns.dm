#define CLASH_SHELL_SHOVE_DELAY (1 DECISECONDS)

/datum/ammo/bullet/shotgun/buckshot/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 17
	penetration = ARMOR_PENETRATION_TIER_6

/datum/ammo/bullet/shotgun/spread/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 17
	penetration = ARMOR_PENETRATION_TIER_6
	scatter = SCATTER_AMOUNT_TIER_3

/datum/ammo/bullet/shotgun/buckshot/masterkey/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = initial(damage) * DAMAGE_MULT
	penetration = initial(penetration)

/datum/ammo/bullet/shotgun/spread/masterkey/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	var/datum/ammo/main_shell = /datum/ammo/bullet/shotgun/buckshot/masterkey
	damage = initial(main_shell.damage) * DAMAGE_MULT
	penetration = initial(penetration)
	scatter = initial(scatter)

/datum/ammo/bullet/shotgun/heavy/buckshot/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 19
	penetration = ARMOR_PENETRATION_TIER_6
	accurate_range = 4
	max_range = 4

/datum/ammo/bullet/shotgun/heavy/buckshot/spread/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	max_range = 6
	scatter = SCATTER_AMOUNT_TIER_5

/datum/ammo/bullet/shotgun/slug/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 44
	clash_slug_reach()

/datum/ammo/bullet/shotgun/heavy/slug/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 43
	clash_slug_reach()

/datum/ammo/bullet/shotgun/proc/clash_slug_reach()
	effective_range_max = 8
	accurate_range = 8
	max_range = 9

/datum/ammo/bullet/shotgun/heavy/buckshot/spread/on_hit_mob(mob/M, obj/projectile/P)
	if(!clash_hvh_rules())
		return ..()

/datum/ammo/bullet/shotgun/buckshot/slam_back(mob/living/living_mob, obj/projectile/fired_projectile)
	if(!clash_hvh_rules())
		return ..()
	clash_delay_slam(living_mob, fired_projectile)

/datum/ammo/bullet/shotgun/heavy/buckshot/slam_back(mob/living/living_mob, obj/projectile/fired_projectile)
	if(!clash_hvh_rules())
		return ..()
	clash_delay_slam(living_mob, fired_projectile)

/datum/ammo/bullet/shotgun/proc/clash_delay_slam(mob/living/living_mob, obj/projectile/fired_projectile)
	var/direction = Get_Compass_Dir(fired_projectile.z ? fired_projectile : fired_projectile.firer, living_mob)
	if(direction)
		addtimer(CALLBACK(src, PROC_REF(clash_slam), living_mob, direction), CLASH_SHELL_SHOVE_DELAY)

/datum/ammo/bullet/shotgun/proc/clash_slam(mob/living/living_mob, direction)
	if(QDELETED(living_mob) || living_mob.body_position == LYING_DOWN)
		return
	if(!step(living_mob, direction))
		living_mob.animation_attack_on(get_step(living_mob, direction))
		playsound(living_mob.loc, "punch", 25, 1)
		living_mob.visible_message(SPAN_DANGER("[living_mob] slams into an obstacle!"), SPAN_HIGHDANGER("You slam into an obstacle!"), null, 4, CHAT_TYPE_TAKING_HIT)
		living_mob.apply_damage(MELEE_FORCE_TIER_2, enviro = damage_enviro)

#undef CLASH_SHELL_SHOVE_DELAY

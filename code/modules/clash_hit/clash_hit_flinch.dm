SUBSYSTEM_DEF(clash_hit_flinch)
	name = "Clash Hit Flinch"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_hit_flinch/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(on_mob_logged_in))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_hit_flinch/proc/on_mob_logged_in(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(ishuman(new_mob) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		new_mob.AddElement(/datum/element/clash_hit_flinch)

/datum/element/clash_hit_flinch

/datum/element/clash_hit_flinch/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_bullet_act))

/datum/element/clash_hit_flinch/Detach(datum/source, force)
	. = ..()
	UnregisterSignal(source, COMSIG_HUMAN_BULLET_ACT)

/datum/element/clash_hit_flinch/proc/on_bullet_act(mob/living/carbon/human/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	if(damage_result <= 0 || source.stat == DEAD)
		return
	var/direction = get_dir(bullet.starting, source) || bullet.dir
	var/push_x = 0
	var/push_y = 0
	if(direction & EAST)
		push_x = 1
	else if(direction & WEST)
		push_x = -1
	if(direction & NORTH)
		push_y = 1
	else if(direction & SOUTH)
		push_y = -1
	play_clash_hit_effect(source, bullet, damage_result, push_x, push_y)
	if(source.body_position == LYING_DOWN)
		return
	var/strength = clamp(2 + damage_result / 6, 2, 6)
	if(bullet.def_zone == "head")
		strength += 2
	animate(source, pixel_w = push_x * strength, pixel_z = push_y * strength, time = 1, easing = CUBIC_EASING|EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(pixel_w = 0, pixel_z = 0, time = 2, easing = CUBIC_EASING|EASE_IN)

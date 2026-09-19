/proc/clash_is_intruder(atom/movable/mover, faction)
	if(!faction || !SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH))
		return FALSE
	var/mob/living/intruder = isliving(mover) ? mover : mover?.launch_metadata?.thrower
	return istype(intruder) && intruder.faction != faction

/area/clash_arena/var/clash_faction

/area/clash_arena/Enter(atom/movable/mover, atom/oldloc)
	if(clash_is_intruder(mover, clash_faction))
		if(isliving(mover))
			mover.balloon_alert(mover, "enemy base")
		return FALSE
	return ..()

/obj/structure/blocker/clash_gate
	name = "base shield"
	desc = "A faction-keyed barrier. Friendly personnel and fire pass through, hostiles do not."
	icon_state = "purple_line"
	density = FALSE
	layer = ABOVE_OBJ_LAYER
	var/faction

/obj/structure/blocker/clash_gate/BlockedPassDirs(atom/movable/mover, target_dir)
	return clash_is_intruder(mover, faction) ? BLOCKED_MOVEMENT : NO_BLOCKED_MOVEMENT

/obj/structure/blocker/clash_gate/get_projectile_hit_boolean(obj/projectile/bullet)
	return clash_is_intruder(bullet.firer, faction)

/obj/structure/blocker/clash_gate/uscm
	name = "USCM base shield"
	faction = FACTION_MARINE
	color = "#5a8fe6"

/obj/structure/blocker/clash_gate/upp
	name = "UPP base shield"
	faction = FACTION_UPP
	color = "#e61919"

/proc/clash_is_intruder(atom/movable/mover, faction)
	if(!faction || !SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH))
		return FALSE
	var/mob/living/intruder = isliving(mover) ? mover : mover?.launch_metadata?.thrower
	return istype(intruder) && intruder.faction != faction

/area/clash_arena/var/clash_faction

/// Whether mover is one of this base's own team being held in during the pre-match countdown
/proc/clash_is_held(atom/movable/mover, faction, atom/newloc)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!faction || !istype(clash_mode) || !clash_mode.bases_sealed || !isliving(mover))
		return FALSE
	var/mob/living/held = mover
	if(held.faction != faction)
		return FALSE
	var/area/clash_arena/destination = get_area(newloc)
	return !istype(destination) || destination.clash_faction != faction

/area/clash_arena/Enter(atom/movable/mover, atom/oldloc)
	if(clash_is_intruder(mover, clash_faction))
		if(isliving(mover))
			mover.balloon_alert(mover, "enemy base")
		return FALSE
	if(clash_faction && clash_carries_enemy_flag(mover))
		mover.balloon_alert(mover, "take the flag to your stand")
		return FALSE
	return ..()

/area/clash_arena/Exit(atom/movable/mover, atom/newloc)
	if(clash_is_held(mover, clash_faction, newloc))
		mover.balloon_alert(mover, "match not started")
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

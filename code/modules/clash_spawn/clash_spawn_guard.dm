/// Longest a guard can last, even if its owner never leaves base
#define CLASH_SPAWN_GUARD_CAP (60 SECONDS)

/**
 * Spawn protection for HvH respawns.
 * Invulnerable while inside their own base, and for a short grace after first stepping out of it.
 * Firing a gun, a melee attack or using a held item (priming a grenade) ends it at once.
 */
/datum/component/clash_spawn_guard
	dupe_mode = COMPONENT_DUPE_HIGHLANDER
	/// How long protection lasts after leaving base
	var/grace
	var/grace_timer
	var/cap_timer

/datum/component/clash_spawn_guard/Initialize(grace)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	src.grace = grace

/datum/component/clash_spawn_guard/RegisterWithParent()
	var/mob/living/guarded = parent
	guarded.grant_spawn_protection(CLASH_SPAWN_GUARD_CAP)
	guarded.add_filter("clash_spawn_guard", 2, outline_filter(1, "#ffffffb0"))
	RegisterSignal(guarded, list(COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_MELEE_ATTACK, COMSIG_MOB_DEATH), PROC_REF(on_break))
	RegisterSignal(guarded, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	cap_timer = addtimer(CALLBACK(src, PROC_REF(expire)), CLASH_SPAWN_GUARD_CAP, TIMER_STOPPABLE)
	if(!in_own_base())
		start_grace()

/datum/component/clash_spawn_guard/UnregisterFromParent()
	var/mob/living/guarded = parent
	UnregisterSignal(guarded, list(COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_MELEE_ATTACK, COMSIG_MOB_DEATH, COMSIG_MOVABLE_MOVED))
	guarded.end_spawn_protection()
	guarded.remove_filter("clash_spawn_guard")

/datum/component/clash_spawn_guard/Destroy(force)
	deltimer(grace_timer)
	deltimer(cap_timer)
	return ..()

/datum/component/clash_spawn_guard/proc/in_own_base()
	var/mob/living/guarded = parent
	var/area/clash_arena/here = get_area(guarded)
	return istype(here) && here.clash_faction && here.clash_faction == guarded.faction

/datum/component/clash_spawn_guard/proc/start_grace()
	if(grace_timer)
		return
	if(!grace)
		expire()
		return
	grace_timer = addtimer(CALLBACK(src, PROC_REF(expire)), grace, TIMER_STOPPABLE)

/datum/component/clash_spawn_guard/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	if(!grace_timer && !in_own_base())
		start_grace()

/datum/component/clash_spawn_guard/proc/on_break(datum/source)
	SIGNAL_HANDLER
	expire()

/datum/component/clash_spawn_guard/proc/expire()
	var/mob/living/guarded = parent
	if(guarded.stat != DEAD)
		guarded.balloon_alert(guarded, "spawn protection over")
	qdel(src)

#undef CLASH_SPAWN_GUARD_CAP

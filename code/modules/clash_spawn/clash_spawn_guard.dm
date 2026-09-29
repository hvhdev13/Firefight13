/datum/component/clash_spawn_guard
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS
	var/duration
	var/expire_timer

/datum/component/clash_spawn_guard/Initialize(duration)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	src.duration = duration

/datum/component/clash_spawn_guard/RegisterWithParent()
	var/mob/living/guarded = parent
	guarded.status_flags |= RECENTSPAWN|GODMODE
	guarded.add_filter("clash_spawn_guard", 2, outline_filter(1, "#ffffffb0"))
	RegisterSignal(guarded, list(COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_MELEE_ATTACK, COMSIG_MOB_DEATH), PROC_REF(on_break))
	RegisterSignal(guarded, list(COMSIG_LIVING_FLAMER_CROSSED, COMSIG_LIVING_FLAMER_FLAMED), PROC_REF(on_flamed))
	restart()

/datum/component/clash_spawn_guard/UnregisterFromParent()
	var/mob/living/guarded = parent
	UnregisterSignal(guarded, list(COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_MELEE_ATTACK, COMSIG_MOB_DEATH, COMSIG_LIVING_FLAMER_CROSSED, COMSIG_LIVING_FLAMER_FLAMED))
	guarded.status_flags &= ~(RECENTSPAWN|GODMODE)
	guarded.remove_filter("clash_spawn_guard")

/datum/component/clash_spawn_guard/InheritComponent(datum/component/new_guard, i_am_original, duration)
	src.duration = duration
	restart()

/datum/component/clash_spawn_guard/proc/restart()
	deltimer(expire_timer)
	expire_timer = addtimer(CALLBACK(src, PROC_REF(expire)), duration, TIMER_STOPPABLE)

/datum/component/clash_spawn_guard/proc/on_flamed(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_NO_IGNITE

/datum/component/clash_spawn_guard/Destroy(force)
	deltimer(expire_timer)
	return ..()

/datum/component/clash_spawn_guard/proc/on_break(datum/source)
	SIGNAL_HANDLER
	expire()

/datum/component/clash_spawn_guard/proc/expire()
	var/mob/living/guarded = parent
	if(guarded.stat != DEAD)
		guarded.balloon_alert(guarded, "spawn protection over")
	qdel(src)

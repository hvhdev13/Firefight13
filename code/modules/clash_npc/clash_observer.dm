SUBSYSTEM_DEF(clash_observer)
	name = "Clash Observer"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_observer/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_MODE_PREGAME_LOBBY, PROC_REF(add_missing_observer_start))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_observer/proc/add_missing_observer_start()
	SIGNAL_HANDLER
	if(length(GLOB.observer_starts))
		return
	var/obj/effect/landmark/late_join/spawn_point = locate() in GLOB.landmarks_list
	if(spawn_point)
		new /obj/effect/landmark/observer_start(spawn_point.loc)

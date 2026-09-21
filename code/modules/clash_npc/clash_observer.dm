GLOBAL_VAR_INIT(clash_observer_fallback_armed, FALSE)

/obj/effect/landmark/late_join/Initialize(mapload, ...)
	. = ..()
	if(GLOB.clash_observer_fallback_armed)
		return
	GLOB.clash_observer_fallback_armed = TRUE
	RegisterSignal(SSdcs, COMSIG_GLOB_MODE_PREGAME_LOBBY, PROC_REF(add_missing_observer_start))

/obj/effect/landmark/late_join/proc/add_missing_observer_start()
	SIGNAL_HANDLER
	if(!length(GLOB.observer_starts))
		new /obj/effect/landmark/observer_start(loc)

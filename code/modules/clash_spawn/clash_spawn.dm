GLOBAL_LIST_INIT(clash_fed_spawn_maps, list(MAP_TDM_JUNGLE))

/proc/clash_fed_spawns()
	return (SSmapping.configs[GROUND_MAP]?.map_name in GLOB.clash_fed_spawn_maps)

SUBSYSTEM_DEF(clash_spawn)
	name = "Clash Spawn"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_spawn/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(on_mob_logged_in))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_spawn/proc/on_mob_logged_in(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(ishuman(new_mob) && clash_fed_spawns())
		RegisterSignal(new_mob, COMSIG_POST_SPAWN_UPDATE, PROC_REF(on_spawned), override = TRUE)

/datum/controller/subsystem/clash_spawn/proc/on_spawned(mob/living/carbon/human/spawned)
	SIGNAL_HANDLER
	UnregisterSignal(spawned, COMSIG_POST_SPAWN_UPDATE)
	spawned.nutrition = NUTRITION_NORMAL

/// Team Deathmatch: small arena rules, reached through the TDM map configs
/datum/game_mode/extended/faction_clash/hvh/tdm
	name = GAMEMODE_TDM
	config_tag = GAMEMODE_TDM
	// Only reached through a map's force_mode, never by the gamemode vote
	fed_spawns = TRUE
	kill_limit = 50
	countdown_time = 20 SECONDS
	spawn_protection = 3 SECONDS

/datum/game_mode/extended/faction_clash/hvh/tdm/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_round_minutes)
		round_time_limit = ground.tdm_round_minutes MINUTES
	if(!isnull(ground?.tdm_respawn_seconds))
		respawn_cooldown = ground.tdm_respawn_seconds SECONDS
	if(!isnull(ground?.tdm_kill_limit))
		kill_limit = ground.tdm_kill_limit
	if(!isnull(ground?.tdm_countdown_seconds))
		countdown_time = ground.tdm_countdown_seconds SECONDS
	if(!isnull(ground?.tdm_spawn_protection_seconds))
		spawn_protection = ground.tdm_spawn_protection_seconds SECONDS
	log_debug("TDM: [ground?.map_name || "unknown map"], [round_time_limit / 600] minutes, first to [kill_limit || "none"], [respawn_cooldown / 10]s respawn, [countdown_time / 10]s countdown, [spawn_protection / 10]s spawn protection")
	return ..()

/// Team Deathmatch: small arena rules, reached through the TDM map configs
/datum/game_mode/extended/faction_clash/hvh/tdm
	name = GAMEMODE_TDM
	config_tag = GAMEMODE_TDM
	// Only reached through a map's force_mode, never by the gamemode vote
	fed_spawns = TRUE
	use_kits = TRUE
	round_time_limit = 10 MINUTES
	matches_per_round = 3
	kill_limit = 25
	countdown_time = 20 SECONDS
	spawn_protection = 3 SECONDS
	idle_limit = 3 MINUTES

/datum/game_mode/extended/faction_clash/hvh/tdm/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_match_minutes)
		round_time_limit = ground.tdm_match_minutes MINUTES
	if(ground?.tdm_matches)
		matches_per_round = ground.tdm_matches
	if(!isnull(ground?.tdm_respawn_seconds))
		respawn_cooldown = ground.tdm_respawn_seconds SECONDS
	if(!isnull(ground?.tdm_kill_limit))
		kill_limit = ground.tdm_kill_limit
	if(!isnull(ground?.tdm_countdown_seconds))
		countdown_time = ground.tdm_countdown_seconds SECONDS
	if(!isnull(ground?.tdm_spawn_protection_seconds))
		spawn_protection = ground.tdm_spawn_protection_seconds SECONDS
	log_debug("TDM: [ground?.map_name || "unknown map"], best of [matches_per_round], [round_time_limit / 600] minute matches, first to [kill_limit || "none"], [respawn_cooldown / 10]s respawn, [countdown_time / 10]s countdown, [spawn_protection / 10]s spawn protection")
	return ..()

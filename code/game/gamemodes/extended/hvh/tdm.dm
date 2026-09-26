/// Team Deathmatch: small arena rules, reached through the TDM map configs
/datum/game_mode/extended/faction_clash/hvh/tdm
	name = GAMEMODE_TDM
	config_tag = GAMEMODE_TDM
	// Only reached through a map's force_mode, never by the gamemode vote
	fed_spawns = TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_round_minutes)
		round_time_limit = ground.tdm_round_minutes MINUTES
	if(!isnull(ground?.tdm_respawn_seconds))
		respawn_cooldown = ground.tdm_respawn_seconds SECONDS
	log_debug("TDM: [ground?.map_name || "unknown map"], [round_time_limit / 600] minutes, [respawn_cooldown / 10]s respawn")
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm
	name = GAMEMODE_TDM
	config_tag = GAMEMODE_TDM
	fed_spawns = TRUE
	use_kits = TRUE
	round_time_limit = 10 MINUTES
	matches_per_round = 3
	kill_limit = 40
	countdown_time = 20 SECONDS
	spawn_protection = 5 SECONDS
	idle_limit = 10 MINUTES
	arena_rules = TRUE
	progression = TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_match_minutes)
		round_time_limit = ground.tdm_match_minutes MINUTES
	if(ground?.tdm_matches)
		matches_per_round = ground.tdm_matches
	if(!isnull(ground?.tdm_respawn_seconds))
		respawn_cooldown = ground.tdm_respawn_seconds SECONDS
	if(kill_limit && !isnull(ground?.tdm_kill_limit))
		kill_limit = ground.tdm_kill_limit
	if(!isnull(ground?.tdm_countdown_seconds))
		countdown_time = ground.tdm_countdown_seconds SECONDS
	if(!isnull(ground?.tdm_spawn_protection_seconds))
		spawn_protection = ground.tdm_spawn_protection_seconds SECONDS
	log_debug("TDM: [ground?.map_name || "unknown map"], best of [matches_per_round], [round_time_limit / 600] minute matches, first to [kill_limit || "none"], [respawn_cooldown / 10]s respawn, [countdown_time / 10]s countdown, [spawn_protection / 10]s spawn protection")
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/get_welcome_rules()
	if(type != /datum/game_mode/extended/faction_clash/hvh/tdm)
		return ..()
	return list(
		"[matches_per_round] match\s per round.",
		"First team to [kill_limit] kills wins, otherwise the team with the most kills when time runs out wins.",
		"Respawn enabled.",
		"Bots fill lowpop and have a grey \[BOT\] tag and a chevron marker. A kill on a player scores 1, a kill on a bot scores 0.5, whoever makes it. Kills on bots give 25% of regular XP.",
	)

/datum/game_mode/extended/faction_clash/hvh/tdm/get_welcome_tagline()
	if(type == /datum/game_mode/extended/faction_clash/hvh/tdm)
		return "Kill. Respawn. Repeat."
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/roundend_ceasefire()
	var/result = get_round_result_line()
	marine_announcement("[finish_reason]. [result]\n\nVote for the next mode, then the map. The server restarts 15 seconds after the votes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("[finish_reason]. [result]\n\nVote for the next mode, then the map. The server restarts 15 seconds after the votes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

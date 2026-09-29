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
	idle_limit = 3 MINUTES
	arena_rules = TRUE

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
		"First team to [kill_limit] kills wins or with the most kills when time runs out wins.",
		"You can respawn [respawn_cooldown / 10] seconds after dying using the Respawn button in the center of your screen.",
		"Players named \[BOT\] are bots. Kills on bots and by bots do not count toward the score.",
	)

/datum/game_mode/extended/faction_clash/hvh/tdm/roundend_ceasefire()
	var/result = get_round_result_line()
	marine_announcement("[finish_reason]. [result]\n\nFinal scores in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("[finish_reason]. [result]\n\nFinal scores in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

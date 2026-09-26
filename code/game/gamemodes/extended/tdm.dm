/datum/game_mode/extended/faction_clash/cm_vs_upp/tdm
	name = GAMEMODE_TDM
	config_tag = GAMEMODE_TDM
	// Only reached through a map's force_mode, never by the gamemode vote
	votable = FALSE
	fed_spawns = TRUE
	landing_ceasefire = FALSE

/datum/game_mode/extended/faction_clash/cm_vs_upp/tdm/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_round_minutes)
		round_time_limit = ground.tdm_round_minutes MINUTES
	if(!isnull(ground?.tdm_respawn_seconds))
		respawn_cooldown = ground.tdm_respawn_seconds SECONDS
	log_debug("TDM: [ground?.map_name || "unknown map"], [round_time_limit / 600] minutes, [respawn_cooldown / 10]s respawn")
	return ..()

/datum/game_mode/extended/faction_clash/cm_vs_upp/tdm/deleyed_announce()
	var/minutes = round_time_limit / 600
	marine_announcement("Team Deathmatch is live. Most kills after [minutes] minutes wins.\n\nRespawns are open. The enemy staging area is shielded, do not waste time on it.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Team Deathmatch is live. Most kills after [minutes] minutes wins.\n\nRespawns are open. The enemy staging area is shielded, do not waste time on it.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/cm_vs_upp/tdm/announce_ceasefire()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/result
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR)
			result = "USCM wins [uscm] to [upp]."
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			result = "UPP wins [upp] to [uscm]."
		else
			result = "Draw at [uscm] each."
	marine_announcement("Time. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Time. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/cm_vs_upp/tdm/announce_final_result()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("Match over. USCM victory, [uscm] to [upp].", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. USCM victory, [uscm] to [upp].", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("Match over. UPP victory, [upp] to [uscm].", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. UPP victory, [upp] to [uscm].", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		else
			marine_announcement("Match over. Draw, [uscm] each.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. Draw, [uscm] each.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

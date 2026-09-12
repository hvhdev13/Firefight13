/// How long to delay the round completion (command is immediately notified)
#define ROUND_END_DELAY (2 MINUTES)

/datum/game_mode/extended/faction_clash/cm_vs_upp
	name = GAMEMODE_FACTION_CLASH_UPP_CM
	config_tag = GAMEMODE_FACTION_CLASH_UPP_CM
	flags_round_type = MODE_THUNDERSTORM|MODE_FACTION_CLASH
	starting_round_modifiers = list(
		/datum/gamemode_modifier/blood_optimization,
		/datum/gamemode_modifier/defib_past_armor,
		/datum/gamemode_modifier/disable_combat_cas,
		/datum/gamemode_modifier/disable_ib,
		/datum/gamemode_modifier/disable_mortar,
		/datum/gamemode_modifier/disable_ob,
		/datum/gamemode_modifier/disable_attacking_corpses,
		/datum/gamemode_modifier/disable_long_range_sentry,
		/datum/gamemode_modifier/disable_stripdrag_enemy,
		/datum/gamemode_modifier/indestructible_splints,
		/datum/gamemode_modifier/mortar_laser_warning,
		/datum/gamemode_modifier/no_body_c4,
		/datum/gamemode_modifier/heavy_specialists,
		/datum/gamemode_modifier/weaker_explosions_fire,
	)

	taskbar_icon = 'icons/taskbar/gml_hvh.png'
	var/upp_ship = "ssv_rostock.dmm"
	var/round_time_limit = 90 MINUTES
	var/scoring_started = FALSE
	var/list/faction_kills = list()
	var/list/faction_deaths = list()
	var/list/player_scores = list()
	var/list/environment_kills = list()

/datum/game_mode/extended/faction_clash/cm_vs_upp/pre_setup()
	. = ..()
	GLOB.round_should_check_for_win = FALSE

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/start_round_timer()
	if(scoring_started)
		return
	scoring_started = TRUE
	addtimer(CALLBACK(src, PROC_REF(round_time_expired)), round_time_limit)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/score_kill(faction, mob_name)
	if(faction)
		faction_kills[faction] = (faction_kills[faction] || 0) + 1
	if(mob_name)
		var/list/entry = player_scores[mob_name]
		if(!entry)
			entry = list("kills" = 0, "deaths" = 0, "faction" = faction)
			player_scores[mob_name] = entry
		entry["kills"] += 1

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/score_death(faction, mob_name, cause)
	if(faction)
		faction_deaths[faction] = (faction_deaths[faction] || 0) + 1
	if(mob_name)
		var/list/entry = player_scores[mob_name]
		if(!entry)
			entry = list("kills" = 0, "deaths" = 0, "faction" = faction)
			player_scores[mob_name] = entry
		entry["deaths"] += 1
	if(cause)
		environment_kills[cause] = (environment_kills[cause] || 0) + 1

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/round_time_expired()
	if(round_finished)
		return
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	if(uscm > upp)
		round_finished = MODE_INFESTATION_M_MAJOR
	else if(upp > uscm)
		round_finished = MODE_FACTION_CLASH_UPP_MAJOR
	else
		round_finished = MODE_FACTION_CLASH_DRAW
	roundend_ceasefire()
	SSticker.roundend_check_paused = TRUE
	addtimer(VARSET_CALLBACK(SSticker, roundend_check_paused, FALSE), ROUND_END_DELAY)


/datum/game_mode/extended/faction_clash/cm_vs_upp/get_roles_list()
	return GLOB.ROLES_CM_VS_UPP

/datum/game_mode/extended/faction_clash/cm_vs_upp/post_setup()
	. = ..()
	start_round_timer()
	SSweather.force_weather_holder(/datum/weather_ss_map_holder/faction_clash)
	for(var/area/area in GLOB.all_areas)
		if(is_mainship_level(area.z))
			continue
		area.base_lighting_alpha = 150
		area.update_base_lighting()

/datum/game_mode/extended/faction_clash/cm_vs_upp/process()
	if(--round_started > 0)
		return FALSE //Initial countdown, just to be safe, so that everyone has a chance to spawn before we check anything.
	. = ..()
	if(!round_finished)
		if(++round_checkwin >= 5) //Only check win conditions every 5 ticks.
			if(GLOB.round_should_check_for_win)
				check_win()
			round_checkwin = 0


/datum/game_mode/extended/faction_clash/cm_vs_upp/check_win()
	return

/datum/game_mode/extended/faction_clash/cm_vs_upp/check_finished()
	if(round_finished)
		return TRUE

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/roundend_ceasefire()
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("ALERT: USCM ground force overrun scenario in progress. Automated command directive issued, all USCM personnel are ordered to evacuate combat zone.\n\nOpposing Force have issued a ceasefire, risk of capture of USCM personnel by opposing force is high, avoid contact and evade capture.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy force are combat inoperative, enemy force are conducting an evacuation of the operations zone.\n\nA ceasefire is in effect. Union forces are directed to attempt to capture fleeing enemy force personnel.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_UPP_MINOR)
			marine_announcement("ALERT: USCM ground force overrun scenario in progress. Automated command directive issued, all USCM personnel are ordered to evacuate combat zone.\n\nOpposing Force have issued a ceasefire, risk of capture of USCM personnel by opposing force is high, avoid contact and evade capture.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy force are combat inoperative, enemy force are conducting an evacuation of the operations zone.\n\nA ceasefire is in effect. Union forces are directed to attempt to capture fleeing enemy force personnel.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("ALERT: Opposing force are conducting emergency evacuation of the operations zone. Confidence is high that opposing forces are retreating from the planet.\n\nCeasefire is in effect to minimise non-combatant casualties, ground forces are directed to intercept and detain retreating opposing forces\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Unsustainable combat losses noted. Automated strategic reposition order is now in effect. All Union combat personnel are to return to dropships and re-deploy to the SSV Rostock.\n\nEnemy force have instituted a ceasefire, exploit this to assist in evading capture.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MINOR)
			marine_announcement("ALERT: Opposing force are conducting emergency evacuation of the operations zone. Confidence is high that opposing forces are retreating from the planet.\n\nCeasefire is in effect to minimise non-combatant casualties, ground forces are directed to intercept and detain retreating opposing forces.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Unsustainable combat losses noted. Automated strategic reposition order is now in effect. All Union combat personnel are to return to dropships and re-deploy to the SSV Rostock.\n\nEnemy force have instituted a ceasefire, exploit this to assist in evading capture.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Further information pending in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Additional facts pending in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)


/datum/game_mode/extended/faction_clash/cm_vs_upp/declare_completion()
	announce_ending()
	var/musical_track
	var/end_icon = "draw"
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_major"
		if(MODE_FACTION_CLASH_UPP_MINOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_minor"
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/winning_triumph1.ogg','sound/theme/winning_triumph2.ogg','sound/theme/winning_triumph3.ogg')
			end_icon = "marine_major"
		if(MODE_INFESTATION_M_MINOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/neutral_hopeful1.ogg','sound/theme/neutral_hopeful2.ogg')
			end_icon = "marine_minor"
		if(MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: Inconclusive combat outcome. Unable to assess tactical or strategic situation.\n\nDispatching automated request to High Command for further directives.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Battle situation has developed not necessarily to the Unions advantage\n\nDispatching request for new directives to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			end_icon = "draw"
			musical_track = 'sound/theme/neutral_hopeful2.ogg'
		else
			end_icon = "draw"
			musical_track = 'sound/theme/neutral_hopeful2.ogg'
	var/sound/theme = sound(musical_track, channel = SOUND_CHANNEL_LOBBY)
	theme.status = SOUND_STREAM
	sound_to(world, theme)

	calculate_end_statistics()
	show_end_statistics(end_icon)

	declare_completion_announce_fallen_soldiers()
	declare_completion_announce_predators()
	declare_completion_announce_medal_awards()
	declare_fun_facts()
	announce_scoreboard()
	export_round_stats()

	return TRUE

/datum/game_mode/extended/faction_clash/cm_vs_upp/ds_first_landed(obj/docking_port/stationary/marine_dropship)
	if(round_started > 0) //we enter here on shipspawn but do not want this
		return
	.=..()
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	addtimer(CALLBACK(src,PROC_REF(ceasefire_warning)), 4 MINUTES)
	addtimer(CALLBACK(src,PROC_REF(ceasefire_end)), 5 MINUTES)
	addtimer(VARSET_CALLBACK(GLOB, round_should_check_for_win, TRUE), 15 MINUTES)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/ceasefire_warning()
	marine_announcement("Ceasefire ends in one minute.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire ends in one minute.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/ceasefire_end()
	marine_announcement("Ceasefire is over. Combat operations may commence.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire is over. Combat operations may commence.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = FALSE)
	GLOB.round_should_check_for_win = TRUE



/datum/game_mode/extended/faction_clash/cm_vs_upp/announce()
	. = ..()
	addtimer(CALLBACK(src,PROC_REF(deleyed_announce)), 10 SECONDS)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/deleyed_announce()
	marine_announcement("An automated distress call has been received from the local colony.\n\nAlert! Sensors have detected a Union of Progressive People's warship in orbit of colony. Enemy Vessel has refused automated hails and is entering lower-planetary orbit. High likelihood enemy vessel is preparing to deploy dropships to local colony. Authorization to interdict and repel hostile force from allied territory has been granted. Automated thawing of cryostasis marine reserves in progress.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Alert! Sensors have detected encroaching USCM vessel on an intercept course with local colony.\n\nIntelligence suggests this is the [MAIN_SHIP_NAME]. Confidence is high that USCM force is acting counter to Union interests in this area. Authorization to deploy ground forces to disrupt foreign power attempt to encroach on Union interests has been granted. Emergency awakening of cryostasis troop reserves in progress.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)


/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/announce_scoreboard()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/list/output = list("<br><h2>Final Score</h2>")
	output += "USCM [uscm] kills, [faction_deaths[FACTION_MARINE] || 0] losses<br>"
	output += "UPP [upp] kills, [faction_deaths[FACTION_UPP] || 0] losses<br>"

	var/list/ranked = list()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		if(entry["kills"] > 0 || entry["deaths"] > 0)
			ranked += list(list("name" = name, "kills" = entry["kills"], "deaths" = entry["deaths"], "faction" = entry["faction"]))
	for(var/i = 1 to length(ranked))
		for(var/j = i + 1 to length(ranked))
			var/list/x = ranked[i]
			var/list/y = ranked[j]
			if(y["kills"] > x["kills"])
				ranked[i] = y
				ranked[j] = x

	if(length(ranked))
		output += "<br><b>Top performers</b><br>"
		for(var/i = 1 to min(10, length(ranked)))
			var/list/entry = ranked[i]
			output += "[i]. [entry["name"]] ([entry["faction"]]) - [entry["kills"]] kills, [entry["deaths"]] deaths<br>"

	var/top_env, var/top_env_count = 0
	for(var/cause in environment_kills)
		if(environment_kills[cause] > top_env_count)
			top_env_count = environment_kills[cause]
			top_env = cause
	if(top_env)
		output += "<br>Most common cause of death: [top_env] ([top_env_count])<br>"
	if(GLOB.round_statistics)
		output += "Total shots fired: [GLOB.round_statistics.total_projectiles_fired]<br>"
		output += "Total revives: [GLOB.round_statistics.total_revives]<br>"
		output += "Friendly fire incidents: [GLOB.round_statistics.total_friendly_fire_instances]<br>"
	to_world(output.Join())

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/export_round_stats()
	if(!GLOB.round_statistics)
		return
	var/list/weapons = list()
	for(var/key in GLOB.round_statistics.weapon_stats_list)
		var/datum/entity/weapon_stats/weapon = GLOB.round_statistics.weapon_stats_list[key]
		if(!weapon.total_shots && !weapon.total_kills && !weapon.total_damage)
			continue
		weapons[weapon.name] = list(
			"shots" = weapon.total_shots || 0,
			"hits" = weapon.total_shots_hit || 0,
			"kills" = weapon.total_kills || 0,
			"damage" = weapon.total_damage || 0,
			"friendly_fire" = weapon.total_friendly_fire || 0,
		)
	var/list/players = list()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		players[name] = list("kills" = entry["kills"], "deaths" = entry["deaths"], "faction" = entry["faction"])

	var/list/payload = list(
		"round_id" = GLOB.round_id,
		"map" = SSmapping.configs[GROUND_MAP]?.map_name,
		"result" = round_finished,
		"length_minutes" = round((world.time - SSticker.round_start_time) / 600, 0.1),
		"faction_kills" = faction_kills,
		"faction_deaths" = faction_deaths,
		"causes_of_death" = environment_kills,
		"weapons" = weapons,
		"players" = players,
	)
	var/path = "data/hvh_stats/round_[GLOB.round_id || world.time].json"
	WRITE_FILE(file(path), json_encode(payload))

#undef ROUND_END_DELAY

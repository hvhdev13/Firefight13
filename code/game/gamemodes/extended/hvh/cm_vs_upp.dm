/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp
	name = GAMEMODE_FACTION_CLASH_UPP_CM
	config_tag = GAMEMODE_FACTION_CLASH_UPP_CM
	votable = FALSE
	map_vote_mode = GAMEMODE_FACTION_CLASH_UPP_CM
	score_label = "tickets"
	round_time_limit = 30 MINUTES
	var/upp_ship = "ssv_rostock.dmm"
	var/tickets = 200
	var/list/ticket_callouts_made = list()
	var/first_match_fallback = 20 MINUTES
	var/first_match_timer_id

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.fc_tickets)
		tickets = ground.fc_tickets
	if(ground?.fc_match_minutes)
		round_time_limit = ground.fc_match_minutes MINUTES
	log_debug("FC: [ground?.map_name || "unknown map"], [tickets] tickets a team, [round_time_limit / 600] minute cap")
	return ..()

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/can_start(bypass_checks = FALSE)
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground.disable_ship_map)
		var/fallback = ground.force_mode || GAMEMODE_TDM
		message_admins("Faction Clash cannot run on [ground.map_name] because it has no ships. The mode is now [fallback].")
		to_chat(world, SPAN_BOLDNOTICE("Faction Clash needs a map with ships. This round will be [fallback] instead."))
		GLOB.master_mode = fallback
		return FALSE
	return ..()

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/proc/tickets_left(faction)
	return max(0, tickets - (faction_deaths[faction] || 0))

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/get_match_score(faction)
	return tickets_left(faction)

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/get_round_tiebreak(faction)
	return tickets_left(faction)

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/get_score_limit()
	return tickets

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/get_limit_text()
	return "[tickets] tickets a team"

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/score_death(faction, mob_name, cause, owner_ckey)
	. = ..()
	if(!match_live || round_finished || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return
	update_score_huds()
	var/left = tickets_left(faction)
	if(left <= 0)
		addtimer(CALLBACK(src, PROC_REF(finish_match), "[faction == FACTION_MARINE ? "USCM" : "UPP"] ran out of tickets"), 1)
		return
	for(var/step in list(100, 50, 25, 10))
		if(left != step)
			continue
		var/list/made = ticket_callouts_made[faction]
		if(!made)
			made = list()
			ticket_callouts_made[faction] = made
		if(step in made)
			return
		made += step
		var/enemy = faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
		announce_to_faction(faction, "[step] tickets left. Every death counts.")
		announce_to_faction(enemy, "The enemy is down to [step] tickets.")
		return

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/admin_set_score(faction, score)
	faction_deaths[faction] = max(0, tickets - score)
	update_score_huds()
	if(tickets_left(faction) <= 0)
		finish_match("[faction == FACTION_MARINE ? "USCM" : "UPP"] ran out of tickets")

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/open_first_match()
	first_match_timer_id = addtimer(CALLBACK(src, PROC_REF(start_first_match)), first_match_fallback, TIMER_STOPPABLE)
	log_debug("HVH: waiting for the first landing, match starts by [first_match_fallback / 600] minutes at the latest")

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/proc/start_first_match()
	deltimer(first_match_timer_id)
	first_match_timer_id = null
	if(match_number || match_live || round_finished)
		return
	begin_countdown()

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/get_welcome_rules()
	. = ..()
	.[1] = "Each team has [tickets] tickets and every death costs one. A team out of tickets loses. Otherwise, after [round_time_limit / 600] minutes, the team with more tickets left wins."
	. += "The fight starts on the colony. Deploy by dropship from your ship. The first landing starts a five minute ceasefire, and the clock and scoring start when it ends."

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/announce_ceasefire()
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
		if(MODE_FACTION_CLASH_DRAW, MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Further information pending in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Additional facts pending in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)


/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/announce_final_result()
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_UPP_MINOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MINOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_DRAW, MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: Inconclusive combat outcome. Unable to assess tactical or strategic situation.\n\nDispatching automated request to High Command for further directives.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Battle situation has developed not necessarily to the Unions advantage\n\nDispatching request for new directives to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/ds_first_landed(obj/docking_port/stationary/marine_dropship)
	if(round_started > 0) //we enter here on shipspawn but do not want this
		return
	.=..()
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	deltimer(first_match_timer_id)
	first_match_timer_id = null
	addtimer(CALLBACK(src,PROC_REF(ceasefire_warning)), 4 MINUTES)
	addtimer(CALLBACK(src,PROC_REF(ceasefire_end)), 5 MINUTES)
	addtimer(VARSET_CALLBACK(GLOB, round_should_check_for_win, TRUE), 15 MINUTES)

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/proc/ceasefire_warning()
	marine_announcement("Ceasefire ends in one minute.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire ends in one minute.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/proc/ceasefire_end()
	marine_announcement("Ceasefire is over. Combat operations may commence.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire is over. Combat operations may commence.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = FALSE)
	GLOB.round_should_check_for_win = TRUE
	start_first_match()



/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/deleyed_announce()
	marine_announcement("An automated distress call has been received from the local colony.\n\nAlert! Sensors have detected a Union of Progressive People's warship in orbit of colony. Enemy Vessel has refused automated hails and is entering lower-planetary orbit. High likelihood enemy vessel is preparing to deploy dropships to local colony. Authorization to interdict and repel hostile force from allied territory has been granted. Automated thawing of cryostasis marine reserves in progress.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Alert! Sensors have detected encroaching USCM vessel on an intercept course with local colony.\n\nIntelligence suggests this is the [MAIN_SHIP_NAME]. Confidence is high that USCM force is acting counter to Union interests in this area. Authorization to deploy ground forces to disrupt foreign power attempt to encroach on Union interests has been granted. Emergency awakening of cryostasis troop reserves in progress.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

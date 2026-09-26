/// Faction Clash: the full-size UPP vs USCM operation, dropship landing ceasefire and the warship storyline
/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp
	name = GAMEMODE_FACTION_CLASH_UPP_CM
	config_tag = GAMEMODE_FACTION_CLASH_UPP_CM
	votable = TRUE
	var/upp_ship = "ssv_rostock.dmm"

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



/datum/game_mode/extended/faction_clash/hvh/cm_vs_upp/deleyed_announce()
	marine_announcement("An automated distress call has been received from the local colony.\n\nAlert! Sensors have detected a Union of Progressive People's warship in orbit of colony. Enemy Vessel has refused automated hails and is entering lower-planetary orbit. High likelihood enemy vessel is preparing to deploy dropships to local colony. Authorization to interdict and repel hostile force from allied territory has been granted. Automated thawing of cryostasis marine reserves in progress.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Alert! Sensors have detected encroaching USCM vessel on an intercept course with local colony.\n\nIntelligence suggests this is the [MAIN_SHIP_NAME]. Confidence is high that USCM force is acting counter to Union interests in this area. Authorization to deploy ground forces to disrupt foreign power attempt to encroach on Union interests has been granted. Emergency awakening of cryostasis troop reserves in progress.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

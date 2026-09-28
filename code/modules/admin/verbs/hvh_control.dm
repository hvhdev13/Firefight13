/// Admin controls for driving HvH matches, mostly for playtesting
/client/proc/hvh_control()
	set name = "HvH Control"
	set desc = "End or skip HvH matches, set scores, move objectives, toggle bots."
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode))
		to_chat(usr, SPAN_WARNING("This is not an HvH round."))
		return
	var/list/actions = list("End match now", "Skip countdown or break", "Set a team's score", "Toggle bots ([GLOB.clash_bots_enabled ? "on" : "off"])")
	if(clash_mode.can_rebuild_objectives())
		actions += list("Re-place objectives", "Jump to an objective")
	var/choice = tgui_input_list(usr, "What should happen?", "HvH Control", actions)
	if(!choice || SSticker.mode != clash_mode || clash_mode.round_finished)
		return
	switch(choice)
		if("End match now")
			if(!clash_mode.match_live)
				to_chat(usr, SPAN_WARNING("No match is being played right now."))
				return
			clash_mode.admin_tampered = TRUE
			clash_mode.finish_match("Ended by an admin")
		if("Skip countdown or break")
			if(clash_mode.intermission_end_time)
				clash_mode.end_intermission()
			else if(clash_mode.countdown_end_time)
				clash_mode.start_match()
			else if(!clash_mode.match_live && !clash_mode.match_number)
				// Faction Clash waiting on its first landing
				clash_mode.begin_countdown()
			else
				to_chat(usr, SPAN_WARNING("There is no countdown or break to skip."))
				return
		if("Set a team's score")
			var/team = tgui_input_list(usr, "Which team?", "HvH Control", list("USCM", "UPP"))
			if(!team)
				return
			var/faction = team == "USCM" ? FACTION_MARINE : FACTION_UPP
			var/score = tgui_input_number(usr, "New [clash_mode.score_label] for [team] this match.", "HvH Control", clash_mode.get_match_score(faction), 10000, 0)
			if(isnull(score) || !clash_mode.match_live)
				return
			clash_mode.admin_tampered = TRUE
			clash_mode.admin_set_score(faction, score)
			choice = "Set [team] [clash_mode.score_label] to [score]"
		if("Re-place objectives")
			clash_mode.rebuild_objectives()
		if("Jump to an objective")
			var/list/spots = clash_mode.get_objective_turfs()
			var/label = tgui_input_list(usr, "Jump to which?", "HvH Control", spots)
			var/turf/spot = spots[label]
			if(!spot)
				return
			var/client/admin = usr.client
			if(!isobserver(admin.mob))
				admin.admin_ghost()
			admin.mob.forceMove(spot)
			return
		else
			GLOB.clash_bots_enabled = !GLOB.clash_bots_enabled
			choice = "Bots [GLOB.clash_bots_enabled ? "enabled" : "disabled"]"
	message_admins("[key_name_admin(usr)] used HvH Control: [choice].")
	log_admin("[key_name(usr)] used HvH Control: [choice].")

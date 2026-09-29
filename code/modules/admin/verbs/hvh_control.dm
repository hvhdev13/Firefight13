#define CLASH_MODE_OVERRIDE_FILE "data/mode_override.txt"

/client/proc/hvh_control()
	set name = "HvH Control"
	set desc = "End or skip HvH matches, set scores, move objectives, open the bot panel."
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode))
		if(!SSticker.mode && (GLOB.master_mode in HVH_MODE_TAGS))
			hvh_change_mode()
			return
		to_chat(usr, SPAN_WARNING("This is not an HvH round."))
		return
	var/list/actions = list("End match now", "Skip countdown or break", "Set a team's score", "Bot Control Panel")
	if(clash_mode.can_rebuild_objectives())
		actions += list("Re-place objectives", "Jump to an objective")
	actions += "Change game mode"
	var/choice = tgui_input_list(usr, "What should happen?", "HvH Control", actions)
	if(choice == "Change game mode")
		hvh_change_mode()
		return
	if(choice == "Bot Control Panel")
		clash_bot_panel()
		return
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
	message_admins("[key_name_admin(usr)] used HvH Control: [choice].")
	log_admin("[key_name(usr)] used HvH Control: [choice].")

/client/proc/hvh_change_mode()
	if(!check_rights(R_EVENT))
		return
	var/pregame = !SSticker.mode
	if(pregame && SSticker.current_state != GAME_STATE_PREGAME)
		to_chat(usr, SPAN_WARNING("The server is setting up the round. Try again in a moment."))
		return
	var/datum/map_config/ground = pregame ? SSmapping.configs[GROUND_MAP] : (LAZYACCESS(SSmapping.next_map_configs, GROUND_MAP) || SSmapping.configs[GROUND_MAP])
	var/new_mode = tgui_input_list(usr, "Pick the mode for [pregame ? "this" : "the next"] round on [ground.map_name]. Now: [GLOB.master_mode].", "Change game mode", HVH_MODE_TAGS)
	if(!new_mode)
		return
	if(new_mode == GAMEMODE_FACTION_CLASH_UPP_CM)
		var/block = get_clash_fc_block(ground, pregame)
		if(block)
			to_chat(usr, SPAN_WARNING(block))
			return
	var/note = new_mode == GAMEMODE_FACTION_CLASH_UPP_CM ? "" : " Team Deathmatch, King of the Hill, Domination and Capture the Flag place their zones and flag stands on any arena map by themselves."
	if(pregame)
		if(SSticker.mode || SSticker.current_state != GAME_STATE_PREGAME)
			to_chat(usr, SPAN_WARNING("The round started while you were choosing. Nothing was changed."))
			return
		GLOB.master_mode = new_mode
		message_admins("[key_name_admin(usr)] changed the mode for this round to [new_mode].[note]")
		log_admin("[key_name(usr)] changed the mode for this round to [new_mode].")
		to_world(SPAN_NOTICE("<b><i>The mode for this round is now: [new_mode]</i></b>"))
		for(var/mob/new_player/player as anything in GLOB.new_player_list)
			SStgui.update_uis(player)
		return
	var/when = tgui_alert(usr, "The mode can't change during a round. [new_mode] will run for the next round only, then the map's own mode comes back.", "Change game mode", list("Next round", "Restart now", "Cancel"))
	if(!when || when == "Cancel")
		return
	fdel(CLASH_MODE_OVERRIDE_FILE)
	WRITE_FILE(file(CLASH_MODE_OVERRIDE_FILE), new_mode)
	message_admins("[key_name_admin(usr)] set the mode for the next round to [new_mode].[note]")
	log_admin("[key_name(usr)] set the mode for the next round to [new_mode].")
	if(when == "Restart now")
		admin_holder?.restart()

/proc/get_clash_fc_block(datum/map_config/ground, pregame)
	if(pregame)
		if(!SSmapping.load_group_bounds["ssv_rostock"])
			return "Faction Clash needs the UPP ship, which only loads at world start, and [ground.map_name] started without it. Set it for the next round on a map with ships instead."
		return null
	if(ground.disable_ship_map)
		return "Faction Clash needs a map with ships. [ground.map_name] has none, so no dropship would ever land and the match would never start."
	if(ground.force_mode && ground.force_mode != GAMEMODE_FACTION_CLASH_UPP_CM)
		return "[ground.map_name] forces [ground.force_mode], so the UPP ship would not load for Faction Clash."
	return null

/proc/consume_clash_mode_override()
	if(!fexists(CLASH_MODE_OVERRIDE_FILE))
		return null
	var/new_mode = trim(file2text(CLASH_MODE_OVERRIDE_FILE))
	fdel(CLASH_MODE_OVERRIDE_FILE)
	if(!(new_mode in HVH_MODE_TAGS))
		log_game("HvH mode override '[new_mode]' is not an HvH mode, ignored.")
		return null
	if(!clash_map_fits_mode(SSmapping.configs[GROUND_MAP], new_mode))
		log_game("HvH mode override to [new_mode] ignored, [SSmapping.configs[GROUND_MAP].map_name] cannot run it.")
		message_admins("The one round mode override to [new_mode] was dropped because [SSmapping.configs[GROUND_MAP].map_name] cannot run it.")
		return null
	log_game("HvH mode override applied: [new_mode].")
	return new_mode

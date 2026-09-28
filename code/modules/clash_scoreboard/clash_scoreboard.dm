GLOBAL_DATUM_INIT(clash_scoreboard, /datum/clash_scoreboard, new)

/datum/clash_scoreboard

/datum/clash_scoreboard/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashScoreboard", "Scoreboard")
		ui.open()

/datum/clash_scoreboard/ui_state(mob/user)
	return GLOB.always_state

/datum/clash_scoreboard/ui_data(mob/user)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode))
		return list("active" = FALSE)
	return clash_mode.get_scoreboard_data(user)

/datum/clash_scoreboard/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("close")
			ui.close()
			return TRUE
		if("stats")
			GLOB.clash_career.tgui_interact(ui.user)
			return TRUE
		if("loadout")
			if(clash_uses_kits())
				open_clash_kit_screen(ui.user)
			return TRUE

/proc/open_clash_scoreboard(mob/user)
	if(!istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		to_chat(user, SPAN_WARNING("There is no scoreboard this round."))
		return
	GLOB.clash_scoreboard.tgui_interact(user)

/proc/toggle_clash_scoreboard(mob/user)
	if(!user || !istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		return FALSE
	var/datum/tgui/open_ui = SStgui.get_open_ui(user, GLOB.clash_scoreboard)
	if(open_ui)
		open_ui.close()
		return TRUE
	GLOB.clash_scoreboard.tgui_interact(user)
	return TRUE

/mob/verb/clash_scoreboard()
	set name = "Scoreboard"
	set category = "OOC"
	open_clash_scoreboard(src)

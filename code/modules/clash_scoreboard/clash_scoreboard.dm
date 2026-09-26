/// The one live scoreboard every viewer shares, its data is built per viewer
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

/// Opens the live scoreboard for user, if a HvH round is running
/proc/open_clash_scoreboard(mob/user)
	if(!istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		to_chat(user, SPAN_WARNING("There is no scoreboard this round."))
		return
	GLOB.clash_scoreboard.tgui_interact(user)

/mob/verb/clash_scoreboard()
	set name = "Scoreboard"
	set category = "OOC"
	open_clash_scoreboard(src)

/atom/movable/screen/faction_score/clicked(mob/user, list/mods)
	open_clash_scoreboard(user)
	return TRUE

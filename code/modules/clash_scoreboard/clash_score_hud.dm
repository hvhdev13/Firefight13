#define SCORE_PANEL_WIDTH 224
#define SCORE_PANEL_HEIGHT 36
#define SCORE_SIDE_WIDTH 78
#define SCORE_FILL_STEPS 24

GLOBAL_LIST_EMPTY(clash_score_panel_icons)

/proc/clash_tint(color, alpha)
	var/list/rgb = rgb2num(color)
	return rgb(rgb[1], rgb[2], rgb[3], alpha)

/proc/get_clash_score_panel_icon(left_color, right_color, left_step, right_step, own_side)
	var/key = "[left_color]|[right_color]|[left_step]|[right_step]|[own_side]"
	if(GLOB.clash_score_panel_icons[key])
		return GLOB.clash_score_panel_icons[key]
	var/icon/panel = icon('icons/effects/effects.dmi', "nothing")
	panel.Scale(SCORE_PANEL_WIDTH, SCORE_PANEL_HEIGHT)
	var/right_start = SCORE_PANEL_WIDTH - SCORE_SIDE_WIDTH + 1
	panel.DrawBox(rgb(8, 10, 13, 205), 2, 1, SCORE_PANEL_WIDTH - 1, SCORE_PANEL_HEIGHT)
	panel.DrawBox(rgb(8, 10, 13, 205), 1, 2, SCORE_PANEL_WIDTH, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(clash_tint(left_color, own_side == 1 ? 70 : 42), 2, 2, SCORE_SIDE_WIDTH, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(clash_tint(right_color, own_side == 2 ? 70 : 42), right_start, 2, SCORE_PANEL_WIDTH - 1, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(left_color, 2, 2, 4, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(right_color, SCORE_PANEL_WIDTH - 3, 2, SCORE_PANEL_WIDTH - 1, SCORE_PANEL_HEIGHT - 1)
	if(own_side == 1)
		panel.DrawBox(rgb(255, 255, 255, 150), 5, SCORE_PANEL_HEIGHT - 1, SCORE_SIDE_WIDTH, SCORE_PANEL_HEIGHT - 1)
	else if(own_side == 2)
		panel.DrawBox(rgb(255, 255, 255, 150), right_start, SCORE_PANEL_HEIGHT - 1, SCORE_PANEL_WIDTH - 4, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(rgb(255, 255, 255, 28), SCORE_SIDE_WIDTH + 1, 4, SCORE_SIDE_WIDTH + 1, SCORE_PANEL_HEIGHT - 3)
	panel.DrawBox(rgb(255, 255, 255, 28), right_start - 1, 4, right_start - 1, SCORE_PANEL_HEIGHT - 3)
	var/track_left = 8
	var/track_right = SCORE_SIDE_WIDTH - 3
	var/track_length = track_right - track_left + 1
	panel.DrawBox(rgb(255, 255, 255, 30), track_left, 4, track_right, 5)
	panel.DrawBox(rgb(255, 255, 255, 30), right_start + 3, 4, SCORE_PANEL_WIDTH - 8, 5)
	var/left_fill = round(track_length * left_step / SCORE_FILL_STEPS)
	if(left_fill > 0)
		panel.DrawBox(left_color, track_left, 4, track_left + left_fill - 1, 5)
	var/right_fill = round(track_length * right_step / SCORE_FILL_STEPS)
	if(right_fill > 0)
		panel.DrawBox(right_color, SCORE_PANEL_WIDTH - 8 - right_fill + 1, 4, SCORE_PANEL_WIDTH - 8, 5)
	GLOB.clash_score_panel_icons[key] = panel
	return panel

/proc/clash_score_text(text, x, y, width, height)
	var/mutable_appearance/label = mutable_appearance()
	label.maptext = text
	label.maptext_x = x
	label.maptext_y = y
	label.maptext_width = width
	label.maptext_height = height
	label.appearance_flags = RESET_COLOR|RESET_ALPHA|KEEP_APART
	return label

/datum/game_mode/extended/faction_clash/hvh/proc/build_score_panel()
	var/uscm = get_match_score(FACTION_MARINE)
	var/upp = get_match_score(FACTION_UPP)
	var/uscm_alive = count_side(FACTION_MARINE)
	var/upp_alive = count_side(FACTION_UPP)
	var/limit = get_score_limit()
	var/uscm_color = faction_color(FACTION_MARINE)
	var/upp_color = faction_color(FACTION_UPP)
	var/list/clock = get_clock_parts()
	var/right_start = SCORE_PANEL_WIDTH - SCORE_SIDE_WIDTH + 1
	var/text_width = SCORE_SIDE_WIDTH - 12
	var/name_y = SCORE_PANEL_HEIGHT - 12
	var/big = "font-family: \"VCR OSD Mono\"; font-size: 14px; -dm-text-outline: 1px black; vertical-align: bottom; color: #ffffff"
	var/small = "font-family: \"Small Fonts\"; font-size: 6px; -dm-text-outline: 1px black; vertical-align: bottom"
	var/list/texts = list()
	texts += clash_score_text("<span style='[small]; color: #e8ecef; text-align: left'>USCM</span>", 9, name_y, text_width, 10)
	texts += clash_score_text("<span style='[small]; color: #8a939c; text-align: right'>[score_label]</span>", 8, name_y, text_width, 10)
	texts += clash_score_text("<span style='[big]; text-align: right'>[uscm]</span>", 8, 7, text_width, 17)
	texts += clash_score_text("<span style='[small]; color: #9aa3ab; text-align: left'>[uscm_alive] alive</span>", 9, 7, text_width, 10)
	texts += clash_score_text("<span style='[small]; color: #e8ecef; text-align: right'>UPP</span>", right_start + 3, name_y, text_width, 10)
	texts += clash_score_text("<span style='[small]; color: #8a939c; text-align: left'>[score_label]</span>", right_start + 4, name_y, text_width, 10)
	texts += clash_score_text("<span style='[big]; text-align: left'>[upp]</span>", right_start + 4, 7, text_width, 17)
	texts += clash_score_text("<span style='[small]; color: #9aa3ab; text-align: right'>[upp_alive] alive</span>", right_start + 3, 7, text_width, 10)
	var/center_width = right_start - SCORE_SIDE_WIDTH - 2
	texts += clash_score_text("<span style='font-family: \"VCR OSD Mono\"; font-size: 12px; -dm-text-outline: 1px black; vertical-align: bottom; text-align: center; color: [clock[3] ? "#ff6a6a" : "#e8ecef"]'>[clock[1]]</span>", SCORE_SIDE_WIDTH + 1, 14, center_width, 18)
	texts += clash_score_text("<span style='[small]; text-align: center; color: #9aa3ab'>[clock[2]]</span>", SCORE_SIDE_WIDTH + 1, 4, center_width, 10)
	return list(
		"key" = "[uscm]|[upp]|[limit]|[clock[1]]|[clock[2]]|[uscm_alive]|[upp_alive]",
		"texts" = texts,
		"left_color" = uscm_color,
		"right_color" = upp_color,
		"left_step" = limit ? clamp(round(uscm / limit * SCORE_FILL_STEPS), 0, SCORE_FILL_STEPS) : 0,
		"right_step" = limit ? clamp(round(upp / limit * SCORE_FILL_STEPS), 0, SCORE_FILL_STEPS) : 0,
	)

/datum/game_mode/extended/faction_clash/hvh/proc/get_clock_parts()
	if(round_finished)
		return list("FINAL", "ROUND OVER", FALSE)
	if(intermission_end_time)
		var/pause = CEILING(max(0, intermission_end_time - world.time) / 10, 1)
		return list("0:[pause < 10 ? "0" : ""][pause]", "NEXT MATCH", FALSE)
	if(countdown_end_time)
		var/hold = CEILING(max(0, countdown_end_time - world.time) / 10, 1)
		return list("0:[hold < 10 ? "0" : ""][hold]", "GET READY", TRUE)
	if(!match_live || !round_end_time)
		return list("--:--", "WAITING", FALSE)
	var/seconds = CEILING(max(0, round_end_time - world.time) / 10, 1)
	var/label = matches_per_round > 1 ? "MATCH [match_number]/[matches_per_round]" : "TIME LEFT"
	return list("[floor(seconds / 60)]:[seconds % 60 < 10 ? "0" : ""][seconds % 60]", label, seconds <= 60)

/atom/movable/screen/faction_score/proc/show_panel(list/state, mob/viewer)
	var/own_side = viewer.faction == FACTION_MARINE ? 1 : (viewer.faction == FACTION_UPP ? 2 : 0)
	var/key = "[state["key"]]|[own_side]"
	if(shown_panel == key)
		return
	shown_panel = key
	icon = get_clash_score_panel_icon(state["left_color"], state["right_color"], state["left_step"], state["right_step"], own_side)
	overlays = state["texts"]

/atom/movable/screen/faction_score/proc/hide_panel()
	shown_panel = null
	icon = null
	overlays.Cut()

#undef SCORE_PANEL_WIDTH
#undef SCORE_PANEL_HEIGHT
#undef SCORE_SIDE_WIDTH
#undef SCORE_FILL_STEPS

#define SCORE_CANVAS_WIDTH 224
#define SCORE_PANEL_WIDTH 200
#define SCORE_PANEL_HEIGHT 26
#define SCORE_PANEL_LEFT 12
#define SCORE_SIDE_WIDTH 68
#define SCORE_FILL_STEPS 24

GLOBAL_LIST_EMPTY(clash_score_panel_icons)

/proc/clash_tint(color, alpha)
	var/list/rgb = rgb2num(color)
	return rgb(rgb[1], rgb[2], rgb[3], alpha)

/proc/clash_score_pips(icon/panel, color, wins, needed, start_x, direction)
	for(var/index in 1 to needed)
		var/x = start_x + (index - 1) * 5 * direction
		panel.DrawBox(index <= wins ? color : rgb(255, 255, 255, 45), min(x, x + 2 * direction), SCORE_PANEL_HEIGHT - 6, max(x, x + 2 * direction), SCORE_PANEL_HEIGHT - 4)

/proc/get_clash_score_panel_icon(left_color, right_color, left_step, right_step, own_side, left_wins, right_wins, needed)
	var/key = "[left_color]|[right_color]|[left_step]|[right_step]|[own_side]|[left_wins]|[right_wins]|[needed]"
	if(GLOB.clash_score_panel_icons[key])
		return GLOB.clash_score_panel_icons[key]
	var/icon/panel = icon('icons/effects/effects.dmi', "nothing")
	panel.Scale(SCORE_CANVAS_WIDTH, SCORE_PANEL_HEIGHT)
	var/left = SCORE_PANEL_LEFT
	var/right = SCORE_PANEL_LEFT + SCORE_PANEL_WIDTH - 1
	var/left_end = left + SCORE_SIDE_WIDTH - 1
	var/right_start = right - SCORE_SIDE_WIDTH + 1
	panel.DrawBox(rgb(8, 10, 13, 215), left + 1, 1, right - 1, SCORE_PANEL_HEIGHT)
	panel.DrawBox(rgb(8, 10, 13, 215), left, 2, right, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(clash_tint(left_color, own_side == 1 ? 64 : 36), left + 1, 2, left_end, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(clash_tint(right_color, own_side == 2 ? 64 : 36), right_start, 2, right - 1, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(left_color, left, 2, left + 1, SCORE_PANEL_HEIGHT - 1)
	panel.DrawBox(right_color, right - 1, 2, right, SCORE_PANEL_HEIGHT - 1)
	if(own_side == 1)
		panel.DrawBox(rgb(255, 255, 255, 120), left + 2, SCORE_PANEL_HEIGHT - 1, left_end, SCORE_PANEL_HEIGHT - 1)
	else if(own_side == 2)
		panel.DrawBox(rgb(255, 255, 255, 120), right_start, SCORE_PANEL_HEIGHT - 1, right - 2, SCORE_PANEL_HEIGHT - 1)
	var/track_length = SCORE_SIDE_WIDTH - 6
	panel.DrawBox(rgb(255, 255, 255, 26), left + 4, 2, left + 3 + track_length, 2)
	panel.DrawBox(rgb(255, 255, 255, 26), right - 3 - track_length, 2, right - 4, 2)
	var/left_fill = round(track_length * left_step / SCORE_FILL_STEPS)
	if(left_fill > 0)
		panel.DrawBox(left_color, left + 4, 2, left + 3 + left_fill, 2)
	var/right_fill = round(track_length * right_step / SCORE_FILL_STEPS)
	if(right_fill > 0)
		panel.DrawBox(right_color, right - 3 - right_fill, 2, right - 4, 2)
	if(needed > 1)
		clash_score_pips(panel, left_color, left_wins, needed, left_end - 4, -1)
		clash_score_pips(panel, right_color, right_wins, needed, right_start + 2, 1)
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

/proc/clash_score_digits(score)
	var/text = "[score]"
	var/dot = findtext(text, ".")
	if(!dot)
		return text
	return "[copytext(text, 1, dot)]<span style='font-family: \"Small Fonts\"'>.</span>[copytext(text, dot + 1)]"

/datum/game_mode/extended/faction_clash/hvh/proc/get_panel_score(faction)
	if(!round_finished)
		return get_match_score(faction)
	return matches_per_round > 1 ? (match_wins[faction] || 0) : get_round_tiebreak(faction)

/datum/game_mode/extended/faction_clash/hvh/proc/build_score_panel()
	var/uscm = get_panel_score(FACTION_MARINE)
	var/upp = get_panel_score(FACTION_UPP)
	var/uscm_alive = count_side(FACTION_MARINE)
	var/upp_alive = count_side(FACTION_UPP)
	var/limit = get_score_limit()
	var/list/clock = get_clock_parts()
	var/needed = matches_per_round > 1 ? wins_needed() : 0
	var/left = SCORE_PANEL_LEFT
	var/right_start = SCORE_PANEL_LEFT + SCORE_PANEL_WIDTH - SCORE_SIDE_WIDTH
	var/text_width = SCORE_SIDE_WIDTH - 10
	var/big = "font-family: \"VCR OSD Mono\"; font-size: [max(length(replacetext("[uscm]", ".", "")), length(replacetext("[upp]", ".", ""))) >= 4 ? 11 : 14]px; -dm-text-outline: 1px black; vertical-align: middle; color: #ffffff"
	var/small = "font-family: \"Small Fonts\"; font-size: 6px; -dm-text-outline: 1px black; vertical-align: bottom"
	var/list/texts = list()
	texts += clash_score_text("<span style='[small]; color: #e8ecef; text-align: left'>USCM</span>", left + 5, 13, text_width, 10)
	if(shows_alive_count())
		texts += clash_score_text("<span style='[small]; color: #8a939c; text-align: left'>[uscm_alive] alive</span>", left + 5, 3, text_width, 10)
	texts += clash_score_text("<span style='[big]; text-align: right'>[clash_score_digits(uscm)]</span>", left + 5, 3, text_width, 22)
	texts += clash_score_text("<span style='[small]; color: #e8ecef; text-align: right'>UPP</span>", right_start + 5, 13, text_width, 10)
	if(shows_alive_count())
		texts += clash_score_text("<span style='[small]; color: #8a939c; text-align: right'>[upp_alive] alive</span>", right_start + 5, 3, text_width, 10)
	texts += clash_score_text("<span style='[big]; text-align: left'>[clash_score_digits(upp)]</span>", right_start + 5, 3, text_width, 22)
	var/center_x = left + SCORE_SIDE_WIDTH
	var/center_width = right_start - center_x
	texts += clash_score_text("<span style='font-family: \"VCR OSD Mono\"; font-size: 11px; -dm-text-outline: 1px black; vertical-align: bottom; text-align: center; color: [clock[3] ? "#ff6a6a" : "#e8ecef"]'>[clock[1]]</span>", center_x, 10, center_width, 16)
	texts += clash_score_text("<span style='[small]; text-align: center; color: #8a939c'>[clock[2]]</span>", center_x, 1, center_width, 10)
	return list(
		"key" = "[uscm]|[upp]|[limit]|[clock[1]]|[clock[2]]|[uscm_alive]|[upp_alive]|[match_wins[FACTION_MARINE]]|[match_wins[FACTION_UPP]]",
		"texts" = texts,
		"left_color" = faction_color(FACTION_MARINE),
		"right_color" = faction_color(FACTION_UPP),
		"left_step" = limit ? clamp(round(uscm / limit * SCORE_FILL_STEPS), 0, SCORE_FILL_STEPS) : 0,
		"right_step" = limit ? clamp(round(upp / limit * SCORE_FILL_STEPS), 0, SCORE_FILL_STEPS) : 0,
		"left_wins" = match_wins[FACTION_MARINE] || 0,
		"right_wins" = match_wins[FACTION_UPP] || 0,
		"needed" = needed,
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
	var/label = matches_per_round > 1 ? "MATCH [match_number] OF [matches_per_round]" : "TIME LEFT"
	return list("[floor(seconds / 60)]:[seconds % 60 < 10 ? "0" : ""][seconds % 60]", label, seconds <= 60)

/atom/movable/screen/faction_score/proc/show_panel(list/state, mob/viewer)
	var/own_side = viewer.faction == FACTION_MARINE ? 1 : (viewer.faction == FACTION_UPP ? 2 : 0)
	var/key = "[state["key"]]|[own_side]"
	if(shown_panel == key)
		return
	shown_panel = key
	icon = get_clash_score_panel_icon(state["left_color"], state["right_color"], state["left_step"], state["right_step"], own_side, state["left_wins"], state["right_wins"], state["needed"])
	overlays = state["texts"]

/atom/movable/screen/faction_score/proc/hide_panel()
	shown_panel = null
	icon = null
	overlays.Cut()

/client/var/atom/movable/screen/clash_final_count/clash_final_count

/atom/movable/screen/clash_final_count
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "CENTER-3:97,TOP-5"
	maptext_width = 160
	maptext_height = 64
	maptext_x = -64
	maptext_y = -16
	alpha = 0

/atom/movable/screen/clash_final_count/proc/show(seconds)
	maptext = "<span style='font-family: \"VCR OSD Mono\"; font-size: 28px; text-align: center; vertical-align: middle; -dm-text-outline: 2px #0a0c0f; color: [seconds ? "#ff5a4f" : "#ffffff"]'>0:[seconds < 10 ? "0" : ""][seconds]</span>"
	animate(src)
	transform = matrix(0.6, 0, 0, 0, 0.6, 0)
	alpha = 255
	animate(src, transform = matrix(1.3, 0, 0, 0, 1.3, 0), time = 3, easing = CUBIC_EASING|EASE_OUT)
	animate(transform = matrix(1.45, 0, 0, 0, 1.45, 0), time = 3)
	animate(transform = matrix(1.7, 0, 0, 0, 1.7, 0), alpha = 0, time = 3, easing = QUAD_EASING|EASE_IN)

/proc/clash_show_final_count(client/player, seconds)
	if(!player.clash_final_count)
		player.clash_final_count = new
	if(!(player.clash_final_count in player.screen))
		player.screen += player.clash_final_count
	player.clash_final_count.show(seconds)

/client/var/atom/movable/screen/clash_match_banner/clash_match_banner

/atom/movable/screen/clash_match_banner
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "CENTER-3:97,CENTER+2"
	maptext_width = 320
	maptext_height = 64
	maptext_x = -144
	maptext_y = -16
	alpha = 0

/atom/movable/screen/clash_match_banner/proc/show(title, color, detail)
	maptext = "<span style='text-align: center; vertical-align: middle; -dm-text-outline: 2px #0a0c0f'><span style='font-family: \"VCR OSD Mono\"; font-size: 26px; color: [color]'>[title]</span><br><span style='font-family: \"Small Fonts\"; font-size: 7px; color: #d0d6dc'>[detail]</span></span>"
	animate(src)
	transform = matrix(0.8, 0, 0, 0, 0.8, 0)
	alpha = 0
	animate(src, alpha = 255, transform = matrix(), time = 3, easing = CUBIC_EASING|EASE_OUT)
	animate(time = 35)
	animate(alpha = 0, time = 5)

/proc/clash_show_match_banner(client/player, title, color, detail)
	if(!player.clash_match_banner)
		player.clash_match_banner = new
	if(!(player.clash_match_banner in player.screen))
		player.screen += player.clash_match_banner
	player.clash_match_banner.show(title, color, detail)

/proc/clash_place_killfeed_line(atom/movable/screen/faction_killfeed/line, index, below_objectives)
	line.screen_loc = "CENTER-3,TOP-2:20"
	line.maptext_width = 640
	line.maptext_x = SCORE_PANEL_LEFT + SCORE_PANEL_WIDTH / 2 - line.maptext_width / 2
	line.maptext_y = -6 - index * 12 - (below_objectives ? 24 : 0)

#undef SCORE_CANVAS_WIDTH
#undef SCORE_PANEL_WIDTH
#undef SCORE_PANEL_HEIGHT
#undef SCORE_PANEL_LEFT
#undef SCORE_SIDE_WIDTH
#undef SCORE_FILL_STEPS

#define CLASH_AMMO_REFRESH (2 DECISECONDS)

/obj/item/weapon/gun/var/clash_ammo_readout = FALSE

/obj/item/weapon/gun/rifle/m41a
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/rifle/m41aMK1
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/rifle/lmg
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/smartgun
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/rifle/m4ra
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/lever_action/xm88
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/smg/m39
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/pistol/m4a3
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/pistol/mod88
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/pistol/vp78
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/pistol/m10
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/revolver/m44
	clash_ammo_readout = TRUE

/obj/item/weapon/gun/smartgun/upp
	clash_ammo_readout = FALSE

/obj/item/weapon/gun/smartgun/clf
	clash_ammo_readout = FALSE

/obj/item/weapon/gun/smartgun/rmc
	clash_ammo_readout = FALSE

/obj/item/weapon/gun/smartgun/l56a2
	clash_ammo_readout = FALSE

/client/var/atom/movable/screen/clash_ammo_counter/clash_ammo_counter

/atom/movable/screen/clash_ammo_counter
	name = "ammo"
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "EAST-3:24,2:7"
	maptext_width = 32
	maptext_height = 20
	maptext_y = 4
	var/frame_key

/atom/movable/screen/clash_ammo_counter/proc/update(mob/user, obj/item/weapon/gun/gun)
	var/datum/preferences/prefs = user.client.prefs
	var/style = user.faction == FACTION_UPP ? HUD_RED : prefs.UI_style
	if(!(style in GLOB.custom_human_huds))
		style = HUD_MIDNIGHT
	if(frame_key != "[style][prefs.UI_style_color]")
		frame_key = "[style][prefs.UI_style_color]"
		var/mutable_appearance/frame = mutable_appearance('icons/mob/hud/clash_ammo.dmi', style)
		frame.color = prefs.UI_style_color
		underlays = list(frame)
	if(alpha != prefs.UI_style_alpha)
		alpha = prefs.UI_style_alpha
	var/rounds = gun.current_mag?.current_rounds || 0
	var/fill = gun.current_mag?.max_rounds ? rounds / gun.current_mag.max_rounds : 0
	var/text = "<span style='text-align: center; vertical-align: bottom; font-family: \"VCR OSD Mono\"; font-size: 11px; color: [hsv_gradient(fill, 0, "#ff4030", 0.5, "#ffd23c", 1, "#4aa8ff")]; -dm-text-outline: 1px black'>[rounds]</span>"
	if(maptext != text)
		maptext = text

/datum/game_mode/extended/faction_clash/hvh/var/ammo_timer_id

/datum/game_mode/extended/faction_clash/hvh/proc/update_clash_ammo_counters()
	for(var/mob/player as anything in GLOB.player_list)
		var/client/player_client = player.client
		var/obj/item/weapon/gun/gun = player.get_active_hand()
		var/atom/movable/screen/clash_ammo_counter/counter = player_client?.clash_ammo_counter
		if(!player_client || !isgun(gun) || !gun.clash_ammo_readout || player.stat == DEAD || !player.hud_used?.hud_shown)
			if(counter && (counter in player_client.screen))
				player_client.remove_from_screen(counter)
			continue
		if(!counter)
			counter = new
			player_client.clash_ammo_counter = counter
		if(!(counter in player_client.screen))
			player_client.add_to_screen(counter)
		counter.update(player, gun)

/datum/game_mode/extended/faction_clash/hvh/proc/start_clash_ammo_counters()
	ammo_timer_id = addtimer(CALLBACK(src, PROC_REF(update_clash_ammo_counters)), CLASH_AMMO_REFRESH, TIMER_LOOP|TIMER_STOPPABLE)

#undef CLASH_AMMO_REFRESH

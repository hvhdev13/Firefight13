#define CHATBOX_ROWS 8
#define CHATBOX_MIN_ROWS 4
#define CHATBOX_MAX_ROWS 16
#define CHATBOX_ROW_HEIGHT 10
#define CHATBOX_HISTORY 50
#define CHATBOX_LINE_LIFE (10 SECONDS)
#define CHATBOX_TICK (1 SECONDS)
#define CHATBOX_WIDTH 320
#define CHATBOX_MIN_WIDTH 160
#define CHATBOX_MAX_WIDTH 640
#define CHATBOX_WIDTH_STEP 16
#define CHATBOX_LEFT 6
#define CHATBOX_BOTTOM 142
#define CHATBOX_TOGGLE_SIZE 11
#define CHATBOX_BAR_GAP 2
#define CHATBOX_ARROW_SIZE 11
#define CHATBOX_THUMB_MIN 4
#define CHATBOX_WHEEL_LINES 2
#define CHATBOX_TEXT_INDENT (CHATBOX_TOGGLE_SIZE + 4)
#define CHATBOX_FRAME_ALPHA_TYPING 3
#define CHATBOX_FRAME_ALPHA_RESIZING 140
#define CHATBOX_ALPHA_IDLE 90
#define CHATBOX_IDLE_FADE (5 DECISECONDS)
#define CHATBOX_COLOR_FRAME rgb(14, 17, 21)
#define CHATBOX_COLOR_BAR_FILL rgb(14, 17, 21, 140)
#define CHATBOX_COLOR_BAR_MARK rgb(106, 116, 124)
#define CHATBOX_COLOR_UNREAD rgb(240, 180, 40)
#define CHATBOX_COLOR_UNREAD_WASH rgb(240, 180, 40, 90)
#define CHATBOX_COLOR_TEXT "#e6e6e6"
#define CHATBOX_COLOR_LOCAL "#f0d98c"
#define CHATBOX_COLOR_ALL "#ffffff"
#define CHATBOX_COLOR_RADIO "#1fcc44"
#define CHATBOX_COLOR_LOOC "#f557b8"
#define CHATBOX_COLOR_DEAD "#e3c2ff"
#define COMSIG_KB_CLIENT_TEAM_DOWN "keybinding_client_team_down"

GLOBAL_DATUM(clash_chatbox_frame_icon, /icon)
GLOBAL_DATUM(clash_chatbox_grip_icon, /icon)
GLOBAL_DATUM(clash_chatbox_unread_icon, /icon)
GLOBAL_LIST_EMPTY(clash_chatbox_bar_icons)

/client/var/list/clash_chat_lines = list()
/client/var/clash_chat_typing = FALSE
/client/var/clash_chat_scroll = 0
/client/var/clash_chat_unread = FALSE
/client/var/clash_chat_rows = CHATBOX_ROWS
/client/var/clash_chat_width = CHATBOX_WIDTH
/client/var/clash_chat_resizing = FALSE
/client/var/clash_chat_idle = FALSE
/client/var/clash_chatbox_hidden
/client/var/atom/movable/screen/clash_chatbox/clash_chatbox
/client/var/atom/movable/screen/clash_chatbox_frame/clash_chatbox_frame
/client/var/atom/movable/screen/clash_chatbox_toggle/clash_chatbox_toggle
/client/var/atom/movable/screen/clash_chatbox_bar/clash_chatbox_bar
/client/var/atom/movable/screen/clash_chatbox_grip/clash_chatbox_grip

/datum/keybinding/client/communication/team
	hotkey_keys = list("U")
	classic_keys = list("Unbound")
	name = TEAM_CHANNEL
	full_name = "Team Chat"
	keybind_signal = COMSIG_KB_CLIENT_TEAM_DOWN

/atom/movable/screen/clash_chatbox
	name = ""
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	maptext_x = CHATBOX_TEXT_INDENT

/atom/movable/screen/clash_chatbox_frame
	name = ""
	color = CHATBOX_COLOR_FRAME
	layer = HUD_LAYER
	mouse_opacity = MOUSE_OPACITY_OPAQUE

/atom/movable/screen/clash_chatbox_frame/Initialize(mapload, ...)
	. = ..()
	icon = get_clash_chatbox_frame_icon()

/atom/movable/screen/clash_chatbox_frame/clicked(mob/user, list/mods)
	return TRUE

/atom/movable/screen/clash_chatbox_frame/MouseWheel(delta_x, delta_y, location, control, params)
	usr.client?.clash_chat_scroll_by(delta_y > 0 ? CHATBOX_WHEEL_LINES : -CHATBOX_WHEEL_LINES)

/atom/movable/screen/clash_chatbox_toggle
	name = "Toggle chat box"
	icon = null
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/shown_key

/atom/movable/screen/clash_chatbox_toggle/clicked(mob/user, list/mods)
	user.client?.clash_toggle_chatbox()
	return TRUE

/atom/movable/screen/clash_chatbox_grip
	name = "Resize chat box"
	icon = null
	mouse_opacity = MOUSE_OPACITY_OPAQUE

/atom/movable/screen/clash_chatbox_grip/Initialize(mapload, client/player)
	. = ..()
	icon = get_clash_chatbox_grip_icon()
	RegisterSignal(player, COMSIG_CLIENT_LMB_DRAG, PROC_REF(on_drag))
	RegisterSignal(player, COMSIG_CLIENT_VIEW_CHANGED, PROC_REF(on_view_change))

/atom/movable/screen/clash_chatbox_grip/proc/on_drag(client/source, atom/src_object, atom/over_object, params)
	SIGNAL_HANDLER
	if(src_object != src)
		return
	var/list/mods = params2list(params)
	source.clash_chatbox_resize_to(mods[SCREEN_LOC])

/atom/movable/screen/clash_chatbox_grip/proc/on_view_change(client/source)
	SIGNAL_HANDLER
	source.clash_chatbox_layout()

/atom/movable/screen/clash_chatbox_grip/clicked(mob/user, list/mods)
	return TRUE

/atom/movable/screen/clash_chatbox_grip/MouseDrop(over_object, src_location, over_location, src_control, over_control, params)
	var/client/player = usr.client
	if(!player)
		return
	var/list/mods = params2list(params)
	player.clash_chatbox_resize_to(mods[SCREEN_LOC])
	player.clash_chatbox_finish_resize()

/atom/movable/screen/clash_chatbox_bar
	name = "Chat history"
	icon = null
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/height
	var/shown_key
	var/thumb_middle

/atom/movable/screen/clash_chatbox_bar/clicked(mob/user, list/mods)
	var/client/player = user.client
	if(!player)
		return TRUE
	var/click_y = text2num(mods[ICON_Y])
	if(click_y > height - CHATBOX_ARROW_SIZE)
		player.clash_chat_scroll_by(1)
	else if(click_y <= CHATBOX_ARROW_SIZE)
		player.clash_chat_scroll_by(-1)
	else
		player.clash_chat_scroll_by(click_y > thumb_middle ? player.clash_chat_rows : -player.clash_chat_rows)
	return TRUE

/atom/movable/screen/clash_chatbox_bar/MouseWheel(delta_x, delta_y, location, control, params)
	usr.client?.clash_chat_scroll_by(delta_y > 0 ? CHATBOX_WHEEL_LINES : -CHATBOX_WHEEL_LINES)

/atom/movable/screen/clash_chatbox_bar/proc/update(total, scroll, rows)
	var/track = height - CHATBOX_ARROW_SIZE * 2
	var/thumb = track
	var/start = CHATBOX_ARROW_SIZE + 1
	if(total > rows)
		thumb = max(CHATBOX_THUMB_MIN, round(track * rows / total))
		start += round((track - thumb) * scroll / (total - rows))
	thumb_middle = start + thumb / 2
	var/key = "[height]-[start]-[thumb]"
	if(shown_key == key)
		return
	shown_key = key
	icon = get_clash_chatbox_bar_icon(height, start, thumb)

/proc/get_clash_chatbox_bar_icon(height, start, thumb)
	var/key = "[height]-[start]-[thumb]"
	if(GLOB.clash_chatbox_bar_icons[key])
		return GLOB.clash_chatbox_bar_icons[key]
	var/icon/bar = icon('icons/effects/effects.dmi', "nothing")
	bar.Scale(CHATBOX_TOGGLE_SIZE, height)
	bar.DrawBox(CHATBOX_COLOR_BAR_FILL, 1, 1, CHATBOX_TOGGLE_SIZE, height)
	var/middle = ceil(CHATBOX_TOGGLE_SIZE / 2)
	for(var/row in 0 to 2)
		bar.DrawBox(CHATBOX_COLOR_BAR_MARK, middle - row, height - 3 - row, middle + row, height - 3 - row)
		bar.DrawBox(CHATBOX_COLOR_BAR_MARK, middle - row, 3 + row, middle + row, 3 + row)
	bar.DrawBox(CHATBOX_COLOR_BAR_MARK, 3, start, CHATBOX_TOGGLE_SIZE - 2, start + thumb - 1)
	GLOB.clash_chatbox_bar_icons[key] = bar
	return bar

/proc/get_clash_chatbox_unread_icon()
	if(!GLOB.clash_chatbox_unread_icon)
		var/icon/button = icon(get_clash_radar_toggle_icon(FALSE))
		button.SwapColor(CHATBOX_COLOR_BAR_MARK, CHATBOX_COLOR_UNREAD)
		button.Blend(CHATBOX_COLOR_UNREAD_WASH, ICON_OVERLAY)
		GLOB.clash_chatbox_unread_icon = button
	return GLOB.clash_chatbox_unread_icon

/proc/get_clash_chatbox_grip_icon()
	if(!GLOB.clash_chatbox_grip_icon)
		var/icon/button = icon(get_clash_hud_button_icon())
		for(var/line in list(11, 14, 17))
			for(var/x in max(4, line - 9) to min(9, line - 4))
				button.DrawBox(CHATBOX_COLOR_BAR_MARK, x, line - x)
		GLOB.clash_chatbox_grip_icon = button
	return GLOB.clash_chatbox_grip_icon

/proc/get_clash_chatbox_frame_icon()
	if(!GLOB.clash_chatbox_frame_icon)
		var/icon/frame = icon('icons/effects/effects.dmi', "nothing")
		frame.DrawBox(rgb(255, 255, 255), 1, 1, world.icon_size, world.icon_size)
		GLOB.clash_chatbox_frame_icon = frame
	return GLOB.clash_chatbox_frame_icon

/datum/game_mode/extended/faction_clash/hvh/proc/start_clash_chat()
	addtimer(CALLBACK(src, PROC_REF(update_clash_chatboxes)), CHATBOX_TICK, TIMER_LOOP)
	for(var/client/player as anything in GLOB.clients)
		player.update_special_keybinds()
		player.tgui_say?.load()

/datum/game_mode/extended/faction_clash/hvh/proc/update_clash_chatboxes()
	for(var/client/player as anything in GLOB.clients)
		if(player.clash_chat_resizing && !player.holding_click)
			player.clash_chatbox_finish_resize()
		else if(player.clash_chat_typing && !player.tgui_say?.window_open)
			player.clash_chat_set_typing(FALSE)
		else
			player.clash_chatbox_update()

/client/proc/clash_say_channels()
	return clash_fast_medicine() ? list(TEAM_CHANNEL, ALL_CHANNEL) : list()

/client/proc/clash_chat_set_typing(typing)
	if(clash_chat_typing == typing)
		return
	clash_chat_typing = typing
	if(!typing)
		clash_chat_scroll = 0
		clash_chat_refresh()
	clash_chatbox_update()

/client/proc/clash_chat_refresh()
	for(var/index in max(1, length(clash_chat_lines) - clash_chat_rows + 1) to length(clash_chat_lines))
		var/list/line = clash_chat_lines[index]
		line["expiry"] = world.time + CHATBOX_LINE_LIFE

/client/proc/clash_chat_scroll_by(amount)
	var/scroll = clamp(clash_chat_scroll + amount, 0, max(0, length(clash_chat_lines) - clash_chat_rows))
	if(scroll == clash_chat_scroll)
		return
	clash_chat_scroll = scroll
	if(!scroll)
		clash_chat_refresh()
	clash_chatbox_update()

/client/proc/clash_toggle_chatbox()
	clash_chatbox_hidden = !clash_chatbox_hidden
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(progress)
		progress.chatbox = !clash_chatbox_hidden
		progress.save()
	if(!clash_chatbox_hidden)
		clash_chat_unread = FALSE
		clash_chat_refresh()
	clash_chatbox_update()

/client/proc/clash_chatbox_max_width()
	var/list/view_size = getviewsize(view)
	return clamp(view_size[1] * world.icon_size - CHATBOX_LEFT * 2, CHATBOX_MIN_WIDTH, CHATBOX_MAX_WIDTH)

/client/proc/clash_chatbox_create()
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	clash_chatbox_hidden = !!(progress && !progress.chatbox)
	if(progress?.chatbox_width)
		clash_chat_width = progress.chatbox_width
	if(progress?.chatbox_rows)
		clash_chat_rows = clamp(progress.chatbox_rows, CHATBOX_MIN_ROWS, CHATBOX_MAX_ROWS)
	clash_chatbox = new
	clash_chatbox_frame = new
	clash_chatbox_toggle = new
	clash_chatbox_bar = new
	clash_chatbox_grip = new(null, src)
	clash_chatbox_layout()

/client/proc/clash_chatbox_layout()
	clash_chat_width = clamp(clash_chat_width, CHATBOX_MIN_WIDTH, clash_chatbox_max_width())
	var/height = clash_chat_rows * CHATBOX_ROW_HEIGHT
	var/bar_height = height - CHATBOX_TOGGLE_SIZE - CHATBOX_BAR_GAP
	clash_chatbox.screen_loc = clash_chatbox_loc(0, 0)
	clash_chatbox.maptext_width = clash_chat_width - CHATBOX_TEXT_INDENT * 2
	clash_chatbox.maptext_height = height
	clash_chatbox_frame.transform = matrix(clash_chat_width / world.icon_size, 0, 0, 0, height / world.icon_size, 0)
	clash_chatbox_frame.screen_loc = clash_chatbox_loc((clash_chat_width - world.icon_size) * 0.5, (height - world.icon_size) * 0.5)
	clash_chatbox_toggle.screen_loc = clash_chatbox_loc(0, bar_height + CHATBOX_BAR_GAP)
	clash_chatbox_grip.screen_loc = clash_chatbox_loc(clash_chat_width - CHATBOX_TOGGLE_SIZE, height - CHATBOX_TOGGLE_SIZE)
	clash_chatbox_bar.screen_loc = clash_chatbox_loc(0, 0)
	clash_chatbox_bar.height = bar_height

/proc/clash_chatbox_loc(x, y)
	return "WEST:[CHATBOX_LEFT + x],SOUTH:[CHATBOX_BOTTOM + y]"

/client/proc/clash_chatbox_resize_to(screen_loc)
	if(!screen_loc || clash_chatbox_hidden)
		return
	var/list/pixel = params2screenpixel(screen_loc)
	var/grip_middle = CHATBOX_TOGGLE_SIZE * 0.5
	var/width = clamp(round(pixel[1] - CHATBOX_LEFT + grip_middle, CHATBOX_WIDTH_STEP), CHATBOX_MIN_WIDTH, clash_chatbox_max_width())
	var/rows = clamp(round((pixel[2] - CHATBOX_BOTTOM + grip_middle) / CHATBOX_ROW_HEIGHT, 1), CHATBOX_MIN_ROWS, CHATBOX_MAX_ROWS)
	if(clash_chat_resizing && width == clash_chat_width && rows == clash_chat_rows)
		return
	clash_chat_resizing = TRUE
	clash_chat_width = width
	clash_chat_rows = rows
	clash_chat_scroll = clamp(clash_chat_scroll, 0, max(0, length(clash_chat_lines) - rows))
	clash_chatbox_layout()
	clash_chatbox_update()

/client/proc/clash_chatbox_finish_resize()
	if(!clash_chat_resizing)
		return
	clash_chat_resizing = FALSE
	clash_chat_refresh()
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(progress)
		progress.chatbox_width = clash_chat_width
		progress.chatbox_rows = clash_chat_rows
		progress.save()
	clash_chatbox_update()

/client/proc/clash_chatbox_show(atom/movable/screen/part, shown)
	if(shown && !(part in screen))
		add_to_screen(part)
	else if(!shown && (part in screen))
		remove_from_screen(part)

/client/proc/clash_chatbox_update()
	if(!clash_fast_medicine() || !mob || isnewplayer(mob))
		for(var/atom/movable/screen/part as anything in list(clash_chatbox, clash_chatbox_frame, clash_chatbox_toggle, clash_chatbox_bar, clash_chatbox_grip))
			clash_chatbox_show(part, FALSE)
		return
	if(!clash_chatbox_toggle)
		clash_chatbox_create()
	clash_chatbox_show(clash_chatbox_toggle, TRUE)
	var/toggle_key = clash_chatbox_hidden ? (clash_chat_unread ? "unread" : "off") : "on"
	if(clash_chatbox_toggle.shown_key != toggle_key)
		clash_chatbox_toggle.shown_key = toggle_key
		clash_chatbox_toggle.icon = toggle_key == "unread" ? get_clash_chatbox_unread_icon() : get_clash_radar_toggle_icon(toggle_key == "on")
	var/total = length(clash_chat_lines)
	var/list/shown = list()
	for(var/index in max(1, total - clash_chat_scroll - clash_chat_rows + 1) to total - clash_chat_scroll)
		var/list/line = clash_chat_lines[index]
		if(clash_chat_scroll || clash_chat_typing || clash_chat_resizing || line["expiry"] > world.time)
			shown += line["text"]
	var/barred = !clash_chatbox_hidden && total
	clash_chatbox_show(clash_chatbox_bar, barred)
	if(barred)
		clash_chatbox_bar.update(total, clash_chat_scroll, clash_chat_rows)
	var/idle = !length(shown)
	clash_chatbox_show(clash_chatbox_grip, !clash_chatbox_hidden && !idle)
	clash_chatbox_grip.mouse_opacity = clash_chat_resizing ? MOUSE_OPACITY_TRANSPARENT : MOUSE_OPACITY_OPAQUE
	if(clash_chat_idle != idle)
		clash_chat_idle = idle
		animate(clash_chatbox_bar, alpha = idle ? CHATBOX_ALPHA_IDLE : 255, time = CHATBOX_IDLE_FADE)
	var/framed = !clash_chatbox_hidden && (clash_chat_typing || clash_chat_resizing)
	clash_chatbox_show(clash_chatbox_frame, framed)
	if(framed)
		clash_chatbox_frame.alpha = clash_chat_resizing ? CHATBOX_FRAME_ALPHA_RESIZING : CHATBOX_FRAME_ALPHA_TYPING
		clash_chatbox_frame.mouse_opacity = clash_chat_resizing ? MOUSE_OPACITY_TRANSPARENT : MOUSE_OPACITY_OPAQUE
	clash_chatbox_show(clash_chatbox, !clash_chatbox_hidden)
	if(clash_chatbox_hidden)
		return
	var/text = length(shown) ? "<span style='font-family: \"Small Fonts\"; font-size: 6px; vertical-align: bottom; color: [CHATBOX_COLOR_TEXT]; -dm-text-outline: 1px black'>[shown.Join("<br>")]</span>" : ""
	if(clash_chatbox.maptext != text)
		clash_chatbox.maptext = text

/proc/clash_chatbox_add(client/listener, client/sender, tag, tag_color, name, name_color, message)
	listener.clash_chat_lines += list(list(
		"expiry" = world.time + CHATBOX_LINE_LIFE,
		"text" = "<span style='color: [tag_color]'>\[[tag]\]</span> <span style='color: [name_color]'>[name]</span>: [message]",
	))
	if(length(listener.clash_chat_lines) > CHATBOX_HISTORY)
		listener.clash_chat_lines.Cut(1, length(listener.clash_chat_lines) - CHATBOX_HISTORY + 1)
	if(listener.clash_chat_scroll)
		listener.clash_chat_scroll = min(listener.clash_chat_scroll + 1, length(listener.clash_chat_lines) - listener.clash_chat_rows)
	if(listener.clash_chatbox_hidden && listener != sender)
		listener.clash_chat_unread = TRUE
	listener.clash_chatbox_update()

/mob/proc/clash_chat_side()
	var/mob/body = isobserver(src) ? mind?.current : src
	if(body && !isnewplayer(body) && (body.faction in list(FACTION_MARINE, FACTION_UPP)))
		return body.faction

/proc/clash_chat_side_color(mob/speaker)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return clash_mode.faction_color(speaker?.clash_chat_side())

/proc/clash_chat_local(mob/listener, mob/speaker, name, message)
	if(!listener.client || !clash_fast_medicine())
		return
	clash_chatbox_add(listener.client, speaker?.client, "LOCAL", CHATBOX_COLOR_LOCAL, name, clash_chat_side_color(speaker), message)

/proc/clash_chat_radio(mob/listener, mob/speaker, name, message)
	if(!listener.client || !clash_fast_medicine() || (listener.sdisabilities & DISABILITY_DEAF) || listener.ear_deaf)
		return
	clash_chatbox_add(listener.client, speaker?.client, "RADIO", CHATBOX_COLOR_RADIO, name, clash_chat_side_color(speaker), message)

/proc/clash_chat_dead(client/listener, mob/speaker, message)
	if(!listener || !clash_fast_medicine())
		return
	clash_chatbox_add(listener, speaker.client, "DEAD", CHATBOX_COLOR_DEAD, html_encode(speaker.real_name), clash_chat_side_color(speaker), message)

/proc/clash_chat_ooc(client/listener, client/sender, color, name, message)
	if(!clash_fast_medicine())
		return
	clash_chatbox_add(listener, sender, "OOC", color, name, CHATBOX_COLOR_TEXT, message)

/proc/clash_chat_looc(client/listener, client/sender, name, message)
	if(!clash_fast_medicine())
		return
	clash_chatbox_add(listener, sender, "LOOC", CHATBOX_COLOR_LOOC, name, CHATBOX_COLOR_TEXT, message)

/mob/proc/clash_chat_can_send(message)
	if(!length(message) || !client)
		return FALSE
	if(!clash_fast_medicine())
		to_chat(src, SPAN_WARNING("Team and all chat only work in the arena."))
		return FALSE
	if(client.prefs.muted & MUTE_IC)
		to_chat(src, SPAN_DANGER("You cannot speak in IC (Muted)."))
		return FALSE
	if(isliving(src) && stat == UNCONSCIOUS)
		to_chat(src, SPAN_WARNING("You can't talk while unconscious."))
		return FALSE
	return client.attempt_talking(message) && filter_message(client, message)

/mob/proc/clash_all_chat(message)
	message = trim(strip_html(message, MAX_MESSAGE_LEN))
	if(isnewplayer(src))
		to_chat(src, SPAN_WARNING("You can't use all chat from the lobby."))
		return
	if(!clash_chat_can_send(message))
		return
	log_say("ALL/[key_name(src)] : [message]")
	var/speaker_name = html_encode(real_name)
	var/side_color = clash_chat_side_color(src)
	var/line = "<span class='game say'><b>\[ALL\]</b> <span style='color: [side_color]'><b>[speaker_name]</b></span>: [message]</span>"
	for(var/client/listener as anything in GLOB.clients)
		to_chat(listener, line)
		clash_chatbox_add(listener, client, "ALL", CHATBOX_COLOR_ALL, speaker_name, side_color, message)

/mob/proc/clash_team_chat(message)
	message = trim(strip_html(message, MAX_MESSAGE_LEN))
	if(!clash_chat_can_send(message))
		return
	var/side = clash_chat_side()
	if(!side)
		to_chat(src, SPAN_WARNING("You are not on a team."))
		return
	log_say("TEAM/[key_name(src)] : [message]")
	var/speaker_name = html_encode(real_name)
	var/side_color = clash_chat_side_color(src)
	var/line = "<span class='game say'><b>\[TEAM\]</b> <span style='color: [side_color]'><b>[speaker_name]</b></span>: [message]</span>"
	for(var/client/listener as anything in GLOB.clients)
		if(listener.mob?.clash_chat_side() != side)
			continue
		to_chat(listener, line)
		clash_chatbox_add(listener, client, "TEAM", side_color, speaker_name, side_color, message)

/client/verb/clash_team_say(message as text)
	set name = "Team"
	set hidden = TRUE
	mob.clash_team_chat(message)

/client/verb/clash_all_say(message as text)
	set name = "All"
	set hidden = TRUE
	mob.clash_all_chat(message)

#undef CHATBOX_ROWS
#undef CHATBOX_MIN_ROWS
#undef CHATBOX_MAX_ROWS
#undef CHATBOX_ROW_HEIGHT
#undef CHATBOX_HISTORY
#undef CHATBOX_LINE_LIFE
#undef CHATBOX_TICK
#undef CHATBOX_WIDTH
#undef CHATBOX_MIN_WIDTH
#undef CHATBOX_MAX_WIDTH
#undef CHATBOX_WIDTH_STEP
#undef CHATBOX_LEFT
#undef CHATBOX_BOTTOM
#undef CHATBOX_TOGGLE_SIZE
#undef CHATBOX_BAR_GAP
#undef CHATBOX_ARROW_SIZE
#undef CHATBOX_THUMB_MIN
#undef CHATBOX_WHEEL_LINES
#undef CHATBOX_TEXT_INDENT
#undef CHATBOX_FRAME_ALPHA_TYPING
#undef CHATBOX_FRAME_ALPHA_RESIZING
#undef CHATBOX_ALPHA_IDLE
#undef CHATBOX_IDLE_FADE
#undef CHATBOX_COLOR_FRAME
#undef CHATBOX_COLOR_BAR_FILL
#undef CHATBOX_COLOR_BAR_MARK
#undef CHATBOX_COLOR_UNREAD
#undef CHATBOX_COLOR_UNREAD_WASH
#undef CHATBOX_COLOR_TEXT
#undef CHATBOX_COLOR_LOCAL
#undef CHATBOX_COLOR_ALL
#undef CHATBOX_COLOR_RADIO
#undef CHATBOX_COLOR_LOOC
#undef CHATBOX_COLOR_DEAD
#undef COMSIG_KB_CLIENT_TEAM_DOWN

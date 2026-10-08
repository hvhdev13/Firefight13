#define CHATBOX_LINES 8
#define CHATBOX_HISTORY 50
#define CHATBOX_LINE_LIFE (10 SECONDS)
#define CHATBOX_TICK (1 SECONDS)
#define CHATBOX_WIDTH 320
#define CHATBOX_HEIGHT 80
#define CHATBOX_TOGGLE_SIZE 11
#define CHATBOX_BAR_BOTTOM (CHATBOX_TOGGLE_SIZE + 2)
#define CHATBOX_BAR_HEIGHT (CHATBOX_HEIGHT - CHATBOX_BAR_BOTTOM)
#define CHATBOX_ARROW_SIZE 11
#define CHATBOX_THUMB_MIN 4
#define CHATBOX_WHEEL_LINES 2
#define CHATBOX_TEXT_INDENT (CHATBOX_TOGGLE_SIZE + 4)
#define CHATBOX_COLOR_BAR_FILL rgb(14, 17, 21, 140)
#define CHATBOX_COLOR_BAR_MARK rgb(106, 116, 124)
#define CHATBOX_COLOR_UNREAD rgb(240, 217, 140, 110)
#define CHATBOX_COLOR_TEXT "#e6e6e6"
#define CHATBOX_COLOR_LOCAL "#f0d98c"
#define CHATBOX_COLOR_ALL "#ffffff"
#define CHATBOX_COLOR_RADIO "#1fcc44"
#define CHATBOX_COLOR_LOOC "#f557b8"
#define CHATBOX_COLOR_DEAD "#e3c2ff"
#define COMSIG_KB_CLIENT_TEAM_DOWN "keybinding_client_team_down"

GLOBAL_DATUM(clash_chatbox_backdrop, /icon)
GLOBAL_DATUM(clash_chatbox_unread_icon, /icon)
GLOBAL_LIST_EMPTY(clash_chatbox_bar_icons)

/client/var/list/clash_chat_lines = list()
/client/var/clash_chat_typing = FALSE
/client/var/clash_chat_scroll = 0
/client/var/clash_chat_unread = FALSE
/client/var/clash_chatbox_hidden
/client/var/atom/movable/screen/clash_chatbox/clash_chatbox
/client/var/atom/movable/screen/clash_chatbox_toggle/clash_chatbox_toggle
/client/var/atom/movable/screen/clash_chatbox_bar/clash_chatbox_bar

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
	screen_loc = "WEST:6,5:14"
	maptext_x = CHATBOX_TEXT_INDENT
	maptext_width = CHATBOX_WIDTH - CHATBOX_TEXT_INDENT
	maptext_height = CHATBOX_HEIGHT

/atom/movable/screen/clash_chatbox/clicked(mob/user, list/mods)
	return TRUE

/atom/movable/screen/clash_chatbox/MouseWheel(delta_x, delta_y, location, control, params)
	usr.client?.clash_chat_scroll_by(delta_y > 0 ? CHATBOX_WHEEL_LINES : -CHATBOX_WHEEL_LINES)

/atom/movable/screen/clash_chatbox_toggle
	name = "Toggle chat box"
	icon = null
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	screen_loc = "WEST:6,5:14"
	var/shown_key

/atom/movable/screen/clash_chatbox_toggle/clicked(mob/user, list/mods)
	user.client?.clash_toggle_chatbox()
	return TRUE

/atom/movable/screen/clash_chatbox_bar
	name = "Chat history"
	icon = null
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	screen_loc = "WEST:6,5:14"
	pixel_y = CHATBOX_BAR_BOTTOM
	var/shown_key
	var/thumb_middle

/atom/movable/screen/clash_chatbox_bar/clicked(mob/user, list/mods)
	var/click_y = text2num(mods[ICON_Y])
	if(click_y > CHATBOX_BAR_HEIGHT - CHATBOX_ARROW_SIZE)
		user.client?.clash_chat_scroll_by(1)
	else if(click_y <= CHATBOX_ARROW_SIZE)
		user.client?.clash_chat_scroll_by(-1)
	else
		user.client?.clash_chat_scroll_by(click_y > thumb_middle ? CHATBOX_LINES : -CHATBOX_LINES)
	return TRUE

/atom/movable/screen/clash_chatbox_bar/MouseWheel(delta_x, delta_y, location, control, params)
	usr.client?.clash_chat_scroll_by(delta_y > 0 ? CHATBOX_WHEEL_LINES : -CHATBOX_WHEEL_LINES)

/atom/movable/screen/clash_chatbox_bar/proc/update(total, scroll)
	var/track = CHATBOX_BAR_HEIGHT - CHATBOX_ARROW_SIZE * 2
	var/thumb = max(CHATBOX_THUMB_MIN, round(track * CHATBOX_LINES / total))
	var/start = CHATBOX_ARROW_SIZE + 1 + round((track - thumb) * scroll / (total - CHATBOX_LINES))
	thumb_middle = start + thumb / 2
	var/key = "[start]-[thumb]"
	if(shown_key == key)
		return
	shown_key = key
	icon = get_clash_chatbox_bar_icon(start, thumb)

/proc/get_clash_chatbox_bar_icon(start, thumb)
	var/key = "[start]-[thumb]"
	if(GLOB.clash_chatbox_bar_icons[key])
		return GLOB.clash_chatbox_bar_icons[key]
	var/icon/bar = icon('icons/effects/effects.dmi', "nothing")
	bar.Scale(CHATBOX_TOGGLE_SIZE, CHATBOX_BAR_HEIGHT)
	bar.DrawBox(CHATBOX_COLOR_BAR_FILL, 1, 1, CHATBOX_TOGGLE_SIZE, CHATBOX_BAR_HEIGHT)
	var/middle = ceil(CHATBOX_TOGGLE_SIZE / 2)
	for(var/row in 0 to 2)
		bar.DrawBox(CHATBOX_COLOR_BAR_MARK, middle - row, CHATBOX_BAR_HEIGHT - 3 - row, middle + row, CHATBOX_BAR_HEIGHT - 3 - row)
		bar.DrawBox(CHATBOX_COLOR_BAR_MARK, middle - row, 3 + row, middle + row, 3 + row)
	bar.DrawBox(CHATBOX_COLOR_BAR_MARK, 3, start, CHATBOX_TOGGLE_SIZE - 2, start + thumb - 1)
	GLOB.clash_chatbox_bar_icons[key] = bar
	return bar

/proc/get_clash_chatbox_unread_icon()
	if(!GLOB.clash_chatbox_unread_icon)
		var/icon/button = icon(get_clash_radar_toggle_icon(FALSE))
		button.Blend(CHATBOX_COLOR_UNREAD, ICON_OVERLAY)
		GLOB.clash_chatbox_unread_icon = button
	return GLOB.clash_chatbox_unread_icon

/proc/get_clash_chatbox_backdrop()
	if(!GLOB.clash_chatbox_backdrop)
		var/icon/backdrop = icon('icons/effects/effects.dmi', "nothing")
		backdrop.Scale(CHATBOX_WIDTH, CHATBOX_HEIGHT)
		backdrop.DrawBox(rgb(0, 0, 0, 3), 1, 1, CHATBOX_WIDTH, CHATBOX_HEIGHT)
		GLOB.clash_chatbox_backdrop = backdrop
	return GLOB.clash_chatbox_backdrop

/datum/game_mode/extended/faction_clash/hvh/proc/start_clash_chat()
	addtimer(CALLBACK(src, PROC_REF(update_clash_chatboxes)), CHATBOX_TICK, TIMER_LOOP)
	for(var/client/player as anything in GLOB.clients)
		player.update_special_keybinds()
		player.tgui_say?.load()

/datum/game_mode/extended/faction_clash/hvh/proc/update_clash_chatboxes()
	for(var/client/player as anything in GLOB.clients)
		if(player.clash_chat_typing && !player.tgui_say?.window_open)
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
	for(var/index in max(1, length(clash_chat_lines) - CHATBOX_LINES + 1) to length(clash_chat_lines))
		var/list/line = clash_chat_lines[index]
		line["expiry"] = world.time + CHATBOX_LINE_LIFE

/client/proc/clash_chat_scroll_by(amount)
	var/scroll = clamp(clash_chat_scroll + amount, 0, max(0, length(clash_chat_lines) - CHATBOX_LINES))
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

/client/proc/clash_chatbox_update()
	if(!clash_fast_medicine() || !mob || isnewplayer(mob))
		if(clash_chatbox_toggle in screen)
			remove_from_screen(clash_chatbox_toggle)
		if(clash_chatbox in screen)
			remove_from_screen(clash_chatbox)
		if(clash_chatbox_bar in screen)
			remove_from_screen(clash_chatbox_bar)
		return
	if(isnull(clash_chatbox_hidden))
		var/datum/clash_progress/progress = clash_progress_of(ckey)
		clash_chatbox_hidden = !!(progress && !progress.chatbox)
	if(!clash_chatbox_toggle)
		clash_chatbox_toggle = new
	if(!(clash_chatbox_toggle in screen))
		add_to_screen(clash_chatbox_toggle)
	var/toggle_key = clash_chatbox_hidden ? (clash_chat_unread ? "unread" : "off") : "on"
	if(clash_chatbox_toggle.shown_key != toggle_key)
		clash_chatbox_toggle.shown_key = toggle_key
		clash_chatbox_toggle.icon = toggle_key == "unread" ? get_clash_chatbox_unread_icon() : get_clash_radar_toggle_icon(toggle_key == "on")
	var/total = length(clash_chat_lines)
	if(clash_chatbox_hidden || total <= CHATBOX_LINES)
		if(clash_chatbox_bar in screen)
			remove_from_screen(clash_chatbox_bar)
	else
		if(!clash_chatbox_bar)
			clash_chatbox_bar = new
		if(!(clash_chatbox_bar in screen))
			add_to_screen(clash_chatbox_bar)
		clash_chatbox_bar.update(total, clash_chat_scroll)
	if(clash_chatbox_hidden)
		if(clash_chatbox in screen)
			remove_from_screen(clash_chatbox)
		return
	if(!clash_chatbox)
		clash_chatbox = new
	if(!(clash_chatbox in screen))
		add_to_screen(clash_chatbox)
	clash_chatbox.mouse_opacity = clash_chat_typing ? MOUSE_OPACITY_OPAQUE : MOUSE_OPACITY_TRANSPARENT
	var/list/shown = list()
	for(var/index in max(1, total - clash_chat_scroll - CHATBOX_LINES + 1) to total - clash_chat_scroll)
		var/list/line = clash_chat_lines[index]
		if(clash_chat_scroll || clash_chat_typing || line["expiry"] > world.time)
			shown += line["text"]
	var/text = length(shown) ? "<span style='font-family: \"Small Fonts\"; font-size: 6px; vertical-align: bottom; color: [CHATBOX_COLOR_TEXT]; -dm-text-outline: 1px black'>[shown.Join("<br>")]</span>" : ""
	if(clash_chatbox.maptext == text)
		return
	clash_chatbox.maptext = text
	clash_chatbox.icon = length(shown) ? get_clash_chatbox_backdrop() : null

/proc/clash_chatbox_add(client/listener, client/sender, tag, tag_color, name, name_color, message)
	listener.clash_chat_lines += list(list(
		"expiry" = world.time + CHATBOX_LINE_LIFE,
		"text" = "<span style='color: [tag_color]'>\[[tag]\]</span> <span style='color: [name_color]'>[name]</span>: [message]",
	))
	if(length(listener.clash_chat_lines) > CHATBOX_HISTORY)
		listener.clash_chat_lines.Cut(1, length(listener.clash_chat_lines) - CHATBOX_HISTORY + 1)
	if(listener.clash_chat_scroll)
		listener.clash_chat_scroll = min(listener.clash_chat_scroll + 1, length(listener.clash_chat_lines) - CHATBOX_LINES)
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

#undef CHATBOX_LINES
#undef CHATBOX_HISTORY
#undef CHATBOX_LINE_LIFE
#undef CHATBOX_TICK
#undef CHATBOX_WIDTH
#undef CHATBOX_HEIGHT
#undef CHATBOX_TOGGLE_SIZE
#undef CHATBOX_BAR_BOTTOM
#undef CHATBOX_BAR_HEIGHT
#undef CHATBOX_ARROW_SIZE
#undef CHATBOX_THUMB_MIN
#undef CHATBOX_WHEEL_LINES
#undef CHATBOX_TEXT_INDENT
#undef CHATBOX_COLOR_BAR_FILL
#undef CHATBOX_COLOR_BAR_MARK
#undef CHATBOX_COLOR_UNREAD
#undef CHATBOX_COLOR_TEXT
#undef CHATBOX_COLOR_LOCAL
#undef CHATBOX_COLOR_ALL
#undef CHATBOX_COLOR_RADIO
#undef CHATBOX_COLOR_LOOC
#undef CHATBOX_COLOR_DEAD
#undef COMSIG_KB_CLIENT_TEAM_DOWN

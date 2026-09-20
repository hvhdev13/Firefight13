#define RESPAWN_BUTTON_WIDTH 128
#define RESPAWN_BUTTON_HEIGHT 26

#define RESPAWN_STATE_COOLDOWN "cooldown"
#define RESPAWN_STATE_READY "ready"
#define RESPAWN_STATE_HOVER "hover"

GLOBAL_LIST_EMPTY(clash_respawn_button_icons)

/proc/get_clash_respawn_button_icon(state)
	if(GLOB.clash_respawn_button_icons[state])
		return GLOB.clash_respawn_button_icons[state]
	var/fill_light
	var/fill_dark
	var/bevel
	var/accent
	switch(state)
		if(RESPAWN_STATE_COOLDOWN)
			fill_light = rgb(38, 42, 47)
			fill_dark = rgb(33, 37, 42)
			bevel = rgb(72, 80, 88)
			accent = rgb(88, 95, 103)
		if(RESPAWN_STATE_READY)
			fill_light = rgb(42, 58, 46)
			fill_dark = rgb(37, 52, 41)
			bevel = rgb(96, 128, 102)
			accent = rgb(76, 175, 80)
		if(RESPAWN_STATE_HOVER)
			fill_light = rgb(50, 72, 58)
			fill_dark = rgb(45, 65, 52)
			bevel = rgb(132, 186, 140)
			accent = rgb(118, 222, 121)
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(rgb(10, 12, 15), 2, 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(rgb(10, 12, 15), 1, 2, RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT - 1)
	for(var/row in 3 to RESPAWN_BUTTON_HEIGHT - 2)
		button.DrawBox(row % 2 ? fill_light : fill_dark, 3, row, RESPAWN_BUTTON_WIDTH - 2, row)
	button.DrawBox(bevel, 2, RESPAWN_BUTTON_HEIGHT - 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(bevel, 2, 2, 2, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(rgb(19, 22, 25), 2, 2, RESPAWN_BUTTON_WIDTH - 1, 2)
	button.DrawBox(rgb(19, 22, 25), RESPAWN_BUTTON_WIDTH - 1, 2, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(accent, 3, 3, 5, RESPAWN_BUTTON_HEIGHT - 2)
	button.DrawBox(accent, RESPAWN_BUTTON_WIDTH - 5, 3, RESPAWN_BUTTON_WIDTH - 3, RESPAWN_BUTTON_HEIGHT - 2)
	GLOB.clash_respawn_button_icons[state] = button
	return button

/atom/movable/screen/clash_respawn
	name = "Respawn"
	icon = null
	screen_loc = "CENTER-2:16,CENTER-3"
	maptext_width = RESPAWN_BUTTON_WIDTH
	maptext_height = 16
	maptext_y = 7
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/state
	var/hovered = FALSE
	var/shown_seconds

/atom/movable/screen/clash_respawn/proc/update(mob/viewer)
	if((viewer.stat != DEAD && !isobserver(viewer)) || !viewer.timeofdeath)
		if(!alpha)
			return
		alpha = 0
		mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		state = null
		hovered = FALSE
		return
	alpha = 255
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/remaining = viewer.timeofdeath + RESPAWN_COOLDOWN - world.time
	if(remaining > 0)
		var/seconds = CEILING(remaining / 10, 1)
		if(state != RESPAWN_STATE_COOLDOWN || seconds != shown_seconds)
			shown_seconds = seconds
			show_state(RESPAWN_STATE_COOLDOWN)
		return
	var/wanted_state = hovered ? RESPAWN_STATE_HOVER : RESPAWN_STATE_READY
	if(wanted_state != state)
		show_state(wanted_state)

/atom/movable/screen/clash_respawn/proc/show_state(new_state)
	if(state != new_state)
		state = new_state
		icon = get_clash_respawn_button_icon(state)
	var/text_color = "#e6f5e8"
	var/label = "RESPAWN"
	switch(state)
		if(RESPAWN_STATE_COOLDOWN)
			text_color = "#828a92"
			label = "RESPAWN [floor(shown_seconds / 60)]:[shown_seconds % 60 < 10 ? "0" : ""][shown_seconds % 60]"
		if(RESPAWN_STATE_HOVER)
			text_color = "#ffffff"
	maptext = MAPTEXT_VCR_OSD_MONO("<span style='font-size: 12px; text-align: center; color: [text_color]'>[label]</span>")

/atom/movable/screen/clash_respawn/MouseEntered(location, control, params)
	hovered = TRUE
	if(state == RESPAWN_STATE_READY)
		show_state(RESPAWN_STATE_HOVER)

/atom/movable/screen/clash_respawn/MouseExited(location, control, params)
	hovered = FALSE
	if(state == RESPAWN_STATE_HOVER)
		show_state(RESPAWN_STATE_READY)

/atom/movable/screen/clash_respawn/clicked(mob/user, list/mods)
	if(state != RESPAWN_STATE_READY && state != RESPAWN_STATE_HOVER)
		return TRUE
	user.abandon_mob()
	return TRUE

#undef RESPAWN_BUTTON_WIDTH
#undef RESPAWN_BUTTON_HEIGHT
#undef RESPAWN_STATE_COOLDOWN
#undef RESPAWN_STATE_READY
#undef RESPAWN_STATE_HOVER

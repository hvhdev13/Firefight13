#define RESPAWN_BUTTON_WIDTH 128
#define RESPAWN_BUTTON_HEIGHT 26
#define RESPAWN_BAR_START 9
#define RESPAWN_BAR_END (RESPAWN_BUTTON_WIDTH - 4)

#define RESPAWN_STATE_COOLDOWN "cooldown"
#define RESPAWN_STATE_READY "ready"
#define RESPAWN_STATE_HOVER "hover"

GLOBAL_LIST_EMPTY(clash_respawn_button_icons)
GLOBAL_LIST_EMPTY(clash_respawn_bar_icons)

/proc/get_clash_respawn_button_icon(state)
	if(GLOB.clash_respawn_button_icons[state])
		return GLOB.clash_respawn_button_icons[state]
	var/fill_light
	var/fill_dark
	var/bevel
	var/accent
	switch(state)
		if(RESPAWN_STATE_COOLDOWN)
			fill_light = rgb(39, 44, 50)
			fill_dark = rgb(35, 40, 45)
			bevel = rgb(77, 86, 94)
			accent = rgb(92, 99, 107)
		if(RESPAWN_STATE_READY)
			fill_light = rgb(42, 58, 46)
			fill_dark = rgb(38, 53, 42)
			bevel = rgb(93, 122, 99)
			accent = rgb(76, 175, 80)
		if(RESPAWN_STATE_HOVER)
			fill_light = rgb(49, 70, 58)
			fill_dark = rgb(44, 64, 52)
			bevel = rgb(127, 180, 135)
			accent = rgb(111, 214, 114)
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(rgb(10, 12, 15), 2, 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(rgb(10, 12, 15), 1, 2, RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT - 1)
	for(var/row in 2 to RESPAWN_BUTTON_HEIGHT - 1)
		button.DrawBox(row % 2 ? fill_light : fill_dark, 2, row, RESPAWN_BUTTON_WIDTH - 1, row)
	button.DrawBox(bevel, 2, RESPAWN_BUTTON_HEIGHT - 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(bevel, 2, 2, 2, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(rgb(21, 24, 27), 2, 2, RESPAWN_BUTTON_WIDTH - 1, 2)
	button.DrawBox(rgb(21, 24, 27), RESPAWN_BUTTON_WIDTH - 1, 2, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(accent, 3, 3, 5, RESPAWN_BUTTON_HEIGHT - 2)
	if(state == RESPAWN_STATE_COOLDOWN)
		button.DrawBox(rgb(21, 24, 27), RESPAWN_BAR_START, 4, RESPAWN_BAR_END, 5)
	GLOB.clash_respawn_button_icons[state] = button
	return button

/proc/get_clash_respawn_bar_icon(filled)
	var/cache_key = "[filled]"
	if(GLOB.clash_respawn_bar_icons[cache_key])
		return GLOB.clash_respawn_bar_icons[cache_key]
	var/icon/bar = icon('icons/effects/effects.dmi', "nothing")
	bar.Scale(RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	bar.DrawBox(rgb(201, 162, 39), RESPAWN_BAR_START, 4, RESPAWN_BAR_START + filled - 1, 5)
	GLOB.clash_respawn_bar_icons[cache_key] = bar
	return bar

/atom/movable/screen/clash_respawn
	name = "Respawn"
	icon = null
	screen_loc = "CENTER-2:16,CENTER-3"
	maptext_width = RESPAWN_BUTTON_WIDTH
	maptext_height = 16
	maptext_y = 8
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/state
	var/hovered = FALSE

/atom/movable/screen/clash_respawn/proc/update(mob/viewer)
	if((viewer.stat != DEAD && !isobserver(viewer)) || !viewer.timeofdeath)
		if(!alpha)
			return
		alpha = 0
		mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		state = null
		hovered = FALSE
		animate(src)
		color = null
		return
	alpha = 255
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/remaining = viewer.timeofdeath + RESPAWN_COOLDOWN - world.time
	if(remaining > 0)
		show_cooldown(remaining)
	else if(!state || state == RESPAWN_STATE_COOLDOWN)
		show_ready()

/atom/movable/screen/clash_respawn/proc/show_cooldown(remaining)
	if(state != RESPAWN_STATE_COOLDOWN)
		state = RESPAWN_STATE_COOLDOWN
		icon = get_clash_respawn_button_icon(RESPAWN_STATE_COOLDOWN)
		animate(src)
		color = null
	var/seconds = CEILING(remaining / 10, 1)
	var/track = RESPAWN_BAR_END - RESPAWN_BAR_START + 1
	var/filled = clamp(round(track * (1 - remaining / RESPAWN_COOLDOWN)), 0, track)
	overlays = filled ? list(get_clash_respawn_bar_icon(filled)) : list()
	maptext = MAPTEXT_VCR_OSD_MONO("<span style='font-size: 12px; text-align: center; color: #8b939b'>RESPAWN [floor(seconds / 60)]:[seconds % 60 < 10 ? "0" : ""][seconds % 60]</span>")

/atom/movable/screen/clash_respawn/proc/show_ready()
	state = hovered ? RESPAWN_STATE_HOVER : RESPAWN_STATE_READY
	icon = get_clash_respawn_button_icon(state)
	overlays.Cut()
	maptext = MAPTEXT_VCR_OSD_MONO("<span style='font-size: 12px; text-align: center; color: [hovered ? "#ffffff" : "#e6f5e8"]'>RESPAWN</span>")
	animate(src)
	color = null
	if(!hovered)
		animate(src, color = "#c3dcc7", time = 8, loop = -1, easing = SINE_EASING)
		animate(color = "#ffffff", time = 8, easing = SINE_EASING)

/atom/movable/screen/clash_respawn/MouseEntered(location, control, params)
	hovered = TRUE
	if(state == RESPAWN_STATE_READY)
		show_ready()

/atom/movable/screen/clash_respawn/MouseExited(location, control, params)
	hovered = FALSE
	if(state == RESPAWN_STATE_HOVER)
		show_ready()

/atom/movable/screen/clash_respawn/clicked(mob/user, list/mods)
	if(state != RESPAWN_STATE_READY && state != RESPAWN_STATE_HOVER)
		return TRUE
	user.abandon_mob()
	return TRUE

#undef RESPAWN_BUTTON_WIDTH
#undef RESPAWN_BUTTON_HEIGHT
#undef RESPAWN_BAR_START
#undef RESPAWN_BAR_END
#undef RESPAWN_STATE_COOLDOWN
#undef RESPAWN_STATE_READY
#undef RESPAWN_STATE_HOVER

#define RESPAWN_BUTTON_WIDTH 128
#define RESPAWN_BUTTON_HEIGHT 28
#define RESPAWN_BUTTON_BORDER 2

GLOBAL_LIST_EMPTY(clash_respawn_button_icons)

/proc/get_clash_respawn_button_icon(fill_color, border_color)
	var/cache_key = "[fill_color][border_color]"
	if(GLOB.clash_respawn_button_icons[cache_key])
		return GLOB.clash_respawn_button_icons[cache_key]
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(border_color, 1, 1, RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(fill_color, 1 + RESPAWN_BUTTON_BORDER, 1 + RESPAWN_BUTTON_BORDER, RESPAWN_BUTTON_WIDTH - RESPAWN_BUTTON_BORDER, RESPAWN_BUTTON_HEIGHT - RESPAWN_BUTTON_BORDER)
	GLOB.clash_respawn_button_icons[cache_key] = button
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
	var/ready = FALSE

/atom/movable/screen/clash_respawn/proc/update(mob/viewer)
	if((viewer.stat != DEAD && !isobserver(viewer)) || !viewer.timeofdeath)
		if(!alpha)
			return
		alpha = 0
		mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		return
	var/now_ready = world.time >= viewer.timeofdeath + RESPAWN_COOLDOWN
	if(alpha && now_ready == ready)
		return
	ready = now_ready
	alpha = 255
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	if(ready)
		icon = get_clash_respawn_button_icon("#1f6b2add", "#4ade5a")
		maptext = "<span class='maptext center' style='font-size: 8px; color: #ffffff'><b>RESPAWN</b></span>"
	else
		icon = get_clash_respawn_button_icon("#2a2a2add", "#5a5a5a")
		maptext = "<span class='maptext center' style='font-size: 8px; color: #8a8a8a'><b>RESPAWN</b></span>"

/atom/movable/screen/clash_respawn/clicked(mob/user, list/mods)
	if(!ready)
		return TRUE
	user.abandon_mob()
	return TRUE

#undef RESPAWN_BUTTON_WIDTH
#undef RESPAWN_BUTTON_HEIGHT
#undef RESPAWN_BUTTON_BORDER

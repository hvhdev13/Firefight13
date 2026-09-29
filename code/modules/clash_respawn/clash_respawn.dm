#define RESPAWN_BUTTON_WIDTH 144
#define RESPAWN_BUTTON_HEIGHT 32
#define RESPAWN_FILL_STEPS 48

#define RESPAWN_STATE_COOLDOWN "cooldown"
#define RESPAWN_STATE_READY "ready"
#define RESPAWN_STATE_HOVER "hover"

GLOBAL_LIST_EMPTY(clash_respawn_button_icons)

/proc/get_clash_respawn_button_icon(state, fill_step = 0)
	var/key = state == RESPAWN_STATE_COOLDOWN ? "[state]-[fill_step]" : state
	if(GLOB.clash_respawn_button_icons[key])
		return GLOB.clash_respawn_button_icons[key]
	var/fill_light
	var/fill_dark
	var/bevel
	var/accent
	var/edge = rgb(10, 12, 15)
	switch(state)
		if(RESPAWN_STATE_COOLDOWN)
			fill_light = rgb(34, 38, 43)
			fill_dark = rgb(30, 34, 39)
			bevel = rgb(66, 73, 81)
			accent = rgb(80, 87, 95)
		if(RESPAWN_STATE_READY)
			fill_light = rgb(40, 62, 46)
			fill_dark = rgb(35, 55, 41)
			bevel = rgb(98, 140, 106)
			accent = rgb(76, 175, 80)
		if(RESPAWN_STATE_HOVER)
			fill_light = rgb(52, 82, 60)
			fill_dark = rgb(46, 74, 54)
			bevel = rgb(150, 205, 158)
			accent = rgb(130, 232, 132)
			edge = rgb(190, 240, 195)
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(edge, 2, 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(edge, 1, 2, RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT - 1)
	for(var/row in 3 to RESPAWN_BUTTON_HEIGHT - 2)
		button.DrawBox(row % 2 ? fill_light : fill_dark, 3, row, RESPAWN_BUTTON_WIDTH - 2, row)
	var/body_width = RESPAWN_BUTTON_WIDTH - 10
	var/filled = state == RESPAWN_STATE_COOLDOWN ? round(body_width * fill_step / RESPAWN_FILL_STEPS) : 0
	if(filled > 0)
		for(var/row in 3 to RESPAWN_BUTTON_HEIGHT - 2)
			button.DrawBox(row % 2 ? rgb(38, 56, 44) : rgb(34, 50, 39), 6, row, 5 + filled, row)
		button.DrawBox(rgb(96, 170, 104), 5 + filled, 3, 5 + filled, RESPAWN_BUTTON_HEIGHT - 2)
		button.DrawBox(rgb(76, 175, 80), 6, 3, 5 + filled, 4)
	button.DrawBox(bevel, 2, RESPAWN_BUTTON_HEIGHT - 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(bevel, 2, 2, 2, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(rgb(19, 22, 25), 2, 2, RESPAWN_BUTTON_WIDTH - 1, 2)
	button.DrawBox(rgb(19, 22, 25), RESPAWN_BUTTON_WIDTH - 1, 2, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(accent, 3, 3, 5, RESPAWN_BUTTON_HEIGHT - 2)
	button.DrawBox(accent, RESPAWN_BUTTON_WIDTH - 5, 3, RESPAWN_BUTTON_WIDTH - 3, RESPAWN_BUTTON_HEIGHT - 2)
	GLOB.clash_respawn_button_icons[key] = button
	return button

/atom/movable/screen/clash_respawn
	name = "Respawn"
	icon = null
	screen_loc = "CENTER-2:8,CENTER-3"
	maptext_width = RESPAWN_BUTTON_WIDTH
	maptext_height = RESPAWN_BUTTON_HEIGHT
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/state
	var/hovered = FALSE
	var/shown_seconds
	var/shown_step
	var/counted_down = FALSE

/proc/clash_can_redeploy(mob/viewer)
	if(isobserver(viewer))
		var/mob/dead/observer/ghost = viewer
		var/mob/body = ghost.mind?.current
		return !(ghost.can_reenter_corpse && body && body != ghost && body.stat != DEAD)
	return isliving(viewer) && viewer.stat == DEAD && viewer.timeofdeath

/atom/movable/screen/clash_respawn/proc/update(mob/viewer)
	if(!clash_can_redeploy(viewer))
		if(!alpha)
			return
		animate(src)
		alpha = 0
		mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		state = null
		hovered = FALSE
		counted_down = FALSE
		return
	if(!alpha)
		pixel_y = -8
		animate(src, alpha = 255, pixel_y = 0, time = 3, easing = CUBIC_EASING|EASE_OUT)
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/cooldown = clash_respawn_cooldown()
	var/remaining = clash_respawn_wait(viewer)
	if(remaining > 0)
		counted_down = TRUE
		var/seconds = CEILING(remaining / 10, 1)
		var/step = cooldown > 0 ? clamp(floor((1 - remaining / cooldown) * RESPAWN_FILL_STEPS), 0, RESPAWN_FILL_STEPS - 1) : 0
		if(state != RESPAWN_STATE_COOLDOWN || seconds != shown_seconds || step != shown_step)
			shown_seconds = seconds
			shown_step = step
			show_state(RESPAWN_STATE_COOLDOWN)
		return
	var/wanted_state = hovered ? RESPAWN_STATE_HOVER : RESPAWN_STATE_READY
	if(wanted_state == state)
		return
	var/was_waiting = state == RESPAWN_STATE_COOLDOWN
	show_state(wanted_state)
	if(was_waiting && counted_down && viewer.client)
		playsound_client(viewer.client, 'sound/machines/ping.ogg', vol = 35)

/atom/movable/screen/clash_respawn/proc/pulse()
	if(state != RESPAWN_STATE_READY)
		return
	animate(src, alpha = 205, time = 9, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = 9, easing = SINE_EASING)

/atom/movable/screen/clash_respawn/proc/show_state(new_state)
	var/entering = state != new_state
	state = new_state
	icon = get_clash_respawn_button_icon(state, shown_step)
	var/kits = clash_uses_kits()
	switch(state)
		if(RESPAWN_STATE_COOLDOWN)
			name = kits ? "Loadout" : "Respawn"
			desc = kits ? "Pick your loadout while you wait to deploy." : "You can respawn when the wait runs out."
			var/time = "[floor(shown_seconds / 60)]:[shown_seconds % 60 < 10 ? "0" : ""][shown_seconds % 60]"
			maptext = "<span style='text-align: center; vertical-align: middle; -dm-text-outline: 1px black'><span style='font-family: \"Small Fonts\"; font-size: 6px; color: #8a939c'>[kits ? "LOADOUT  ·  DEPLOY IN" : "RESPAWN IN"]</span><br><span style='font-family: \"VCR OSD Mono\"; font-size: 11px; color: #d0d6dc'>[time]</span></span>"
		if(RESPAWN_STATE_READY, RESPAWN_STATE_HOVER)
			name = kits ? "Deploy" : "Respawn"
			desc = kits ? "Pick your loadout and deploy." : "Return to the lobby and pick a role."
			var/color = state == RESPAWN_STATE_HOVER ? "#ffffff" : "#e6f5e8"
			maptext = "<span style='text-align: center; vertical-align: middle; -dm-text-outline: 1px #0a0c0f'><span style='font-family: \"VCR OSD Mono\"; font-size: 12px; color: [color]'>[kits ? "DEPLOY" : "RESPAWN"]</span><br><span style='font-family: \"Small Fonts\"; font-size: 6px; color: #9fc9a4'>[kits ? "CHOOSE LOADOUT" : "CLICK TO REJOIN"]</span></span>"
	if(!entering)
		return
	if(state == RESPAWN_STATE_HOVER)
		animate(src, alpha = 255, time = 1)
	else if(state == RESPAWN_STATE_READY)
		pulse()

/atom/movable/screen/clash_respawn/MouseEntered(location, control, params)
	hovered = TRUE
	if(state == RESPAWN_STATE_READY)
		show_state(RESPAWN_STATE_HOVER)

/atom/movable/screen/clash_respawn/MouseExited(location, control, params)
	hovered = FALSE
	if(state == RESPAWN_STATE_HOVER)
		show_state(RESPAWN_STATE_READY)

/atom/movable/screen/clash_respawn/clicked(mob/user, list/mods)
	if(!state)
		return TRUE
	if(clash_uses_kits())
		open_clash_kit_screen(user)
		return TRUE
	if(state != RESPAWN_STATE_READY && state != RESPAWN_STATE_HOVER)
		to_chat(user, SPAN_WARNING("You can respawn in [shown_seconds] second\s."))
		return TRUE
	user.abandon_mob()
	return TRUE

#undef RESPAWN_BUTTON_WIDTH
#undef RESPAWN_BUTTON_HEIGHT
#undef RESPAWN_FILL_STEPS
#undef RESPAWN_STATE_COOLDOWN
#undef RESPAWN_STATE_READY
#undef RESPAWN_STATE_HOVER

#define DEATH_CARD_WIDTH 272
#define DEATH_CARD_HEIGHT 132
#define DEATH_CARD_BAND 16
#define DEATH_CARD_ICON_BOX 64
#define DEATH_CARD_GUN_STRIP 28

/client/var/list/clash_death_card

GLOBAL_LIST_EMPTY(clash_death_card_icons)

/proc/get_clash_death_card_icon(accent, has_killer, health)
	var/health_step = isnum(health) ? clamp(round(health / 5), 0, 20) : -1
	var/key = "[accent]|[has_killer]|[health_step]"
	if(GLOB.clash_death_card_icons[key])
		return GLOB.clash_death_card_icons[key]
	var/icon/card = icon('icons/effects/effects.dmi', "nothing")
	card.Scale(DEATH_CARD_WIDTH, DEATH_CARD_HEIGHT)
	card.DrawBox(rgb(8, 10, 13, 220), 2, 1, DEATH_CARD_WIDTH - 1, DEATH_CARD_HEIGHT)
	card.DrawBox(rgb(8, 10, 13, 220), 1, 2, DEATH_CARD_WIDTH, DEATH_CARD_HEIGHT - 1)
	card.DrawBox(clash_tint(accent, 38), 2, DEATH_CARD_HEIGHT - 38, DEATH_CARD_WIDTH - 1, DEATH_CARD_HEIGHT - 1)
	card.DrawBox(accent, 2, DEATH_CARD_HEIGHT - 3, DEATH_CARD_WIDTH - 1, DEATH_CARD_HEIGHT - 1)
	card.DrawBox(rgb(255, 255, 255, 14), 2, 2, DEATH_CARD_WIDTH - 1, DEATH_CARD_BAND)
	card.DrawBox(rgb(255, 255, 255, 36), 2, DEATH_CARD_BAND + 1, DEATH_CARD_WIDTH - 1, DEATH_CARD_BAND + 1)
	if(has_killer)
		var/box_top = DEATH_CARD_HEIGHT - 8
		var/box_bottom = box_top - DEATH_CARD_ICON_BOX - DEATH_CARD_GUN_STRIP + 1
		card.DrawBox(rgb(14, 17, 21, 250), 8, box_bottom, 8 + DEATH_CARD_ICON_BOX - 1, box_top)
		card.DrawBox(rgb(255, 255, 255, 24), 10, box_bottom + DEATH_CARD_GUN_STRIP, 8 + DEATH_CARD_ICON_BOX - 3, box_bottom + DEATH_CARD_GUN_STRIP)
		card.DrawBox(clash_tint(accent, 120), 8, box_bottom, 8 + DEATH_CARD_ICON_BOX - 1, box_bottom)
		if(health_step >= 0)
			var/bar_y = box_bottom - 5
			card.DrawBox(rgb(255, 255, 255, 30), 8, bar_y, 8 + DEATH_CARD_ICON_BOX - 1, bar_y + 1)
			var/filled = round(DEATH_CARD_ICON_BOX * health_step / 20)
			if(filled > 0)
				var/bar_color = health_step > 12 ? rgb(95, 211, 95) : (health_step > 6 ? rgb(230, 190, 70) : rgb(230, 80, 70))
				card.DrawBox(bar_color, 8, bar_y, 8 + filled - 1, bar_y + 1)
	GLOB.clash_death_card_icons[key] = card
	return card

/atom/movable/screen/clash_death_card
	name = "Death recap"
	desc = "Click to hide."
	icon = null
	screen_loc = "CENTER-4:8,CENTER-2:6"
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/list/shown

/atom/movable/screen/clash_death_card/proc/update(mob/viewer)
	var/client/viewer_client = viewer.client
	if(viewer.stat != DEAD && !isobserver(viewer))
		if(viewer_client && ishuman(viewer))
			viewer_client.clash_death_card = null
		hide()
		return
	var/list/card = viewer_client?.clash_death_card
	if(!card || card["dismissed"])
		hide()
		return
	if(shown == card)
		return
	shown = card
	icon = get_clash_death_card_icon(card["color"], card["has_killer"], card["health"])
	overlays = card["overlays"]
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	pixel_y = 8
	alpha = 0
	animate(src, alpha = 255, pixel_y = 0, time = 3, easing = CUBIC_EASING|EASE_OUT)

/atom/movable/screen/clash_death_card/proc/hide()
	if(!alpha && !shown)
		return
	shown = null
	animate(src)
	alpha = 0
	overlays.Cut()
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/clash_death_card/clicked(mob/user, list/mods)
	if(user.client?.clash_death_card)
		user.client.clash_death_card["dismissed"] = TRUE
	hide()
	return TRUE

/**
 * Fills in victim's death card and shows it at once
 *
 * killer_name is null for a death to the environment. weapon is the item that did it, drawn large beside the text.
 * health is the killer's health left in percent, or null. life_line sums up the life that just ended.
 */
/proc/clash_death_card_picture(appearance_source, width, height, center_x, center_y, max_scale, room)
	var/scale = min(max_scale, room / max(width, height))
	if(scale >= 1)
		scale = floor(scale)
	var/mutable_appearance/picture = new(appearance_source)
	picture.plane = FLOAT_PLANE
	picture.layer = FLOAT_LAYER
	picture.dir = SOUTH
	picture.maptext = null
	picture.pixel_x = 0
	picture.pixel_y = 0
	picture.pixel_w = 0
	picture.pixel_z = 0
	picture.alpha = 255
	picture.filters = null
	picture.transform = matrix(scale, 0, center_x - width / 2, 0, scale, center_y - height / 2)
	picture.appearance_flags = RESET_ALPHA|KEEP_APART|PIXEL_SCALE
	return picture

/proc/set_clash_death_card(mob/victim, headline, killer_name, color, detail, list/notes, obj/item/weapon, health, life_line, mutable_appearance/portrait)
	if(!victim?.client)
		return
	var/has_killer = !!killer_name
	var/text_x = has_killer ? 8 + DEATH_CARD_ICON_BOX + 8 : 10
	var/text_width = DEATH_CARD_WIDTH - text_x - 8
	var/outline = "-dm-text-outline: 1px black"
	var/list/lines = list()
	lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #aab2b9'>[headline]</span>"
	var/shown_name = killer_name ? replacetext(killer_name, " \[BOT\]", "") : "YOU DIED"
	var/name_size = length(shown_name) > 22 ? 10 : (length(shown_name) > 17 ? 12 : 14)
	var/bot_tag = killer_name && shown_name != killer_name ? " <span style='font-family: \"Small Fonts\"; font-size: 6px; color: #8a939c'>BOT</span>" : ""
	lines += "<span style='font-family: \"VCR OSD Mono\"; font-size: [name_size]px; color: [color]'>[html_encode(shown_name)]</span>[bot_tag]"
	lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #e2e6ea'>[detail]</span>"
	for(var/note in notes)
		lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #d9bf7e'>[note]</span>"
	var/list/overlays = list()
	var/mutable_appearance/body = mutable_appearance()
	body.maptext = "<span style='[outline]; text-align: left; vertical-align: top'>[lines.Join("<br>")]</span>"
	body.maptext_x = text_x
	body.maptext_y = DEATH_CARD_BAND + 4
	body.maptext_width = text_width
	body.maptext_height = DEATH_CARD_HEIGHT - DEATH_CARD_BAND - 10
	body.appearance_flags = RESET_COLOR|RESET_ALPHA|KEEP_APART
	overlays += body
	if(life_line)
		var/mutable_appearance/band = mutable_appearance()
		band.maptext = "<span style='[outline]; font-family: \"Small Fonts\"; font-size: 6px; text-align: center; color: #aab2b9'>[life_line]</span>"
		band.maptext_y = 2
		band.maptext_width = DEATH_CARD_WIDTH
		band.maptext_height = DEATH_CARD_BAND - 2
		band.appearance_flags = RESET_COLOR|RESET_ALPHA|KEEP_APART
		overlays += band
	if(has_killer && isnum(health))
		var/mutable_appearance/health_label = mutable_appearance()
		health_label.maptext = "<span style='[outline]; font-family: \"Small Fonts\"; font-size: 6px; text-align: center; color: #8a939c'>THEIR HP [health]%</span>"
		health_label.maptext_x = 8
		health_label.maptext_y = DEATH_CARD_BAND + 2
		health_label.maptext_width = DEATH_CARD_ICON_BOX
		health_label.maptext_height = 10
		health_label.appearance_flags = RESET_COLOR|RESET_ALPHA|KEEP_APART
		overlays += health_label
	var/box_center_x = 8 + DEATH_CARD_ICON_BOX / 2
	var/box_bottom = DEATH_CARD_HEIGHT - 8 - DEATH_CARD_ICON_BOX - DEATH_CARD_GUN_STRIP
	if(has_killer && portrait)
		overlays += clash_death_card_picture(portrait, world.icon_size, world.icon_size, box_center_x, box_bottom + DEATH_CARD_GUN_STRIP + DEATH_CARD_ICON_BOX / 2, 2, DEATH_CARD_ICON_BOX)
	if(has_killer && weapon)
		var/icon/weapon_icon = icon(weapon.icon, weapon.icon_state)
		overlays += clash_death_card_picture(weapon, weapon_icon.Width(), weapon_icon.Height(), box_center_x, box_bottom + DEATH_CARD_GUN_STRIP / 2, 2, DEATH_CARD_ICON_BOX)
	victim.client.clash_death_card = list(
		"color" = color,
		"has_killer" = has_killer,
		"health" = health,
		"overlays" = overlays,
	)
	if(victim.stat == DEAD)
		victim.hud_used?.clash_death_card?.update(victim)

#undef DEATH_CARD_WIDTH
#undef DEATH_CARD_HEIGHT
#undef DEATH_CARD_BAND
#undef DEATH_CARD_ICON_BOX
#undef DEATH_CARD_GUN_STRIP

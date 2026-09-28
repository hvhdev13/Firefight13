#define RESPAWN_BUTTON_WIDTH 144
#define RESPAWN_BUTTON_HEIGHT 32
/// Steps the cooldown fill is drawn in, each one a cached icon
#define RESPAWN_FILL_STEPS 48

#define RESPAWN_STATE_COOLDOWN "cooldown"
#define RESPAWN_STATE_READY "ready"
#define RESPAWN_STATE_HOVER "hover"

GLOBAL_LIST_EMPTY(clash_respawn_button_icons)

/// The button drawn for a state, cooldown icons also carry how far the wait has filled, from 0 to RESPAWN_FILL_STEPS
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
	// Outline with clipped corners
	button.DrawBox(edge, 2, 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT)
	button.DrawBox(edge, 1, 2, RESPAWN_BUTTON_WIDTH, RESPAWN_BUTTON_HEIGHT - 1)
	// Scanline body
	for(var/row in 3 to RESPAWN_BUTTON_HEIGHT - 2)
		button.DrawBox(row % 2 ? fill_light : fill_dark, 3, row, RESPAWN_BUTTON_WIDTH - 2, row)
	// The wait fills the body left to right in the ready colours, so it reads as a progress bar
	var/body_width = RESPAWN_BUTTON_WIDTH - 10
	var/filled = state == RESPAWN_STATE_COOLDOWN ? round(body_width * fill_step / RESPAWN_FILL_STEPS) : 0
	if(filled > 0)
		for(var/row in 3 to RESPAWN_BUTTON_HEIGHT - 2)
			button.DrawBox(row % 2 ? rgb(38, 56, 44) : rgb(34, 50, 39), 6, row, 5 + filled, row)
		// Bright leading edge and a thin track along the bottom
		button.DrawBox(rgb(96, 170, 104), 5 + filled, 3, 5 + filled, RESPAWN_BUTTON_HEIGHT - 2)
		button.DrawBox(rgb(76, 175, 80), 6, 3, 5 + filled, 4)
	// Bevel light top and left, shade bottom and right
	button.DrawBox(bevel, 2, RESPAWN_BUTTON_HEIGHT - 1, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(bevel, 2, 2, 2, RESPAWN_BUTTON_HEIGHT - 1)
	button.DrawBox(rgb(19, 22, 25), 2, 2, RESPAWN_BUTTON_WIDTH - 1, 2)
	button.DrawBox(rgb(19, 22, 25), RESPAWN_BUTTON_WIDTH - 1, 2, RESPAWN_BUTTON_WIDTH - 1, RESPAWN_BUTTON_HEIGHT - 1)
	// Side accents
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
	/// Whether this viewer watched the wait run down, so the ready chime is not played on login
	var/counted_down = FALSE

/atom/movable/screen/clash_respawn/proc/update(mob/viewer)
	if((viewer.stat != DEAD && !isobserver(viewer)) || !viewer.timeofdeath)
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
		// Slides up into place when the player dies
		pixel_y = -8
		animate(src, alpha = 255, pixel_y = 0, time = 3, easing = CUBIC_EASING|EASE_OUT)
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/cooldown = clash_respawn_cooldown()
	var/remaining = viewer.timeofdeath + cooldown - world.time
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

/// A slow breathing glow while the button waits to be clicked
/atom/movable/screen/clash_respawn/proc/pulse()
	if(state != RESPAWN_STATE_READY)
		return
	animate(src, alpha = 205, time = 9, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = 9, easing = SINE_EASING)

/atom/movable/screen/clash_respawn/proc/show_state(new_state)
	var/entering = state != new_state
	state = new_state
	icon = get_clash_respawn_button_icon(state, shown_step)
	// In kit rounds the button is the way into the spawn menu, so it works through the cooldown too
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
		// Hover stops the breathing so the button sits steady under the cursor
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

#define DEATH_CARD_WIDTH 224
#define DEATH_CARD_HEIGHT 76

/// What the death card shows, kept on the client so it survives ghosting into a new HUD
/client/var/list/clash_death_card

GLOBAL_LIST_EMPTY(clash_death_card_icons)

/proc/get_clash_death_card_icon(accent)
	if(GLOB.clash_death_card_icons[accent])
		return GLOB.clash_death_card_icons[accent]
	var/icon/card = icon('icons/effects/effects.dmi', "nothing")
	card.Scale(DEATH_CARD_WIDTH, DEATH_CARD_HEIGHT)
	card.DrawBox(rgb(10, 12, 15, 215), 2, 1, DEATH_CARD_WIDTH - 1, DEATH_CARD_HEIGHT)
	card.DrawBox(rgb(10, 12, 15, 215), 1, 2, DEATH_CARD_WIDTH, DEATH_CARD_HEIGHT - 1)
	// Killer's colour along the top, a thin rule under the headline
	card.DrawBox(accent, 2, DEATH_CARD_HEIGHT - 2, DEATH_CARD_WIDTH - 1, DEATH_CARD_HEIGHT - 1)
	card.DrawBox(rgb(255, 255, 255, 30), 24, DEATH_CARD_HEIGHT - 36, DEATH_CARD_WIDTH - 23, DEATH_CARD_HEIGHT - 36)
	GLOB.clash_death_card_icons[accent] = card
	return card

/// Who killed you and how, shown while you are down, above the respawn button
/atom/movable/screen/clash_death_card
	name = "Death recap"
	desc = "Click to hide."
	icon = null
	screen_loc = "CENTER-3,CENTER-2:6"
	maptext_width = DEATH_CARD_WIDTH - 8
	maptext_height = DEATH_CARD_HEIGHT
	maptext_x = 4
	maptext_y = -5
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The card data this is showing, so it redraws only on a new death
	var/list/shown

/atom/movable/screen/clash_death_card/proc/update(mob/viewer)
	var/client/viewer_client = viewer.client
	if(viewer.stat != DEAD && !isobserver(viewer))
		// Alive again, the card is spent
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
	icon = get_clash_death_card_icon(card["color"])
	maptext = card["text"]
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
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/clash_death_card/clicked(mob/user, list/mods)
	if(user.client?.clash_death_card)
		user.client.clash_death_card["dismissed"] = TRUE
	hide()
	return TRUE

/// Fills in victim's death card and shows it at once, killer_name null for a death to the environment
/proc/set_clash_death_card(mob/victim, headline, killer_name, color, detail, list/notes)
	if(!victim?.client)
		return
	var/list/lines = list()
	lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #8a939c; letter-spacing: 1px'>[headline]</span>"
	lines += "<span style='font-family: \"VCR OSD Mono\"; font-size: 12px; color: [color]'>[killer_name ? html_encode(killer_name) : "YOU DIED"]</span>"
	lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #d0d6dc'>[detail]</span>"
	for(var/note in notes)
		lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #c9b27a'>[note]</span>"
	victim.client.clash_death_card = list(
		"color" = color,
		"text" = "<span style='text-align: center; vertical-align: top; -dm-text-outline: 1px black'>[lines.Join("<br>")]</span>",
	)
	if(victim.stat == DEAD)
		victim.hud_used?.clash_death_card?.update(victim)

#undef DEATH_CARD_WIDTH
#undef DEATH_CARD_HEIGHT

#define RADAR_SIZE 96
#define RADAR_RANGE 7
#define RADAR_EDGE_MARGIN 8
#define RADAR_REFRESH (5 DECISECONDS)
#define RADAR_SWEEP_TAIL 45
#define RADAR_SWEEP_PERIOD 20
#define RADAR_BLIP_FADED_ALPHA 30

#define RADAR_COLOR_BEVEL rgb(77, 86, 94)
#define RADAR_COLOR_SHADOW rgb(21, 24, 27)
#define RADAR_COLOR_TICK rgb(106, 116, 124)
#define RADAR_TOGGLE_SIZE 11

GLOBAL_VAR(clash_turn_sign)
GLOBAL_DATUM(clash_radar_backdrop, /icon)
GLOBAL_DATUM(clash_radar_sweep, /icon)
GLOBAL_LIST_EMPTY(clash_radar_marks)
GLOBAL_LIST_EMPTY(clash_radar_toggle_icons)

/client/var/atom/movable/screen/clash_radar_toggle/clash_radar_toggle

/atom/movable/screen/clash_radar_toggle
	name = "Toggle radar"
	icon = null
	screen_loc = "LEFT:6,TOP:-134"
	pixel_y = RADAR_SIZE - RADAR_TOGGLE_SIZE
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/shown_on

/proc/get_clash_turn_sign()
	if(isnull(GLOB.clash_turn_sign))
		var/matrix/probe = turn(matrix(), 90)
		GLOB.clash_turn_sign = probe.d > 0 ? -1 : 1
	return GLOB.clash_turn_sign

/proc/clash_pattern_icon(list/rows, list/palette)
	var/height = length(rows)
	var/width = length(rows[1])
	var/icon/result = icon('icons/effects/effects.dmi', "nothing")
	result.Scale(width, height)
	for(var/row in 1 to height)
		for(var/column in 1 to width)
			var/pixel = palette[copytext(rows[row], column, column + 1)]
			if(pixel)
				result.DrawBox(pixel, column, height - row + 1)
	return result

/proc/get_clash_radar_backdrop()
	if(GLOB.clash_radar_backdrop)
		return GLOB.clash_radar_backdrop
	var/icon/backdrop = icon('icons/effects/effects.dmi', "nothing")
	backdrop.Scale(RADAR_SIZE, RADAR_SIZE)
	var/radius = RADAR_SIZE * 0.5
	for(var/y in 1 to RADAR_SIZE)
		for(var/x in 1 to RADAR_SIZE)
			var/dx = x - radius - 0.5
			var/dy = y - radius - 0.5
			var/distance = sqrt(dx * dx + dy * dy)
			var/edge = radius - distance
			if(edge <= 0)
				continue
			var/pixel
			if(edge < 1.5)
				pixel = rgb(10, 12, 15, round(255 * min(edge, 1)))
			else if(edge < 3)
				pixel = RADAR_COLOR_BEVEL
			else if(edge < 4)
				pixel = RADAR_COLOR_SHADOW
			else if(abs(distance - radius / 3) < 0.5 || abs(distance - radius * 2 / 3) < 0.5)
				pixel = rgb(38, 52, 61, 200)
			else if(abs(dx) < 0.5 || abs(dy) < 0.5)
				pixel = rgb(31, 42, 50, 200)
			else
				pixel = y % 2 ? rgb(16, 22, 27, 165) : rgb(14, 19, 24, 165)
			backdrop.DrawBox(pixel, x, y)
	var/middle = RADAR_SIZE / 2
	backdrop.DrawBox(RADAR_COLOR_TICK, middle, RADAR_SIZE - 7, middle + 1, RADAR_SIZE - 5)
	backdrop.DrawBox(RADAR_COLOR_TICK, middle, 6, middle + 1, 8)
	backdrop.DrawBox(RADAR_COLOR_TICK, 6, middle, 8, middle + 1)
	backdrop.DrawBox(RADAR_COLOR_TICK, RADAR_SIZE - 7, middle, RADAR_SIZE - 5, middle + 1)
	GLOB.clash_radar_backdrop = backdrop
	return backdrop

/proc/get_clash_radar_sweep()
	if(GLOB.clash_radar_sweep)
		return GLOB.clash_radar_sweep
	var/icon/sweep = icon('icons/effects/effects.dmi', "nothing")
	sweep.Scale(RADAR_SIZE, RADAR_SIZE)
	var/radius = RADAR_SIZE * 0.5
	for(var/y in 1 to RADAR_SIZE)
		for(var/x in 1 to RADAR_SIZE)
			var/dx = x - radius - 0.5
			var/dy = y - radius - 0.5
			var/distance = sqrt(dx * dx + dy * dy)
			if(distance < 1 || distance > radius - 4)
				continue
			var/behind = (360 - delta_to_angle(dx, dy)) % 360
			if(behind >= RADAR_SWEEP_TAIL)
				continue
			sweep.DrawBox(rgb(76, 175, 80, round(80 * (1 - behind / RADAR_SWEEP_TAIL))), x, y)
	GLOB.clash_radar_sweep = sweep
	return sweep

/proc/get_clash_radar_mark(kind)
	if(GLOB.clash_radar_marks[kind])
		return GLOB.clash_radar_marks[kind]
	var/icon/mark
	switch(kind)
		if("ally")
			mark = clash_pattern_icon(list(
				".ooo.",
				"oGGGo",
				"oGGGo",
				"oGGGo",
				".ooo.",
			), list("o" = rgb(10, 12, 15, 220), "G" = rgb(76, 175, 80)))
		if("leader")
			mark = clash_pattern_icon(list(
				"...o...",
				"..oYo..",
				".oYYYo.",
				"oYYYYYo",
				".oYYYo.",
				"..oYo..",
				"...o...",
			), list("o" = rgb(10, 12, 15, 220), "Y" = rgb(224, 180, 58)))
		if("self")
			mark = clash_pattern_icon(list(
				"...o...",
				"..oWo..",
				".oWWWo.",
				"oWWWWWo",
				"oWWoWWo",
				"oWo.oWo",
				".o...o.",
			), list("o" = rgb(10, 12, 15, 220), "W" = rgb(240, 244, 246)))
		if("downed")
			mark = clash_pattern_icon(list(
				"..ooo..",
				"..oRo..",
				"oooRooo",
				"oRRRRRo",
				"oooRooo",
				"..oRo..",
				"..ooo..",
			), list("o" = rgb(10, 12, 15, 220), "R" = rgb(230, 80, 70)))
		if("bot")
			mark = clash_pattern_icon(list(
				".ooo.",
				"oBBBo",
				"oBBBo",
				"oBBBo",
				".ooo.",
			), list("o" = rgb(10, 12, 15, 220), "B" = rgb(80, 150, 240)))
		if("sentry")
			mark = clash_pattern_icon(list(
				".www.",
				"wKKKw",
				"wKKKw",
				"wKKKw",
				".www.",
			), list("w" = rgb(170, 178, 186), "K" = rgb(0, 0, 0)))
		if("crate")
			mark = clash_pattern_icon(list(
				"wwwww",
				"wKKKw",
				"wKKKw",
				"wKKKw",
				"wwwww",
			), list("w" = rgb(170, 178, 186), "K" = rgb(0, 0, 0)))
	GLOB.clash_radar_marks[kind] = mark
	return mark

/atom/movable/clash_radar_sweep
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_ID|VIS_INHERIT_PLANE|VIS_INHERIT_LAYER

/atom/movable/clash_radar_sweep/Initialize(mapload, ...)
	. = ..()
	icon = get_clash_radar_sweep()
	var/spin = get_clash_turn_sign()
	animate(src, transform = turn(matrix(), spin * 120), time = RADAR_SWEEP_PERIOD / 3, loop = -1)
	animate(transform = turn(matrix(), spin * 240), time = RADAR_SWEEP_PERIOD / 3)
	animate(transform = null, time = RADAR_SWEEP_PERIOD / 3)

/atom/movable/clash_radar_blip
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_ID|VIS_INHERIT_PLANE|VIS_INHERIT_LAYER
	alpha = 0
	var/angle = 0
	var/contact

/atom/movable/screen/clash_radar
	name = ""
	icon = null
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "LEFT:6,TOP:-134"
	alpha = 0
	var/atom/movable/clash_radar_sweep/sweep
	var/sweep_started
	var/list/blips = list()
	var/list/painted = list()
	var/last_sweep_angle

/atom/movable/screen/clash_radar/Initialize(mapload, ...)
	. = ..()
	icon = get_clash_radar_backdrop()
	sweep = new
	sweep_started = world.time
	vis_contents += sweep

/atom/movable/screen/clash_radar/Destroy()
	vis_contents.Cut()
	QDEL_NULL(sweep)
	QDEL_LIST(blips)
	return ..()

/atom/movable/screen/clash_radar/proc/clear()
	if(!alpha)
		return
	alpha = 0
	overlays.Cut()
	painted.Cut()
	last_sweep_angle = null
	for(var/atom/movable/clash_radar_blip/blip as anything in blips)
		animate(blip)
		blip.alpha = 0
		blip.contact = null

/atom/movable/screen/clash_radar/proc/get_sweep_angle()
	var/elapsed = world.time - sweep_started
	return 360 * (elapsed - RADAR_SWEEP_PERIOD * floor(elapsed / RADAR_SWEEP_PERIOD)) / RADAR_SWEEP_PERIOD

/atom/movable/screen/clash_radar/proc/get_free_blip()
	for(var/atom/movable/clash_radar_blip/blip as anything in blips)
		if(!blip.contact)
			return blip
	var/atom/movable/clash_radar_blip/new_blip = new
	blips += new_blip
	vis_contents += new_blip
	return new_blip

/atom/movable/screen/clash_radar/proc/fade_blip(atom/movable/clash_radar_blip/blip, behind)
	animate(blip)
	blip.alpha = 255 - (255 - RADAR_BLIP_FADED_ALPHA) * behind / 360
	animate(blip, alpha = RADAR_BLIP_FADED_ALPHA, time = RADAR_SWEEP_PERIOD * (360 - behind) / 360)

/atom/movable/screen/clash_radar/proc/swept(angle, from, arc)
	return (angle - from + 720) % 360 <= arc

/atom/movable/screen/clash_radar/proc/place_mark(atom/movable/clash_radar_blip/blip, dx, dy, kind)
	var/icon/mark_icon = get_clash_radar_mark(kind)
	if(blip.icon != mark_icon)
		blip.icon = mark_icon
	var/per_tile = (RADAR_SIZE * 0.5 - RADAR_EDGE_MARGIN) / RADAR_RANGE
	blip.pixel_x = round(RADAR_SIZE * 0.5 + dx * per_tile - mark_icon.Width() * 0.5)
	blip.pixel_y = round(RADAR_SIZE * 0.5 + dy * per_tile - mark_icon.Height() * 0.5)

/atom/movable/screen/clash_radar/proc/paint(contact, dx, dy, kind, from, arc, sweep_angle)
	var/angle = delta_to_angle(dx, dy)
	if(!swept(angle, from, arc))
		return
	var/atom/movable/clash_radar_blip/blip = painted[contact]
	if(!blip)
		blip = get_free_blip()
		blip.contact = contact
		painted[contact] = blip
	blip.angle = angle
	place_mark(blip, dx, dy, kind)
	fade_blip(blip, (sweep_angle - angle + 720) % 360)

/atom/movable/screen/clash_radar/proc/clash_paint_build(mob/living/carbon/human/viewer, atom/build, kind, list/seen, from, arc, sweep_angle)
	if(build.z != viewer.z)
		return
	var/dx = build.x - viewer.x
	var/dy = build.y - viewer.y
	if(sqrt(dx * dx + dy * dy) > RADAR_RANGE)
		return
	var/contact = "[kind][REF(build)]"
	seen[contact] = TRUE
	paint(contact, dx, dy, kind, from, arc, sweep_angle)

/atom/movable/screen/clash_radar/proc/render(mob/living/carbon/human/viewer)
	alpha = 255
	var/sweep_angle = get_sweep_angle()
	var/from = isnull(last_sweep_angle) ? sweep_angle - 360 * RADAR_REFRESH / RADAR_SWEEP_PERIOD : last_sweep_angle
	var/arc = (sweep_angle - from + 720) % 360
	last_sweep_angle = sweep_angle
	var/list/seen = list()
	for(var/mob/living/carbon/human/ally as anything in GLOB.alive_human_list)
		if(ally == viewer || ally.faction != viewer.faction || ally.z != viewer.z)
			continue
		var/dx = ally.x - viewer.x
		var/dy = ally.y - viewer.y
		if(sqrt(dx * dx + dy * dy) > RADAR_RANGE)
			continue
		var/contact = REF(ally)
		seen[contact] = TRUE
		var/kind = "ally"
		if(ally.statistic_exempt)
			kind = "bot"
		else if(ally.assigned_squad?.squad_leader == ally)
			kind = "leader"
		paint(contact, dx, dy, kind, from, arc, sweep_angle)
	if(clash_fast_medicine() && clash_is_medic(viewer))
		for(var/mob/living/carbon/human/body in GLOB.dead_mob_list)
			if(body.faction != viewer.faction || body.z != viewer.z || body.statistic_exempt || !body.check_tod() || !body.is_revivable())
				continue
			var/dx = body.x - viewer.x
			var/dy = body.y - viewer.y
			var/distance = sqrt(dx * dx + dy * dy)
			if(distance > RADAR_RANGE)
				if(world.time > body.clash_called_until)
					continue
				dx *= RADAR_RANGE / distance
				dy *= RADAR_RANGE / distance
			var/contact = "downed[REF(body)]"
			seen[contact] = TRUE
			paint(contact, dx, dy, "downed", from, arc, sweep_angle)
	if(clash_fast_medicine())
		for(var/ckey in GLOB.clash_engineer_sentries)
			for(var/obj/structure/machinery/defenses/sentry/turret as anything in GLOB.clash_engineer_sentries[ckey])
				if(turret.placed && turret.clash_faction == viewer.faction)
					clash_paint_build(viewer, turret, "sentry", seen, from, arc, sweep_angle)
		for(var/ckey in GLOB.clash_engineer_crates)
			for(var/obj/item/clash_ammo_crate/crate as anything in GLOB.clash_engineer_crates[ckey])
				var/obj/structure/clash_ammo_crate/deployed = crate.loc
				if(istype(deployed) && deployed.faction == viewer.faction)
					clash_paint_build(viewer, deployed, "crate", seen, from, arc, sweep_angle)
	for(var/contact in painted.Copy())
		var/atom/movable/clash_radar_blip/gone = painted[contact]
		if(seen[contact] || !swept(gone.angle, from, arc))
			continue
		painted -= contact
		gone.contact = null
		animate(gone)
		gone.alpha = 0
	var/icon/self_icon = get_clash_radar_mark("self")
	var/image/self_mark = image(self_icon)
	self_mark.pixel_x = round(RADAR_SIZE * 0.5 - self_icon.Width() * 0.5)
	self_mark.pixel_y = round(RADAR_SIZE * 0.5 - self_icon.Height() * 0.5)
	self_mark.transform = turn(matrix(), get_clash_turn_sign() * dir2angle(viewer.dir))
	overlays = list(self_mark)

/datum/game_mode/extended/faction_clash/hvh/var/radar_timer_id

/datum/game_mode/extended/faction_clash/hvh/proc/start_clash_radar()
	radar_timer_id = addtimer(CALLBACK(src, PROC_REF(update_clash_radars)), RADAR_REFRESH, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/proc/update_clash_radars()
	for(var/mob/player as anything in GLOB.player_list)
		var/atom/movable/screen/clash_radar/radar = player.hud_used?.clash_radar
		var/mob/living/carbon/human/human_player = player
		var/equipped = radar && ishuman(player) && player.stat != DEAD && human_player.w_uniform
		var/datum/clash_progress/progress = GLOB.clash_progress.players[player.ckey]
		var/radar_on = !progress || progress.radar
		show_clash_radar_toggle(player.client, equipped, radar_on)
		if(!radar)
			continue
		if(!equipped || !radar_on)
			radar.clear()
			continue
		radar.render(player)

/proc/get_clash_radar_toggle_icon(radar_on)
	var/key = radar_on ? "on" : "off"
	if(GLOB.clash_radar_toggle_icons[key])
		return GLOB.clash_radar_toggle_icons[key]
	var/fill = rgb(14, 17, 21)
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(RADAR_TOGGLE_SIZE, RADAR_TOGGLE_SIZE)
	button.DrawBox(RADAR_COLOR_SHADOW, 1, 1, RADAR_TOGGLE_SIZE, RADAR_TOGGLE_SIZE)
	button.DrawBox(fill, 2, 2, RADAR_TOGGLE_SIZE - 1, RADAR_TOGGLE_SIZE - 1)
	button.DrawBox(RADAR_COLOR_BEVEL, 2, RADAR_TOGGLE_SIZE - 1, RADAR_TOGGLE_SIZE - 1, RADAR_TOGGLE_SIZE - 1)
	if(radar_on)
		button.DrawBox(RADAR_COLOR_TICK, 4, 4, RADAR_TOGGLE_SIZE - 3, 4)
	else
		button.DrawBox(RADAR_COLOR_TICK, 4, 4, RADAR_TOGGLE_SIZE - 3, RADAR_TOGGLE_SIZE - 3)
		button.DrawBox(fill, 5, 5, RADAR_TOGGLE_SIZE - 4, RADAR_TOGGLE_SIZE - 4)
	GLOB.clash_radar_toggle_icons[key] = button
	return button

/proc/show_clash_radar_toggle(client/player, shown, radar_on)
	if(!player)
		return
	var/atom/movable/screen/clash_radar_toggle/button = player.clash_radar_toggle
	if(!shown)
		if(button)
			player.remove_from_screen(button)
		return
	if(!button)
		button = new
		player.clash_radar_toggle = button
	if(!(button in player.screen))
		player.add_to_screen(button)
	button.update(radar_on)

/atom/movable/screen/clash_radar_toggle/proc/update(radar_on)
	if(shown_on == radar_on)
		return
	shown_on = radar_on
	icon = get_clash_radar_toggle_icon(radar_on)

/atom/movable/screen/clash_radar_toggle/clicked(mob/user, list/mods)
	user.clash_toggle_radar()
	var/datum/clash_progress/progress = clash_progress_of(user.ckey)
	if(progress)
		update(progress.radar)
	return TRUE

#undef RADAR_SIZE
#undef RADAR_RANGE
#undef RADAR_EDGE_MARGIN
#undef RADAR_REFRESH
#undef RADAR_SWEEP_TAIL
#undef RADAR_SWEEP_PERIOD
#undef RADAR_BLIP_FADED_ALPHA
#undef RADAR_COLOR_BEVEL
#undef RADAR_COLOR_SHADOW
#undef RADAR_COLOR_TICK
#undef RADAR_TOGGLE_SIZE

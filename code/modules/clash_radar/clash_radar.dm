/// Pixel width and height of the radar
#define RADAR_SIZE 96
/// Tiles shown in each direction from the viewer
#define RADAR_RANGE 7
/// Pixels kept clear between the furthest contact and the rim, so marks stay inside the glass
#define RADAR_EDGE_MARGIN 8
/// How often contacts are redrawn
#define RADAR_REFRESH (5 DECISECONDS)
/// Degrees covered by the fading tail of the sweep
#define RADAR_SWEEP_TAIL 45
/// Deciseconds for one full sweep
#define RADAR_SWEEP_PERIOD 30
/// How faint a contact goes before the sweep reaches it again
#define RADAR_BLIP_FADED_ALPHA 30

#define RADAR_COLOR_BEVEL rgb(77, 86, 94)
#define RADAR_COLOR_SHADOW rgb(21, 24, 27)
#define RADAR_COLOR_TICK rgb(106, 116, 124)

GLOBAL_VAR(clash_turn_sign)
GLOBAL_DATUM(clash_radar_backdrop, /icon)
GLOBAL_DATUM(clash_radar_sweep, /icon)
GLOBAL_LIST_EMPTY(clash_radar_marks)

/// 1 when turn() rotates clockwise on screen, -1 when it rotates counter clockwise
/proc/get_clash_turn_sign()
	if(isnull(GLOB.clash_turn_sign))
		var/matrix/probe = turn(matrix(), 90)
		GLOB.clash_turn_sign = probe.d > 0 ? -1 : 1
	return GLOB.clash_turn_sign

/// Builds an icon from rows of characters, top row first, each character looked up in palette
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
	for(var/atom/movable/clash_radar_blip/blip as anything in blips)
		animate(blip)
		blip.alpha = 0

/// Degrees the sweep has turned from north, clockwise
/atom/movable/screen/clash_radar/proc/get_sweep_angle()
	var/elapsed = world.time - sweep_started
	return 360 * (elapsed - RADAR_SWEEP_PERIOD * floor(elapsed / RADAR_SWEEP_PERIOD)) / RADAR_SWEEP_PERIOD

/atom/movable/screen/clash_radar/proc/get_blip(index)
	while(length(blips) < index)
		var/atom/movable/clash_radar_blip/new_blip = new
		blips += new_blip
		vis_contents += new_blip
	return blips[index]

/// Bright as the sweep crosses the contact, fading to RADAR_BLIP_FADED_ALPHA by the time it comes back around
/atom/movable/screen/clash_radar/proc/fade_blip(atom/movable/clash_radar_blip/blip, behind)
	var/faded = behind + 360 * RADAR_REFRESH / RADAR_SWEEP_PERIOD
	animate(blip)
	blip.alpha = 255 - (255 - RADAR_BLIP_FADED_ALPHA) * behind / 360
	animate(blip, alpha = 255 - (255 - RADAR_BLIP_FADED_ALPHA) * min(faded, 360) / 360, time = RADAR_REFRESH)

/atom/movable/screen/clash_radar/proc/place_mark(atom/movable/clash_radar_blip/blip, dx, dy, kind)
	var/icon/mark_icon = get_clash_radar_mark(kind)
	if(blip.icon != mark_icon)
		blip.icon = mark_icon
	var/per_tile = (RADAR_SIZE * 0.5 - RADAR_EDGE_MARGIN) / RADAR_RANGE
	blip.pixel_x = round(RADAR_SIZE * 0.5 + dx * per_tile - mark_icon.Width() * 0.5)
	blip.pixel_y = round(RADAR_SIZE * 0.5 + dy * per_tile - mark_icon.Height() * 0.5)

/atom/movable/screen/clash_radar/proc/render(mob/living/carbon/human/viewer)
	alpha = 255
	var/sweep_angle = get_sweep_angle()
	var/shown = 0
	for(var/mob/living/carbon/human/ally as anything in GLOB.alive_human_list)
		if(ally == viewer || ally.faction != viewer.faction || ally.z != viewer.z)
			continue
		var/dx = ally.x - viewer.x
		var/dy = ally.y - viewer.y
		if(sqrt(dx * dx + dy * dy) > RADAR_RANGE)
			continue
		shown++
		var/atom/movable/clash_radar_blip/blip = get_blip(shown)
		place_mark(blip, dx, dy, ally.assigned_squad?.squad_leader == ally ? "leader" : "ally")
		fade_blip(blip, (sweep_angle - delta_to_angle(dx, dy) + 720) % 360)
	for(var/index = shown + 1 to length(blips))
		var/atom/movable/clash_radar_blip/spare = blips[index]
		animate(spare)
		spare.alpha = 0
	var/icon/self_icon = get_clash_radar_mark("self")
	var/image/self_mark = image(self_icon)
	self_mark.pixel_x = round(RADAR_SIZE * 0.5 - self_icon.Width() * 0.5)
	self_mark.pixel_y = round(RADAR_SIZE * 0.5 - self_icon.Height() * 0.5)
	self_mark.transform = turn(matrix(), get_clash_turn_sign() * dir2angle(viewer.dir))
	overlays = list(self_mark)

/datum/game_mode/extended/faction_clash/cm_vs_upp/var/radar_timer_id

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/start_clash_radar()
	radar_timer_id = addtimer(CALLBACK(src, PROC_REF(update_clash_radars)), RADAR_REFRESH, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/update_clash_radars()
	for(var/mob/player as anything in GLOB.player_list)
		var/atom/movable/screen/clash_radar/radar = player.hud_used?.clash_radar
		if(!radar)
			continue
		if(player.stat == DEAD || !ishuman(player))
			radar.clear()
			continue
		var/mob/living/carbon/human/human_player = player
		if(!human_player.w_uniform)
			radar.clear()
			continue
		radar.render(player)

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

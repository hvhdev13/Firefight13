/// Pixel width and height of the radar
#define RADAR_SIZE 96
/// Tiles shown in each direction from the viewer
#define RADAR_RANGE 7
/// Opacity of the whole widget
#define RADAR_ALPHA 102
/// Pixel size of a contact dot
#define RADAR_DOT 4
#define RADAR_EDGE 3
/// How often contacts are redrawn
#define RADAR_REFRESH (5 DECISECONDS)

GLOBAL_DATUM(clash_radar_backdrop, /icon)
GLOBAL_LIST_EMPTY(clash_radar_dots)

/proc/get_clash_radar_backdrop()
	if(GLOB.clash_radar_backdrop)
		return GLOB.clash_radar_backdrop
	var/icon/backdrop = icon('icons/effects/effects.dmi', "nothing")
	backdrop.Scale(RADAR_SIZE, RADAR_SIZE)
	var/radius = RADAR_SIZE * 0.5
	for(var/y = 1 to RADAR_SIZE)
		for(var/x = 1 to RADAR_SIZE)
			var/dx = x - radius - 0.5
			var/dy = y - radius - 0.5
			var/edge = radius - sqrt(dx * dx + dy * dy)
			if(edge <= 0)
				continue
			var/coverage = edge < 1 ? edge : 1
			if(edge < RADAR_EDGE)
				backdrop.DrawBox(rgb(92, 124, 156, round(255 * coverage)), x, y)
			else
				backdrop.DrawBox(rgb(18, 26, 38, round(255 * coverage)), x, y)
	GLOB.clash_radar_backdrop = backdrop
	return backdrop

/proc/get_clash_radar_dot(dot_color)
	if(GLOB.clash_radar_dots[dot_color])
		return GLOB.clash_radar_dots[dot_color]
	var/red = hex2num(copytext(dot_color, 2, 4))
	var/green = hex2num(copytext(dot_color, 4, 6))
	var/blue = hex2num(copytext(dot_color, 6, 8))
	var/icon/dot = icon('icons/effects/effects.dmi', "nothing")
	dot.Scale(RADAR_DOT, RADAR_DOT)
	var/radius = RADAR_DOT * 0.5
	for(var/y = 1 to RADAR_DOT)
		for(var/x = 1 to RADAR_DOT)
			var/dx = x - radius - 0.5
			var/dy = y - radius - 0.5
			var/edge = radius - sqrt(dx * dx + dy * dy)
			if(edge <= 0)
				continue
			var/coverage = edge < 1 ? edge : 1
			dot.DrawBox(rgb(red, green, blue, round(255 * coverage)), x, y)
	GLOB.clash_radar_dots[dot_color] = dot
	return dot

/atom/movable/screen/clash_radar
	name = ""
	icon = null
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "LEFT:6,TOP:-134"
	alpha = RADAR_ALPHA

/atom/movable/screen/clash_radar/proc/clear()
	if(!icon)
		return
	icon = null
	overlays.Cut()

/atom/movable/screen/clash_radar/proc/make_dot(dx, dy, dot_color)
	var/image/dot = image(get_clash_radar_dot(dot_color))
	var/per_tile = RADAR_SIZE / (RADAR_RANGE * 2 + 1)
	dot.pixel_x = round(RADAR_SIZE * 0.5 + dx * per_tile - RADAR_DOT * 0.5)
	dot.pixel_y = round(RADAR_SIZE * 0.5 + dy * per_tile - RADAR_DOT * 0.5)
	return dot

/atom/movable/screen/clash_radar/proc/render(mob/living/carbon/human/viewer)
	if(!icon)
		icon = get_clash_radar_backdrop()
	var/list/contacts = list()
	contacts += make_dot(0, 0, "#ffffff")
	for(var/mob/living/carbon/human/ally as anything in GLOB.alive_human_list)
		if(ally == viewer || ally.faction != viewer.faction || ally.z != viewer.z)
			continue
		var/dx = ally.x - viewer.x
		var/dy = ally.y - viewer.y
		if(abs(dx) > RADAR_RANGE || abs(dy) > RADAR_RANGE)
			continue
		var/is_leader = ally.assigned_squad?.squad_leader == ally
		contacts += make_dot(dx, dy, is_leader ? "#ffd24a" : "#4ade5a")
	overlays = contacts

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
#undef RADAR_DOT
#undef RADAR_EDGE
#undef RADAR_ALPHA
#undef RADAR_REFRESH

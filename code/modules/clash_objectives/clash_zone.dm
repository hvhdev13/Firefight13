GLOBAL_LIST_EMPTY(clash_objective_turfs)
GLOBAL_LIST_EMPTY(clash_objective_landmarks)
GLOBAL_DATUM(clash_zone_tile_icon, /icon)

#define CLASH_ZONE_SEARCH_STEPS 60
#define CLASH_ZONE_MAX_RADIUS 7

/area/clash_arena/var/clash_zone = FALSE

/obj/effect/landmark/clash_objective
	name = "Clash objective"
	icon_state = "o_white"
	var/label
	var/radius

/obj/effect/landmark/clash_objective/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_objective_landmarks += src

/obj/effect/landmark/clash_objective/Destroy()
	GLOB.clash_objective_landmarks -= src
	return ..()

/obj/effect/landmark/clash_objective/koth_primary
	name = "KOTH primary hill"
	icon_state = "o_yellow"
	label = "Hill"
	var/rotation = CLASH_HILL_STATIC
	var/rotate_minutes = 3

/obj/effect/landmark/clash_objective/koth_secondary
	name = "KOTH secondary hill"
	label = "Hill"

/obj/effect/landmark/clash_objective/koth_tertiary
	name = "KOTH tertiary hill"
	label = "Hill"

/obj/effect/landmark/clash_objective/domination_zone
	name = "Domination zone"
	icon_state = "o_green"

/obj/effect/landmark/clash_objective/domination_zone/a
	name = "Domination zone A"
	label = "A"

/obj/effect/landmark/clash_objective/domination_zone/b
	name = "Domination zone B"
	label = "B"

/obj/effect/landmark/clash_objective/domination_zone/c
	name = "Domination zone C"
	label = "C"

/proc/get_clash_zone_tile_icon()
	if(GLOB.clash_zone_tile_icon)
		return GLOB.clash_zone_tile_icon
	var/icon/tile = icon('icons/effects/effects.dmi', "nothing")
	tile.Scale(32, 32)
	tile.DrawBox(rgb(255, 255, 255, 50), 1, 1, 32, 32)
	GLOB.clash_zone_tile_icon = tile
	return tile

/obj/effect/clash_zone_tile
	name = "objective"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = BELOW_OBJ_LAYER

/obj/effect/clash_zone_tile/Initialize(mapload, ...)
	. = ..()
	icon = get_clash_zone_tile_icon()

/obj/effect/clash_zone_label
	name = "objective"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_OBJ_LAYER
	maptext_width = 96
	maptext_height = 32
	maptext_x = -32
	maptext_y = 12

/datum/clash_zone
	var/label
	var/turf/center
	var/radius
	var/owner
	var/capturing
	var/progress = 0
	var/contested = FALSE
	var/list/covered = list()
	var/list/obj/effect/clash_zone_tile/tiles = list()
	var/obj/effect/clash_zone_label/marker
	var/shown
	var/preview = FALSE

/datum/clash_zone/New(label, turf/center, radius, preview = FALSE)
	. = ..()
	src.label = label
	src.center = center
	src.radius = radius
	src.preview = preview
	for(var/turf/spot as anything in get_clash_zone_turfs(center, radius))
		covered[spot] = TRUE
		var/obj/effect/clash_zone_tile/tile = new(spot)
		tiles += tile
		if(preview)
			animate(tile, alpha = 0, time = 5, loop = -1)
			animate(alpha = 255, time = 5)
	refresh_tiles()
	marker = new(center)
	if(!preview)
		GLOB.clash_objective_turfs += center

/datum/clash_zone/Destroy(force)
	if(!preview)
		GLOB.clash_objective_turfs -= center
	QDEL_LIST(tiles)
	QDEL_NULL(marker)
	center = null
	covered = null
	return ..()

/datum/clash_zone/proc/refresh_tiles()
	for(var/obj/effect/clash_zone_tile/tile as anything in tiles)
		var/hidden = tile.loc.density ? INVISIBILITY_MAXIMUM : 0
		if(tile.invisibility != hidden)
			tile.invisibility = hidden

/datum/clash_zone/proc/reset()
	owner = null
	capturing = null
	progress = 0
	contested = FALSE

/datum/clash_zone/proc/get_occupant_mobs()
	. = list()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list)
		if(!fighter.client || fighter.statistic_exempt || fighter.stat != CONSCIOUS || !covered[get_turf(fighter)])
			continue
		if(fighter.faction in list(FACTION_MARINE, FACTION_UPP))
			. += fighter

/datum/clash_zone/proc/get_occupants()
	. = list()
	for(var/mob/living/carbon/human/fighter as anything in get_occupant_mobs())
		.[fighter.faction] = (.[fighter.faction] || 0) + 1

/datum/clash_zone/proc/get_state_text(capture_time)
	if(contested)
		return "contested"
	if(capturing && capture_time)
		return "[capturing == FACTION_MARINE ? "USCM" : "UPP"] [round(progress / capture_time * 100)]%"
	if(owner)
		return owner == FACTION_MARINE ? "USCM" : "UPP"
	return "open"

/datum/clash_zone/proc/update_visuals(owner_color, capture_time)
	var/tint = owner_color || "#bbbbbb"
	var/state = get_state_text(capture_time)
	if(shown == "[tint][state]")
		return
	shown = "[tint][state]"
	for(var/obj/effect/clash_zone_tile/tile as anything in tiles)
		tile.color = tint
	var/state_line = state == "open" ? "" : "<br><span style='font-size: 6px'>[state]</span>"
	marker.maptext = "<span class='maptext center' style='font-size: 12px; color: [tint]'>[label]</span>[state_line]"

/datum/clash_zone/proc/show_preview(seconds_left)
	if(shown == "[seconds_left]")
		return
	shown = "[seconds_left]"
	marker.maptext = "<span class='maptext center' style='font-size: 8px; color: #ffffff'>NEXT HILL<br>[clash_clock_text(seconds_left)]</span>"

/proc/get_clash_zone_turfs(turf/center, radius)
	. = list()
	var/area/clash_arena/zone_area = get_area(center)
	if(istype(zone_area) && zone_area.clash_zone)
		for(var/turf/spot in zone_area)
			if(spot.z == center.z)
				. += spot
		return
	for(var/turf/spot as anything in RANGE_TURFS(radius, center))
		if(sqrt((spot.x - center.x) ** 2 + (spot.y - center.y) ** 2) <= radius + 0.3)
			. += spot

/proc/clash_clock_text(seconds)
	return "[floor(seconds / 60)]:[seconds % 60 < 10 ? "0" : ""][seconds % 60]"

/proc/clash_turf_passable(turf/spot)
	if(!spot || spot.density)
		return FALSE
	for(var/obj/thing in spot)
		if(thing.density && thing.anchored && !istype(thing, /obj/structure/machinery/door))
			return FALSE
	return TRUE

/proc/clash_in_base(turf/spot)
	var/area/clash_arena/here = get_area(spot)
	return istype(here) && here.clash_faction

/proc/get_clash_base_centres(z)
	var/list/sums = list()
	for(var/area/clash_arena/base in GLOB.all_areas)
		if(!base.clash_faction)
			continue
		for(var/turf/spot in base)
			if(spot.z != z)
				continue
			var/list/sum = sums[base.clash_faction]
			if(!sum)
				sum = list(0, 0, 0)
				sums[base.clash_faction] = sum
			sum[1] += spot.x
			sum[2] += spot.y
			sum[3] += 1
	. = list()
	for(var/faction in sums)
		var/list/sum = sums[faction]
		.[faction] = list(sum[1] / sum[3], sum[2] / sum[3])

/proc/get_clash_reachable_turfs(turf/start, max_steps = CLASH_ZONE_SEARCH_STEPS)
	. = list()
	if(!clash_turf_passable(start))
		return
	var/list/steps = list()
	steps[start] = 0
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index]
		index++
		var/taken = steps[current]
		if(!clash_in_base(current))
			. += current
		if(taken >= max_steps)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(steps[next]) || !clash_turf_passable(next))
				continue
			steps[next] = taken + 1
			queue += next

/proc/get_clash_nearest_turf(list/candidates, x, y)
	var/best_distance
	for(var/turf/spot as anything in candidates)
		var/distance = (spot.x - x) ** 2 + (spot.y - y) ** 2
		if(isnull(best_distance) || distance < best_distance)
			best_distance = distance
			. = spot

/proc/get_clash_open_turf_near(x, y, z)
	x = clamp(round(x), 1, world.maxx)
	y = clamp(round(y), 1, world.maxy)
	var/turf/origin = locate(x, y, z)
	if(!origin)
		return null
	for(var/reach in 0 to 12)
		var/list/ring = list()
		for(var/turf/spot as anything in RANGE_TURFS(reach, origin))
			if(max(abs(spot.x - x), abs(spot.y - y)) == reach && clash_turf_passable(spot) && !clash_in_base(spot))
				ring += spot
		if(length(ring))
			return get_clash_nearest_turf(ring, x, y)
	return null

/proc/get_clash_ground_z()
	var/list/levels = SSmapping.levels_by_trait(ZTRAIT_GROUND)
	return length(levels) ? levels[1] : null

/proc/get_clash_marker(marker_type, z)
	for(var/obj/effect/landmark/clash_objective/mark as anything in GLOB.clash_objective_landmarks)
		if(mark.type == marker_type && mark.z == z)
			return mark
	return null

/proc/clash_marker_problem(turf/spot)
	if(!clash_turf_passable(spot))
		return "is on a wall or blocked tile"
	if(clash_in_base(spot))
		return "is inside a base"
	return null

/proc/clash_marker_spot(obj/effect/landmark/clash_objective/mark, default_radius)
	return list(mark.label, get_turf(mark), clamp(round(mark.radius || default_radius), 1, CLASH_ZONE_MAX_RADIUS))

/proc/get_clash_auto_objective_spots(count, radius)
	. = list()
	var/z = get_clash_ground_z()
	if(!z)
		return
	var/list/centres = get_clash_base_centres(z)
	var/list/uscm = centres[FACTION_MARINE]
	var/list/upp = centres[FACTION_UPP]
	var/mid_x = world.maxx / 2
	var/mid_y = world.maxy / 2
	var/flank_x = world.maxx / 4
	var/flank_y = 0
	if(uscm && upp)
		mid_x = (uscm[1] + upp[1]) / 2
		mid_y = (uscm[2] + upp[2]) / 2
		var/span_x = upp[1] - uscm[1]
		var/span_y = upp[2] - uscm[2]
		var/span = max(1, sqrt(span_x ** 2 + span_y ** 2))
		var/offset = min(span * 0.3, 20)
		flank_x = -span_y / span * offset
		flank_y = span_x / span * offset
	else
		log_debug("HVH: no base areas found, objectives placed from the map centre")

	var/turf/middle = get_clash_open_turf_near(mid_x, mid_y, z)
	if(!middle)
		log_debug("HVH: no open ground near the map centre for objectives")
		return
	if(count == 1)
		. += list(list("Hill", middle, radius))
		return
	var/list/reachable = get_clash_reachable_turfs(middle)
	. += list(list("A", get_clash_nearest_turf(reachable, mid_x + flank_x, mid_y + flank_y) || middle, radius))
	. += list(list("B", middle, radius))
	. += list(list("C", get_clash_nearest_turf(reachable, mid_x - flank_x, mid_y - flank_y) || middle, radius))

#undef CLASH_ZONE_SEARCH_STEPS
#undef CLASH_ZONE_MAX_RADIUS

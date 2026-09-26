/// Objective centres of the running match, bots hold these when there are any
GLOBAL_LIST_EMPTY(clash_objective_turfs)
/// Mapper placed objectives, used instead of computed ones when present
GLOBAL_LIST_EMPTY(clash_objective_landmarks)
GLOBAL_DATUM(clash_zone_tile_icon, /icon)

/// Steps the placement flood fill takes out from the middle of the map
#define CLASH_ZONE_SEARCH_STEPS 60

/obj/effect/landmark/clash_objective
	name = "Clash objective"
	/// Shown on the zone and in callouts, zones are ordered by it
	var/label = "A"
	/// Tiles from the centre the zone reaches, null for the mode default
	var/radius

/obj/effect/landmark/clash_objective/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_objective_landmarks += src

/obj/effect/landmark/clash_objective/Destroy()
	GLOB.clash_objective_landmarks -= src
	return ..()

/obj/effect/landmark/clash_objective/a
	label = "A"

/obj/effect/landmark/clash_objective/b
	label = "B"

/obj/effect/landmark/clash_objective/c
	label = "C"

/proc/get_clash_zone_tile_icon()
	if(GLOB.clash_zone_tile_icon)
		return GLOB.clash_zone_tile_icon
	var/icon/tile = icon('icons/effects/effects.dmi', "nothing")
	tile.Scale(32, 32)
	tile.DrawBox(rgb(255, 255, 255, 50), 1, 1, 32, 32)
	GLOB.clash_zone_tile_icon = tile
	return tile

/// Floor tint marking a zone, coloured by whoever holds it
/obj/effect/clash_zone_tile
	name = "objective"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = BELOW_OBJ_LAYER

/obj/effect/clash_zone_tile/Initialize(mapload, ...)
	. = ..()
	icon = get_clash_zone_tile_icon()

/// Letter floating over a zone's centre, with capture progress under it
/obj/effect/clash_zone_label
	name = "objective"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_OBJ_LAYER
	maptext_width = 96
	maptext_height = 32
	maptext_x = -32
	maptext_y = 12

/// One capture zone: a disc of tiles, who holds it, and who is taking it
/datum/clash_zone
	var/label
	var/turf/center
	var/radius
	/// Faction holding it, or null
	var/owner
	/// Faction part way through taking it, or null
	var/capturing
	/// Deciseconds of capture built up by capturing
	var/progress = 0
	var/contested = FALSE
	/// Turf to TRUE for every tile inside the zone
	var/list/covered = list()
	var/list/obj/effect/clash_zone_tile/tiles = list()
	var/obj/effect/clash_zone_label/marker
	/// Colour and state last drawn, so an unchanged zone is not redrawn
	var/shown

/datum/clash_zone/New(label, turf/center, radius)
	. = ..()
	src.label = label
	src.center = center
	src.radius = radius
	for(var/turf/spot as anything in RANGE_TURFS(radius, center))
		if(spot.density || sqrt((spot.x - center.x) ** 2 + (spot.y - center.y) ** 2) > radius + 0.3)
			continue
		covered[spot] = TRUE
		tiles += new /obj/effect/clash_zone_tile(spot)
	marker = new(center)
	GLOB.clash_objective_turfs += center

/datum/clash_zone/Destroy(force)
	GLOB.clash_objective_turfs -= center
	QDEL_LIST(tiles)
	QDEL_NULL(marker)
	center = null
	covered = null
	return ..()

/datum/clash_zone/proc/reset()
	owner = null
	capturing = null
	progress = 0
	contested = FALSE

/// Fighters standing in the zone by faction. Only conscious players count, bots never hold or contest.
/datum/clash_zone/proc/get_occupants()
	. = list()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list)
		if(!fighter.client || fighter.statistic_exempt || fighter.stat != CONSCIOUS || !covered[get_turf(fighter)])
			continue
		if(fighter.faction in list(FACTION_MARINE, FACTION_UPP))
			.[fighter.faction] = (.[fighter.faction] || 0) + 1

/// Short status for the HUD and callouts
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

/// Open, walkable and not blocked by anything anchored, doors count as open
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

/// Average position of each side's base area on level z, faction to list(x, y)
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

/// Walkable turfs outside the bases reachable from start, for placing objectives where players can get to them
/proc/get_clash_reachable_turfs(turf/start)
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
		if(taken >= CLASH_ZONE_SEARCH_STEPS)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(steps[next]) || !clash_turf_passable(next))
				continue
			steps[next] = taken + 1
			queue += next

/// The candidate turf closest to x, y
/proc/get_clash_nearest_turf(list/candidates, x, y)
	var/best_distance
	for(var/turf/spot as anything in candidates)
		var/distance = (spot.x - x) ** 2 + (spot.y - y) ** 2
		if(isnull(best_distance) || distance < best_distance)
			best_distance = distance
			. = spot

/// Walkable turf nearest x, y on level z, searching outward, or null
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

/**
 * Where to put count objectives on the ground level, as a list of list(label, turf, radius).
 * Mapped landmarks win. Otherwise the middle of the line between the two bases, and for more than one,
 * the flanks either side of it, snapped to ground players can actually walk to from the middle.
 */
/proc/get_clash_objective_spots(count, radius)
	. = list()
	var/list/levels = SSmapping.levels_by_trait(ZTRAIT_GROUND)
	if(!length(levels))
		return
	var/z = levels[1]
	var/list/marks = list()
	for(var/obj/effect/landmark/clash_objective/mark as anything in GLOB.clash_objective_landmarks)
		if(mark.z == z)
			marks[mark.label] = mark
	if(length(marks))
		for(var/label in sort_list(marks))
			if(length(.) >= count)
				break
			var/obj/effect/landmark/clash_objective/mark = marks[label]
			. += list(list(count == 1 ? "Hill" : label, get_turf(mark), mark.radius || radius))
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
		// At right angles to the base to base line, so each flank is as far from both bases
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

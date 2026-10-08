#define CLASH_HILL_STATIC "static"
#define CLASH_HILL_MATCH "match"
#define CLASH_HILL_TIMED "timed"
#define CLASH_HILL_WARNING (30 SECONDS)
#define CLASH_HILL_BOTS_MOVE (10 SECONDS)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective
	name = "Objective"
	config_tag = null
	kill_limit = 0
	score_label = "points"
	var/point_limit = 120
	var/zone_count = 1
	var/zone_radius = 3
	var/capture_time = 0
	var/persistent = FALSE
	var/list/datum/clash_zone/zones = list()
	var/list/objective_points = list()
	var/list/round_objective_points = list()
	var/list/point_callouts_made = list()
	var/objective_timer_id
	var/list/zone_notes = list()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/post_setup()
	build_zones()
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/build_zones()
	QDEL_LIST(zones)
	zone_notes = list()
	for(var/list/spot in get_zone_spots())
		add_zone(spot)
	if(!length(zones))
		message_admins("HVH: [name] could not place any objectives on this map. Matches will be decided on time as draws.")
		return
	message_admins("HVH: [name]: [zone_notes.Join(" ")]")
	log_game("HVH: [name]: [zone_notes.Join(" ")]")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/get_zone_spots()
	zone_notes += "Objectives placed automatically."
	return get_clash_auto_objective_spots(zone_count, zone_radius)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/add_zone(list/spot)
	var/datum/clash_zone/zone = new(spot[1], spot[2], spot[3])
	zone.update_visuals(null, capture_time)
	zones += zone
	log_debug("HVH: objective [zone.label] at [zone.center.x],[zone.center.y] radius [zone.radius]")
	return zone

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/plan_bots(datum/clash_bot_director/director)
	var/list/spots = list()
	for(var/datum/clash_zone/zone as anything in zones)
		spots += zone.hold
	director.plan_objectives(spots)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/is_objective_turf(turf/spot)
	for(var/datum/clash_zone/zone as anything in zones)
		if(zone.covered[spot])
			return TRUE
	return FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/can_rebuild_objectives()
	return TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/rebuild_objectives()
	build_zones()
	clash_bot_replan()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_objective_turfs()
	. = list()
	for(var/datum/clash_zone/zone as anything in zones)
		.[zone.label] = zone.center

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/admin_set_score(faction, score)
	objective_points[faction] = score
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_welcome_rules()
	return get_objective_rules()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/get_objective_rules()
	return list()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_win_condition()
	var/unit = matches_per_round > 1 ? "Each match" : "The round"
	var/what = zone_count == 1 ? "Hold the hill to score" : "Take and hold the zones to score"
	return "[unit] lasts [round_time_limit / 600] minutes. [what]. First to [point_limit] points, or the most points when time runs out, wins."

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_score_limit()
	return point_limit

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_match_score(faction)
	return objective_points[faction] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_round_tiebreak(faction)
	return round_objective_points[faction] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_limit_text()
	return "First to [point_limit] points"

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_objective_maptext()
	if(!length(zones))
		return list()
	var/list/parts = list()
	for(var/datum/clash_zone/zone as anything in zones)
		parts += "<span style='color: [zone.owner ? faction_color(zone.owner) : "#bbbbbb"]'>[zone.label]</span> [zone.get_state_text(capture_time)][get_zone_note()]"
	return list("<span class='maptext center'>[parts.Join(" | ")]</span>")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_objective_data()
	. = list()
	for(var/datum/clash_zone/zone as anything in zones)
		. += list(list("label" = zone.label, "state" = "[zone.get_state_text(capture_time)][get_zone_note()]", "color" = zone.owner ? faction_color(zone.owner) : "#bbbbbb"))

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/get_zone_note()
	return ""

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_radar_pins(mob/viewer)
	. = list()
	for(var/datum/clash_zone/zone as anything in zones)
		. += list(list("key" = REF(zone), "turf" = zone.center, "letter" = zone.label == "Hill" ? "H" : zone.label, "tone" = clash_radar_tone(zone.owner, viewer), "hollow" = FALSE))

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/on_match_start()
	objective_points = list()
	point_callouts_made = list()
	for(var/datum/clash_zone/zone as anything in zones)
		zone.reset()
		zone.update_visuals(null, capture_time)
	clash_bot_replan()
	if(!objective_timer_id)
		objective_timer_id = addtimer(CALLBACK(src, PROC_REF(tick_objectives)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/archive_match()
	. = ..()
	objective_points = list()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/on_match_end()
	for(var/faction in objective_points)
		round_objective_points[faction] = (round_objective_points[faction] || 0) + objective_points[faction]

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/tick_objectives()
	if(round_finished)
		deltimer(objective_timer_id)
		objective_timer_id = null
		return
	if(!match_live)
		return
	for(var/datum/clash_zone/zone as anything in zones)
		settle_zone(zone)
		zone.update_visuals(zone.owner ? faction_color(zone.owner) : null, capture_time)
		zone.refresh_tiles()
	var/scored = FALSE
	for(var/datum/clash_zone/zone as anything in zones)
		if(zone.owner && (persistent || !zone.contested))
			objective_points[zone.owner] = (objective_points[zone.owner] || 0) + 1
			scored = TRUE
			clash_progress_zone(zone)
	if(scored)
		update_score_huds()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/points = objective_points[faction] || 0
		if(points >= point_limit)
			finish_match("Point limit reached")
			return
		if(points >= point_limit * 0.75 && !(faction in point_callouts_made))
			point_callouts_made += faction
			var/enemy = faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
			announce_to_faction(faction, "[point_limit - points] points to win.")
			announce_to_faction(enemy, "The enemy is [point_limit - points] points from winning.")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/settle_zone(datum/clash_zone/zone)
	var/list/present = zone.get_occupants()
	var/uscm = present[FACTION_MARINE] || 0
	var/upp = present[FACTION_UPP] || 0
	zone.contested = uscm && upp
	var/alone = uscm && !upp ? FACTION_MARINE : (upp && !uscm ? FACTION_UPP : null)
	if(!persistent)
		if(alone && zone.owner != alone)
			announce_zone(zone, alone)
		zone.owner = alone
		return
	if(!alone)
		if(!zone.contested && zone.capturing)
			zone.progress = max(0, zone.progress - 1 SECONDS)
			if(!zone.progress)
				zone.capturing = null
		return
	if(zone.owner == alone)
		zone.capturing = null
		zone.progress = 0
		return
	if(zone.capturing != alone)
		zone.capturing = alone
		zone.progress = 0
	zone.progress += 1 SECONDS
	if(zone.progress >= capture_time)
		zone.owner = alone
		zone.capturing = null
		zone.progress = 0
		announce_zone(zone, alone)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/announce_zone(datum/clash_zone/zone, faction)
	var/team = faction == FACTION_MARINE ? "USCM" : "UPP"
	var/enemy = faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
	var/what = zone.label == "Hill" ? "the hill" : zone.label
	announce_to_faction(faction, "We have [what].")
	announce_to_faction(enemy, "[team] has taken [what].")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth
	name = GAMEMODE_KOTH
	config_tag = GAMEMODE_KOTH
	point_limit = 250
	zone_count = 1
	zone_radius = 3
	var/list/hill_spots = list()
	var/hill_index = 1
	var/rotation = CLASH_HILL_STATIC
	var/rotate_time = 3 MINUTES
	var/admin_rotation
	var/admin_rotate_time
	var/next_move_at
	var/datum/clash_zone/next_hill

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_koth_point_limit)
		point_limit = ground.tdm_koth_point_limit
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_objective_rules()
	. = list("Occupy the \"hill\" with no enemies on it to score points.")
	switch(rotation)
		if(CLASH_HILL_TIMED)
			. += "The hill moves every [rotate_time / (1 MINUTES)] minute\s."
		if(CLASH_HILL_MATCH)
			. += "The hill moves after every match."
	. += "First team to [point_limit] points wins, otherwise the most points when time runs out."

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_zone_spots()
	hill_spots = list()
	hill_index = 1
	rotation = CLASH_HILL_STATIC
	QDEL_NULL(next_hill)
	next_move_at = null
	var/z = get_clash_ground_z()
	if(!z)
		return list()
	var/obj/effect/landmark/clash_objective/koth_primary/main = get_clash_marker(/obj/effect/landmark/clash_objective/koth_primary, z)
	var/list/alternates = list()
	for(var/marker_type in list(/obj/effect/landmark/clash_objective/koth_secondary, /obj/effect/landmark/clash_objective/koth_tertiary))
		var/obj/effect/landmark/clash_objective/alternate = get_clash_marker(marker_type, z)
		if(alternate)
			alternates += alternate
	if(!main)
		zone_notes += length(alternates) ? "Secondary and tertiary hill markers need a KOTH primary hill marker, so the hill was placed automatically." : "No KOTH hill markers on this map, the hill was placed automatically."
		return get_clash_auto_objective_spots(zone_count, zone_radius)
	var/problem = clash_zone_marker_problem(get_turf(main))
	if(problem)
		zone_notes += "The KOTH primary hill marker [problem], so the hill was placed automatically."
		return get_clash_auto_objective_spots(zone_count, zone_radius)
	hill_spots += list(clash_marker_spot(main, zone_radius))
	for(var/obj/effect/landmark/clash_objective/alternate as anything in alternates)
		problem = clash_zone_marker_problem(get_turf(alternate))
		if(problem)
			zone_notes += "[alternate.name] [problem], skipped."
			continue
		hill_spots += list(clash_marker_spot(alternate, zone_radius))
	var/wanted = admin_rotation || main.rotation
	if(!(wanted in list(CLASH_HILL_STATIC, CLASH_HILL_MATCH, CLASH_HILL_TIMED)))
		zone_notes += "The primary hill marker's rotation \"[wanted]\" is not static, match or timed, so the hill stays put."
		wanted = CLASH_HILL_STATIC
	if(wanted != CLASH_HILL_STATIC && length(hill_spots) < 2)
		zone_notes += "Hill rotation needs a usable secondary or tertiary hill marker, so the hill stays put."
		wanted = CLASH_HILL_STATIC
	if(wanted == CLASH_HILL_MATCH && matches_per_round < 2)
		zone_notes += "Moving the hill after every match needs more than one match per round, so the hill stays put."
		wanted = CLASH_HILL_STATIC
	rotation = wanted
	rotate_time = admin_rotate_time || clamp(round(main.rotate_minutes), 1, 10) MINUTES
	var/how = "it stays put"
	switch(rotation)
		if(CLASH_HILL_TIMED)
			how = "it moves every [rotate_time / (1 MINUTES)] minute\s"
		if(CLASH_HILL_MATCH)
			how = "it moves after every match"
	zone_notes += "The hill comes from the map's primary hill marker with [length(hill_spots) - 1] more usable hill\s, [how]."
	return list(hill_spots[1])

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/rebuild_objectives()
	. = ..()
	if(match_live && rotation == CLASH_HILL_TIMED)
		next_move_at = world.time + rotate_time

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/proc/move_hill(index)
	hill_index = index
	QDEL_NULL(next_hill)
	QDEL_LIST(zones)
	add_zone(hill_spots[index])
	clash_bot_replan()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/proc/get_next_hill_index()
	return hill_index % length(hill_spots) + 1

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/on_match_start()
	. = ..()
	next_move_at = rotation == CLASH_HILL_TIMED ? world.time + rotate_time : null

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/on_match_end()
	. = ..()
	QDEL_NULL(next_hill)
	next_move_at = null

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/reset_arena()
	. = ..()
	if(rotation == CLASH_HILL_STATIC)
		return
	var/target = rotation == CLASH_HILL_MATCH ? match_number % length(hill_spots) + 1 : 1
	if(target == hill_index)
		return
	move_hill(target)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/tick_objectives()
	. = ..()
	if(!match_live || !next_move_at)
		return
	var/left = next_move_at - world.time
	if(left <= 0)
		move_hill(get_next_hill_index())
		next_move_at = world.time + rotate_time
		for(var/faction in list(FACTION_MARINE, FACTION_UPP))
			announce_to_faction(faction, "The hill has moved.")
		return
	if(left > CLASH_HILL_WARNING)
		return
	if(!next_hill)
		var/list/spot = hill_spots[get_next_hill_index()]
		next_hill = new(spot[1], spot[2], spot[3], TRUE)
		for(var/faction in list(FACTION_MARINE, FACTION_UPP))
			announce_to_faction(faction, "The hill moves in [CLASH_HILL_WARNING / 10] seconds. Follow the flashing tiles or the H on your radar.")
	next_hill.show_preview(CEILING(left / 10, 1))

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_zone_note()
	if(!next_move_at || !match_live)
		return ""
	return ", moves in [clash_clock_text(CEILING(max(0, next_move_at - world.time) / 10, 1))]"

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_radar_pins(mob/viewer)
	. = ..()
	if(next_hill)
		. += list(list("key" = REF(next_hill), "turf" = next_hill.center, "letter" = "H", "tone" = "open", "hollow" = TRUE))

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/plan_bots(datum/clash_bot_director/director)
	if(!length(zones))
		director.plan_skirmish()
		return
	director.plan_koth(zones[1], next_hill, next_move_at && next_move_at - world.time < CLASH_HILL_BOTS_MOVE)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_admin_objective_actions()
	if(length(hill_spots) < 2)
		return list()
	return list("Move the hill now", "Set hill rotation")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/do_admin_objective_action(choice, mob/user)
	switch(choice)
		if("Move the hill now")
			move_hill(get_next_hill_index())
			if(next_move_at)
				next_move_at = world.time + rotate_time
			if(match_live)
				for(var/faction in list(FACTION_MARINE, FACTION_UPP))
					announce_to_faction(faction, "The hill has moved.")
			return "Moved the hill to spot [hill_index] of [length(hill_spots)]"
		if("Set hill rotation")
			var/list/options = list("Stays put" = CLASH_HILL_STATIC, "After every match" = CLASH_HILL_MATCH, "On a timer" = CLASH_HILL_TIMED)
			var/picked = tgui_input_list(user, "How should the hill move for the rest of this round?", "Hill rotation", options)
			if(!picked)
				return null
			var/minutes
			if(options[picked] == CLASH_HILL_TIMED)
				minutes = tgui_input_number(user, "Move the hill every how many minutes?", "Hill rotation", rotate_time / (1 MINUTES), 10, 1)
				if(!minutes)
					return null
				admin_rotate_time = round(minutes) MINUTES
				rotate_time = admin_rotate_time
			if(options[picked] == CLASH_HILL_MATCH && matches_per_round < 2)
				to_chat(user, SPAN_WARNING("This round has one match, so the hill would never move."))
				return null
			admin_rotation = options[picked]
			rotation = admin_rotation
			QDEL_NULL(next_hill)
			next_move_at = rotation == CLASH_HILL_TIMED && match_live ? world.time + rotate_time : null
			return "Set the hill rotation to [lowertext(picked)][minutes ? ", every [round(minutes)] minute\s" : ""]"
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination
	name = GAMEMODE_DOMINATION
	config_tag = GAMEMODE_DOMINATION
	point_limit = 300
	zone_count = 3
	zone_radius = 2
	capture_time = 8 SECONDS
	persistent = TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_domination_point_limit)
		point_limit = ground.tdm_domination_point_limit
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination/get_zone_spots()
	var/z = get_clash_ground_z()
	if(!z)
		return list()
	var/list/spots = list()
	var/list/problems = list()
	var/found = FALSE
	for(var/obj/effect/landmark/clash_objective/marker_type as anything in list(/obj/effect/landmark/clash_objective/domination_zone/a, /obj/effect/landmark/clash_objective/domination_zone/b, /obj/effect/landmark/clash_objective/domination_zone/c))
		var/obj/effect/landmark/clash_objective/mark = get_clash_marker(marker_type, z)
		if(!mark)
			problems += "[initial(marker_type.label)] is missing"
			continue
		found = TRUE
		var/problem = clash_zone_marker_problem(get_turf(mark))
		if(problem)
			problems += "[mark.label] [problem]"
			continue
		spots += list(clash_marker_spot(mark, zone_radius))
	if(!length(problems))
		for(var/first in 1 to length(spots) - 1)
			for(var/second in first + 1 to length(spots))
				var/list/one = spots[first]
				var/list/two = spots[second]
				if(length(get_clash_zone_turfs(one[2], one[3]) & get_clash_zone_turfs(two[2], two[3])))
					problems += "[one[1]] overlaps [two[1]]"
	if(!length(problems))
		zone_notes += "Zones A, B and C come from the map's markers."
		return spots
	zone_notes += found ? "Zones were placed automatically because domination marker [english_list(problems)]." : "No domination markers on this map, the zones were placed automatically."
	return get_clash_auto_objective_spots(zone_count, zone_radius)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination/plan_bots(datum/clash_bot_director/director)
	if(!length(zones))
		director.plan_skirmish()
		return
	director.plan_domination(zones)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination/get_objective_rules()
	return list(
		"Take a zone by standing on it with no enemies for [capture_time / 10] seconds.",
		"Every zone your team holds scores points even after you leave them.",
		"First team to [point_limit] points wins, otherwise the most points when time runs out.",
	)

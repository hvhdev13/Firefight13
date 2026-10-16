#define CLASH_PUSH_LOW_TIME (60 SECONDS)
#define CLASH_PUSH_KEEPOUT_POINT_GAP 8

GLOBAL_LIST_EMPTY(clash_push_vendors)

/area/clash_arena/var/push_stage
/area/clash_arena/var/push_point

/area/clash_arena/push/battlefield
	name = "\improper Battlefield"
	minimap_color = MINIMAP_AREA_ENGI

/area/clash_arena/push/battlefield/indoors
	name = "\improper Building"
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/point_a
	name = "\improper Point A"
	icon = 'icons/turf/areas.dmi'
	icon_state = "yellow"
	minimap_color = MINIMAP_AREA_ENGI
	clash_zone = TRUE
	push_point = "A"

/area/clash_arena/push/point_a/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/point_b
	name = "\improper Point B"
	icon = 'icons/turf/areas.dmi'
	icon_state = "green"
	minimap_color = MINIMAP_AREA_ENGI
	clash_zone = TRUE
	push_point = "B"

/area/clash_arena/push/point_b/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/point_c
	name = "\improper Point C"
	icon = 'icons/turf/areas.dmi'
	icon_state = "purple"
	minimap_color = MINIMAP_AREA_ENGI
	clash_zone = TRUE
	push_point = "C"

/area/clash_arena/push/point_c/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/point_d
	name = "\improper Point D"
	icon = 'icons/turf/areas.dmi'
	icon_state = "blue"
	minimap_color = MINIMAP_AREA_ENGI
	clash_zone = TRUE
	push_point = "D"

/area/clash_arena/push/point_d/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/point_e
	name = "\improper Point E"
	icon = 'icons/turf/areas.dmi'
	icon_state = "red"
	minimap_color = MINIMAP_AREA_ENGI
	clash_zone = TRUE
	push_point = "E"

/area/clash_arena/push/point_e/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/attacker_start
	name = "\improper Attacker Start"
	icon = 'icons/turf/areas.dmi'
	icon_state = "blue-red"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 0

/area/clash_arena/push/attacker_start/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/behind_a
	name = "\improper Spawn Behind A"
	icon = 'icons/turf/areas.dmi'
	icon_state = "dk_yellow"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 1

/area/clash_arena/push/behind_a/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/behind_b
	name = "\improper Spawn Behind B"
	icon = 'icons/turf/areas.dmi'
	icon_state = "dk_yellow"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 2

/area/clash_arena/push/behind_b/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/behind_c
	name = "\improper Spawn Behind C"
	icon = 'icons/turf/areas.dmi'
	icon_state = "dk_yellow"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 3

/area/clash_arena/push/behind_c/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/behind_d
	name = "\improper Spawn Behind D"
	icon = 'icons/turf/areas.dmi'
	icon_state = "dk_yellow"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 4

/area/clash_arena/push/behind_d/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/area/clash_arena/push/behind_e
	name = "\improper Spawn Behind E"
	icon = 'icons/turf/areas.dmi'
	icon_state = "dk_yellow"
	minimap_color = MINIMAP_AREA_COMMAND
	push_stage = 5

/area/clash_arena/push/behind_e/indoors
	ceiling = CEILING_METAL
	clash_indoors = TRUE

/obj/effect/landmark/clash_objective/push_point
	name = "Push point"
	icon_state = "o_red"

/obj/effect/landmark/clash_objective/push_point/a
	name = "Push point A"
	label = "A"

/obj/effect/landmark/clash_objective/push_point/b
	name = "Push point B"
	label = "B"

/obj/effect/landmark/clash_objective/push_point/c
	name = "Push point C"
	label = "C"

/obj/effect/landmark/clash_objective/push_point/d
	name = "Push point D"
	label = "D"

/obj/effect/landmark/clash_objective/push_point/e
	name = "Push point E"
	label = "E"

/obj/structure/blocker/clash_gate/push
	name = "spawn shield"
	var/turf/home

/obj/structure/blocker/clash_gate/push/Initialize(mapload, ...)
	. = ..()
	home = get_turf(src)
	moveToNullspace()

/obj/structure/blocker/clash_gate/push/proc/set_owner(new_faction, new_color)
	faction = new_faction
	color = new_color
	if(!new_faction)
		name = initial(name)
		moveToNullspace()
		return
	name = "[new_faction == FACTION_MARINE ? "USCM" : "UPP"] spawn shield"
	forceMove(home)

/obj/effect/landmark/clash_push_vendor
	name = "Push vendor"
	icon_state = "supply"
	var/uscm_type
	var/upp_type
	var/obj/structure/machinery/cm_vending/vendor

/obj/effect/landmark/clash_push_vendor/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_push_vendors += src

/obj/effect/landmark/clash_push_vendor/Destroy()
	GLOB.clash_push_vendors -= src
	QDEL_NULL(vendor)
	return ..()

/obj/effect/landmark/clash_push_vendor/proc/set_owner(faction)
	var/wanted = faction == FACTION_MARINE ? uscm_type : (faction == FACTION_UPP ? upp_type : null)
	if(!QDELETED(vendor) && vendor.type == wanted)
		return
	QDEL_NULL(vendor)
	if(!wanted)
		return
	vendor = new wanted(loc)
	vendor.setDir(dir)
	vendor.vend_delay = 0

/obj/effect/landmark/clash_push_vendor/clothing
	name = "Push vendor (clothing rack)"
	uscm_type = /obj/structure/machinery/cm_vending/clothing/marine/clash
	upp_type = /obj/structure/machinery/cm_vending/clothing/antag/upp/clash

/obj/effect/landmark/clash_push_vendor/gear
	name = "Push vendor (gear rack)"
	uscm_type = /obj/structure/machinery/cm_vending/gear/clash
	upp_type = /obj/structure/machinery/cm_vending/gear/antag/clash

/obj/effect/landmark/clash_push_vendor/guns
	name = "Push vendor (gun rack)"
	uscm_type = /obj/structure/machinery/cm_vending/sorted/cargo_guns/squad_prep/clash
	upp_type = /obj/structure/machinery/cm_vending/sorted/cargo_guns/upp_squad_guns/clash

/obj/effect/landmark/clash_push_vendor/tools
	name = "Push vendor (engineer tools)"
	uscm_type = /obj/structure/machinery/cm_vending/sorted/tech/tool_storage/clash
	upp_type = /obj/structure/machinery/cm_vending/sorted/tech/tool_storage/antag/clash

/obj/effect/landmark/clash_push_vendor/medical
	name = "Push vendor (medical)"
	uscm_type = /obj/structure/machinery/cm_vending/sorted/medical/arena
	upp_type = /obj/structure/machinery/cm_vending/sorted/medical/upp/arena

/datum/game_mode/extended/faction_clash/hvh/tdm/push
	name = GAMEMODE_PUSH
	config_tag = GAMEMODE_PUSH
	kill_limit = 0
	matches_per_round = 2
	countdown_time = 40 SECONDS
	countdown_beeps = 5
	intermission_time = 25 SECONDS
	respawn_cooldown = 15 SECONDS
	team_gap = 1
	score_label = "points"
	capture_award = "Spearhead"
	respawn_wait_label = "NEXT WAVE"
	admins_skip_respawn = FALSE
	var/point_time = 5 MINUTES
	var/point_radius = 3
	var/capture_time = 30 SECONDS
	var/list/capture_rates = list(1, 1.5, 2)
	var/drain_rate = 0.5
	var/tickets_per_attacker = 6
	var/list/ticket_callouts = list(10, 5)
	var/attack_wave = 20 SECONDS
	var/defend_wave = 30 SECONDS
	var/first_attacker
	var/attacker
	var/list/point_spots = list()
	var/list/rooms = list()
	var/list/room_turfs = list()
	var/list/room_centres = list()
	var/list/room_owners = list()
	var/live_index = 0
	var/datum/clash_zone/live_zone
	var/taken = 0
	var/tickets = 0
	var/ticket_refill = 0
	var/best_progress = 0
	var/attack_started_at
	var/last_capture_at
	var/wave_anchor
	var/attack_won = FALSE
	var/last_beep
	var/list/callouts_made = list()
	var/list/attacks = list()
	var/push_timer_id
	var/setup_keepout = 15
	var/list/keepout = list()
	var/list/obj/effect/clash_zone_tile/keepout_marks = list()
	var/attackers_on_point = 0
	var/overtime = FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/push/pre_setup()
	. = ..()
	matches_per_round = initial(matches_per_round)
	respawn_cooldown = initial(respawn_cooldown)
	round_time_limit = point_time
	build_push(get_clash_ground_z())
	first_attacker = pick(FACTION_MARINE, FACTION_UPP)
	prepare_attack(first_attacker)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/side_name(faction)
	return faction == FACTION_MARINE ? "USCM" : "UPP"

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/other_side(faction)
	return faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/defender()
	return other_side(attacker)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/attacker_for_match(number)
	return number % 2 ? first_attacker : other_side(first_attacker)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/build_push(z)
	if(!z)
		return
	var/list/notes = list()
	var/list/zone_turfs = list()
	var/list/room_areas = list()
	var/list/room_open = list()
	var/list/room_tiles = list()
	for(var/area/clash_arena/place in GLOB.all_areas)
		if(!place.push_point && isnull(place.push_stage))
			continue
		var/list/open = list()
		for(var/turf/spot in place)
			if(spot.z != z)
				continue
			if(!isnull(place.push_stage))
				room_tiles[spot] = place.push_stage + 1
			if(clash_turf_passable(spot) && !(locate(/obj/effect/landmark/clash_push_vendor) in spot))
				open += spot
		if(!length(open))
			continue
		if(place.push_point)
			zone_turfs[place.push_point] += open
			continue
		var/stage_key = "[place.push_stage]"
		if(!room_areas[stage_key])
			room_areas[stage_key] = list()
			room_open[stage_key] = list()
		room_areas[stage_key] += place
		room_open[stage_key] += open
	var/list/markers = list(
		"A" = /obj/effect/landmark/clash_objective/push_point/a,
		"B" = /obj/effect/landmark/clash_objective/push_point/b,
		"C" = /obj/effect/landmark/clash_objective/push_point/c,
		"D" = /obj/effect/landmark/clash_objective/push_point/d,
		"E" = /obj/effect/landmark/clash_objective/push_point/e,
	)
	var/missing
	for(var/label in markers)
		var/obj/effect/landmark/clash_objective/mark = get_clash_marker(markers[label], z)
		var/list/zone = zone_turfs[label]
		if(!mark && !length(zone))
			missing = missing || label
			continue
		if(missing)
			notes += "Point [label] is ignored because point [missing] is missing."
			continue
		var/turf/centre = mark ? get_turf(mark) : clash_push_centre(zone)
		if(!isnull(room_tiles[centre]))
			notes += "Point [label] is inside a spawn room."
		for(var/turf/spot as anything in zone)
			var/touching = FALSE
			for(var/direction in GLOB.cardinals)
				if(!isnull(room_tiles[get_step(spot, direction)]))
					touching = TRUE
					break
			if(touching)
				notes += "Point [label] touches a spawn room."
				break
		point_spots += list(list(label, centre, point_radius))
	var/count = length(point_spots)
	if(!count)
		message_admins("HVH: [name] found no points on this map (paint Point A, B, C areas). Attacks can only run out of time.")
		return
	for(var/stage in 0 to count)
		rooms += list(room_areas["[stage]"] || list())
		room_turfs += list(room_open["[stage]"] || list())
		room_owners += null
		room_centres += room_open["[stage]"] ? clash_push_centre(room_open["[stage]"]) : null
		if(!room_open["[stage]"])
			notes += "[stage ? "Spawn Behind [point_spots[stage][1]]" : "Attacker Start"] is missing."
	for(var/stage_key in room_areas)
		if(text2num(stage_key) > count)
			notes += "Spawn Behind [ascii2text(64 + text2num(stage_key))] is painted but the map has only [count] point\s."
	for(var/stage in 0 to count)
		var/doors = place_push_shields(room_turfs[stage + 1], room_tiles, stage)
		if(length(room_turfs[stage + 1]) && !doors)
			notes += "[stage ? "Spawn Behind [point_spots[stage][1]]" : "Attacker Start"] has no way out."
		if(stage == 0 && length(doors))
			var/list/first = point_spots[1]
			var/nearest = 999
			for(var/turf/door as anything in doors)
				nearest = min(nearest, get_dist(door, first[2]))
			if(nearest < setup_keepout + CLASH_PUSH_KEEPOUT_POINT_GAP)
				notes += "Point A is [nearest] tiles from the Attacker Start doors (keep it [setup_keepout + CLASH_PUSH_KEEPOUT_POINT_GAP] or more), so the setup keep-out may cut defenders off from it."
	for(var/obj/effect/landmark/clash_push_vendor/spot as anything in GLOB.clash_push_vendors)
		if(spot.z == z && isnull(room_tiles[get_turf(spot)]))
			notes += "[spot.name] at [spot.x],[spot.y] is outside the spawn rooms."
	if(length(room_turfs[1]))
		add_push_spawn_points(pick(room_turfs[1]))
	var/summary = "[name]: [count] point\s. [length(notes) ? notes.Join(" ") : "Map checks passed."]"
	message_admins("HVH: [summary]")
	log_game("HVH: [summary]")
	return summary

/proc/clash_push_centre(list/turfs)
	var/x_sum = 0
	var/y_sum = 0
	for(var/turf/spot as anything in turfs)
		x_sum += spot.x
		y_sum += spot.y
	return get_clash_nearest_turf(turfs, x_sum / length(turfs), y_sum / length(turfs))

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/place_push_shields(list/open, list/room_tiles, stage)
	. = list()
	for(var/turf/spot as anything in open)
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(spot, direction)
			if(!next || room_tiles[next] == stage + 1 || !clash_turf_passable(next))
				continue
			. += spot
			if(!(locate(/obj/structure/blocker/clash_gate/push) in spot))
				new /obj/structure/blocker/clash_gate/push(spot)
			break

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/add_push_spawn_points(turf/start)
	if(!length(GLOB.latejoin))
		new /obj/effect/landmark/late_join(start)
	var/list/fill_types = list(FACTION_MARINE = /obj/effect/landmark/clash_npc/uscm/fill, FACTION_UPP = /obj/effect/landmark/clash_npc/upp/fill)
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(spawner.team_fill)
			fill_types -= spawner.faction
	for(var/faction in fill_types)
		var/fill_type = fill_types[faction]
		new fill_type(start)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/spawn_stage(faction)
	if(!live_index || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return null
	if(faction == attacker)
		for(var/stage in live_index - 1 to 0 step -1)
			if(length(room_turfs[stage + 1]))
				return stage
		return null
	for(var/stage in live_index to length(point_spots))
		if(length(room_turfs[stage + 1]))
			return stage
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/room_centre(stage)
	return isnull(stage) ? null : room_centres[stage + 1]

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_side_spawn_turf(faction)
	var/stage = spawn_stage(faction)
	if(isnull(stage))
		return null
	var/list/spots = room_turfs[stage + 1]
	var/list/free = list()
	for(var/turf/spot as anything in spots)
		if(!(locate(/mob/living) in spot))
			free += spot
	return pick(length(free) ? free : spots)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/apply_rooms()
	var/attack_stage = spawn_stage(attacker)
	var/defend_stage = spawn_stage(defender())
	for(var/index in 1 to length(room_owners))
		var/owner = index - 1 == attack_stage ? attacker : (index - 1 == defend_stage ? defender() : null)
		if(owner == room_owners[index])
			continue
		room_owners[index] = owner
		for(var/area/clash_arena/room as anything in rooms[index])
			room.clash_faction = owner
		if(owner)
			clear_room(rooms[index], owner)
	for(var/obj/structure/blocker/clash_gate/push/gate in GLOB.clash_gates)
		var/owner = room_owner_at(gate.home)
		if(gate.faction != owner)
			gate.set_owner(owner, owner && faction_color(owner))
	for(var/obj/effect/landmark/clash_push_vendor/spot as anything in GLOB.clash_push_vendors)
		spot.set_owner(room_owner_at(get_turf(spot)))
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		var/turf/new_home = get_side_spawn_turf(bot.body?.faction)
		if(new_home)
			bot.home = new_home

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/room_owner_at(turf/spot)
	var/area/clash_arena/room = get_area(spot)
	return istype(room) && !isnull(room.push_stage) ? room.clash_faction : null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/clear_room(list/room_areas, owner)
	for(var/area/clash_arena/room as anything in room_areas)
		for(var/turf/spot in room)
			for(var/obj/structure/machinery/defenses/sentry/turret in spot)
				if(turret.clash_faction && turret.clash_faction != owner)
					qdel(turret)
			if(!match_live)
				continue
			for(var/mob/living/carbon/human/fighter in spot)
				if(fighter.stat == DEAD || fighter.faction == owner || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)))
					continue
				var/turf/fallback = get_side_spawn_turf(fighter.faction)
				if(!fallback)
					continue
				fighter.forceMove(fallback)
				to_chat(fighter, SPAN_WARNING("This spawn now belongs to the enemy. You fall back to your own."))

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/prepare_attack(faction)
	attacker = faction
	live_index = length(point_spots) ? 1 : 0
	taken = 0
	tickets = 0
	attack_won = FALSE
	last_capture_at = null
	callouts_made = list()
	open_point()
	apply_rooms()
	clash_bot_replan()
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/open_point()
	QDEL_NULL(live_zone)
	best_progress = 0
	if(!live_index)
		return
	var/list/spot = point_spots[live_index]
	live_zone = new(spot[1], spot[2], spot[3])
	live_zone.update_visuals(null, capture_time)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/reset_arena()
	prepare_attack(attacker_for_match(match_number + 1))
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/announce_countdown()
	var/first = live_zone ? live_zone.label : "the first point"
	var/seconds = countdown_time / 10
	announce_to_faction(attacker, "[side_name(attacker)] attacks. Take [first] first. You are held at your spawn for [seconds] seconds while the enemy sets up.")
	announce_to_faction(defender(), "[side_name(defender())] defends. Set up on [first], the attack starts in [seconds] seconds. Keep out of the marked area around the enemy spawn until then.")
	build_keepout()
	for(var/client/player as anything in GLOB.clients)
		show_role_banner(player)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/build_keepout()
	clear_keepout()
	if(!live_zone)
		return
	for(var/obj/structure/blocker/clash_gate/push/gate in GLOB.clash_gates)
		if(gate.faction != attacker)
			continue
		for(var/turf/spot in range(setup_keepout, gate))
			if(keepout[spot] || !clash_turf_passable(spot) || clash_in_base(spot) || live_zone.covered[spot] || get_dist(spot, live_zone.center) <= CLASH_PUSH_KEEPOUT_POINT_GAP)
				continue
			keepout[spot] = TRUE
			RegisterSignal(spot, COMSIG_TURF_ENTER, PROC_REF(on_keepout_enter))
	for(var/turf/spot as anything in keepout)
		var/obj/effect/clash_zone_tile/mark = new(spot)
		mark.color = faction_color(attacker)
		keepout_marks += mark

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/clear_keepout()
	for(var/turf/spot as anything in keepout)
		UnregisterSignal(spot, COMSIG_TURF_ENTER)
	keepout = list()
	QDEL_LIST(keepout_marks)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/keeps_out(mob/living/mover, turf/spot)
	return keepout[spot] && mover.faction == defender() && !keepout[get_turf(mover)]

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/on_keepout_enter(turf/spot, atom/movable/mover)
	SIGNAL_HANDLER
	if(!isliving(mover) || !keeps_out(mover, spot))
		return NONE
	mover.balloon_alert(mover, "too close to the enemy spawn")
	return COMPONENT_TURF_DENY_MOVEMENT

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/show_role_banner(client/player)
	var/side = clash_side_of(player.mob)
	var/first = live_zone ? live_zone.label : "the first point"
	if(side == attacker)
		clash_show_match_banner(player, "ATTACK", faction_color(side), "Take [first]. Held at your spawn until the setup ends.")
	else if(side == defender())
		clash_show_match_banner(player, "DEFEND", faction_color(side), "Set up on [first]. Keep out of the marked area around their spawn.")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/holds_side(faction)
	return bases_sealed && faction == attacker

/datum/game_mode/extended/faction_clash/hvh/tdm/push/start_round_timer()
	round_end_time = world.time + point_time
	if(!radar_timer_id)
		start_clash_radar()
	log_debug("HVH: [side_name(attacker)] attack started, [point_time / 600] minutes per point")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/on_match_start()
	clear_keepout()
	overtime = FALSE
	attack_started_at = world.time
	wave_anchor = world.time
	last_beep = null
	tickets = tickets_per_attacker * max(1, count_fighters(attacker))
	ticket_refill = tickets
	clash_bot_replan()
	show_final_count(0)
	for(var/client/player as anything in GLOB.clients)
		var/side = clash_side_of(player.mob)
		if(side == attacker)
			clash_show_match_banner(player, "TAKE [live_zone?.label]", faction_color(side), "[point_time / 600] minutes per point, [tickets] tickets.")
		else if(side == defender())
			clash_show_match_banner(player, "HOLD [live_zone?.label]", faction_color(side), "The attack is on.")
	if(!push_timer_id)
		push_timer_id = addtimer(CALLBACK(src, PROC_REF(tick_push)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/on_match_end()
	attacks[attacker] = list("points" = taken, "time" = last_capture_at ? last_capture_at - attack_started_at : 0, "progress" = attack_won ? 0 : best_progress)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/count_fighters(faction, standing_only = FALSE)
	. = 0
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list)
		if(fighter.faction != faction || !is_ground_level(fighter.z) || !clash_counts_on_objectives(fighter))
			continue
		if(standing_only && fighter.stat == UNCONSCIOUS && fighter.health < 0)
			continue
		.++

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/tick_push()
	if(round_finished)
		deltimer(push_timer_id)
		push_timer_id = null
		return
	if(!match_live || !live_zone)
		return
	settle_point()
	if(!match_live)
		return
	var/left = round_end_time - world.time
	if(left <= 0)
		if(!attackers_on_point)
			round_time_expired(match_number)
			return
		if(!overtime)
			start_overtime()
		return
	if(tickets <= 0 && !count_fighters(attacker, TRUE))
		finish_match("Out of tickets")
		return
	var/seconds = CEILING(left / 10, 1)
	if(seconds <= 3 && seconds != last_beep)
		last_beep = seconds
		match_countdown_beep(match_number, FALSE)
	var/callout = "time[live_index]"
	if(left <= CLASH_PUSH_LOW_TIME && !(callout in callouts_made))
		callouts_made += callout
		announce_to_faction(attacker, "One minute left to take [live_zone.label].")
		announce_to_faction(defender(), "Hold [live_zone.label] for one more minute.")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/is_overtime()
	return overtime && match_live

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/start_overtime()
	overtime = TRUE
	var/label = live_zone.label
	announce_to_faction(attacker, "Overtime! Stay on [label] and take it. Leave it and the attack is over.")
	announce_to_faction(defender(), "Overtime! Clear [label] of attackers to end the attack.")
	for(var/client/player as anything in GLOB.clients)
		clash_show_match_banner(player, "OVERTIME", "#ffb840", "The attack ends when no attacker is on [label].")
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/settle_point()
	var/list/present = live_zone.get_occupants()
	var/attacking = present[attacker] || 0
	attackers_on_point = attacking
	var/defending = present[defender()] || 0
	live_zone.contested = attacking && defending
	if(attacking && !defending)
		if(!live_zone.capturing)
			announce_to_faction(defender(), "[live_zone.label] is being captured!")
		live_zone.capturing = attacker
		live_zone.progress += 1 SECONDS * capture_rates[min(attacking, length(capture_rates))]
		clash_progress_zone(live_zone, attacker)
	else if(!attacking)
		live_zone.progress = max(0, live_zone.progress - 1 SECONDS * drain_rate)
	if(!live_zone.progress)
		live_zone.capturing = null
	best_progress = max(best_progress, min(1, live_zone.progress / capture_time))
	if(live_zone.progress >= capture_time)
		capture_point()
		return
	live_zone.update_visuals(live_zone.capturing ? faction_color(attacker) : null, capture_time)
	live_zone.refresh_tiles()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/capture_point()
	var/label = live_zone.label
	taken++
	last_capture_at = world.time
	for(var/mob/living/carbon/human/fighter as anything in live_zone.get_occupant_mobs())
		if(fighter.faction != attacker)
			continue
		var/list/entry = get_score_entry(fighter.real_name, fighter.faction, fighter.mind?.ckey || fighter.ckey)
		entry["captures"] = (entry["captures"] || 0) + 1
		clash_progress_point_capture(fighter)
	log_debug("HVH: [side_name(attacker)] took point [label], [taken] of [length(point_spots)]")
	if(taken >= length(point_spots))
		attack_won = TRUE
		finish_match("All points taken")
		return
	var/early = get_early_finish()
	if(early)
		attack_won = TRUE
		finish_match(early)
		return
	live_index++
	open_point()
	round_end_time = world.time + point_time
	last_beep = null
	overtime = FALSE
	var/was_out = tickets <= 0
	tickets = max(tickets, ticket_refill)
	apply_rooms()
	if(was_out)
		clash_bot_refill()
	clash_bot_replan()
	var/next = live_zone.label
	announce_to_faction(attacker, "We took [label]. Push on to [next].")
	announce_to_faction(defender(), "[label] has fallen. Fall back and hold [next].")
	for(var/client/player as anything in GLOB.clients)
		clash_show_match_banner(player, "[label] TAKEN", faction_color(attacker), "Next point: [next]")
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/get_early_finish()
	var/list/first = attacks[defender()]
	if(match_number < 2 || !first)
		return null
	if(taken > first["points"])
		return "[side_name(attacker)] took more points"
	if(taken == first["points"] && last_capture_at - attack_started_at < first["time"])
		return "[side_name(attacker)] matched the points faster"
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_match_winner(uscm, upp)
	return attack_won ? attacker : defender()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/finish_match(reason)
	var/before = length(match_results)
	. = ..()
	if(length(match_results) == before)
		return
	var/winner = attack_won ? attacker : defender()
	var/title = attack_won ? "[side_name(attacker)] BROKE THROUGH" : "[side_name(defender())] HELD"
	for(var/client/player as anything in GLOB.clients)
		clash_show_match_banner(player, title, faction_color(winner), "[reason]. [side_name(attacker)] took [taken] of [length(point_spots)].")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_respawn_cooldown(mob/user)
	var/side = clash_side_of(user)
	return side ? wave_period(side) : respawn_cooldown

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_respawn_wait(mob/user)
	var/side = clash_side_of(user)
	if(!(side in list(FACTION_MARINE, FACTION_UPP)))
		return ..()
	return match_live ? next_wave_wait(side, user.timeofdeath) : 0

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_side_respawn_delay(faction)
	return match_live ? max(1, next_wave_wait(faction, world.time)) : 1 SECONDS

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/wave_period(faction)
	return faction == attacker ? attack_wave : defend_wave

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/next_wave_wait(faction, since)
	var/period = wave_period(faction)
	var/wave_at = wave_anchor + CEILING(max(0, since - wave_anchor) / period, 1) * period
	return max(0, wave_at - world.time)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_spawn_block(faction)
	if(match_live && faction == attacker && tickets <= 0)
		return "No tickets left"
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/on_fighter_spawned(mob/living/carbon/human/fighter)
	if(countdown_end_time && fighter.client)
		show_role_banner(fighter.client)
	if(!match_live || fighter.faction != attacker)
		return
	tickets = max(0, tickets - 1)
	if(tickets in ticket_callouts)
		announce_to_faction(attacker, "[tickets] tickets left.")
	if(!tickets)
		announce_to_faction(attacker, "Out of tickets. No more respawns this attack.")
		announce_to_faction(defender(), "The enemy is out of tickets. Finish them.")
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/plan_bots(datum/clash_bot_director/director)
	if(!live_zone)
		director.plan_skirmish()
		return
	director.own_base = room_centre(spawn_stage(director.faction))
	director.enemy_base = room_centre(spawn_stage(director.enemy_faction()))
	director.plan_push(live_zone, director.faction == attacker)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/is_objective_turf(turf/spot)
	return live_zone && live_zone.covered[spot]

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_objective_turfs()
	. = list()
	for(var/list/spot as anything in point_spots)
		.["Point [spot[1]]"] = spot[2]

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/get_point_states()
	. = list()
	for(var/index in 1 to length(point_spots))
		var/list/spot = point_spots[index]
		if(index <= taken)
			. += list(list("label" = spot[1], "state" = "taken", "color" = faction_color(attacker)))
		else if(index == live_index && live_zone)
			. += list(list("label" = spot[1], "state" = live_zone.get_state_text(capture_time), "color" = "#ffffff"))
		else
			. += list(list("label" = spot[1], "state" = "locked", "color" = "#bbbbbb"))

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_objective_data()
	return get_point_states()

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_objective_maptext()
	if(!length(point_spots))
		return list()
	var/list/parts = list()
	for(var/list/point as anything in get_point_states())
		parts += "<span style='color: [point["color"]]'>[point["label"]]</span> [point["state"]]"
	return list("<span class='maptext center'>[parts.Join(" | ")]</span>")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_radar_pins(mob/viewer)
	. = list()
	for(var/index in 1 to length(point_spots))
		var/list/spot = point_spots[index]
		var/done = index <= taken
		. += list(list("key" = "push[index]", "turf" = spot[2], "letter" = spot[1], "tone" = done ? clash_radar_tone(attacker, viewer) : "open", "hollow" = !done && index != live_index))

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_match_score(faction)
	return faction == attacker ? taken : (attacks[faction]?["points"] || 0)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_panel_score(faction)
	return get_match_score(faction)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_round_tiebreak(faction)
	return attacks[faction]?["points"] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_score_limit()
	return length(point_spots)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_limit_text()
	return "Most points taken"

/datum/game_mode/extended/faction_clash/hvh/tdm/push/can_set_score()
	return FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_series_line()
	return attacker ? "Attacking: [side_name(attacker)]" : null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_panel_pips()
	return 0

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_panel_subline(faction)
	if(round_finished || intermission_end_time)
		return null
	if(faction != attacker)
		return "defending"
	return match_live ? "[tickets] ticket\s" : "attacking"

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_clock_parts()
	. = ..()
	if(round_finished)
		return
	if(is_overtime())
		.[2] = "OVERTIME"
	else if(intermission_end_time)
		.[2] = "SIDES SWAP"
	else if(countdown_end_time && !match_live)
		.[2] = "SETUP"
	else if(match_live && live_zone)
		.[2] = "TAKE [live_zone.label]"

/datum/game_mode/extended/faction_clash/hvh/tdm/push/proc/get_attack_winner()
	var/list/uscm = attacks[FACTION_MARINE]
	var/list/upp = attacks[FACTION_UPP]
	if(!uscm || !upp)
		return null
	if(uscm["points"] != upp["points"])
		return uscm["points"] > upp["points"] ? FACTION_MARINE : FACTION_UPP
	if(uscm["points"] && uscm["time"] != upp["time"])
		return uscm["time"] < upp["time"] ? FACTION_MARINE : FACTION_UPP
	if(uscm["progress"] != upp["progress"])
		return uscm["progress"] > upp["progress"] ? FACTION_MARINE : FACTION_UPP
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_round_result()
	switch(get_attack_winner())
		if(FACTION_MARINE)
			return MODE_INFESTATION_M_MAJOR
		if(FACTION_UPP)
			return MODE_FACTION_CLASH_UPP_MAJOR
	return MODE_FACTION_CLASH_DRAW

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_round_result_line()
	var/winner = get_attack_winner()
	if(!winner)
		var/list/any = attacks[FACTION_MARINE] || attacks[FACTION_UPP]
		return any ? "Draw, [any["points"]] point\s each." : "Draw."
	var/list/won = attacks[winner]
	var/list/lost = attacks[other_side(winner)]
	if(won["points"] > lost["points"])
		return "[side_name(winner)] wins, [won["points"]] points to [lost["points"]]."
	if(won["points"])
		return "[side_name(winner)] wins, [won["points"]] point\s each, taken faster."
	return "[side_name(winner)] wins, no points taken, [side_name(winner)] came closer."

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_match_result_line(list/result, number)
	if(isnull(number))
		number = length(match_results)
	var/side = attacker_for_match(number)
	return "[side_name(side)] took [side == FACTION_MARINE ? result["uscm"] : result["upp"]] of [length(point_spots)] point\s."

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_admin_objective_actions()
	return list("Take the live point", "Set tickets")

/datum/game_mode/extended/faction_clash/hvh/tdm/push/do_admin_objective_action(choice, mob/user)
	switch(choice)
		if("Take the live point")
			if(!match_live || !live_zone)
				to_chat(user, SPAN_WARNING("No attack is running right now."))
				return null
			var/label = live_zone.label
			admin_tampered = TRUE
			capture_point()
			return "Took point [label] for the [side_name(attacker)] attack"
		if("Set tickets")
			var/amount = tgui_input_number(user, "Attacker tickets. Now: [tickets].", "Tickets", tickets, 500, 0)
			if(isnull(amount))
				return null
			admin_tampered = TRUE
			tickets = round(amount)
			update_score_huds()
			return "Set the [side_name(attacker)] tickets to [tickets]"
	return null

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_welcome_tagline()
	return "Take the ground. Hold the line."

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_welcome_rules()
	return list(
		"One side attacks and the other defends, then the sides swap.",
		"Attackers take the points in order. Stand on the live point to capture it. More attackers capture faster, any defender on it stops the capture.",
		"Attackers get [point_time / 600] minutes per point and a pool of tickets. Every attacker respawn costs a ticket, revives are free.",
		"Respawns come in waves, attackers every [attack_wave / 10] seconds, defenders every [defend_wave / 10].",
		"The side that takes more points wins. With the same number of points, the faster attack wins.",
		"Bots fill lowpop and have a grey \[BOT\] tag and a chevron marker. Kills on bots give 25% of regular XP.",
	)

/datum/game_mode/extended/faction_clash/hvh/tdm/push/get_win_condition()
	return "Each side attacks once. Attackers have [point_time / 600] minutes per point. Take more points than the enemy, or the same number faster."

#undef CLASH_PUSH_LOW_TIME
#undef CLASH_PUSH_KEEPOUT_POINT_GAP

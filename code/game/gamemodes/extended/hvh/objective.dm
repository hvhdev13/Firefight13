/// Arena modes won on held ground instead of kills. Kills are still tracked for stats, streaks and MVP. Never picked directly.
/datum/game_mode/extended/faction_clash/hvh/tdm/objective
	name = "Objective"
	config_tag = null
	kill_limit = 0
	score_label = "points"
	/// Points that win the match early
	var/point_limit = 120
	var/zone_count = 1
	var/zone_radius = 3
	/// Deciseconds a side must hold a zone alone to take it, 0 to hold it only while standing on it
	var/capture_time = 0
	/// Whether a taken zone stays taken, and scores, after its holders leave
	var/persistent = FALSE
	var/list/datum/clash_zone/zones = list()
	var/list/objective_points = list()
	var/list/round_objective_points = list()
	/// Factions already told they are close to the point limit this match
	var/list/point_callouts_made = list()
	var/objective_timer_id

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_point_limit)
		point_limit = ground.tdm_point_limit
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/post_setup()
	build_zones()
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/build_zones()
	QDEL_LIST(zones)
	for(var/list/spot in get_clash_objective_spots(zone_count, zone_radius))
		var/datum/clash_zone/zone = new(spot[1], spot[2], spot[3])
		zone.update_visuals(null, capture_time)
		zones += zone
		log_debug("HVH: objective [zone.label] at [zone.center.x],[zone.center.y] radius [zone.radius]")
	if(!length(zones))
		message_admins("HVH: [name] could not place any objectives on this map. Matches will be decided on time as draws.")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/can_rebuild_objectives()
	return TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/rebuild_objectives()
	build_zones()
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.post && !bot.post.rally_id)
			bot.anchor = bot.post.get_hold_turf()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_objective_turfs()
	. = list()
	for(var/datum/clash_zone/zone as anything in zones)
		.[zone.label] = zone.center

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/admin_set_score(faction, score)
	objective_points[faction] = score
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_welcome_rules()
	. = ..()
	.[1] = get_objective_rule()

/// The rule line explaining how this mode scores
/datum/game_mode/extended/faction_clash/hvh/tdm/objective/proc/get_objective_rule()
	return ""

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
		parts += "<span style='color: [zone.owner ? faction_color(zone.owner) : "#bbbbbb"]'>[zone.label]</span> [zone.get_state_text(capture_time)]"
	return list("<span class='maptext center'>[parts.Join(" | ")]</span>")

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/get_objective_data()
	. = list()
	for(var/datum/clash_zone/zone as anything in zones)
		. += list(list("label" = zone.label, "state" = zone.get_state_text(capture_time), "color" = zone.owner ? faction_color(zone.owner) : "#bbbbbb"))

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/on_match_start()
	objective_points = list()
	point_callouts_made = list()
	for(var/datum/clash_zone/zone as anything in zones)
		zone.reset()
		zone.update_visuals(null, capture_time)
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.post && !bot.post.rally_id)
			bot.anchor = bot.post.get_hold_turf()
	if(!objective_timer_id)
		objective_timer_id = addtimer(CALLBACK(src, PROC_REF(tick_objectives)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/archive_match()
	. = ..()
	objective_points = list()

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/on_match_end()
	for(var/faction in objective_points)
		round_objective_points[faction] = (round_objective_points[faction] || 0) + objective_points[faction]

/// Once a second: settle who holds each zone, then score it
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
	for(var/datum/clash_zone/zone as anything in zones)
		if(zone.owner && (persistent || !zone.contested))
			objective_points[zone.owner] = (objective_points[zone.owner] || 0) + 1
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

/// Works out a zone's holder from who is standing in it
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
		// Nobody pushing it, so a half taken zone slips back
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

/// King of the Hill: one hill in the middle, a point a second while one side stands on it alone
/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth
	name = GAMEMODE_KOTH
	config_tag = GAMEMODE_KOTH
	point_limit = 120
	zone_count = 1
	zone_radius = 3

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/koth/get_objective_rule()
	var/unit = matches_per_round > 1 ? "Matches" : "Rounds"
	return "[unit] last [round_time_limit / 600] minutes. Stand on the hill with no enemies on it to score a point every second. First to [point_limit] points wins, otherwise the most points when time runs out. Bots fight over the hill but cannot hold or contest it."

/// Domination: three zones, taken by holding them alone for a few seconds, each scoring for its holder every second
/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination
	name = GAMEMODE_DOMINATION
	config_tag = GAMEMODE_DOMINATION
	point_limit = 300
	zone_count = 3
	zone_radius = 2
	capture_time = 8 SECONDS
	persistent = TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/objective/domination/get_objective_rule()
	var/unit = matches_per_round > 1 ? "Matches" : "Rounds"
	return "[unit] last [round_time_limit / 600] minutes. Take a zone by standing on it with no enemies for [capture_time / 10] seconds. Every zone you hold scores a point each second, even after you leave it. First to [point_limit] points wins, otherwise the most points when time runs out. Bots fight over the zones but cannot take or contest them."

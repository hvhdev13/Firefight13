/// How fast a line fades when it expires
#define KILLFEED_FADE (5 DECISECONDS)
/// How fast a line is flicked out when a newer kill pushes it off
#define KILLFEED_PUSH_FADE (2 DECISECONDS)
/// How long a killfeed line stays up
#define KILLFEED_LIFETIME (8 SECONDS)
/// Player gap that locks the larger side from being joined
#define CLASH_TEAM_GAP 5
#define CLASH_USCM_SQUADS list(SQUAD_MARINE_1, SQUAD_MARINE_2)
#define CLASH_MAP_VOTE_LEAD (5 MINUTES)
/// Kill counts that trigger a streak announcement
GLOBAL_LIST_INIT(clash_streak_steps, list(3, 5, 7, 10, 15, 20))

/datum/game_mode/extended/faction_clash/cm_vs_upp
	name = GAMEMODE_FACTION_CLASH_UPP_CM
	config_tag = GAMEMODE_FACTION_CLASH_UPP_CM
	flags_round_type = MODE_THUNDERSTORM|MODE_FACTION_CLASH
	starting_round_modifiers = list(
		/datum/gamemode_modifier/blood_optimization,
		/datum/gamemode_modifier/defib_past_armor,
		/datum/gamemode_modifier/disable_combat_cas,
		/datum/gamemode_modifier/disable_ib,
		/datum/gamemode_modifier/disable_mortar,
		/datum/gamemode_modifier/disable_ob,
		/datum/gamemode_modifier/disable_attacking_corpses,
		/datum/gamemode_modifier/disable_long_range_sentry,
		/datum/gamemode_modifier/disable_stripdrag_enemy,
		/datum/gamemode_modifier/indestructible_splints,
		/datum/gamemode_modifier/mortar_laser_warning,
		/datum/gamemode_modifier/no_body_c4,
		/datum/gamemode_modifier/heavy_specialists,
		/datum/gamemode_modifier/weaker_explosions_fire,
	)

	taskbar_icon = 'icons/taskbar/gml_hvh.png'
	skip_roundend_votes = TRUE
	var/upp_ship = "ssv_rostock.dmm"
	var/round_time_limit = 30 MINUTES
	var/scoring_started = FALSE
	var/list/faction_kills = list()
	var/list/faction_deaths = list()
	var/list/player_scores = list()
	var/list/environment_kills = list()
	var/list/killfeed = list()
	var/list/kill_streaks = list()
	var/list/last_killed_by = list()
	var/respawn_timer_id
	var/round_end_time
	var/list/disabled_squads = list()
	var/list/clamped_jobs = list()

/datum/game_mode/extended/faction_clash/cm_vs_upp/pre_setup()
	. = ..()
	GLOB.round_should_check_for_win = FALSE
	restrict_uscm_squads()
	unlock_upp_job_slots()

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/restrict_uscm_squads()
	for(var/datum/squad/squad as anything in GLOB.RoleAuthority.squads)
		if(squad.faction != FACTION_MARINE || !squad.roundstart || squad.name == "Root")
			continue
		if(squad.name in CLASH_USCM_SQUADS)
			continue
		squad.roundstart = FALSE
		disabled_squads += squad
		log_debug("HVH: squad [squad.name] withheld from roundstart")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/unlock_upp_job_slots()
	for(var/title in UPP_JOB_LIST)
		var/datum/job/job = GLOB.RoleAuthority.roles_by_name[title]
		if(!job || job.total_positions == -1)
			continue
		clamped_jobs[job] = list(job.total_positions, job.spawn_positions)
		job.total_positions = -1
		job.spawn_positions = -1
		log_debug("HVH: [title] slots unlocked")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/restore_upp_job_slots()
	for(var/datum/job/job as anything in clamped_jobs)
		var/list/saved = clamped_jobs[job]
		job.total_positions = saved[1]
		job.spawn_positions = saved[2]
	clamped_jobs.Cut()

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/restore_uscm_squads()
	for(var/datum/squad/squad as anything in disabled_squads)
		squad.roundstart = TRUE
	disabled_squads.Cut()

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/start_round_timer()
	if(scoring_started)
		return
	scoring_started = TRUE
	round_end_time = world.time + round_time_limit
	addtimer(CALLBACK(src, PROC_REF(round_time_expired)), round_time_limit)
	addtimer(CALLBACK(src, PROC_REF(start_map_vote)), max(1, round_time_limit - CLASH_MAP_VOTE_LEAD))
	respawn_timer_id = addtimer(CALLBACK(src, PROC_REF(update_respawn_huds)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)
	start_clash_radar()
	log_debug("HVH: round timer armed for [round_time_limit / 600] minutes")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/count_side(faction)
	var/count = 0
	for(var/mob/living/carbon/human/player as anything in GLOB.alive_human_list)
		if(player.client && player.faction == faction)
			count++
	return count

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/can_join_side(rank)
	var/uscm = count_side(FACTION_MARINE)
	var/upp = count_side(FACTION_UPP)
	if(rank in UPP_JOB_LIST)
		return upp - uscm < CLASH_TEAM_GAP
	return uscm - upp < CLASH_TEAM_GAP

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/faction_color(faction)
	switch(faction)
		if(FACTION_MARINE)
			return "#5a8fe6"
		if(FACTION_UPP)
			return "#e61919"
	return "#cccccc"

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/get_score_entry(mob_name, faction, owner_ckey)
	var/list/entry = player_scores[mob_name]
	if(!entry)
		entry = list("kills" = 0, "deaths" = 0, "shots" = 0, "hits" = 0, "best_streak" = 0, "faction" = faction, "ckey" = owner_ckey)
		player_scores[mob_name] = entry
	if(owner_ckey && !entry["ckey"])
		entry["ckey"] = owner_ckey
	return entry

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/get_score_maptext()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/list/lines = list("<span class='maptext center' style='font-size: 10px'><span style='color: #5a8fe6'>USCM [uscm]</span> | <span style='color: #e61919'>[upp] UPP</span></span>")
	lines += "<span class='maptext center'><span style='color: #5a8fe6'>Players: [count_side(FACTION_MARINE)]</span> | <span style='color: #e61919'>Players: [count_side(FACTION_UPP)]</span></span>"
	var/clock = get_round_clock()
	if(clock)
		lines += ""
		lines += clock
	return lines.Join("<br>")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/get_round_clock()
	if(!round_end_time || round_finished)
		return null
	var/remaining = max(0, round_end_time - world.time)
	var/seconds = CEILING(remaining / 10, 1)
	var/minutes = floor(seconds / 60)
	seconds = seconds % 60
	return "<span class='maptext center'>[minutes]:[seconds < 10 ? "0[seconds]" : "[seconds]"] left</span>"

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/get_killfeed_line(list/entry)
	return "<span class='maptext' style='text-align: right'><span style='color: [entry["killer_color"]]'>[entry["killer"]]</span> killed <span style='color: [entry["victim_color"]]'>[entry["victim"]]</span>[entry["cause"] ? " ([entry["cause"]])" : ""]</span>"

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/render_killfeed_for(mob/player)
	var/list/lines = player.hud_used?.faction_killfeed
	if(!length(lines))
		return
	for(var/i = 1 to length(lines))
		var/atom/movable/screen/faction_killfeed/line = lines[i]
		var/entry_index = length(killfeed) - i + 1
		if(entry_index < 1)
			line.maptext = ""
			line.alpha = 255
			continue
		line.maptext = get_killfeed_line(killfeed[entry_index])
		line.alpha = 255

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/render_killfeed()
	for(var/mob/player as anything in GLOB.player_list)
		render_killfeed_for(player)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/fade_killfeed_line(index, duration)
	var/slot = length(killfeed) - index + 1
	if(slot < 1)
		return
	for(var/mob/player as anything in GLOB.player_list)
		var/list/lines = player.hud_used?.faction_killfeed
		if(slot > length(lines))
			continue
		var/atom/movable/screen/faction_killfeed/line = lines[slot]
		if(!line.maptext)
			continue
		animate(line, alpha = 0, time = duration)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/get_respawn_line(mob/player)
	if(player.stat != DEAD && !isobserver(player))
		return null
	if(!player.timeofdeath)
		return null
	var/remaining = player.timeofdeath + RESPAWN_COOLDOWN - world.time
	if(remaining <= 0)
		return "<span class='maptext center'>Respawn available</span>"
	var/seconds = CEILING(remaining / 10, 1)
	var/minutes = floor(seconds / 60)
	seconds = seconds % 60
	return "<span class='maptext center'>Respawn in [minutes]:[seconds < 10 ? "0[seconds]" : "[seconds]"]</span>"

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/compose_hud_maptext(mob/player, base)
	var/line = get_respawn_line(player)
	return line ? "[base]<br>[line]" : base

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/update_score_huds()
	var/base = get_score_maptext()
	for(var/mob/player as anything in GLOB.player_list)
		var/atom/movable/screen/faction_score/display = player.hud_used?.faction_score
		if(display)
			display.maptext = compose_hud_maptext(player, base)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/update_respawn_huds()
	if(round_finished)
		deltimer(respawn_timer_id)
		respawn_timer_id = null
		return
	var/base = get_score_maptext()
	for(var/mob/player as anything in GLOB.player_list)
		player.hud_used?.clash_respawn?.update(player)
		var/atom/movable/screen/faction_score/display = player.hud_used?.faction_score
		if(!display)
			continue
		var/text = compose_hud_maptext(player, base)
		if(display.maptext != text)
			display.maptext = text

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/score_kill(faction, mob_name, owner_ckey)
	if(faction)
		faction_kills[faction] = (faction_kills[faction] || 0) + 1
	if(mob_name)
		var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
		entry["kills"] += 1
	update_score_huds()
	log_debug("HVH: kill faction=[faction || "none"] killer=[mob_name || "none"]")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/score_death(faction, mob_name, cause, owner_ckey)
	if(faction)
		faction_deaths[faction] = (faction_deaths[faction] || 0) + 1
	if(mob_name)
		var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
		entry["deaths"] += 1
	if(cause)
		environment_kills[cause] = (environment_kills[cause] || 0) + 1
	log_debug("HVH: death faction=[faction || "none"] victim=[mob_name || "none"] cause=[cause || "none"]")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/score_shot(mob_name, faction, hit, amount = 1, owner_ckey)
	if(!mob_name)
		return
	var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
	if(hit)
		entry["hits"] += amount
	else
		entry["shots"] += amount

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/report_kill(mob/victim, mob/killer, cause)
	var/health_left = 0
	if(isliving(killer))
		var/mob/living/living_killer = killer
		health_left = max(0, round(living_killer.health / living_killer.maxHealth * 100))
	to_chat(victim, SPAN_WARNING("Killed by [killer.real_name][cause ? " ([cause])" : ""] at [get_dist(victim, killer)] tiles. They had [health_left]% health left."))
	to_chat(killer, SPAN_NOTICE("You killed [victim.real_name]."))

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/report_environment_death(mob/victim, cause)
	if(!cause)
		return
	to_chat(victim, SPAN_WARNING("Killed by [cause]."))

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/add_killfeed(killer, killer_faction, victim, victim_faction, cause)
	killfeed += list(list(
		"killer" = killer,
		"victim" = victim,
		"cause" = cause,
		"killer_color" = faction_color(killer_faction),
		"victim_color" = faction_color(victim_faction),
		"expiry" = world.time + KILLFEED_LIFETIME,
		"fading" = FALSE,
	))
	if(length(killfeed) > CLASH_KILLFEED_LINES)
		fade_killfeed_line(1, KILLFEED_PUSH_FADE)
		addtimer(CALLBACK(src, PROC_REF(drop_oldest_killfeed)), KILLFEED_PUSH_FADE)
	else
		render_killfeed()
	addtimer(CALLBACK(src, PROC_REF(prune_killfeed)), KILLFEED_LIFETIME + 1)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/drop_oldest_killfeed()
	if(length(killfeed) > CLASH_KILLFEED_LINES)
		killfeed.Cut(1, 2)
	render_killfeed()

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/prune_killfeed()
	var/faded = FALSE
	for(var/i = length(killfeed) to 1 step -1)
		var/list/entry = killfeed[i]
		if(entry["expiry"] > world.time || entry["fading"])
			continue
		entry["fading"] = TRUE
		fade_killfeed_line(i, KILLFEED_FADE)
		faded = TRUE
	if(faded)
		addtimer(CALLBACK(src, PROC_REF(drop_faded_killfeed)), KILLFEED_FADE)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/drop_faded_killfeed()
	for(var/i = length(killfeed) to 1 step -1)
		var/list/entry = killfeed[i]
		if(entry["fading"])
			killfeed.Cut(i, i + 1)
	render_killfeed()

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/announce_to_faction(faction, message)
	for(var/mob/player as anything in GLOB.player_list)
		if(player.faction == faction)
			to_chat(player, SPAN_BOLDNOTICE(message))

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/track_streak(killer, killer_faction, victim, victim_faction, killer_ckey)
	kill_streaks[victim] = 0
	if(!killer)
		return
	var/streak = (kill_streaks[killer] || 0) + 1
	kill_streaks[killer] = streak
	var/list/entry = get_score_entry(killer, killer_faction, killer_ckey)
	if(streak > entry["best_streak"])
		entry["best_streak"] = streak
	if(last_killed_by[killer] == victim)
		last_killed_by[killer] = null
		announce_to_faction(killer_faction, "[killer] got revenge on [victim].")
	last_killed_by[victim] = killer
	if(streak in GLOB.clash_streak_steps)
		announce_to_faction(killer_faction, "[killer] is on a [streak] kill streak.")
		announce_to_faction(victim_faction, "[killer] is on a [streak] kill streak. Put them down.")

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/round_time_expired()
	if(round_finished)
		return
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	if(uscm > upp)
		round_finished = MODE_INFESTATION_M_MAJOR
	else if(upp > uscm)
		round_finished = MODE_FACTION_CLASH_UPP_MAJOR
	else
		round_finished = MODE_FACTION_CLASH_DRAW
	log_debug("HVH: time limit reached, uscm=[uscm] upp=[upp] result=[round_finished]")
	roundend_ceasefire()


/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/start_map_vote()
	if(round_finished)
		return
	log_debug("HVH: map vote opening, [CLASH_MAP_VOTE_LEAD / 600] minutes left")
	SSvote.initiate_vote("groundmap", "SERVER", null, TRUE)

/datum/game_mode/extended/faction_clash/cm_vs_upp/get_roles_list()
	return GLOB.ROLES_CM_VS_UPP

/datum/game_mode/extended/faction_clash/cm_vs_upp/post_setup()
	. = ..()
	for(var/hivenumber in GLOB.hive_datum)
		var/datum/hive_status/hive = GLOB.hive_datum[hivenumber]
		hive.UnregisterSignal(SSdcs, COMSIG_GLOB_POST_SETUP)
	start_round_timer()
	SSweather.force_weather_holder(/datum/weather_ss_map_holder/faction_clash)
	for(var/area/area in GLOB.all_areas)
		if(is_mainship_level(area.z))
			continue
		area.base_lighting_alpha = 150
		area.update_base_lighting()

/datum/game_mode/extended/faction_clash/cm_vs_upp/process()
	if(--round_started > 0)
		return FALSE //Initial countdown, just to be safe, so that everyone has a chance to spawn before we check anything.
	. = ..()
	if(!round_finished)
		if(++round_checkwin >= 5) //Only check win conditions every 5 ticks.
			if(GLOB.round_should_check_for_win)
				check_win()
			round_checkwin = 0


/datum/game_mode/extended/faction_clash/cm_vs_upp/check_win()
	return

/datum/game_mode/extended/faction_clash/cm_vs_upp/check_finished()
	if(round_finished)
		return TRUE

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/roundend_ceasefire()
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("ALERT: USCM ground force overrun scenario in progress. Automated command directive issued, all USCM personnel are ordered to evacuate combat zone.\n\nOpposing Force have issued a ceasefire, risk of capture of USCM personnel by opposing force is high, avoid contact and evade capture.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy force are combat inoperative, enemy force are conducting an evacuation of the operations zone.\n\nA ceasefire is in effect. Union forces are directed to attempt to capture fleeing enemy force personnel.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_UPP_MINOR)
			marine_announcement("ALERT: USCM ground force overrun scenario in progress. Automated command directive issued, all USCM personnel are ordered to evacuate combat zone.\n\nOpposing Force have issued a ceasefire, risk of capture of USCM personnel by opposing force is high, avoid contact and evade capture.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy force are combat inoperative, enemy force are conducting an evacuation of the operations zone.\n\nA ceasefire is in effect. Union forces are directed to attempt to capture fleeing enemy force personnel.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("ALERT: Opposing force are conducting emergency evacuation of the operations zone. Confidence is high that opposing forces are retreating from the planet.\n\nCeasefire is in effect to minimise non-combatant casualties, ground forces are directed to intercept and detain retreating opposing forces\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Unsustainable combat losses noted. Automated strategic reposition order is now in effect. All Union combat personnel are to return to dropships and re-deploy to the SSV Rostock.\n\nEnemy force have instituted a ceasefire, exploit this to assist in evading capture.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_INFESTATION_M_MINOR)
			marine_announcement("ALERT: Opposing force are conducting emergency evacuation of the operations zone. Confidence is high that opposing forces are retreating from the planet.\n\nCeasefire is in effect to minimise non-combatant casualties, ground forces are directed to intercept and detain retreating opposing forces.\n\nFinal report being prepared in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Unsustainable combat losses noted. Automated strategic reposition order is now in effect. All Union combat personnel are to return to dropships and re-deploy to the SSV Rostock.\n\nEnemy force have instituted a ceasefire, exploit this to assist in evading capture.\n\nFinal report being prepared in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Further information pending in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: A ceasefire is now in effect. Further details pending. All combat operations are to cease. Additional facts pending in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)


/datum/game_mode/extended/faction_clash/cm_vs_upp/declare_completion()
	restore_uscm_squads()
	restore_upp_job_slots()
	announce_ending()
	var/musical_track
	var/end_icon = "draw"
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_major"
		if(MODE_FACTION_CLASH_UPP_MINOR)
			marine_announcement("ALERT: All ground forces killed in action or non-responsive. Landing zone overrun. Impossible to sustain combat operations.\n\nMission Abort Authorized! Commencing automatic vessel deorbit procedure from operations zone.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Enemy landing zone status. Under Union Military Control. Enemy ground forces. Deceased and/or in Union Military custody.\n\nMission Accomplished! Dispatching subspace signal to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_minor"
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/winning_triumph1.ogg','sound/theme/winning_triumph2.ogg','sound/theme/winning_triumph3.ogg')
			end_icon = "marine_major"
		if(MODE_INFESTATION_M_MINOR)
			marine_announcement("ALERT: Opposing Force landing zone under USCM force control. Orbital scans concludes all opposing force combat personnel are combat inoperative.\n\nMission Accomplished!\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Union landing zone compromised. Union ground forces are non-responsive. Further combat operations impossible.\n\nMission Abort Authorized\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			musical_track = pick('sound/theme/neutral_hopeful1.ogg','sound/theme/neutral_hopeful2.ogg')
			end_icon = "marine_minor"
		if(MODE_BATTLEFIELD_DRAW_STALEMATE)
			marine_announcement("ALERT: Inconclusive combat outcome. Unable to assess tactical or strategic situation.\n\nDispatching automated request to High Command for further directives.\n\nSaving operational report to archive, commencing final systems scan.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("ALERT: Battle situation has developed not necessarily to the Unions advantage\n\nDispatching request for new directives to Sector Command.\n\nConcluding operational report for dispatch, commencing final data entry and systems scan.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
			end_icon = "draw"
			musical_track = 'sound/theme/neutral_hopeful2.ogg'
		else
			end_icon = "draw"
			musical_track = 'sound/theme/neutral_hopeful2.ogg'
	var/sound/theme = sound(musical_track, channel = SOUND_CHANNEL_LOBBY)
	theme.status = SOUND_STREAM
	sound_to(world, theme)

	calculate_end_statistics()
	show_end_statistics(end_icon)

	declare_completion_announce_fallen_soldiers()
	declare_completion_announce_predators()
	declare_completion_announce_medal_awards()
	declare_fun_facts()
	announce_scoreboard()
	announce_personal_stats()
	export_round_stats()

	return TRUE

/datum/game_mode/extended/faction_clash/cm_vs_upp/ds_first_landed(obj/docking_port/stationary/marine_dropship)
	if(round_started > 0) //we enter here on shipspawn but do not want this
		return
	.=..()
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("First troops have landed on the colony! Five minute long ceasefire is in effect to allow evacuation of civilians.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	addtimer(CALLBACK(src,PROC_REF(ceasefire_warning)), 4 MINUTES)
	addtimer(CALLBACK(src,PROC_REF(ceasefire_end)), 5 MINUTES)
	addtimer(VARSET_CALLBACK(GLOB, round_should_check_for_win, TRUE), 15 MINUTES)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/ceasefire_warning()
	marine_announcement("Ceasefire ends in one minute.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire ends in one minute.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/ceasefire_end()
	marine_announcement("Ceasefire is over. Combat operations may commence.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Ceasefire is over. Combat operations may commence.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = FALSE)
	GLOB.round_should_check_for_win = TRUE



/datum/game_mode/extended/faction_clash/cm_vs_upp/announce()
	. = ..()
	addtimer(CALLBACK(src,PROC_REF(deleyed_announce)), 10 SECONDS)

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/deleyed_announce()
	marine_announcement("An automated distress call has been received from the local colony.\n\nAlert! Sensors have detected a Union of Progressive People's warship in orbit of colony. Enemy Vessel has refused automated hails and is entering lower-planetary orbit. High likelihood enemy vessel is preparing to deploy dropships to local colony. Authorization to interdict and repel hostile force from allied territory has been granted. Automated thawing of cryostasis marine reserves in progress.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Alert! Sensors have detected encroaching USCM vessel on an intercept course with local colony.\n\nIntelligence suggests this is the [MAIN_SHIP_NAME]. Confidence is high that USCM force is acting counter to Union interests in this area. Authorization to deploy ground forces to disrupt foreign power attempt to encroach on Union interests has been granted. Emergency awakening of cryostasis troop reserves in progress.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)


/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/announce_scoreboard()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/list/output = list("<br><h2>Final Score</h2>")
	output += "USCM [uscm] kills, [faction_deaths[FACTION_MARINE] || 0] losses<br>"
	output += "UPP [upp] kills, [faction_deaths[FACTION_UPP] || 0] losses<br>"

	var/list/ranked = list()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		if(entry["kills"] > 0 || entry["deaths"] > 0)
			ranked += list(list("name" = name, "kills" = entry["kills"], "deaths" = entry["deaths"], "faction" = entry["faction"]))
	for(var/i = 1 to length(ranked))
		for(var/j = i + 1 to length(ranked))
			var/list/x = ranked[i]
			var/list/y = ranked[j]
			if(y["kills"] > x["kills"])
				ranked[i] = y
				ranked[j] = x

	if(length(ranked))
		output += "<br><b>Top performers</b><br>"
		for(var/i = 1 to min(10, length(ranked)))
			var/list/entry = ranked[i]
			output += "[i]. [entry["name"]] ([entry["faction"]]) - [entry["kills"]] kills, [entry["deaths"]] deaths<br>"

	var/top_env
	var/top_env_count = 0
	for(var/cause in environment_kills)
		if(environment_kills[cause] > top_env_count)
			top_env_count = environment_kills[cause]
			top_env = cause
	if(top_env)
		output += "<br>Most common cause of death: [top_env] ([top_env_count])<br>"
	if(GLOB.round_statistics)
		output += "Total shots fired: [GLOB.round_statistics.total_projectiles_fired]<br>"
		output += "Total revives: [GLOB.round_statistics.total_revives]<br>"
		output += "Friendly fire incidents: [GLOB.round_statistics.total_friendly_fire_instances]<br>"
	to_world(output.Join())

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/announce_personal_stats()
	for(var/mob/player as anything in GLOB.player_list)
		var/owner_ckey = player.mind?.ckey || player.ckey
		if(!owner_ckey)
			continue
		var/kills = 0
		var/deaths = 0
		var/shots = 0
		var/hits = 0
		var/best_streak = 0
		var/found = FALSE
		for(var/name in player_scores)
			var/list/entry = player_scores[name]
			if(entry["ckey"] != owner_ckey)
				continue
			found = TRUE
			kills += entry["kills"]
			deaths += entry["deaths"]
			shots += entry["shots"]
			hits += entry["hits"]
			if(entry["best_streak"] > best_streak)
				best_streak = entry["best_streak"]
		if(!found)
			continue
		var/list/output = list("<br><b>Your round</b><br>")
		output += "[kills] kills, [deaths] deaths"
		if(deaths)
			output += ", [round(kills / deaths, 0.01)] K/D"
		output += "<br>"
		if(shots)
			output += "[hits] of [shots] shots on target ([round(hits / shots * 100, 0.1)]%)<br>"
		if(best_streak > 1)
			output += "Best streak: [best_streak]<br>"
		to_chat(player, output.Join())

/datum/game_mode/extended/faction_clash/cm_vs_upp/proc/export_round_stats()
	if(!GLOB.round_statistics)
		return
	var/list/weapons = list()
	for(var/key in GLOB.round_statistics.weapon_stats_list)
		var/datum/entity/weapon_stats/weapon = GLOB.round_statistics.weapon_stats_list[key]
		if(!weapon.total_shots && !weapon.total_kills && !weapon.total_damage)
			continue
		weapons[weapon.name] = list(
			"shots" = weapon.total_shots || 0,
			"hits" = weapon.total_shots_hit || 0,
			"kills" = weapon.total_kills || 0,
			"damage" = weapon.total_damage || 0,
			"friendly_fire" = weapon.total_friendly_fire || 0,
		)
	var/list/players = list()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		players[name] = list("kills" = entry["kills"], "deaths" = entry["deaths"], "shots" = entry["shots"], "hits" = entry["hits"], "best_streak" = entry["best_streak"], "faction" = entry["faction"])

	var/list/payload = list(
		"round_id" = GLOB.round_id,
		"map" = SSmapping.configs[GROUND_MAP]?.map_name,
		"result" = round_finished,
		"length_minutes" = round((world.time - SSticker.round_start_time) / 600, 0.1),
		"faction_kills" = faction_kills,
		"faction_deaths" = faction_deaths,
		"causes_of_death" = environment_kills,
		"weapons" = weapons,
		"players" = players,
	)
	var/path = "data/hvh_stats/round_[GLOB.round_id || world.time].json"
	WRITE_FILE(file(path), json_encode(payload))
	log_debug("HVH: stats exported to [path], [length(players)] players, [length(weapons)] weapons")

#undef KILLFEED_FADE
#undef KILLFEED_PUSH_FADE
#undef KILLFEED_LIFETIME
#undef CLASH_TEAM_GAP

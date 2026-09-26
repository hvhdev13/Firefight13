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
/// Kills remaining that trigger a kill limit callout
GLOBAL_LIST_INIT(clash_limit_callouts, list(10, 5, 1))

/// Shared engine for the human vs human modes: two teams, respawns, kill scoring. Never picked directly, the presets beside this file set the rules.
/datum/game_mode/extended/faction_clash/hvh
	name = "HvH"
	config_tag = null
	votable = FALSE
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
	/// How long the dead wait before they may respawn
	var/respawn_cooldown = RESPAWN_COOLDOWN
	/// Whether fresh spawns and bots start with a full stomach
	var/fed_spawns = FALSE
	/// Kills that end the match early, 0 leaves only the timer
	var/kill_limit = 0
	/// Faction to kill limit callouts already made, so each fires once
	var/list/limit_callouts_made = list()
	/// Pre-match hold with bases sealed and weapons down, 0 starts the match at once
	var/countdown_time = 0
	var/countdown_end_time
	/// Whether players are held inside their own base
	var/bases_sealed = FALSE
	/// Invulnerability window after a fresh spawn leaves their base, 0 disables it
	var/spawn_protection = 0
	var/map_vote_started = FALSE
	/// Why the match ended, shown in the ceasefire announcement
	var/finish_reason = "Time"
	map_vote_mode = GAMEMODE_FACTION_CLASH_UPP_CM

/// Respawn wait for the current round, the default outside a clash mode
/proc/clash_respawn_cooldown()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) ? clash_mode.respawn_cooldown : RESPAWN_COOLDOWN

/// Rule lines for the welcome page, in the order they are shown
/datum/game_mode/extended/faction_clash/hvh/proc/get_welcome_rules()
	. = list()
	if(kill_limit)
		. += "Rounds last [round_time_limit / 600] minutes. The first team to [kill_limit] kills wins, otherwise the most kills when time runs out. The map vote opens with [CLASH_MAP_VOTE_LEAD / 600] minutes left, or as soon as a team wins."
	else
		. += "Rounds last [round_time_limit / 600] minutes. The team with the most kills wins. The map vote opens with [CLASH_MAP_VOTE_LEAD / 600] minutes left."
	if(countdown_time)
		. += "The match starts [countdown_time / 10] seconds after the round begins. Until then you are held in your base."
	. += "You can respawn [respawn_cooldown / 10] seconds after dying, using the Respawn button in the centre of the screen."
	if(spawn_protection)
		. += "After spawning you cannot be hurt inside your base, and for [spawn_protection / 10] seconds after leaving it. Firing or using an item ends it early."

/datum/game_mode/extended/faction_clash/hvh/pre_setup()
	. = ..()
	GLOB.round_should_check_for_win = FALSE
	restrict_uscm_squads()
	unlock_upp_job_slots()

/datum/game_mode/extended/faction_clash/hvh/proc/restrict_uscm_squads()
	for(var/datum/squad/squad as anything in GLOB.RoleAuthority.squads)
		if(squad.faction != FACTION_MARINE || !squad.roundstart || squad.name == "Root")
			continue
		if(squad.name in CLASH_USCM_SQUADS)
			continue
		squad.roundstart = FALSE
		disabled_squads += squad
		log_debug("HVH: squad [squad.name] withheld from roundstart")

/datum/game_mode/extended/faction_clash/hvh/proc/unlock_upp_job_slots()
	for(var/title in UPP_JOB_LIST)
		var/datum/job/job = GLOB.RoleAuthority.roles_by_name[title]
		if(!job || job.total_positions == -1)
			continue
		clamped_jobs[job] = list(job.total_positions, job.spawn_positions)
		job.total_positions = -1
		job.spawn_positions = -1
		log_debug("HVH: [title] slots unlocked")

/datum/game_mode/extended/faction_clash/hvh/proc/restore_upp_job_slots()
	for(var/datum/job/job as anything in clamped_jobs)
		var/list/saved = clamped_jobs[job]
		job.total_positions = saved[1]
		job.spawn_positions = saved[2]
	clamped_jobs.Cut()

/datum/game_mode/extended/faction_clash/hvh/proc/restore_uscm_squads()
	for(var/datum/squad/squad as anything in disabled_squads)
		squad.roundstart = TRUE
	disabled_squads.Cut()

/datum/game_mode/extended/faction_clash/hvh/proc/start_round_timer()
	if(scoring_started)
		return
	scoring_started = TRUE
	round_end_time = world.time + round_time_limit
	addtimer(CALLBACK(src, PROC_REF(round_time_expired)), round_time_limit)
	addtimer(CALLBACK(src, PROC_REF(start_map_vote)), max(1, round_time_limit - CLASH_MAP_VOTE_LEAD))
	start_clash_radar()
	log_debug("HVH: round timer armed for [round_time_limit / 600] minutes")

/// Holds both teams in their bases with weapons down, then starts the match
/datum/game_mode/extended/faction_clash/hvh/proc/begin_countdown()
	if(!countdown_time)
		start_match()
		return
	countdown_end_time = world.time + countdown_time
	bases_sealed = TRUE
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		announce_to_faction(faction, "Match starts in [countdown_time / 10] seconds. Gear up, you are held in your base until then.")
	addtimer(CALLBACK(src, PROC_REF(start_match)), countdown_time)
	log_debug("HVH: countdown armed for [countdown_time / 10]s")

/datum/game_mode/extended/faction_clash/hvh/proc/start_match()
	if(scoring_started || round_finished)
		return
	if(bases_sealed)
		bases_sealed = FALSE
		set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = FALSE)
		for(var/faction in list(FACTION_MARINE, FACTION_UPP))
			announce_to_faction(faction, "Fight!")
	countdown_end_time = null
	start_round_timer()
	update_score_huds()

/datum/game_mode/extended/faction_clash/hvh/proc/count_side(faction)
	var/count = 0
	for(var/mob/living/carbon/human/player as anything in GLOB.alive_human_list)
		if(player.client && player.faction == faction)
			count++
	return count

/datum/game_mode/extended/faction_clash/hvh/proc/can_join_side(rank)
	var/uscm = count_side(FACTION_MARINE)
	var/upp = count_side(FACTION_UPP)
	if(rank in UPP_JOB_LIST)
		return upp - uscm < CLASH_TEAM_GAP
	return uscm - upp < CLASH_TEAM_GAP

/datum/game_mode/extended/faction_clash/hvh/proc/faction_color(faction)
	switch(faction)
		if(FACTION_MARINE)
			return "#5a8fe6"
		if(FACTION_UPP)
			return "#e61919"
	return "#cccccc"

/datum/game_mode/extended/faction_clash/hvh/proc/get_score_entry(mob_name, faction, owner_ckey)
	var/list/entry = player_scores[mob_name]
	if(!entry)
		entry = list("kills" = 0, "deaths" = 0, "shots" = 0, "hits" = 0, "best_streak" = 0, "faction" = faction, "ckey" = owner_ckey)
		player_scores[mob_name] = entry
	if(owner_ckey && !entry["ckey"])
		entry["ckey"] = owner_ckey
	return entry

/datum/game_mode/extended/faction_clash/hvh/proc/get_score_maptext()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/list/lines = list("<span class='maptext center' style='font-size: 10px'><span style='color: #5a8fe6'>USCM [uscm]</span> | <span style='color: #e61919'>[upp] UPP</span></span>")
	lines += "<span class='maptext center'><span style='color: #5a8fe6'>Players: [count_side(FACTION_MARINE)]</span> | <span style='color: #e61919'>Players: [count_side(FACTION_UPP)]</span></span>"
	if(kill_limit)
		lines += "<span class='maptext center'>First to [kill_limit]</span>"
	var/clock = get_round_clock()
	if(clock)
		lines += ""
		lines += clock
	return lines.Join("<br>")

/datum/game_mode/extended/faction_clash/hvh/proc/get_round_clock()
	if(round_finished)
		return null
	if(countdown_end_time)
		var/hold = CEILING(max(0, countdown_end_time - world.time) / 10, 1)
		return "<span class='maptext center'>Match starts in [hold]</span>"
	if(!round_end_time)
		return null
	var/remaining = max(0, round_end_time - world.time)
	var/seconds = CEILING(remaining / 10, 1)
	var/minutes = floor(seconds / 60)
	seconds = seconds % 60
	return "<span class='maptext center'>[minutes]:[seconds < 10 ? "0[seconds]" : "[seconds]"] left</span>"

/datum/game_mode/extended/faction_clash/hvh/proc/get_killfeed_line(list/entry)
	return "<span class='maptext' style='text-align: right; font-size: 6px'><span style='color: [entry["killer_color"]]'>[entry["killer"]]</span> killed <span style='color: [entry["victim_color"]]'>[entry["victim"]]</span>[entry["cause"] ? " ([entry["cause"]])" : ""]</span>"

/datum/game_mode/extended/faction_clash/hvh/proc/render_killfeed_for(mob/player)
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

/datum/game_mode/extended/faction_clash/hvh/proc/render_killfeed()
	for(var/mob/player as anything in GLOB.player_list)
		render_killfeed_for(player)

/datum/game_mode/extended/faction_clash/hvh/proc/fade_killfeed_line(index, duration)
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

/datum/game_mode/extended/faction_clash/hvh/proc/get_respawn_line(mob/player)
	if(player.stat != DEAD && !isobserver(player))
		return null
	if(!player.timeofdeath)
		return null
	var/remaining = player.timeofdeath + respawn_cooldown - world.time
	if(remaining <= 0)
		return "<span class='maptext center'>Respawn available</span>"
	var/seconds = CEILING(remaining / 10, 1)
	var/minutes = floor(seconds / 60)
	seconds = seconds % 60
	return "<span class='maptext center'>Respawn in [minutes]:[seconds < 10 ? "0[seconds]" : "[seconds]"]</span>"

/datum/game_mode/extended/faction_clash/hvh/proc/compose_hud_maptext(mob/player, base)
	var/line = get_respawn_line(player)
	return line ? "[base]<br>[line]" : base

/datum/game_mode/extended/faction_clash/hvh/proc/update_score_huds()
	var/base = get_score_maptext()
	for(var/mob/player as anything in GLOB.player_list)
		var/atom/movable/screen/faction_score/display = player.hud_used?.faction_score
		if(display)
			display.maptext = compose_hud_maptext(player, base)

/datum/game_mode/extended/faction_clash/hvh/proc/update_respawn_huds()
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

/datum/game_mode/extended/faction_clash/hvh/proc/score_kill(faction, mob_name, owner_ckey)
	if(faction)
		faction_kills[faction] = (faction_kills[faction] || 0) + 1
	if(mob_name)
		var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
		entry["kills"] += 1
	update_score_huds()
	log_debug("HVH: kill faction=[faction || "none"] killer=[mob_name || "none"]")
	if(faction)
		check_kill_limit(faction)

/datum/game_mode/extended/faction_clash/hvh/proc/check_kill_limit(faction)
	if(!kill_limit || !scoring_started || round_finished)
		return
	var/remaining = kill_limit - (faction_kills[faction] || 0)
	if(remaining <= 0)
		finish_match("Kill limit reached")
		return
	if(!(remaining in GLOB.clash_limit_callouts))
		return
	var/list/made = limit_callouts_made[faction]
	if(!made)
		made = list()
		limit_callouts_made[faction] = made
	if(remaining in made)
		return
	made += remaining
	var/enemy = faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
	if(remaining == 1)
		announce_to_faction(faction, "Next kill wins the match.")
		announce_to_faction(enemy, "The enemy is one kill from winning.")
	else
		announce_to_faction(faction, "[remaining] kills to win.")
		announce_to_faction(enemy, "The enemy is [remaining] kills from winning.")

/datum/game_mode/extended/faction_clash/hvh/proc/score_death(faction, mob_name, cause, owner_ckey)
	if(faction)
		faction_deaths[faction] = (faction_deaths[faction] || 0) + 1
	if(mob_name)
		var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
		entry["deaths"] += 1
		kill_streaks[mob_name] = 0
	if(cause)
		environment_kills[cause] = (environment_kills[cause] || 0) + 1
	log_debug("HVH: death faction=[faction || "none"] victim=[mob_name || "none"] cause=[cause || "none"]")

/datum/game_mode/extended/faction_clash/hvh/proc/score_shot(mob_name, faction, hit, amount = 1, owner_ckey)
	if(!mob_name)
		return
	var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
	if(hit)
		entry["hits"] += amount
	else
		entry["shots"] += amount

/datum/game_mode/extended/faction_clash/hvh/proc/report_kill(mob/victim, mob/killer, cause)
	var/health_left = 0
	if(isliving(killer))
		var/mob/living/living_killer = killer
		health_left = max(0, round(living_killer.health / living_killer.maxHealth * 100))
	to_chat(victim, SPAN_WARNING("Killed by [killer.real_name][cause ? " ([cause])" : ""] at [get_dist(victim, killer)] tiles. They had [health_left]% health left."))
	to_chat(killer, SPAN_NOTICE("You killed [victim.real_name]."))

/datum/game_mode/extended/faction_clash/hvh/proc/report_environment_death(mob/victim, cause)
	if(!cause)
		return
	to_chat(victim, SPAN_WARNING("Killed by [cause]."))

/datum/game_mode/extended/faction_clash/hvh/proc/add_killfeed(killer, killer_faction, victim, victim_faction, cause)
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

/datum/game_mode/extended/faction_clash/hvh/proc/drop_oldest_killfeed()
	if(length(killfeed) > CLASH_KILLFEED_LINES)
		killfeed.Cut(1, 2)
	render_killfeed()

/datum/game_mode/extended/faction_clash/hvh/proc/prune_killfeed()
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

/datum/game_mode/extended/faction_clash/hvh/proc/drop_faded_killfeed()
	for(var/i = length(killfeed) to 1 step -1)
		var/list/entry = killfeed[i]
		if(entry["fading"])
			killfeed.Cut(i, i + 1)
	render_killfeed()

/datum/game_mode/extended/faction_clash/hvh/proc/announce_to_faction(faction, message)
	for(var/mob/player as anything in GLOB.player_list)
		if(player.faction == faction)
			to_chat(player, SPAN_BOLDNOTICE(message))

/datum/game_mode/extended/faction_clash/hvh/proc/track_streak(killer, killer_faction, victim, victim_faction, killer_ckey)
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

/datum/game_mode/extended/faction_clash/hvh/proc/round_time_expired()
	finish_match("Time")

/// Scores the match on kills and ends it, whether time or the kill limit ran out
/datum/game_mode/extended/faction_clash/hvh/proc/finish_match(reason)
	if(round_finished)
		return
	// The round ends as soon as a result is set, so an early finish opens the vote here or never gets one
	if(!map_vote_started)
		start_map_vote()
	finish_reason = reason
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	if(uscm > upp)
		round_finished = MODE_INFESTATION_M_MAJOR
	else if(upp > uscm)
		round_finished = MODE_FACTION_CLASH_UPP_MAJOR
	else
		round_finished = MODE_FACTION_CLASH_DRAW
	log_debug("HVH: [reason], uscm=[uscm] upp=[upp] result=[round_finished]")
	roundend_ceasefire()


/datum/game_mode/extended/faction_clash/hvh/proc/start_map_vote()
	if(round_finished || map_vote_started)
		return
	map_vote_started = TRUE
	log_debug("HVH: map vote opening, [CLASH_MAP_VOTE_LEAD / 600] minutes left")
	SSvote.initiate_vote("groundmap", "SERVER", null, TRUE)

/datum/game_mode/extended/faction_clash/hvh/get_roles_list()
	return GLOB.ROLES_CM_VS_UPP

/datum/game_mode/extended/faction_clash/hvh/post_setup()
	. = ..()
	for(var/hivenumber in GLOB.hive_datum)
		var/datum/hive_status/hive = GLOB.hive_datum[hivenumber]
		hive.UnregisterSignal(SSdcs, COMSIG_GLOB_POST_SETUP)
	respawn_timer_id = addtimer(CALLBACK(src, PROC_REF(update_respawn_huds)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)
	begin_countdown()
	for(var/obj/structure/machinery/cm_vending/vendor in GLOB.machines)
		vendor.vend_delay = 0
	SSweather.force_weather_holder(/datum/weather_ss_map_holder/faction_clash)
	for(var/area/area in GLOB.all_areas)
		if(is_mainship_level(area.z))
			continue
		area.base_lighting_alpha = 150
		area.update_base_lighting()

/datum/game_mode/extended/faction_clash/hvh/process()
	if(--round_started > 0)
		return FALSE //Initial countdown, just to be safe, so that everyone has a chance to spawn before we check anything.
	. = ..()
	if(!round_finished)
		if(++round_checkwin >= 5) //Only check win conditions every 5 ticks.
			if(GLOB.round_should_check_for_win)
				check_win()
			round_checkwin = 0


/datum/game_mode/extended/faction_clash/hvh/check_win()
	return

/datum/game_mode/extended/faction_clash/hvh/check_finished()
	if(round_finished)
		return TRUE

/datum/game_mode/extended/faction_clash/hvh/proc/roundend_ceasefire()
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = TRUE)
	announce_ceasefire()

/datum/game_mode/extended/faction_clash/hvh/declare_completion()
	restore_uscm_squads()
	restore_upp_job_slots()
	announce_ending()
	announce_final_result()
	var/musical_track
	var/end_icon = "draw"
	switch(round_finished)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_major"
		if(MODE_FACTION_CLASH_UPP_MINOR)
			musical_track = pick('sound/theme/lastmanstanding_upp.ogg')
			end_icon = "upp_minor"
		if(MODE_INFESTATION_M_MAJOR)
			musical_track = pick('sound/theme/winning_triumph1.ogg','sound/theme/winning_triumph2.ogg','sound/theme/winning_triumph3.ogg')
			end_icon = "marine_major"
		if(MODE_INFESTATION_M_MINOR)
			musical_track = pick('sound/theme/neutral_hopeful1.ogg','sound/theme/neutral_hopeful2.ogg')
			end_icon = "marine_minor"
		if(MODE_BATTLEFIELD_DRAW_STALEMATE)
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

/datum/game_mode/extended/faction_clash/hvh/announce()
	. = ..()
	addtimer(CALLBACK(src,PROC_REF(deleyed_announce)), 10 SECONDS)

/// Start of round briefing
/datum/game_mode/extended/faction_clash/hvh/proc/deleyed_announce()
	var/minutes = round_time_limit / 600
	marine_announcement("[name] is live. Most kills after [minutes] minutes wins.\n\nRespawns are open. The enemy staging area is shielded, do not waste time on it.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("[name] is live. Most kills after [minutes] minutes wins.\n\nRespawns are open. The enemy staging area is shielded, do not waste time on it.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/// Faction announcements when the scoring stops and the ceasefire begins
/datum/game_mode/extended/faction_clash/hvh/proc/announce_ceasefire()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/result
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR)
			result = "USCM wins [uscm] to [upp]."
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			result = "UPP wins [upp] to [uscm]."
		else
			result = "Draw at [uscm] each."
	marine_announcement("[finish_reason]. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("[finish_reason]. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/// Faction announcements delivered with the final result
/datum/game_mode/extended/faction_clash/hvh/proc/announce_final_result()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR)
			marine_announcement("Match over. USCM victory, [uscm] to [upp].", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. USCM victory, [uscm] to [upp].", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			marine_announcement("Match over. UPP victory, [upp] to [uscm].", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. UPP victory, [upp] to [uscm].", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)
		else
			marine_announcement("Match over. Draw, [uscm] each.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
			marine_announcement("Match over. Draw, [uscm] each.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/hvh/proc/announce_scoreboard()
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

/datum/game_mode/extended/faction_clash/hvh/proc/announce_personal_stats()
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

/datum/game_mode/extended/faction_clash/hvh/proc/export_round_stats()
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

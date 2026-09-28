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
/// Break between matches, with the last match's scoreboard up
#define CLASH_INTERMISSION (30 SECONDS)
/// How recently someone must have hurt a victim to earn an assist on its death
#define CLASH_ASSIST_WINDOW (10 SECONDS)
/// Played to a killer when their kill lands
#define CLASH_KILL_SOUND 'sound/weapons/gun_xm88_directhit_high.ogg'
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
	/// Length of one match
	var/round_time_limit = 30 MINUTES
	/// Whether a match is in play, false in countdowns, intermissions and after the round
	var/match_live = FALSE
	/// Matches a round is played over, a team winning a majority ends the round early
	var/matches_per_round = 1
	var/match_number = 0
	/// One list per finished match: winner faction or null, kills per faction, reason, mvp
	var/list/match_results = list()
	var/list/match_wins = list()
	var/match_timer_id
	var/vote_timer_id
	var/countdown_timer_id
	var/intermission_timer_id
	var/intermission_end_time
	/// Whether weapons are held by a countdown or intermission ceasefire of ours
	var/holding_fire = FALSE
	/// Totals of finished matches, swapped in for the round end reports
	var/list/round_scores = list()
	var/list/round_faction_kills = list()
	var/list/round_faction_deaths = list()
	var/list/round_environment_kills = list()
	/// Idle time after which a living fighter is moved to observer to free their slot, 0 leaves it to the server AFK kick
	var/idle_limit = 0
	var/list/idle_warned = list()
	var/idle_timer_id
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
	/// Whether players build kits (see clash_kit) instead of saving vendor loadouts
	var/use_kits = FALSE
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
	/// What the match score counts, for the scoreboard
	var/score_label = "kills"
	/// Victim name to attacker name to list(time, faction, ckey), for assists
	var/list/recent_damage = list()
	/// Victim name to killer name to kills this match, for the death card
	var/list/rivalries = list()
	/// Name to kills in the life that just ended, for the death card
	var/list/life_kills = list()
	/// Whether an admin ended a match or set a score this round, which keeps it out of career stats
	var/admin_tampered = FALSE
	/// Whether the map is an arena with sealed bases and bots, for the rules shown to players
	var/arena_rules = FALSE
	// The arena map pool, Faction Clash keeps its own
	map_vote_mode = GAMEMODE_TDM

/// Respawn wait for the current round, the default outside a clash mode
/proc/clash_respawn_cooldown()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) ? clash_mode.respawn_cooldown : RESPAWN_COOLDOWN

/// Rule lines for the welcome page, in the order they are shown
/datum/game_mode/extended/faction_clash/hvh/proc/get_welcome_rules()
	. = list()
	var/unit = matches_per_round > 1 ? "Matches" : "Rounds"
	if(kill_limit)
		. += "[unit] last [round_time_limit / 600] minutes. The first team to [kill_limit] kills wins, otherwise the most kills when time runs out."
	else
		. += "[unit] last [round_time_limit / 600] minutes. The team with the most kills wins."
	if(matches_per_round > 1)
		. += "A round is the best of [matches_per_round] matches, with a [CLASH_INTERMISSION / 10] second break and a fresh start between them. The map vote opens during the deciding match."
	else
		. += "The map vote opens with [CLASH_MAP_VOTE_LEAD / 600] minutes left, or as soon as a team wins."
	if(countdown_time)
		. += "Each match starts after a [countdown_time / 10] second countdown. Until then you are held in your base."
	. += "You can respawn [respawn_cooldown / 10] seconds after dying, using the Respawn button in the centre of the screen."
	if(spawn_protection)
		. += "After spawning you cannot be hurt inside your base, and for [spawn_protection / 10] seconds after leaving it. Firing, melee attacks or using an item end it early."
	if(idle_limit)
		. += "Fighters idle for [idle_limit / 600] minutes are moved to observer so the slot frees up."
	if(arena_rules)
		. += "The enemy base is locked. Enemies cannot walk or throw grenades into it."
		. += "Players named \[BOT\] are bots. Kills on bots and by bots never count toward the score."

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
	round_end_time = world.time + round_time_limit
	var/match = match_number
	match_timer_id = addtimer(CALLBACK(src, PROC_REF(round_time_expired), match), round_time_limit, TIMER_STOPPABLE)
	if(could_be_final_match())
		vote_timer_id = addtimer(CALLBACK(src, PROC_REF(start_map_vote)), max(1, round_time_limit - CLASH_MAP_VOTE_LEAD), TIMER_STOPPABLE)
	if(!radar_timer_id)
		start_clash_radar()
	log_debug("HVH: match [match_number] timer armed for [round_time_limit / 600] minutes")

/// Match to show: the one being played or just finished, else the one coming up
/datum/game_mode/extended/faction_clash/hvh/proc/get_display_match()
	if(match_live || intermission_end_time || round_finished)
		return max(1, match_number)
	return min(match_number + 1, matches_per_round)

/// Matches a team must win to take the round
/datum/game_mode/extended/faction_clash/hvh/proc/wins_needed()
	return floor(matches_per_round / 2) + 1

/// Whether the match now starting can end the round, so the map vote belongs in it
/datum/game_mode/extended/faction_clash/hvh/proc/could_be_final_match()
	if(match_number >= matches_per_round)
		return TRUE
	for(var/faction in match_wins)
		if(match_wins[faction] + 1 >= wins_needed())
			return TRUE
	return FALSE

/// Holds everyone's weapons with the ceasefire, releasing only a hold this mode placed
/datum/game_mode/extended/faction_clash/hvh/proc/hold_fire(hold)
	if(holding_fire == hold)
		return
	holding_fire = hold
	set_gamemode_modifier(/datum/gamemode_modifier/ceasefire, enabled = hold)

/// Sets the first match going at round start, modes that deploy first can hold it back
/datum/game_mode/extended/faction_clash/hvh/proc/open_first_match()
	begin_countdown()

/// Holds both teams in their bases with weapons down, then starts the match
/datum/game_mode/extended/faction_clash/hvh/proc/begin_countdown()
	if(!countdown_time)
		start_match()
		return
	countdown_end_time = world.time + countdown_time
	bases_sealed = TRUE
	hold_fire(TRUE)
	var/label = matches_per_round > 1 ? "Match [match_number + 1] of [matches_per_round]" : "Match"
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		announce_to_faction(faction, "[label] starts in [countdown_time / 10] seconds. Gear up, you are held in your base until then.")
	countdown_timer_id = addtimer(CALLBACK(src, PROC_REF(start_match)), countdown_time, TIMER_STOPPABLE)
	log_debug("HVH: countdown armed for [countdown_time / 10]s")

/datum/game_mode/extended/faction_clash/hvh/proc/start_match()
	if(match_live || round_finished)
		return
	deltimer(countdown_timer_id)
	countdown_timer_id = null
	match_number++
	match_live = TRUE
	countdown_end_time = null
	intermission_end_time = null
	bases_sealed = FALSE
	if(holding_fire)
		hold_fire(FALSE)
		for(var/faction in list(FACTION_MARINE, FACTION_UPP))
			announce_to_faction(faction, "Fight!")
	start_round_timer()
	on_match_start()
	update_score_huds()

/// What a match is won on for faction, kills unless a mode scores something else
/datum/game_mode/extended/faction_clash/hvh/proc/get_match_score(faction)
	return faction_kills[faction] || 0

/// What decides a round tied on matches, read after the round totals are swapped in
/datum/game_mode/extended/faction_clash/hvh/proc/get_round_tiebreak(faction)
	return faction_kills[faction] || 0

/// Short line naming what ends a match early, or null
/datum/game_mode/extended/faction_clash/hvh/proc/get_limit_text()
	return kill_limit ? "First to [kill_limit]" : null

/// Extra HUD lines for modes with objectives
/datum/game_mode/extended/faction_clash/hvh/proc/get_objective_maptext()
	return list()

/// Objective states for the scoreboard, empty without objectives
/datum/game_mode/extended/faction_clash/hvh/proc/get_objective_data()
	return list()

/// Whether this mode has objectives an admin can move
/datum/game_mode/extended/faction_clash/hvh/proc/can_rebuild_objectives()
	return FALSE

/// Places the objectives again from scratch
/datum/game_mode/extended/faction_clash/hvh/proc/rebuild_objectives()
	return

/// Objective name to turf, for admin jumps
/datum/game_mode/extended/faction_clash/hvh/proc/get_objective_turfs()
	return list()

/// Sets a side's match score outright, for testing limits and series
/datum/game_mode/extended/faction_clash/hvh/proc/admin_set_score(faction, score)
	faction_kills[faction] = score
	update_score_huds()
	check_kill_limit(faction)

/// Called once a match is live
/datum/game_mode/extended/faction_clash/hvh/proc/on_match_start()
	return

/// Called as a match stops, before it is scored
/datum/game_mode/extended/faction_clash/hvh/proc/on_match_end()
	return

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
		entry = list("kills" = 0, "assists" = 0, "deaths" = 0, "shots" = 0, "hits" = 0, "best_streak" = 0, "faction" = faction, "ckey" = owner_ckey)
		player_scores[mob_name] = entry
	if(owner_ckey && !entry["ckey"])
		entry["ckey"] = owner_ckey
	return entry

/// The small lines under the score bar: the limit, the series and any objectives
/datum/game_mode/extended/faction_clash/hvh/proc/get_score_maptext()
	var/list/parts = list()
	var/limit_text = get_limit_text()
	if(limit_text)
		parts += limit_text
	if(matches_per_round > 1)
		parts += "Series <span style='color: [faction_color(FACTION_MARINE)]'>[match_wins[FACTION_MARINE] || 0]</span>-<span style='color: [faction_color(FACTION_UPP)]'>[match_wins[FACTION_UPP] || 0]</span> · best of [matches_per_round]"
	var/list/lines = list()
	if(length(parts))
		lines += "<span class='maptext center' style='color: #c3c9ce'>[parts.Join("  ·  ")]</span>"
	lines += get_objective_maptext()
	return lines.Join("<br>")

/// Everything the live scoreboard shows, from viewer's point of view
/datum/game_mode/extended/faction_clash/hvh/proc/get_scoreboard_data(mob/viewer)
	var/leader = match_live || intermission_end_time || round_finished ? pick_mvp(player_scores) : null
	var/list/teams = list()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/list/players = list()
		var/list/listed = list()
		var/alive = 0
		for(var/name in player_scores)
			var/list/entry = player_scores[name]
			if(entry["faction"] != faction || !entry["ckey"])
				continue
			var/client/player_client = GLOB.directory[entry["ckey"]]
			var/list/row = scoreboard_row(name, entry, viewer, player_client?.mob, leader)
			players += list(row)
			listed[name] = TRUE
			if(row["alive"])
				alive++
		// Everyone on the team shows up, scored or not
		for(var/mob/living/carbon/human/player as anything in GLOB.alive_human_list)
			if(!player.client || player.faction != faction || listed[player.real_name])
				continue
			players += list(scoreboard_row(player.real_name, null, viewer, player, leader))
			alive++
		teams += list(list(
			"id" = faction == FACTION_MARINE ? "uscm" : "upp",
			"name" = faction == FACTION_MARINE ? "USCM" : "UPP",
			"color" = faction_color(faction),
			"kills" = faction_kills[faction] || 0,
			"deaths" = faction_deaths[faction] || 0,
			"score" = get_match_score(faction),
			"wins" = match_wins[faction] || 0,
			"alive" = alive,
			"own" = viewer.faction == faction,
			"players" = players,
		))
	var/list/results = list()
	for(var/list/result as anything in match_results)
		results += list(list(
			"winner" = result["winner"] == FACTION_MARINE ? "uscm" : (result["winner"] == FACTION_UPP ? "upp" : null),
			"uscm" = result["uscm"],
			"upp" = result["upp"],
			"mvp" = result["mvp"],
		))
	var/remaining = match_live ? max(0, round_end_time - world.time) : 0
	return list(
		"match" = get_display_match(),
		"matches" = matches_per_round,
		"wins_needed" = wins_needed(),
		"series" = list(match_wins[FACTION_MARINE] || 0, match_wins[FACTION_UPP] || 0),
		"results" = results,
		"intermission" = intermission_end_time ? CEILING(max(0, intermission_end_time - world.time) / 10, 1) : 0,
		"active" = TRUE,
		"mode" = name,
		"teams" = teams,
		"kill_limit" = kill_limit,
		"score_limit" = get_score_limit(),
		"score_label" = score_label,
		"limit_text" = get_limit_text(),
		"objectives" = get_objective_data(),
		"seconds_left" = CEILING(remaining / 10, 1),
		"countdown" = countdown_end_time ? CEILING(max(0, countdown_end_time - world.time) / 10, 1) : 0,
		"finished" = !!round_finished,
		"awards" = intermission_end_time || round_finished ? get_awards() : list(),
		"kits" = clash_uses_kits(),
	)

/// Score that wins a match outright, 0 when only time ends it
/datum/game_mode/extended/faction_clash/hvh/proc/get_score_limit()
	return kill_limit

/datum/game_mode/extended/faction_clash/hvh/proc/scoreboard_row(name, list/entry, mob/viewer, mob/player, leader)
	var/mob/living/carbon/human/fighter = ishuman(player) && player.real_name == name ? player : null
	return list(
		"name" = name,
		"role" = fighter?.job,
		"alive" = fighter && fighter.stat != DEAD,
		"kills" = entry?["kills"] || 0,
		"assists" = entry?["assists"] || 0,
		"deaths" = entry?["deaths"] || 0,
		"captures" = entry?["captures"] || 0,
		"best_streak" = entry?["best_streak"] || 0,
		"streak" = kill_streaks[name] || 0,
		"is_viewer" = viewer.ckey && (entry ? entry["ckey"] == viewer.ckey : player?.ckey == viewer.ckey),
		"mvp" = !!leader && name == leader,
	)

/datum/game_mode/extended/faction_clash/hvh/proc/get_killfeed_line(list/entry, mob/viewer)
	// Lines you are in get a gold outline so your own kills and deaths stand out
	var/involved = viewer && (entry["killer"] == viewer.real_name || entry["victim"] == viewer.real_name)
	var/outline = involved ? "-dm-text-outline: 1px #7a5a00" : "-dm-text-outline: 1px black"
	var/weapon = entry["cause"] ? " <span style='color: #9aa3ab'>\[[html_encode(entry["cause"])]\]</span> " : " <span style='color: #9aa3ab'>&gt;</span> "
	return "<span class='maptext' style='text-align: right; font-size: 6px; [outline]'><span style='color: [entry["killer_color"]]'>[html_encode(entry["killer"])][entry["assists"] ? " <span style='color: #9aa3ab'>+[entry["assists"]]</span>" : ""]</span>[weapon]<span style='color: [entry["victim_color"]]'>[html_encode(entry["victim"])]</span></span>"

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
		line.maptext = get_killfeed_line(killfeed[entry_index], player)
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
	// The respawn button carries the countdown itself
	if(player.hud_used?.clash_respawn)
		return base
	var/line = get_respawn_line(player)
	return line ? "[base]<br>[line]" : base

/datum/game_mode/extended/faction_clash/hvh/proc/update_score_huds()
	var/base = get_score_maptext()
	var/list/panel = build_score_panel()
	for(var/mob/player as anything in GLOB.player_list)
		var/atom/movable/screen/faction_score/display = player.hud_used?.faction_score
		if(display)
			display.maptext = compose_hud_maptext(player, base)
			display.show_panel(panel, player)

/// Fills in a freshly made HUD's score bar
/datum/game_mode/extended/faction_clash/hvh/proc/init_score_hud(atom/movable/screen/faction_score/display, mob/viewer)
	display.maptext = compose_hud_maptext(viewer, get_score_maptext())
	display.show_panel(build_score_panel(), viewer)

/datum/game_mode/extended/faction_clash/hvh/proc/update_respawn_huds()
	if(round_finished)
		deltimer(respawn_timer_id)
		respawn_timer_id = null
		return
	var/base = get_score_maptext()
	var/list/panel = build_score_panel()
	for(var/mob/player as anything in GLOB.player_list)
		player.hud_used?.clash_respawn?.update(player)
		player.hud_used?.clash_death_card?.update(player)
		var/atom/movable/screen/faction_score/display = player.hud_used?.faction_score
		if(!display)
			continue
		display.show_panel(panel, player)
		var/text = compose_hud_maptext(player, base)
		if(display.maptext != text)
			display.maptext = text

/datum/game_mode/extended/faction_clash/hvh/proc/score_kill(faction, mob_name, owner_ckey)
	// Nothing scores between matches
	if(!match_live)
		return
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
	if(!kill_limit || !match_live || round_finished)
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
	if(!match_live)
		return
	if(faction)
		faction_deaths[faction] = (faction_deaths[faction] || 0) + 1
	if(mob_name)
		var/list/entry = get_score_entry(mob_name, faction, owner_ckey)
		entry["deaths"] += 1
		life_kills[mob_name] = kill_streaks[mob_name] || 0
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

/datum/game_mode/extended/faction_clash/hvh/proc/report_kill(mob/victim, mob/killer, cause, list/assisters)
	var/health_left = 0
	if(isliving(killer))
		var/mob/living/living_killer = killer
		health_left = max(0, round(living_killer.health / living_killer.maxHealth * 100))
	var/distance = get_dist(victim, killer)
	to_chat(victim, SPAN_WARNING("Killed by [killer.real_name][cause ? " ([cause])" : ""] at [distance] tiles. They had [health_left]% health left."))
	show_death_card(victim, killer, cause, distance, health_left, assisters)
	to_chat(killer, SPAN_NOTICE("You killed [victim.real_name]."))
	if(killer.client)
		playsound_client(killer.client, CLASH_KILL_SOUND, null, 50)

/// Notes that attacker hurt victim, for assists. Bots neither earn assists nor are scored as victims.
/datum/game_mode/extended/faction_clash/hvh/proc/record_damage(mob/living/victim, mob/attacker)
	if(!match_live || round_finished || victim.statistic_exempt || attacker.statistic_exempt || attacker.faction == victim.faction)
		return
	var/list/attackers = recent_damage[victim.real_name]
	if(!attackers)
		attackers = list()
		recent_damage[victim.real_name] = attackers
	attackers[attacker.real_name] = list("time" = world.time, "faction" = attacker.faction, "ckey" = attacker.mind?.ckey || attacker.ckey)

/// Credits an assist to everyone but the killer who recently hurt the victim, returns their names
/datum/game_mode/extended/faction_clash/hvh/proc/credit_assists(victim_name, killer_name)
	. = list()
	var/list/attackers = recent_damage[victim_name]
	recent_damage -= victim_name
	if(!match_live)
		return
	for(var/name in attackers)
		var/list/hit = attackers[name]
		if(name == killer_name || world.time - hit["time"] > CLASH_ASSIST_WINDOW)
			continue
		var/list/entry = get_score_entry(name, hit["faction"], hit["ckey"])
		entry["assists"] += 1
		. += name

/datum/game_mode/extended/faction_clash/hvh/proc/report_environment_death(mob/victim, cause)
	set_clash_death_card(victim, "ELIMINATED", null, "#8a939c", cause ? "Killed by [html_encode(cause)]" : "Cause unknown", null, null, null, get_life_line(victim))
	if(!cause)
		return
	to_chat(victim, SPAN_WARNING("Killed by [cause]."))

/// Builds the on-screen recap of who killed victim and how
/datum/game_mode/extended/faction_clash/hvh/proc/show_death_card(mob/victim, mob/killer, cause, distance, health_left, list/assisters)
	var/victim_name = victim.real_name
	var/killer_name = killer.real_name
	var/list/details = list()
	if(cause)
		details += html_encode(cause)
	details += "[distance] tile\s away"
	var/list/notes = list()
	if(victim.faction == killer.faction)
		notes += "<span style='color: #ff8a70'>Friendly fire.</span>"
	// What the killer has done this match
	var/list/killer_entry = player_scores[killer_name]
	var/streak = kill_streaks[killer_name]
	if(killer_entry)
		notes += "Their match: [killer_entry["kills"]] kills, [killer_entry["deaths"]] deaths[streak >= 2 ? ", [streak] streak" : ""]"
	if(match_live && victim.faction != killer.faction)
		var/list/by_killer = rivalries[victim_name]
		if(!by_killer)
			by_killer = list()
			rivalries[victim_name] = by_killer
		by_killer[killer_name] = (by_killer[killer_name] || 0) + 1
		var/times = by_killer[killer_name]
		if(times >= 2)
			notes += "<span style='color: #ff8a70'>NEMESIS</span>: they have killed you [times] times"
	if(length(assisters))
		notes += "Assisted by [html_encode(english_list(assisters))]"
	if(length(notes) > 3)
		notes.Cut(4)
	// The weapon only when it is still what they hold, a swapped hand would show the wrong one
	var/obj/item/weapon = killer.get_active_hand()
	if(!istype(weapon) || (cause && weapon.name != cause))
		weapon = null
	set_clash_death_card(victim, "KILLED BY", killer_name, faction_color(killer.faction), details.Join("  ·  "), notes, weapon, health_left, get_life_line(victim))

/// One line summing up the life that just ended, for the bottom of the death card
/datum/game_mode/extended/faction_clash/hvh/proc/get_life_line(mob/victim)
	var/list/parts = list()
	var/kills = life_kills[victim.real_name] || 0
	parts += "[kills] kill\s"
	var/alive = round(victim.life_time_total / 10)
	if(alive > 0)
		parts += "[floor(alive / 60)]:[alive % 60 < 10 ? "0" : ""][alive % 60] alive"
	var/list/entry = player_scores[victim.real_name]
	if(entry)
		parts += "match [entry["kills"]]/[entry["deaths"]] K/D"
	return "YOUR LIFE  ·  [parts.Join("  ·  ")]"

/datum/game_mode/extended/faction_clash/hvh/proc/add_killfeed(killer, killer_faction, victim, victim_faction, cause, assists = 0)
	killfeed += list(list(
		"killer" = killer,
		"assists" = assists,
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
	if(!killer || !match_live)
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

/datum/game_mode/extended/faction_clash/hvh/proc/round_time_expired(match)
	if(match == match_number)
		finish_match("Time")

/// Scores the match on kills and ends it, whether time or the kill limit ran out. Ends the round too once the series is decided.
/datum/game_mode/extended/faction_clash/hvh/proc/finish_match(reason)
	if(round_finished || !match_live)
		return
	match_live = FALSE
	deltimer(match_timer_id)
	deltimer(vote_timer_id)
	match_timer_id = null
	vote_timer_id = null
	finish_reason = reason
	on_match_end()
	var/uscm = get_match_score(FACTION_MARINE)
	var/upp = get_match_score(FACTION_UPP)
	var/winner = uscm > upp ? FACTION_MARINE : (upp > uscm ? FACTION_UPP : null)
	if(winner)
		match_wins[winner] = (match_wins[winner] || 0) + 1
	var/mvp = pick_mvp(player_scores)
	match_results += list(list("winner" = winner, "uscm" = uscm, "upp" = upp, "reason" = reason, "mvp" = mvp))
	log_debug("HVH: match [match_number] ended, [reason], uscm=[uscm] upp=[upp] winner=[winner || "draw"]")
	if(match_number < matches_per_round && (match_wins[FACTION_MARINE] || 0) < wins_needed() && (match_wins[FACTION_UPP] || 0) < wins_needed())
		begin_intermission()
		return
	// The round ends as soon as a result is set, so an early finish opens the vote here or never gets one
	if(!map_vote_started)
		start_map_vote()
	archive_match()
	// The round end reports read the live tallies, so they get the whole round's
	player_scores = round_scores
	faction_kills = round_faction_kills
	faction_deaths = round_faction_deaths
	environment_kills = round_environment_kills
	round_finished = get_round_result()
	record_career()
	update_score_huds()
	log_debug("HVH: round result [round_finished]")
	roundend_ceasefire()

/// Writes the round into everyone's career stats, run once the round totals are swapped in
/datum/game_mode/extended/faction_clash/hvh/proc/record_career()
	if(admin_tampered)
		log_game("Clash career: round not recorded, an admin ended a match or set a score")
		message_admins("HvH: this round was not saved to career stats because an admin ended a match or set a score.")
		return
	var/winner
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR, MODE_INFESTATION_M_MINOR)
			winner = FACTION_MARINE
		if(MODE_FACTION_CLASH_UPP_MAJOR, MODE_FACTION_CLASH_UPP_MINOR)
			winner = FACTION_UPP
	var/list/mvps = list()
	for(var/list/result as anything in match_results)
		if(result["mvp"])
			mvps += result["mvp"]
	GLOB.clash_career.record_round(player_scores, winner, mvps, name)

/datum/game_mode/extended/faction_clash/hvh/proc/get_round_result()
	var/uscm = matches_per_round > 1 ? (match_wins[FACTION_MARINE] || 0) : 0
	var/upp = matches_per_round > 1 ? (match_wins[FACTION_UPP] || 0) : 0
	if(uscm == upp)
		uscm = get_round_tiebreak(FACTION_MARINE)
		upp = get_round_tiebreak(FACTION_UPP)
	if(uscm > upp)
		return MODE_INFESTATION_M_MAJOR
	if(upp > uscm)
		return MODE_FACTION_CLASH_UPP_MAJOR
	return MODE_FACTION_CLASH_DRAW

/// Highest scorer in a score table: kills, half an assist, three per flag capture, then fewest deaths
/datum/game_mode/extended/faction_clash/hvh/proc/pick_mvp(list/scores)
	var/best
	var/list/best_entry
	for(var/name in scores)
		var/list/entry = scores[name]
		if(!entry["ckey"] || (!entry["kills"] && !entry["assists"] && !entry["captures"]))
			continue
		if(best_entry)
			var/score = entry["kills"] + entry["assists"] * 0.5 + (entry["captures"] || 0) * 3
			var/best_score = best_entry["kills"] + best_entry["assists"] * 0.5 + (best_entry["captures"] || 0) * 3
			if(score < best_score || (score == best_score && entry["deaths"] >= best_entry["deaths"]))
				continue
		best = name
		best_entry = entry
	return best

/// Folds the finished match into the round totals and clears it for the next one
/datum/game_mode/extended/faction_clash/hvh/proc/archive_match()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		var/list/total = round_scores[name]
		if(!total)
			round_scores[name] = entry.Copy()
			continue
		for(var/stat in list("kills", "assists", "deaths", "shots", "hits", "captures"))
			total[stat] = (total[stat] || 0) + (entry[stat] || 0)
		total["best_streak"] = max(total["best_streak"], entry["best_streak"])
		if(!total["ckey"])
			total["ckey"] = entry["ckey"]
	for(var/faction in faction_kills)
		round_faction_kills[faction] = (round_faction_kills[faction] || 0) + faction_kills[faction]
	for(var/faction in faction_deaths)
		round_faction_deaths[faction] = (round_faction_deaths[faction] || 0) + faction_deaths[faction]
	for(var/cause in environment_kills)
		round_environment_kills[cause] = (round_environment_kills[cause] || 0) + environment_kills[cause]
	player_scores = list()
	faction_kills = list()
	faction_deaths = list()
	environment_kills = list()
	kill_streaks = list()
	last_killed_by = list()
	recent_damage = list()
	rivalries = list()
	life_kills = list()
	limit_callouts_made = list()

/// Break between matches: weapons down, last match's scoreboard up, then a fresh start
/datum/game_mode/extended/faction_clash/hvh/proc/begin_intermission()
	hold_fire(TRUE)
	intermission_end_time = world.time + CLASH_INTERMISSION
	var/list/result = match_results[length(match_results)]
	var/line = get_match_result_line(result)
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		announce_to_faction(faction, "[result["reason"]]. [line][result["mvp"] ? " MVP: [result["mvp"]]." : ""] Next match in [CLASH_INTERMISSION / 10] seconds.")
	for(var/mob/player as anything in GLOB.player_list)
		GLOB.clash_scoreboard.tgui_interact(player)
	update_score_huds()
	intermission_timer_id = addtimer(CALLBACK(src, PROC_REF(end_intermission)), CLASH_INTERMISSION, TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/proc/end_intermission()
	if(round_finished || !intermission_end_time)
		return
	deltimer(intermission_timer_id)
	intermission_timer_id = null
	intermission_end_time = null
	archive_match()
	reset_arena()
	killfeed.Cut()
	render_killfeed()
	begin_countdown()

/// Fresh start between matches: survivors healed and sent home, corpses cleared, the dead free to respawn, bots back at their posts
/datum/game_mode/extended/faction_clash/hvh/proc/reset_arena()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.human_mob_list.Copy())
		if(QDELETED(fighter) || !is_ground_level(fighter.z) || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)))
			continue
		if(fighter.stat == DEAD)
			// Nobody gets to be revived into the next match, so free anyone still in their body and clear it
			if(fighter.client)
				fighter.ghostize(FALSE)
			qdel(fighter)
			continue
		if(fighter.statistic_exempt || !fighter.mind)
			continue
		fighter.stop_pulling()
		fighter.buckled?.unbuckle()
		fighter.rejuvenate()
		var/turf/home = get_clash_home_turf(fighter)
		if(home)
			fighter.forceMove(home)
		if(length(fighter.clash_spawn_points))
			fighter.vendor_points = fighter.clash_spawn_points[1]
			fighter.vendor_snowflake_points = fighter.clash_spawn_points[2]
		if(spawn_protection)
			fighter.AddComponent(/datum/component/clash_spawn_guard, spawn_protection)
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots.Copy())
		// Fill bots whose seat a player has since taken sit the next match out
		if(bot.post?.team_fill && !bot.post.active)
			bot.retire()
		else
			bot.return_to_post()
	for(var/mob/player as anything in GLOB.player_list)
		if((isobserver(player) || player.stat == DEAD) && player.timeofdeath)
			player.timeofdeath = min(player.timeofdeath, world.time - respawn_cooldown)
	log_debug("HVH: arena reset for match [match_number + 1]")

/// Moves fighters idle past the limit to observer, so they stop holding a team slot and skewing balance and bot fill
/datum/game_mode/extended/faction_clash/hvh/proc/check_idle()
	if(round_finished)
		deltimer(idle_timer_id)
		idle_timer_id = null
		return
	if(!match_live)
		return
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list.Copy())
		var/client/player = fighter.client
		if(!player || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)) || CLIENT_IS_AFK_SAFE(player))
			continue
		if(player.inactivity >= idle_limit)
			idle_warned -= player.ckey
			log_access("HVH idle: [key_name(fighter)] moved to observer after [round(player.inactivity / 600, 0.1)] minutes idle")
			to_chat(fighter, SPAN_WARNING("You were idle for [idle_limit / 600] minutes and have been moved to observer. Respawn when you are back."))
			fighter.ghostize(FALSE)
			qdel(fighter)
		else if(player.inactivity >= idle_limit - 1 MINUTES)
			if(!(player.ckey in idle_warned))
				idle_warned += player.ckey
				to_chat(fighter, SPAN_WARNING("You have been idle a while. In about a minute you will be moved to observer to free your slot."))
		else
			idle_warned -= player.ckey

/// Result sentence for one finished match, the latest unless a number is given
/datum/game_mode/extended/faction_clash/hvh/proc/get_match_result_line(list/result, number)
	if(isnull(number))
		number = length(match_results)
	var/uscm = result["uscm"]
	var/upp = result["upp"]
	switch(result["winner"])
		if(FACTION_MARINE)
			return "USCM takes match [number], [uscm] to [upp]."
		if(FACTION_UPP)
			return "UPP takes match [number], [upp] to [uscm]."
	return "Match [number] drawn at [uscm] each."

/// Result sentence for the round, by series when there is one, else by kills
/datum/game_mode/extended/faction_clash/hvh/proc/get_round_result_line()
	var/uscm = get_round_tiebreak(FACTION_MARINE)
	var/upp = get_round_tiebreak(FACTION_UPP)
	if(matches_per_round > 1)
		var/uscm_wins = match_wins[FACTION_MARINE] || 0
		var/upp_wins = match_wins[FACTION_UPP] || 0
		switch(round_finished)
			if(MODE_INFESTATION_M_MAJOR)
				return "USCM wins the series [uscm_wins] to [upp_wins]."
			if(MODE_FACTION_CLASH_UPP_MAJOR)
				return "UPP wins the series [upp_wins] to [uscm_wins]."
		return "Series drawn, [uscm_wins] to [upp_wins]."
	switch(round_finished)
		if(MODE_INFESTATION_M_MAJOR)
			return "USCM wins [uscm] to [upp]."
		if(MODE_FACTION_CLASH_UPP_MAJOR)
			return "UPP wins [upp] to [uscm]."
	return "Draw at [uscm] each."

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
	if(idle_limit)
		idle_timer_id = addtimer(CALLBACK(src, PROC_REF(check_idle)), 30 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)
	open_first_match()
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
	var/briefing = "[name] is live. [get_win_condition()]\n\nRespawns are open. The enemy staging area is shielded, do not waste time on it."
	marine_announcement(briefing, "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement(briefing, "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/// One sentence on how a match is won, for the opening briefing
/datum/game_mode/extended/faction_clash/hvh/proc/get_win_condition()
	var/unit = matches_per_round > 1 ? "Each match" : "The round"
	var/limit = kill_limit ? "First to [kill_limit] kills, or the" : "The"
	return "[unit] lasts [round_time_limit / 600] minutes. [limit] most kills when time runs out wins."

/// Faction announcements when the scoring stops and the ceasefire begins
/datum/game_mode/extended/faction_clash/hvh/proc/announce_ceasefire()
	var/result = get_round_result_line()
	marine_announcement("[finish_reason]. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("[finish_reason]. [result]\n\nCeasefire is in effect. Final scores in two minutes.", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/// Faction announcements delivered with the final result
/datum/game_mode/extended/faction_clash/hvh/proc/announce_final_result()
	var/result = get_round_result_line()
	marine_announcement("Round over. [result]", "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement("Round over. [result]", "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/hvh/proc/announce_scoreboard()
	var/uscm = faction_kills[FACTION_MARINE] || 0
	var/upp = faction_kills[FACTION_UPP] || 0
	var/list/output = list("<br><h2>Final Score</h2>")
	output += "USCM [uscm] kills, [faction_deaths[FACTION_MARINE] || 0] losses<br>"
	output += "UPP [upp] kills, [faction_deaths[FACTION_UPP] || 0] losses<br>"
	if(matches_per_round > 1)
		output += "<br><b>Matches</b><br>"
		for(var/i in 1 to length(match_results))
			var/list/result = match_results[i]
			output += "[i]. [get_match_result_line(result, i)] ([result["reason"]])[result["mvp"] ? " MVP [result["mvp"]]" : ""]<br>"

	var/mvp = pick_mvp(player_scores)
	if(mvp)
		var/list/mvp_entry = player_scores[mvp]
		output += "<br><b>MVP: [mvp]</b> ([mvp_entry["faction"]]) - [mvp_entry["kills"]] kills, [mvp_entry["assists"]] assists, [mvp_entry["deaths"]] deaths<br>"
	var/list/awards = get_awards()
	if(length(awards))
		output += "<br><b>Awards</b><br>"
		for(var/award in awards)
			output += "[award]<br>"

	var/list/ranked = list()
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		if(entry["kills"] > 0 || entry["deaths"] > 0)
			ranked += list(list("name" = name, "kills" = entry["kills"], "assists" = entry["assists"], "deaths" = entry["deaths"], "faction" = entry["faction"]))
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
			output += "[i]. [entry["name"]] ([entry["faction"]]) - [entry["kills"]] kills, [entry["assists"]] assists, [entry["deaths"]] deaths<br>"

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

/// Round awards as display lines, each for the best player at one thing, with a floor so small samples do not win
/datum/game_mode/extended/faction_clash/hvh/proc/get_awards()
	. = list()
	var/best_kd_name
	var/best_kd = 0
	var/best_streak_name
	var/best_streak = 1
	var/best_accuracy_name
	var/best_accuracy = 0
	var/best_assists_name
	var/best_assists = 0
	var/best_captures_name
	var/best_captures = 0
	for(var/name in player_scores)
		var/list/entry = player_scores[name]
		if(!entry["ckey"])
			continue
		if(entry["kills"] >= 5)
			var/kd = entry["kills"] / max(1, entry["deaths"])
			if(kd > best_kd)
				best_kd = kd
				best_kd_name = name
		if(entry["best_streak"] > best_streak)
			best_streak = entry["best_streak"]
			best_streak_name = name
		if(entry["shots"] >= 30)
			var/accuracy = entry["hits"] / entry["shots"]
			if(accuracy > best_accuracy)
				best_accuracy = accuracy
				best_accuracy_name = name
		if(entry["assists"] > best_assists)
			best_assists = entry["assists"]
			best_assists_name = name
		if((entry["captures"] || 0) > best_captures)
			best_captures = entry["captures"]
			best_captures_name = name
	if(best_kd_name)
		. += "Deadliest: [best_kd_name], [round(best_kd, 0.01)] K/D"
	if(best_streak_name)
		. += "Unstoppable: [best_streak_name], [best_streak] kill streak"
	if(best_accuracy_name)
		. += "Sharpshooter: [best_accuracy_name], [round(best_accuracy * 100, 0.1)]% of shots on target"
	if(best_assists_name)
		. += "Team player: [best_assists_name], [best_assists] assists"
	if(best_captures_name)
		. += "Flag runner: [best_captures_name], [best_captures] captures"

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
	payload["matches"] = match_results
	var/path = "data/hvh_stats/round_[GLOB.round_id || world.time].json"
	WRITE_FILE(file(path), json_encode(payload))
	log_debug("HVH: stats exported to [path], [length(players)] players, [length(weapons)] weapons")

#undef KILLFEED_FADE
#undef KILLFEED_PUSH_FADE
#undef KILLFEED_LIFETIME
#undef CLASH_TEAM_GAP

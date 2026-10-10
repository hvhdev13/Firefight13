#define CLASH_ELIM_DISCONNECT_GRACE (30 SECONDS)
#define CLASH_ELIM_ACTIVE_WINDOW (2 MINUTES)
#define CLASH_ELIM_HUNT_AFTER (90 SECONDS)
#define CLASH_ELIM_HUNT_LEFT 3
#define CLASH_ELIM_FIRST_COUNTDOWN (30 SECONDS)
#define CLASH_ELIM_LOBBY_SECONDS 60
#define CLASH_ELIM_HOPELESS_TOXIN 60
#define CLASH_ELIM_CRIT_LIMIT (15 SECONDS)
#define CLASH_ELIM_COUNTDOWN_BEEPS 10

GLOBAL_LIST_EMPTY(clash_ready_sides)

/datum/controller/subsystem/ticker/Initialize(timeofday)
	. = ..()
	if(GLOB.master_mode == GAMEMODE_ELIMINATION)
		var/datum/config_entry/number/lobby = config.entries_by_type[/datum/config_entry/number/lobby_countdown]
		lobby.config_entry_value = CLASH_ELIM_LOBBY_SECONDS

/proc/clash_lobby_ready_sides()
	return SSticker.current_state <= GAME_STATE_PREGAME && GLOB.master_mode == GAMEMODE_ELIMINATION

/proc/clash_lobby_ready_side(mob/new_player/player)
	if(!player.ready || !clash_lobby_ready_sides())
		return null
	return GLOB.clash_ready_sides[player.ckey] == FACTION_UPP ? "upp" : "uscm"

/proc/clash_ready_side(mob/new_player/player, faction)
	if(!clash_lobby_ready_sides() || !player.ckey)
		return
	if(player.ready && GLOB.clash_ready_sides[player.ckey] == faction)
		player.ready = FALSE
		GLOB.readied_players--
		return
	if(!player.ready)
		player.ready = TRUE
		GLOB.readied_players++
	GLOB.clash_ready_sides[player.ckey] = faction

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination
	name = GAMEMODE_ELIMINATION
	config_tag = GAMEMODE_ELIMINATION
	round_time_limit = 3 MINUTES
	matches_per_round = 7
	kill_limit = 0
	countdown_time = 15 SECONDS
	respawn_cooldown = 0
	intermission_time = 10 SECONDS
	kill_xp_multiplier = 2.5
	team_gap = 1
	var/team_size = 10
	match_win_xp_multiplier = 0.5
	score_label = "standing"
	idle_limit = 90 SECONDS
	idle_warning = 30 SECONDS
	idle_check_time = 10 SECONDS
	var/list/standing = list()
	var/list/fielded = list()
	var/list/last_callouts = list()
	var/elimination_timer_id
	var/list/disconnected = list()
	var/list/last_side = list()
	var/list/join_queue = list()
	var/waiting_for_players = FALSE
	var/list/crit_since = list()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/pre_setup()
	. = ..()
	round_time_limit = initial(round_time_limit)
	matches_per_round = initial(matches_per_round)
	respawn_cooldown = initial(respawn_cooldown)
	countdown_time = initial(countdown_time)
	for(var/mob/new_player/player as anything in GLOB.new_player_list)
		if(player.ready && player.client)
			player.ready = FALSE
			GLOB.readied_players--
			join_queue[player.ckey] = GLOB.clash_ready_sides[player.ckey]
	log_debug("Elimination: best of [matches_per_round], [round_time_limit / 600] minute matches, [countdown_time / 10]s countdown, [intermission_time / 10]s between matches")

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/post_setup()
	. = ..()
	apply_team_size()
	elimination_timer_id = addtimer(CALLBACK(src, PROC_REF(tick_elimination)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/apply_team_size()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		GLOB.clash_bot_fill_targets[faction] = team_size
		GLOB.clash_bot_caps[faction] = max(GLOB.clash_bot_caps[faction], team_size)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/can_join_side(rank, mob/joiner)
	if(count_for_balance(clash_kit_faction_for_job(rank), joiner) >= team_size)
		return FALSE
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_admin_objective_actions()
	return list("Set team size")

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/do_admin_objective_action(choice, mob/user)
	if(choice != "Set team size")
		return null
	var/size = tgui_input_number(user, "Players a side, bots fill up to it. Now: [team_size].", "Team size", team_size, 20, 1)
	if(!size)
		return null
	team_size = round(size)
	apply_team_size()
	return "Set the Elimination team size to [team_size] a side"

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_welcome_rules()
	return list(
		"[matches_per_round] matches per round, first to [wins_needed()] match wins takes the round.",
		"Wipe out the enemy team to win.",
		"Riflemen only.",
		"If time runs out, team with more fighters alive wins.",
		"Base shields disabled when the match starts.",
		"Kills and assists give [kill_xp_multiplier]x XP.",
		"Bots fill lowpop and have a grey \[BOT\] tag and a chevron marker. Kills on bots give 25% of regular XP.",
	)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_roles_list()
	return list(JOB_SQUAD_MARINE, JOB_UPP)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_welcome_tagline()
	return "One life. No respawns. Make it count."

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_win_condition()
	return "Each match lasts [round_time_limit / 600] minutes. Wipe out the enemy team to win the match. If time runs out, the team with more fighters standing wins."

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/deleyed_announce()
	var/briefing = "[name] is live. [get_win_condition()]\n\nNo respawns during a match. Base shields drop when the match starts."
	marine_announcement(briefing, "ARES 3.2", 'sound/AI/commandreport.ogg', FACTION_MARINE)
	marine_announcement(briefing, "1VAN/3", 'sound/AI/commandreport.ogg', FACTION_UPP)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/bases_open()
	return match_live

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/counts_for_bot_fill(client/player)
	return !isobserver(player.mob) || recently_active(player)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/count_for_balance(faction, mob/joiner)
	. = count_side(faction)
	for(var/mob/dead/observer/ghost as anything in GLOB.observer_list)
		var/client/player = ghost.client
		if(player && ghost != joiner && last_side[player.ckey] == faction && recently_active(player) && clash_can_redeploy(ghost))
			.++

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/recently_active(client/player)
	return player.inactivity < max(CLASH_ELIM_ACTIVE_WINDOW, world.time - (round_end_time - round_time_limit))

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/plan_bots(datum/clash_bot_director/director)
	if(match_live && (world.time >= round_end_time - round_time_limit + CLASH_ELIM_HUNT_AFTER || (standing[director.enemy_faction()] || 0) <= CLASH_ELIM_HUNT_LEFT))
		director.plan_hunt()
		return
	director.plan_skirmish()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/begin_countdown()
	countdown_time = match_number ? initial(countdown_time) : CLASH_ELIM_FIRST_COUNTDOWN
	. = ..()
	for(var/seconds_left in 1 to CLASH_ELIM_COUNTDOWN_BEEPS)
		addtimer(CALLBACK(src, PROC_REF(countdown_beep), match_number, seconds_left), countdown_time - seconds_left SECONDS)
	deploy_returning()
	refresh_kit_screens()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/countdown_beep(match, seconds)
	if(match != match_number || match_live || !countdown_end_time || round_finished)
		return
	show_count(seconds)
	if(seconds == 1)
		clash_bot_fill()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/show_count(seconds)
	for(var/client/player as anything in GLOB.clients)
		playsound_client(player, seconds ? 'sound/effects/sebb_beep.ogg' : 'sound/machines/beepalert.ogg', null, 50)
		clash_show_final_count(player, seconds)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/shows_alive_count()
	return FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/has_medics()
	return FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/live_regear_open()
	return countdown_end_time && !match_live

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/deploy_returning()
	var/list/queue = list()
	var/list/anyone = list()
	var/list/pending = list(FACTION_MARINE = count_side(FACTION_MARINE), FACTION_UPP = count_side(FACTION_UPP))
	for(var/client/player as anything in GLOB.clients.Copy())
		var/mob/waiting = player.mob
		var/datum/clash_kit_screen/screen
		var/side
		if((player.ckey in join_queue) && (isnewplayer(waiting) || (isobserver(waiting) && clash_can_redeploy(waiting))))
			screen = get_clash_kit_screen(waiting)
			screen.pick_job_for(waiting)
			side = join_queue[player.ckey]
			if(!side)
				anyone[waiting] = screen
				continue
		else if(isobserver(waiting))
			screen = GLOB.clash_kit_screens[player.ckey]
			side = last_side[player.ckey]
			if(!screen?.job || !side || !recently_active(player) || !clash_can_redeploy(waiting) || clash_kit_faction_for_job(screen.job) != side)
				continue
		else
			continue
		queue[waiting] = list(screen, side)
		pending[side]++
	for(var/mob/waiting as anything in shuffle(anyone))
		var/side = pending[FACTION_MARINE] == pending[FACTION_UPP] ? pick(FACTION_MARINE, FACTION_UPP) : (pending[FACTION_MARINE] < pending[FACTION_UPP] ? FACTION_MARINE : FACTION_UPP)
		queue[waiting] = list(anyone[waiting], side)
		pending[side]++
	join_queue.Cut()
	var/list/by_side = list(FACTION_MARINE = list(), FACTION_UPP = list())
	for(var/mob/waiting as anything in queue)
		var/list/entry = queue[waiting]
		by_side[entry[2]] += waiting
	var/list/counts = list(FACTION_MARINE = count_side(FACTION_MARINE), FACTION_UPP = count_side(FACTION_UPP))
	var/list/ordered = list()
	while(length(by_side[FACTION_MARINE]) || length(by_side[FACTION_UPP]))
		var/side = !length(by_side[FACTION_UPP]) || (length(by_side[FACTION_MARINE]) && counts[FACTION_MARINE] <= counts[FACTION_UPP]) ? FACTION_MARINE : FACTION_UPP
		var/list/side_list = by_side[side]
		var/mob/next = side_list[1]
		side_list.Cut(1, 2)
		ordered[next] = queue[next]
		counts[side]++
	if(length(ordered))
		INVOKE_ASYNC(src, PROC_REF(deploy_queue), ordered)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/deploy_queue(list/queue)
	for(var/mob/waiting as anything in queue)
		if(QDELETED(waiting) || !waiting.client || match_live)
			continue
		var/list/entry = queue[waiting]
		var/datum/clash_kit_screen/screen = entry[1]
		screen.show_side(entry[2])
		if(!can_join_side(screen.job, waiting))
			var/other = entry[2] == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
			screen.show_side(other)
			if(can_join_side(screen.job, waiting))
				to_chat(waiting, SPAN_NOTICE("Your side is full, so you join the [other == FACTION_MARINE ? "USCM" : "UPP"]."))
			else
				screen.show_side(entry[2])
		if(!can_join_side(screen.job, waiting))
			join_queue[waiting.ckey] = entry[2]
			to_chat(waiting, SPAN_WARNING("Your side is full. You join at the next match if there is room."))
			if(isnewplayer(waiting))
				var/mob/new_player/lobby = waiting
				usr = lobby
				lobby.attempt_observe()
			continue
		to_chat(waiting, SPAN_NOTICE("Deploying you for the next match as [clash_role_name(screen.job)]."))
		usr = waiting
		screen.deploy(waiting)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/join_from_lobby(mob/new_player/user, faction, datum/clash_kit_screen/screen)
	if(get_spawn_block())
		join_queue[user.ckey] = faction
		to_chat(user, SPAN_NOTICE("You will join [faction == FACTION_MARINE ? "USCM" : "UPP"] when the next match starts."))
		return TRUE
	var/client/player = user.client
	screen.deploy(user)
	return ishuman(player?.mob)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/finish_match(reason)
	var/before = length(match_results)
	. = ..()
	if(length(match_results) == before)
		return
	var/list/result = match_results[length(match_results)]
	var/title = "DRAW"
	var/color = "#cccccc"
	switch(result["winner"])
		if(FACTION_MARINE)
			title = "USCM WINS"
			color = faction_color(FACTION_MARINE)
		if(FACTION_UPP)
			title = "UPP WINS"
			color = faction_color(FACTION_UPP)
	for(var/client/player as anything in GLOB.clients)
		clash_show_match_banner(player, title, color, reason)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/countdown_done()
	var/list/away = get_away_bodies()
	if(length(get_standing(FACTION_MARINE, away)) && length(get_standing(FACTION_UPP, away)))
		waiting_for_players = FALSE
		start_match()
		return
	if(!waiting_for_players)
		waiting_for_players = TRUE
		for(var/faction in list(FACTION_MARINE, FACTION_UPP))
			announce_to_faction(faction, "Waiting for players on both sides.")
	countdown_end_time = world.time + 5 SECONDS
	countdown_timer_id = addtimer(CALLBACK(src, PROC_REF(countdown_done)), 5 SECONDS, TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_spawn_block()
	return match_live ? "Wait until the match ends" : null

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/can_set_score()
	return FALSE

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_match_score(faction)
	return standing[faction] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_score_limit()
	return max(fielded[FACTION_MARINE] || 0, fielded[FACTION_UPP] || 0)

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/get_match_result_line(list/result, number)
	if(isnull(number))
		number = length(match_results)
	switch(result["winner"])
		if(FACTION_MARINE)
			return "USCM takes match [number] with [result["uscm"]] standing."
		if(FACTION_UPP)
			return "UPP takes match [number] with [result["upp"]] standing."
	if(!result["uscm"])
		return "Match [number] drawn, both teams wiped out."
	return "Match [number] drawn with [result["uscm"]] standing each."

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/get_standing(faction, list/away)
	. = list()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list)
		if(fighter.faction == faction && is_ground_level(fighter.z) && is_standing(fighter, away))
			. += fighter

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/is_standing(mob/living/carbon/human/fighter, list/away)
	var/datum/weakref/ref = WEAKREF(fighter)
	if(fighter.client || away?[fighter] || clash_is_bot(fighter))
		disconnected -= ref
		return TRUE
	if(!fighter.key)
		return FALSE
	if(!disconnected[ref])
		disconnected[ref] = world.time
	return world.time - disconnected[ref] < CLASH_ELIM_DISCONNECT_GRACE

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/get_away_bodies()
	. = list()
	for(var/mob/dead/observer/ghost as anything in GLOB.observer_list)
		if(ghost.client && ghost.can_reenter_corpse && ishuman(ghost.mind?.original))
			.[ghost.mind.original] = TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/reset_arena()
	var/list/away = get_away_bodies()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list.Copy())
		if(fighter.client || !fighter.key || away[fighter] || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)) || !is_ground_level(fighter.z))
			continue
		fighter.ghostize(FALSE)
		qdel(fighter)
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/on_match_start()
	fielded = list()
	last_callouts = list()
	disconnected = list()
	crit_since = list()
	clash_show_gates(FALSE)
	show_count(0)
	tick_elimination()
	refresh_kit_screens()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/on_match_end()
	var/list/away = get_away_bodies()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		standing[faction] = length(get_standing(faction, away))
	clash_show_gates(TRUE)
	refresh_kit_screens()

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/refresh_kit_screens()
	for(var/ckey in GLOB.clash_kit_screens)
		SStgui.update_uis(GLOB.clash_kit_screens[ckey])

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/finish_hopeless()
	var/list/still_down = list()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list.Copy())
		if(fighter.stat != UNCONSCIOUS || fighter.health >= 0 || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)) || !is_ground_level(fighter.z))
			continue
		var/datum/weakref/ref = WEAKREF(fighter)
		var/down_since = crit_since[ref] || world.time
		if(!beyond_saving(fighter) && world.time - down_since < CLASH_ELIM_CRIT_LIMIT)
			still_down[ref] = down_since
			continue
		to_chat(fighter, SPAN_WARNING("Your wounds are beyond saving without a medic."))
		fighter.death(fighter.last_damage_data)
	crit_since = still_down

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/beyond_saving(mob/living/carbon/human/fighter)
	if((fighter.species.flags & IS_SYNTHETIC) || (fighter.chem_effect_flags & CHEM_EFFECT_ORGAN_STASIS))
		return FALSE
	if(fighter.getToxLoss() >= CLASH_ELIM_HOPELESS_TOXIN)
		return TRUE
	var/datum/internal_organ/heart/heart = fighter.internal_organs_by_name["heart"]
	if(!heart)
		return TRUE
	var/pumped = fighter.blood_volume
	if(heart.organ_status >= ORGAN_BRUISED)
		pumped *= clamp(100 - 2 * heart.damage, 30, 100) / 100
	return pumped < BLOOD_VOLUME_OKAY

/datum/game_mode/extended/faction_clash/hvh/tdm/elimination/proc/tick_elimination()
	if(round_finished)
		deltimer(elimination_timer_id)
		elimination_timer_id = null
		return
	if(intermission_end_time || (!match_live && !countdown_end_time))
		return
	if(match_live)
		finish_hopeless()
	var/list/fighters = list()
	var/list/away = get_away_bodies()
	var/changed = FALSE
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		fighters[faction] = get_standing(faction, away)
		var/count = length(fighters[faction])
		if(count != standing[faction])
			changed = TRUE
		standing[faction] = count
		if(match_live)
			fielded[faction] = max(fielded[faction] || 0, count)
		for(var/mob/living/carbon/human/fighter as anything in fighters[faction])
			if(fighter.ckey)
				last_side[fighter.ckey] = faction
	if(changed)
		update_score_huds()
	if(!match_live)
		return
	var/uscm_out = fielded[FACTION_MARINE] && !standing[FACTION_MARINE]
	var/upp_out = fielded[FACTION_UPP] && !standing[FACTION_UPP]
	if(uscm_out && upp_out)
		finish_match("Both teams eliminated")
		return
	if(uscm_out || upp_out)
		finish_match("[uscm_out ? "USCM" : "UPP"] eliminated")
		return
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		if(standing[faction] != 1 || fielded[faction] < 2 || (faction in last_callouts))
			continue
		last_callouts += faction
		var/mob/living/carbon/human/last = fighters[faction][1]
		announce_to_faction(faction, "[last.real_name] is the last one standing.")
		announce_to_faction(faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE, "One enemy left.")

#undef CLASH_ELIM_DISCONNECT_GRACE
#undef CLASH_ELIM_ACTIVE_WINDOW
#undef CLASH_ELIM_HUNT_AFTER
#undef CLASH_ELIM_HUNT_LEFT
#undef CLASH_ELIM_FIRST_COUNTDOWN
#undef CLASH_ELIM_LOBBY_SECONDS
#undef CLASH_ELIM_HOPELESS_TOXIN
#undef CLASH_ELIM_CRIT_LIMIT
#undef CLASH_ELIM_COUNTDOWN_BEEPS

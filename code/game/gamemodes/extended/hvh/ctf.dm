#define CLASH_FLAG_STAND_MIN_GAP 10

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf
	name = GAMEMODE_CTF
	config_tag = GAMEMODE_CTF
	kill_limit = 0
	score_label = "captures"
	var/capture_limit = 3
	var/flag_return_time = 30 SECONDS
	var/list/obj/item/clash_flag/flags = list()
	var/list/stands = list()
	var/list/captures = list()
	var/list/stand_tiles = list()
	var/list/round_captures = list()
	var/flag_timer_id

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/pre_setup()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	if(ground?.tdm_capture_limit)
		capture_limit = ground.tdm_capture_limit
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/post_setup()
	build_stands()
	return ..()

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/build_stands()
	var/list/notes = list()
	stands = get_clash_flag_spots(notes)
	var/turf/uscm_home = stands[FACTION_MARINE]
	var/turf/upp_home = stands[FACTION_UPP]
	if(!uscm_home || !upp_home || get_dist(uscm_home, upp_home) < CLASH_FLAG_STAND_MIN_GAP)
		message_admins("HVH: [name] could not place two flag stands far enough apart on this map. Matches will be decided on time as draws.")
		stands = list()
		return
	message_admins("HVH: [name]: [notes.Join(" ")]")
	log_game("HVH: [name]: [notes.Join(" ")]")
	for(var/faction in stands)
		var/turf/home = stands[faction]
		stand_tiles += place_clash_flag_stand(home, faction_color(faction))
		GLOB.clash_objective_turfs |= home
		spawn_flag(faction)
		log_debug("HVH: [faction] flag stand at [home.x],[home.y]")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/can_rebuild_objectives()
	return TRUE

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/rebuild_objectives()
	for(var/faction in flags)
		var/obj/item/clash_flag/flag = flags[faction]
		if(QDELETED(flag))
			continue
		if(ismob(flag.loc))
			var/mob/holder = flag.loc
			holder.drop_inv_item_on_ground(flag, TRUE, TRUE)
		if(flag.carrier)
			release_carrier(flag)
		qdel(flag)
	flags = list()
	for(var/faction in stands)
		GLOB.clash_objective_turfs -= stands[faction]
	QDEL_LIST(stand_tiles)
	build_stands()
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.post && !bot.post.rally_id)
			bot.anchor = bot.post.get_hold_turf()

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_radar_pins(mob/viewer)
	. = list()
	for(var/faction in stands)
		var/tone = clash_radar_tone(faction, viewer)
		. += list(list("key" = "stand[faction]", "turf" = stands[faction], "letter" = "F", "tone" = tone, "hollow" = FALSE))
		var/obj/item/clash_flag/flag = flags[faction]
		if(!QDELETED(flag) && flag.state != CLASH_FLAG_HOME)
			. += list(list("key" = REF(flag), "turf" = get_turf(flag), "letter" = "F", "tone" = tone, "hollow" = TRUE))

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_objective_turfs()
	. = list()
	for(var/faction in stands)
		.["[faction == FACTION_MARINE ? "USCM" : "UPP"] flag stand"] = stands[faction]

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/admin_set_score(faction, score)
	captures[faction] = score
	update_score_huds()
	if(score >= capture_limit)
		finish_match("Capture limit reached")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/spawn_flag(faction)
	var/turf/home = stands[faction]
	if(!home)
		return null
	var/flag_type = faction == FACTION_MARINE ? /obj/item/clash_flag/uscm : /obj/item/clash_flag/upp
	var/obj/item/clash_flag/flag = new flag_type(home)
	flags[faction] = flag
	return flag

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_welcome_rules()
	return list(
		"Each flag stands outside its base.",
		"Carry the enemy flag to your own flag's stand while yours is home to score.",
		"Touch your own flag where it lies to send it home. Dropped flag returns home by itself after [flag_return_time / 10] seconds.",
		"First team to [capture_limit] captures wins, otherwise the most captures when time runs out.",
		"Flag carriers cannot enter their own base.",
	)

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_win_condition()
	var/unit = matches_per_round > 1 ? "Each match" : "The round"
	return "[unit] lasts [round_time_limit / 600] minutes. Bring the enemy flag to your own stand to score. First to [capture_limit] captures, or the most captures when time runs out, wins."

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_score_limit()
	return capture_limit

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_match_score(faction)
	return captures[faction] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_round_tiebreak(faction)
	return round_captures[faction] || 0

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_limit_text()
	return "First to [capture_limit] captures"

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/get_flag_state_text(obj/item/clash_flag/flag)
	if(QDELETED(flag))
		return "missing"
	switch(flag.state)
		if(CLASH_FLAG_CARRIED)
			return "taken by [flag.carrier?.real_name]"
		if(CLASH_FLAG_DROPPED)
			return "dropped, home in [CEILING(max(0, flag.dropped_at + flag_return_time - world.time) / 10, 1)]s"
	return "home"

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_objective_maptext()
	if(!length(flags))
		return list()
	var/list/parts = list()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		parts += "<span style='color: [faction_color(faction)]'>[faction == FACTION_MARINE ? "USCM" : "UPP"] flag</span> [get_flag_state_text(flags[faction])]"
	return list("<span class='maptext center'>[parts.Join(" | ")]</span>")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/get_objective_data()
	. = list()
	for(var/faction in flags)
		. += list(list("label" = "[faction == FACTION_MARINE ? "USCM" : "UPP"] flag", "state" = get_flag_state_text(flags[faction]), "color" = faction_color(faction)))

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/on_match_start()
	captures = list()
	for(var/faction in stands)
		var/obj/item/clash_flag/flag = flags[faction]
		if(QDELETED(flag))
			spawn_flag(faction)
		else
			return_flag(flag, null, TRUE)
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.post && !bot.post.rally_id)
			bot.anchor = bot.post.get_hold_turf()
	if(!flag_timer_id)
		flag_timer_id = addtimer(CALLBACK(src, PROC_REF(tick_flags)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE)

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/on_match_end()
	for(var/faction in captures)
		round_captures[faction] = (round_captures[faction] || 0) + captures[faction]

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/archive_match()
	. = ..()
	captures = list()

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/settle_flag(obj/item/clash_flag/flag)
	if(QDELETED(flag))
		return
	var/mob/living/carbon/human/holder = flag.loc
	if(ishuman(holder) && (holder.l_hand == flag || holder.r_hand == flag))
		if(flag.carrier != holder)
			take_flag(flag, holder)
		return
	if(ismob(flag.loc) || !isturf(flag.loc))
		if(ismob(flag.loc))
			var/mob/wearer = flag.loc
			wearer.drop_inv_item_on_ground(flag, TRUE, TRUE)
		if(!isturf(flag.loc))
			flag.forceMove(get_turf(flag))
	if(flag.state == CLASH_FLAG_HOME && flag.loc == flag.home)
		return
	if(flag.carrier)
		release_carrier(flag)
	if(flag.state != CLASH_FLAG_DROPPED)
		flag.state = CLASH_FLAG_DROPPED
		flag.dropped_at = world.time
		flag.show_planted(FALSE)
		announce_flag(flag, "dropped")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/take_flag(obj/item/clash_flag/flag, mob/living/carbon/human/runner)
	if(flag.carrier)
		release_carrier(flag)
	flag.carrier = runner
	flag.state = CLASH_FLAG_CARRIED
	flag.dropped_at = null
	flag.show_planted(FALSE)
	RegisterSignal(runner, list(COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETING), PROC_REF(on_carrier_lost), override = TRUE)
	runner.add_filter("clash_flag_carrier", 3, outline_filter(2, faction_color(flag.faction)))
	qdel(runner.GetComponent(/datum/component/clash_spawn_guard))
	announce_flag(flag, "taken", runner)

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/release_carrier(obj/item/clash_flag/flag)
	var/mob/living/carbon/human/runner = flag.carrier
	flag.carrier = null
	if(QDELETED(runner))
		return
	var/still_carrying = FALSE
	for(var/faction in flags)
		var/obj/item/clash_flag/other = flags[faction]
		if(other != flag && other?.carrier == runner)
			still_carrying = TRUE
	if(!still_carrying)
		UnregisterSignal(runner, list(COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETING))
		runner.remove_filter("clash_flag_carrier")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/on_carrier_lost(mob/living/carbon/human/runner)
	SIGNAL_HANDLER
	var/turf/spot = get_turf(runner)
	for(var/faction in flags)
		var/obj/item/clash_flag/flag = flags[faction]
		if(QDELETED(flag) || flag.carrier != runner)
			continue
		runner.drop_inv_item_on_ground(flag, TRUE, TRUE)
		if(flag.loc != spot)
			flag.forceMove(spot)
		settle_flag(flag)

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/return_flag(obj/item/clash_flag/flag, mob/returner, silent = FALSE)
	if(ismob(flag.loc))
		var/mob/holder = flag.loc
		holder.drop_inv_item_on_ground(flag, TRUE, TRUE)
	if(flag.carrier)
		release_carrier(flag)
	flag.forceMove(flag.home)
	flag.state = CLASH_FLAG_HOME
	flag.dropped_at = null
	flag.show_planted(TRUE)
	if(!silent)
		announce_flag(flag, "returned", returner)

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/announce_flag(obj/item/clash_flag/flag, event, mob/who)
	var/owner = flag.faction
	var/other = owner == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE
	var/owner_name = owner == FACTION_MARINE ? "USCM" : "UPP"
	switch(event)
		if("taken")
			announce_to_faction(owner, "Our flag has been taken by [who.real_name]!")
			announce_to_faction(other, "[who.real_name] has the [owner_name] flag. Get it home!")
		if("dropped")
			announce_to_faction(owner, "Our flag is down. Touch it to send it home.")
			announce_to_faction(other, "The [owner_name] flag is down. Pick it back up!")
		if("returned")
			announce_to_faction(owner, who ? "[who.real_name] returned our flag." : "Our flag is home.")
			announce_to_faction(other, "The [owner_name] flag is home again.")
		if("captured")
			announce_to_faction(other, "[who.real_name] captured the [owner_name] flag!")
			announce_to_faction(owner, "[who.real_name] captured our flag.")

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/tick_flags()
	if(round_finished)
		deltimer(flag_timer_id)
		flag_timer_id = null
		return
	if(!match_live)
		return
	for(var/faction in stands)
		var/obj/item/clash_flag/flag = flags[faction]
		if(QDELETED(flag))
			flag = spawn_flag(faction)
			announce_flag(flag, "returned")
			continue
		settle_flag(flag)
		var/area/clash_arena/here = get_area(flag)
		if(istype(here) && here.clash_faction && here.clash_faction != flag.faction)
			return_flag(flag)
			continue
		if(flag.state == CLASH_FLAG_DROPPED && world.time - flag.dropped_at >= flag_return_time)
			return_flag(flag)
			continue
		if(flag.state != CLASH_FLAG_CARRIED)
			continue
		var/mob/living/carbon/human/runner = flag.carrier
		var/obj/item/clash_flag/own = flags[runner.faction]
		if(QDELETED(own) || own.state != CLASH_FLAG_HOME || runner.z != own.home.z || get_dist(runner, own.home) > 1)
			continue
		score_capture(flag, runner)
		if(round_finished || !match_live)
			return

/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/proc/score_capture(obj/item/clash_flag/flag, mob/living/carbon/human/runner)
	captures[runner.faction] = (captures[runner.faction] || 0) + 1
	var/list/entry = get_score_entry(runner.real_name, runner.faction, runner.mind?.ckey || runner.ckey)
	entry["captures"] = (entry["captures"] || 0) + 1
	clash_progress_capture(runner)
	announce_flag(flag, "captured", runner)
	return_flag(flag, null, TRUE)
	log_debug("HVH: [runner.real_name] captured the [flag.faction] flag, [runner.faction] at [captures[runner.faction]]")
	if(captures[runner.faction] >= capture_limit)
		finish_match("Capture limit reached")

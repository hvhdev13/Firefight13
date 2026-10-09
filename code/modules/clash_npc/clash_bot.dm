#define CLASH_BOT_TICK 1
#define CLASH_BOT_THINK 3
#define CLASH_BOT_SIGHT 7
#define CLASH_BOT_ACCURACY 0.7
#define CLASH_BOT_RELOAD_DELAY 25
#define CLASH_BOT_COVER_RESCAN 30
#define CLASH_BOT_REPATH_DELAY 5
#define CLASH_BOT_PATHS_PER_TICK 2
#define CLASH_BOT_MEMORY 60
#define CLASH_BOT_WOUNDED 0.45
#define CLASH_BOT_RETREAT_HEALTH 0.3
#define CLASH_BOT_STUCK_LIMIT 3
#define CLASH_BOT_SEARCH_DELAY 6
#define CLASH_BOT_HEAL_DELAY 100
#define CLASH_BOT_SCAVENGE_RANGE 8
#define CLASH_BOT_CLOSE_RANGE 4
#define CLASH_BOT_HEARING 10
#define CLASH_BOT_DANGER_TIME (20 SECONDS)
#define CLASH_BOT_DANGER_COST 6
#define CLASH_BOT_DODGE_DELAY 5
#define CLASH_BOT_DODGE_TIME (2 SECONDS)
#define CLASH_BOT_SETTLE_TIME (3 SECONDS)
#define CLASH_BOT_SUPPRESSED 50
#define CLASH_BOT_FOLLOW_RANGE 3
#define CLASH_BOT_POSITION_RANGE 5
#define CLASH_BOT_PRIORITY_BONUS 3
#define CLASH_BOT_CARRIER_BONUS 8
#define CLASH_BOT_MEDIC_RANGE 7
#define CLASH_BOT_PATIENT_HEALTH 0.6
#define CLASH_BOT_PATIENT_SCAN (2 SECONDS)
#define CLASH_BOT_TREAT_DELAY (2 SECONDS)
#define CLASH_BOT_LANE_CLOSE 50
#define CLASH_BOT_LANE_NEAR 30
#define CLASH_BOT_LANE_FAR 20
#define CLASH_BOT_VOLLEY_STALL (2 SECONDS)
#define CLASH_BOT_COMMIT (1.5 SECONDS)
#define CLASH_BOT_RETREAT_TIME (4 SECONDS)
#define CLASH_BOT_RETREAT_COOLDOWN (6 SECONDS)
#define CLASH_BOT_RETREAT_RANGE 6
#define CLASH_BOT_SEEK_TIME (10 SECONDS)
#define CLASH_BOT_SEEK_SLACK 10
#define CLASH_BOT_COMBAT_STEP 4
#define CLASH_BOT_COMBAT_SLACK 6
#define CLASH_BOT_COMBAT_RESCAN 33
#define CLASH_BOT_BRACE_RETRY (5 SECONDS)
#define CLASH_BOT_LANE_PATIENCE (1 SECONDS)
#define CLASH_BOT_FAILED_GOAL_TIME (10 SECONDS)
#define CLASH_BOT_BLOCKED_STEP_TIME (5 SECONDS)
#define CLASH_BOT_STATE_OBJECTIVE "objective"
#define CLASH_BOT_STATE_COMBAT "combat"
#define CLASH_BOT_STATE_SEEK "seek"
#define CLASH_BOT_STATE_RETREAT "retreat"
#define CLASH_BOT_STATE_RECOVER "recover"
#define CLASH_BOT_STATE_MEDIC "medic"
#define CLASH_BOT_STATE_CARRY "carry"
#define CLASH_BOT_STATE_DODGE "dodge"

GLOBAL_LIST_EMPTY(clash_bots)
GLOBAL_LIST_EMPTY(clash_bot_cover_claims)
GLOBAL_VAR_INIT(clash_bot_paths_this_tick, 0)
GLOBAL_VAR_INIT(clash_bots_enabled, TRUE)

SUBSYSTEM_DEF(clash_bots)
	name = "Clash Bots"
	wait = CLASH_BOT_TICK
	flags = SS_NO_INIT
	var/list/currentrun = list()

/datum/controller/subsystem/clash_bots/stat_entry(msg)
	msg = "B: [length(GLOB.clash_bots)]"
	return ..()

/datum/controller/subsystem/clash_bots/fire(resumed = FALSE)
	if(!resumed)
		GLOB.clash_bot_paths_this_tick = 0
		currentrun = GLOB.clash_bots_enabled ? GLOB.clash_bots.Copy() : list()
		if(GLOB.clash_bots_enabled)
			for(var/faction in GLOB.clash_bot_directors)
				var/datum/clash_bot_director/director = GLOB.clash_bot_directors[faction]
				if(world.time >= director.next_plan)
					director.plan()
	while(length(currentrun))
		var/datum/clash_bot/bot = currentrun[length(currentrun)]
		currentrun.len--
		if(!QDELETED(bot))
			bot.tick()
		if(MC_TICK_CHECK)
			return

/proc/set_clash_bots_enabled(enabled)
	GLOB.clash_bots_enabled = enabled
	if(enabled)
		return
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		bot.stop_volley()

/datum/clash_bot
	var/mob/living/carbon/human/body
	var/obj/effect/landmark/clash_npc/post
	var/obj/item/weapon/gun/gun
	var/mob/living/carbon/human/target
	var/turf/anchor
	var/turf/home
	var/hold_radius = 6
	var/turf/destination
	var/list/path
	var/turf/claimed
	var/list/watched_turfs = list()
	var/next_fire = 0
	var/next_step = 0
	var/next_repath = 0
	var/next_cover_scan = 0
	var/next_search = 0
	var/next_heal = 0
	var/stuck_for = 0
	var/firing = FALSE
	var/last_round_at = 0
	var/atom/aim_atom
	var/shots_left = 0
	var/dry = FALSE
	var/task
	var/mob/living/carbon/human/leader
	var/task_key
	var/datum/clash_zone/zone
	var/turf/via
	var/keep_off = 0
	var/obj/item/clash_flag/flag_goal
	var/mob/living/carbon/human/chase
	var/mob/living/carbon/human/wait_for
	var/wait_until = 0
	var/arrived_at = 0
	var/next_position = 0
	var/turf/heard_turf
	var/heard_at = 0
	var/target_since = 0
	var/dodge_seen = 0
	var/dodge_until = 0
	var/was_suppressed = FALSE
	var/list/danger = list()
	var/heavy = FALSE
	var/medic = FALSE
	var/mob/living/carbon/human/medic_patient
	var/next_patient_scan = 0
	var/next_think = 0
	var/next_brace = 0
	var/state = CLASH_BOT_STATE_OBJECTIVE
	var/state_since = 0
	var/list/known = list()
	var/list/known_pos = list()
	var/searched = FALSE
	var/target_lost_at = 0
	var/lane_blocked_since = 0
	var/retreat_until = 0
	var/retreat_ready_at = 0
	var/seek_until = 0
	var/turf/pending_destination
	var/list/failed_goals = list()
	var/list/blocked_steps = list()

/datum/clash_bot/New(mob/living/carbon/human/new_body, obj/effect/landmark/clash_npc/new_post)
	. = ..()
	body = new_body
	post = new_post
	anchor = new_post ? new_post.get_hold_turf() : get_turf(new_body)
	if(new_post)
		hold_radius = new_post.hold_radius
	heavy = clash_is_heavy(body)
	medic = clash_is_medic(body)
	arm_up()
	RegisterSignal(body, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(body, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired))
	RegisterSignal(body, COMSIG_MOVABLE_MOVED, PROC_REF(watch_nearby_turfs))
	watch_nearby_turfs()
	GLOB.clash_bots += src
	var/datum/clash_bot_director/director = clash_bot_director(body.faction)
	director.next_plan = min(director.next_plan, world.time + 1 SECONDS)

/datum/clash_bot/Destroy(force)
	stop_volley()
	release_cover()
	unwatch_turfs()
	GLOB.clash_bots -= src
	if(!QDELETED(gun))
		UnregisterSignal(gun, COMSIG_GUN_BEFORE_FIRE)
	if(!QDELETED(body))
		UnregisterSignal(body, list(COMSIG_HUMAN_BULLET_ACT, COMSIG_MOB_FIRED_GUN, COMSIG_MOVABLE_MOVED))
	body = null
	post = null
	gun = null
	primary = null
	sidearm = null
	knife = null
	grenade = null
	homes = null
	target = null
	heard_turf = null
	aim_atom = null
	known = null
	known_pos = null
	failed_goals = null
	pending_destination = null
	leader = null
	task_key = null
	zone = null
	via = null
	flag_goal = null
	chase = null
	wait_for = null
	medic_patient = null
	danger = null
	path_card = null
	anchor = null
	home = null
	destination = null
	path = null
	return ..()

/datum/clash_bot/proc/on_gun_fire(obj/item/weapon/gun/source, obj/projectile/bullet, atom/aim)
	SIGNAL_HANDLER
	var/settle = 0.8 + 0.3 * min(1, (world.time - target_since) / CLASH_BOT_SETTLE_TIME)
	if(world.time - body.l_move_time < 5)
		settle *= 0.85
	if(was_suppressed)
		settle *= 0.8
	bullet.accuracy *= CLASH_BOT_ACCURACY * settle

/datum/clash_bot/proc/on_fired(mob/source, obj/item/weapon/gun/fired)
	SIGNAL_HANDLER
	if(!firing)
		return
	last_round_at = world.time
	shots_left--
	if(shots_left <= 0)
		stop_volley()

/datum/clash_bot/proc/on_shot(mob/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	remember(bullet.firer)
	mark_danger(get_turf(body))
	next_cover_scan = min(next_cover_scan, world.time + 5)

/datum/clash_bot/proc/on_bullet_near(turf/source, atom/movable/entering)
	SIGNAL_HANDLER
	if(istype(entering, /obj/projectile))
		var/obj/projectile/bullet = entering
		remember(bullet.firer)

/datum/clash_bot/proc/remember(atom/thing)
	var/mob/living/carbon/human/enemy = thing
	if(!istype(enemy) || enemy.faction == body.faction || enemy.stat == DEAD)
		return
	known[enemy] = world.time
	known_pos[enemy] = get_turf(enemy)

/datum/clash_bot/proc/forget(mob/living/carbon/human/enemy)
	known -= enemy
	known_pos -= enemy

/datum/clash_bot/proc/perceive()
	for(var/mob/living/carbon/human/enemy as anything in known.Copy())
		if(QDELETED(enemy) || enemy.stat == DEAD || enemy.z != body.z || world.time - known[enemy] > CLASH_BOT_MEMORY)
			forget(enemy)
	searched = world.time >= next_search
	if(searched)
		next_search = world.time + CLASH_BOT_SEARCH_DELAY + rand(0, 3)
		var/turf/here = get_turf(body)
		for(var/mob/living/carbon/human/enemy in oview(CLASH_BOT_SIGHT, body))
			if(enemy.faction != body.faction && enemy.stat != DEAD && line_clear(here, get_turf(enemy)))
				remember(enemy)
	if(medic && hands == 2 && !carrying())
		update_patient()

/datum/clash_bot/proc/latest_known()
	var/mob/living/carbon/human/latest
	for(var/mob/living/carbon/human/enemy as anything in known)
		if(!latest || known[enemy] > known[latest])
			latest = enemy
	return latest

/datum/clash_bot/proc/focus_turf()
	if(target)
		return get_turf(target)
	var/mob/living/carbon/human/latest = latest_known()
	if(latest)
		return known_pos[latest]
	if(heard_turf && world.time - heard_at < CLASH_BOT_MEMORY)
		return heard_turf
	return null

/datum/clash_bot/proc/contact_recent()
	return length(known) || (heard_turf && world.time - heard_at < CLASH_BOT_MEMORY)

/datum/clash_bot/proc/tick()
	if(world.time >= next_think)
		next_think = world.time + CLASH_BOT_THINK
		think()
		return
	if(QDELETED(body) || body.stat == DEAD || body.is_mob_incapacitated() || HAS_TRAIT(body, TRAIT_FLOORED) || world.time < busy_until)
		return
	fire_tick()
	handle_movement()
	face_focus()

/datum/clash_bot/proc/think()
	if(QDELETED(body) || body.stat == DEAD)
		post?.bot_died(body)
		qdel(src)
		return
	if(body.is_mob_incapacitated())
		stop_volley()
		return
	if(body.on_fire)
		stop_volley()
		body.resist_fire()
		return
	if(!check_hands() || world.time < busy_until)
		return
	var/ceasefire = MODE_HAS_MODIFIER(/datum/gamemode_modifier/ceasefire)
	perceive()
	update_target()
	var/suppressed = clash_suppression_now(body) >= CLASH_BOT_SUPPRESSED
	if(suppressed && !was_suppressed)
		next_cover_scan = 0
	was_suppressed = suppressed
	watch_grenades()
	if(!ceasefire)
		grab_nearby_flag()
	var/obj/item/weapon/gun/wanted = pick_gun()
	charging = !ceasefire && should_charge(wanted)
	bleed_out(HAS_TRAIT(body, TRAIT_FLOORED) && !(wanted && gun_ready(wanted)))
	decide()
	try_brace()
	if(charging)
		stab()
	else
		if(wanted != gun || (wanted && body.get_active_hand() != wanted))
			ready_gun(wanted)
		else if(gun && hands == 2 && (gun.flags_item & TWOHANDED) && !(gun.flags_item & WIELDED) && !carrying())
			gun.wield(body)
		if(ceasefire)
			stop_volley()
		else if(target)
			if(carrying() && get_dist(body, target) > CLASH_BOT_CLOSE_RANGE)
				stop_volley()
			else if(state == CLASH_BOT_STATE_RETREAT || carrying() || !try_grenade())
				fight()
		else if(firing)
			stop_volley()
		else if(state == CLASH_BOT_STATE_MEDIC)
			treat_patient()
		else if(contact_recent() && prob(heavy ? 60 : 25))
			suppress()
		else if(state == CLASH_BOT_STATE_OBJECTIVE || state == CLASH_BOT_STATE_RECOVER)
			try_heal()
	if(QDELETED(body))
		return
	fire_tick()
	if(!HAS_TRAIT(body, TRAIT_FLOORED))
		handle_movement()
	face_focus()

/datum/clash_bot/proc/update_target()
	var/atom/previous = target
	var/mob/living/carbon/human/best
	var/best_score
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	for(var/mob/living/carbon/human/enemy as anything in known)
		if(world.time - known[enemy] > CLASH_BOT_SEARCH_DELAY * 2 || !can_engage(enemy))
			continue
		known[enemy] = world.time
		known_pos[enemy] = get_turf(enemy)
		var/score = get_dist(body, enemy)
		if(enemy == previous)
			score -= 2
		if(clash_carries_enemy_flag(enemy))
			score -= CLASH_BOT_CARRIER_BONUS
		else if(istype(clash_mode) && clash_mode.is_objective_turf(get_turf(enemy)))
			score -= CLASH_BOT_PRIORITY_BONUS
		if(isnull(best_score) || score < best_score)
			best = enemy
			best_score = score
	if(!best)
		if(previous && !ismob(previous) && can_engage(previous))
			best = previous
		else if(searched)
			best = find_target()
	target = best
	if(target)
		target_lost_at = 0
	else if(previous && !target_lost_at)
		target_lost_at = world.time
	if(target != previous)
		stop_volley()
		target_since = world.time
		next_fire = max(next_fire, world.time + rand(2, 5))

/datum/clash_bot/proc/can_engage(mob/living/carbon/human/candidate)
	if(istype(candidate, /obj/structure/machinery/defenses/sentry))
		var/obj/structure/machinery/defenses/sentry/turret = candidate
		if(QDELETED(turret) || !turret.placed || !turret.clash_faction || turret.clash_faction == body.faction || turret.z != body.z || get_dist(body, turret) > CLASH_BOT_SIGHT)
			return FALSE
		return clear_shot(get_turf(turret), null, FALSE)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate.faction == body.faction || candidate.GetComponent(/datum/component/clash_spawn_guard))
		return FALSE
	if(candidate.z != body.z || get_dist(body, candidate) > CLASH_BOT_SIGHT)
		return FALSE
	if(!can_enter(get_turf(candidate)))
		return FALSE
	return clear_shot(get_turf(candidate), candidate, FALSE)

/datum/clash_bot/proc/clear_shot(turf/aim, mob/candidate, check_allies = TRUE)
	if(locate(/obj/structure/blocker/clash_gate) in get_turf(body))
		return FALSE
	for(var/turf/line_turf as anything in get_line(body, aim, include_start_atom = FALSE))
		if(line_turf.density || line_turf.opacity || (locate(/obj/structure/blocker/clash_gate) in line_turf))
			return FALSE
		for(var/obj/thing in line_turf)
			if(thing.opacity || (thing.density && thing.projectile_coverage >= PROJECTILE_COVERAGE_HIGH && line_turf != aim))
				return FALSE
	return !check_allies || !ally_in_lane(aim)

/datum/clash_bot/proc/ally_in_lane(atom/aim, turf/start)
	start = start || get_turf(body)
	var/turf/end = get_turf(aim)
	if(!start || !end || start == end)
		return FALSE
	var/reach = get_dist(start, end)
	var/angle = Get_Angle(start, end)
	for(var/mob/living/carbon/human/ally as anything in GLOB.alive_human_list)
		if(ally == body || ally.faction != body.faction || ally.z != start.z)
			continue
		var/distance = get_dist(start, ally)
		if(!distance || distance > reach + 1)
			continue
		var/off = abs(Get_Angle(start, ally) - angle)
		if(off > 180)
			off = 360 - off
		if(off <= (distance == 1 ? CLASH_BOT_LANE_CLOSE : (distance == 2 ? CLASH_BOT_LANE_NEAR : CLASH_BOT_LANE_FAR)))
			return TRUE
	return FALSE

/datum/clash_bot/proc/find_target()
	var/obj/structure/machinery/defenses/sentry/closest
	var/closest_distance = CLASH_BOT_SIGHT + 1
	for(var/obj/structure/machinery/defenses/sentry/turret in oview(CLASH_BOT_SIGHT, body))
		var/distance = get_dist(body, turret)
		if(distance >= closest_distance || !can_engage(turret))
			continue
		closest = turret
		closest_distance = distance
	return closest

/datum/clash_bot/proc/fight()
	if(!gun)
		return
	if(firing)
		if(aim_atom == target && clear_shot(get_turf(target), target, FALSE))
			return
		stop_volley()
	if(world.time < next_fire)
		return
	if(!has_ammo())
		if(!dry && hands == 2)
			next_fire = world.time + CLASH_BOT_RELOAD_DELAY
			INVOKE_ASYNC(src, PROC_REF(reload))
		return
	if(ally_in_lane(target))
		if(!lane_blocked_since)
			lane_blocked_since = world.time
		return
	lane_blocked_since = 0
	start_volley(target, was_suppressed ? rand(2, 3) : (heavy ? rand(8, 14) : rand(4, 8)))

/datum/clash_bot/proc/suppress()
	var/turf/aim = focus_turf()
	if(firing || world.time < next_fire || !has_ammo() || !aim)
		return
	if(get_dist(body, aim) > CLASH_BOT_SIGHT || !clear_shot(aim))
		return
	body.face_atom(aim)
	start_volley(aim, heavy ? rand(5, 9) : rand(2, 4))

/datum/clash_bot/proc/decide()
	var/wanted = pick_state()
	if(wanted == state)
		return
	if(world.time < state_since + CLASH_BOT_COMMIT && !(wanted in list(CLASH_BOT_STATE_DODGE, CLASH_BOT_STATE_COMBAT, CLASH_BOT_STATE_RETREAT, CLASH_BOT_STATE_CARRY)))
		return
	enter_state(wanted)

/datum/clash_bot/proc/pick_state()
	if(world.time < dodge_until)
		return CLASH_BOT_STATE_DODGE
	if(carrying())
		return CLASH_BOT_STATE_CARRY
	if(should_retreat())
		return CLASH_BOT_STATE_RETREAT
	if(charging || target)
		return CLASH_BOT_STATE_COMBAT
	if(state == CLASH_BOT_STATE_COMBAT && target_lost_at && world.time - target_lost_at < CLASH_BOT_COMMIT)
		return CLASH_BOT_STATE_COMBAT
	if(hands == 2 && (dry || !primary))
		return CLASH_BOT_STATE_RECOVER
	if(medic_patient)
		return CLASH_BOT_STATE_MEDIC
	if(seek_goal())
		return CLASH_BOT_STATE_SEEK
	return CLASH_BOT_STATE_OBJECTIVE

/datum/clash_bot/proc/enter_state(new_state)
	if(state == CLASH_BOT_STATE_RETREAT)
		retreat_ready_at = world.time + CLASH_BOT_RETREAT_COOLDOWN
	if(new_state == CLASH_BOT_STATE_RETREAT)
		retreat_until = world.time + CLASH_BOT_RETREAT_TIME
	if(new_state == CLASH_BOT_STATE_SEEK)
		seek_until = world.time + CLASH_BOT_SEEK_TIME
	state = new_state
	state_since = world.time
	next_cover_scan = 0
	release_cover()

/datum/clash_bot/proc/should_retreat()
	if(!length(known) || body.health <= 0 || body.health >= body.maxHealth * CLASH_BOT_RETREAT_HEALTH)
		return FALSE
	if(state == CLASH_BOT_STATE_RETREAT ? world.time >= retreat_until : world.time < retreat_ready_at)
		return FALSE
	return seen_by_enemy()

/datum/clash_bot/proc/seen_by_enemy()
	var/turf/here = get_turf(body)
	for(var/mob/living/carbon/human/enemy as anything in known)
		if(!QDELETED(enemy) && enemy.stat == CONSCIOUS && get_dist(enemy, body) <= CLASH_BOT_SIGHT && line_clear(get_turf(enemy), here))
			return TRUE
	return FALSE

/datum/clash_bot/proc/seek_goal()
	var/mob/living/carbon/human/latest = latest_known()
	var/turf/goal = latest ? known_pos[latest] : focus_turf()
	if(!goal || body.health < body.maxHealth * CLASH_BOT_RETREAT_HEALTH)
		return null
	if((state == CLASH_BOT_STATE_SEEK && world.time > seek_until) || get_dist(body, goal) <= 1)
		if(latest)
			forget(latest)
		else
			heard_turf = null
		return null
	if(get_dist(goal, leash_centre()) > leash_radius() + CLASH_BOT_SEEK_SLACK && !clash_carries_enemy_flag(latest))
		return null
	return goal

/datum/clash_bot/proc/face_focus()
	if(state == CLASH_BOT_STATE_OBJECTIVE && !contact_recent())
		return
	var/turf/focus = focus_turf()
	if(focus && focus != get_turf(body))
		body.face_atom(focus)

/datum/clash_bot/proc/fight_score(turf/spot, turf/aim)
	if(!line_clear(spot, aim))
		return -50
	. = cover_against(spot, aim)
	var/distance = get_dist(spot, aim)
	if(distance < 2)
		. -= 6
	else if(distance > CLASH_BOT_SIGHT)
		. -= 20
	if(ally_in_lane(aim, spot))
		. -= 8
	if(danger_cost(spot))
		. -= 4
	for(var/mob/living/carbon/human/ally in range(1, spot))
		if(ally != body && ally.faction == body.faction && ally.stat != DEAD)
			. -= 4
	if(get_dist(spot, leash_centre()) > leash_radius() + CLASH_BOT_COMBAT_SLACK)
		. -= 10

/datum/clash_bot/proc/braced()
	if(!gun)
		return FALSE
	var/obj/item/attachable/bipod/bipod = LAZYACCESS(gun.attachments, "under")
	return istype(bipod) && bipod.bipod_deployed

/datum/clash_bot/proc/try_brace()
	if(!heavy || !gun || state != CLASH_BOT_STATE_COMBAT || !target || destination || world.time < next_brace || world.time - body.l_move_time < 1 SECONDS)
		return
	var/obj/item/attachable/bipod/bipod = LAZYACCESS(gun.attachments, "under")
	if(!istype(bipod) || bipod.bipod_deployed)
		return
	next_brace = world.time + CLASH_BOT_BRACE_RETRY
	body.face_atom(target)
	INVOKE_ASYNC(src, PROC_REF(brace), bipod)

/datum/clash_bot/proc/brace(obj/item/attachable/bipod/bipod)
	stop_volley()
	busy_until = world.time + 3 SECONDS
	bipod.activate_attachment(gun, body)
	busy_until = 0

/datum/clash_bot/proc/combat_position()
	var/turf/aim = focus_turf()
	if(!aim)
		return
	var/blocked = lane_blocked_since && world.time - lane_blocked_since > CLASH_BOT_LANE_PATIENCE
	if(world.time < next_cover_scan && !blocked)
		return
	next_cover_scan = world.time + rand(CLASH_BOT_COMBAT_RESCAN, CLASH_BOT_COMBAT_RESCAN * 1.5)
	if(blocked)
		lane_blocked_since = world.time
	var/turf/here = get_turf(body)
	var/turf/best
	var/best_score = fight_score(here, aim) + (blocked ? -10 : (braced() ? 10 : 4))
	var/list/steps = walk_steps(CLASH_BOT_COMBAT_STEP * 2, CLASH_BOT_COMBAT_STEP)
	for(var/turf/spot as anything in steps)
		if(spot == here || spot_blocked(spot) || goal_failed(spot))
			continue
		var/datum/clash_bot/owner = GLOB.clash_bot_cover_claims[spot]
		if(owner && owner != src)
			continue
		var/score = fight_score(spot, aim) - steps[spot] * 0.7
		if(score > best_score)
			best = spot
			best_score = score
	if(best)
		claim_cover(best)
		set_destination(best)

/datum/clash_bot/proc/retreat_position()
	if(world.time < next_cover_scan)
		return
	next_cover_scan = world.time + rand(CLASH_BOT_COMBAT_RESCAN, CLASH_BOT_COMBAT_RESCAN * 1.5)
	var/list/enemies = list()
	for(var/mob/living/carbon/human/enemy as anything in known)
		enemies += known_pos[enemy]
	if(!length(enemies))
		return
	var/turf/here = get_turf(body)
	var/turf/best
	var/best_score
	var/list/steps = walk_steps(CLASH_BOT_RETREAT_RANGE * 2, CLASH_BOT_RETREAT_RANGE)
	for(var/turf/spot as anything in steps)
		if(spot_blocked(spot) || goal_failed(spot))
			continue
		var/datum/clash_bot/owner = GLOB.clash_bot_cover_claims[spot]
		if(owner && owner != src)
			continue
		var/score = -steps[spot] * 0.3
		var/nearest = CLASH_BOT_SIGHT * 2
		for(var/turf/enemy as anything in enemies)
			score += line_clear(enemy, spot) ? cover_against(spot, enemy) * 0.5 - 4 : 12
			nearest = min(nearest, get_dist(spot, enemy))
		score += min(nearest, 10)
		for(var/mob/living/carbon/human/ally in range(1, spot))
			if(ally != body && ally.faction == body.faction && ally.stat != DEAD)
				score -= 3
		if(get_dist(spot, leash_centre()) > leash_radius() + CLASH_BOT_COMBAT_SLACK)
			score -= 10
		if(isnull(best_score) || score > best_score)
			best = spot
			best_score = score
	if(best && best != here)
		claim_cover(best)
		set_destination(best)

/datum/clash_bot/proc/goal_failed(turf/spot)
	return failed_goals[spot] > world.time

/datum/clash_bot/proc/fail_goal(turf/spot)
	if(!spot)
		return
	failed_goals[spot] = world.time + CLASH_BOT_FAILED_GOAL_TIME
	prune_memory(failed_goals)

/datum/clash_bot/proc/block_step(turf/spot)
	blocked_steps[spot] = world.time + CLASH_BOT_BLOCKED_STEP_TIME
	prune_memory(blocked_steps)

/datum/clash_bot/proc/prune_memory(list/memory)
	if(length(memory) <= 30)
		return
	for(var/turf/old as anything in memory.Copy())
		if(memory[old] <= world.time)
			memory -= old

/datum/clash_bot/proc/set_destination(turf/spot)
	if(spot == destination)
		return
	if(destination && spot && length(path) && get_dist(spot, destination) <= 1)
		pending_destination = spot
		return
	destination = spot
	pending_destination = null
	path = null

/datum/clash_bot/proc/choose_destination()
	switch(state)
		if(CLASH_BOT_STATE_DODGE)
			return
		if(CLASH_BOT_STATE_COMBAT)
			if(charging)
				var/turf/aim = get_turf(target)
				if(aim && (!destination || get_dist(destination, aim) > 1))
					set_destination(aim)
				return
			combat_position()
		if(CLASH_BOT_STATE_RETREAT)
			retreat_position()
		if(CLASH_BOT_STATE_RECOVER)
			resupply()
		if(CLASH_BOT_STATE_MEDIC)
			if(get_dist(body, medic_patient) > 1)
				release_cover()
				set_destination(get_turf(medic_patient))
		if(CLASH_BOT_STATE_SEEK)
			var/turf/goal = seek_goal()
			if(goal)
				release_cover()
				set_destination(goal)
		else
			follow_task()

/datum/clash_bot/proc/sidestep(turf/here, turf/blocked)
	block_step(blocked)
	path_card = body.get_idcard()
	var/list/options = list()
	for(var/direction in GLOB.cardinals)
		var/turf/side = get_step(here, direction)
		if(side == blocked || !step_open(here, side, direction) || (locate(/mob/living) in side))
			continue
		if(destination && get_dist(side, destination) > get_dist(here, destination) + 1)
			continue
		options += side
	if(!length(options))
		return FALSE
	var/turf/side = pick(options)
	step(body, get_dir(here, side))
	path = null
	return get_turf(body) == side

/datum/clash_bot/proc/handle_movement()
	if(world.time < next_step)
		return
	choose_destination()
	var/turf/here = get_turf(body)
	if(!length(path) && pending_destination)
		destination = pending_destination
		pending_destination = null
	if(!destination || here == destination)
		destination = null
		path = null
		return
	if(!length(path))
		if(world.time < next_repath || GLOB.clash_bot_paths_this_tick >= CLASH_BOT_PATHS_PER_TICK)
			return
		GLOB.clash_bot_paths_this_tick++
		next_repath = world.time + CLASH_BOT_REPATH_DELAY
		path = find_path(destination)
		if(!length(path))
			fail_goal(destination)
			if(destination == claimed)
				release_cover()
			destination = null
			next_cover_scan = 0
			return
	var/turf/next = path[1]
	next_step = world.time + max(2, body.movement_delay())
	step(body, get_dir(here, next))
	var/turf/arrived = get_turf(body)
	if(arrived == next)
		path.Cut(1, 2)
		stuck_for = 0
		return
	if(arrived != here)
		path = null
		stuck_for = 0
		return
	for(var/obj/structure/machinery/door/blocking_door in next)
		if(blocking_door.density && blocking_door.operating == DOOR_OPERATING_OPENING)
			return
	for(var/obj/structure/fence/gate in next)
		if(gate.density && gate.operating)
			return
	stuck_for++
	var/obj/structure/machinery/door/firedoor/shutter = locate() in next
	if(stuck_for == 1 && shutter?.density && !shutter.operating && !door_shut(next))
		INVOKE_ASYNC(shutter, TYPE_PROC_REF(/obj/structure/machinery/door, open), TRUE)
		return
	var/obj/structure/fence/gate = locate() in next
	if(stuck_for == 1 && fence_gate(gate))
		gate.attack_hand(body)
		return
	if(stuck_for == 1 && (locate(/mob/living) in next) && sidestep(here, next))
		return
	if(stuck_for < CLASH_BOT_STUCK_LIMIT)
		return
	stuck_for = 0
	path = null
	block_step(next)
	fail_goal(destination)
	if(destination == claimed)
		release_cover()
	destination = null
	next_cover_scan = 0

/datum/clash_bot/proc/get_activity()
	if(!GLOB.clash_bots_enabled)
		return "Paused"
	if(stranded_since)
		return "Bleeding out"
	if(charging)
		return "Charging"
	switch(state)
		if(CLASH_BOT_STATE_COMBAT)
			return "Fighting"
		if(CLASH_BOT_STATE_SEEK)
			return "Searching"
		if(CLASH_BOT_STATE_RETREAT)
			return "Falling back"
		if(CLASH_BOT_STATE_RECOVER)
			return "Restocking"
		if(CLASH_BOT_STATE_MEDIC)
			return "Treating"
		if(CLASH_BOT_STATE_CARRY)
			return "Carrying the flag"
		if(CLASH_BOT_STATE_DODGE)
			return "Dodging"
	return destination ? "Moving" : "Holding"

/datum/clash_bot/proc/watch_nearby_turfs()
	SIGNAL_HANDLER
	unwatch_turfs()
	for(var/turf/open/nearby in range(1, body))
		RegisterSignal(nearby, COMSIG_TURF_ENTERED, PROC_REF(on_bullet_near))
		watched_turfs += nearby

/datum/clash_bot/proc/unwatch_turfs()
	for(var/turf/watched as anything in watched_turfs)
		UnregisterSignal(watched, COMSIG_TURF_ENTERED)
	watched_turfs.Cut()

/datum/clash_bot/proc/has_ammo()
	return gun && (gun.in_chamber || gun.current_mag?.current_rounds > 0)

/datum/clash_bot/proc/start_volley(atom/aim, rounds)
	firing = TRUE
	if(prob(1))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, emote), "warcry")
	shots_left = rounds
	last_round_at = world.time
	aim_atom = aim
	fire_tick()

/datum/clash_bot/proc/fire_tick()
	if(!firing || !gun || body.get_active_hand() != gun)
		return
	if(QDELETED(aim_atom) || !has_ammo() || world.time - last_round_at > CLASH_BOT_VOLLEY_STALL)
		stop_volley()
		return
	if(ally_in_lane(aim_atom))
		if(!lane_blocked_since)
			lane_blocked_since = world.time
		return
	body.clash_aim_turf = get_turf(aim_atom)
	gun.Fire(aim_atom, body)

/datum/clash_bot/proc/stop_volley()
	if(!firing)
		return
	firing = FALSE
	aim_atom = null
	next_fire = world.time + (heavy ? rand(3, 6) : rand(5, 10))

/datum/clash_bot/proc/reload()
	if(QDELETED(body) || body.stat == DEAD)
		return
	stop_volley()
	var/obj/item/ammo_magazine/spare = find_magazine(gun)
	if(!spare)
		if(gun == primary)
			dry = TRUE
		return
	busy_until = world.time + 5 SECONDS
	if(gun.current_mag)
		gun.unload(body, TRUE, TRUE)
	gun.unwield(body)
	var/obj/item/storage/holder = spare.loc
	if(istype(holder))
		holder.remove_from_storage(spare, get_turf(body))
	body.put_in_hands(spare, FALSE)
	gun.replace_magazine(body, spare)
	if(gun.flags_item & TWOHANDED)
		gun.wield(body)
	busy_until = 0

/datum/clash_bot/proc/try_heal()
	if(world.time < next_heal || contact_recent() || firing || hands < 2 || carrying())
		return
	if(body.health >= body.maxHealth * CLASH_BOT_WOUNDED)
		return
	var/obj/item/medicine = find_medicine()
	if(!medicine)
		return
	next_heal = world.time + CLASH_BOT_HEAL_DELAY
	INVOKE_ASYNC(src, PROC_REF(heal_with), medicine, body)

/datum/clash_bot/proc/heal_with(obj/item/medicine, mob/living/carbon/human/patient)
	stop_volley()
	busy_until = world.time + 10 SECONDS
	gun?.unwield(body)
	var/obj/item/storage/holder = medicine.loc
	if(istype(holder))
		holder.remove_from_storage(medicine, get_turf(body))
	body.put_in_hands(medicine, FALSE)
	if(medicine.loc == body)
		medicine.attack(patient, body)
	busy_until = 0
	if(QDELETED(body) || body.stat == DEAD)
		return
	if(!QDELETED(medicine) && medicine.loc == body && !(istype(holder) && holder.can_be_inserted(medicine, body, TRUE) && holder.handle_item_insertion(medicine, TRUE, body)))
		body.drop_inv_item_to_loc(medicine, get_turf(body))
	if(gun?.flags_item & TWOHANDED)
		gun.wield(body)

/datum/clash_bot/proc/update_patient()
	if(medic_patient && !needs_medic(medic_patient))
		medic_patient = null
	if(!medic_patient && world.time >= next_patient_scan)
		next_patient_scan = world.time + CLASH_BOT_PATIENT_SCAN
		medic_patient = find_patient()

/datum/clash_bot/proc/treat_patient()
	if(!medic_patient || get_dist(body, medic_patient) > 1 || world.time < next_heal)
		return
	var/obj/item/tool = medic_tool(medic_patient)
	if(!tool)
		medic_patient = null
		return
	next_heal = world.time + CLASH_BOT_TREAT_DELAY
	INVOKE_ASYNC(src, PROC_REF(heal_with), tool, medic_patient)

/datum/clash_bot/proc/needs_medic(mob/living/carbon/human/patient)
	if(QDELETED(patient) || patient == body || patient.faction != body.faction || patient.z != body.z || get_dist(body, patient) > CLASH_BOT_MEDIC_RANGE)
		return FALSE
	if(patient.stat == DEAD)
		return patient.check_tod() && patient.is_revivable() && !!(locate(/obj/item/device/defibrillator) in body.get_contents())
	var/list/mark = GLOB.clash_medic_marks[patient]
	return (mark && mark["until"]) || patient.health < patient.maxHealth * CLASH_BOT_PATIENT_HEALTH || (!clash_is_bot(patient) && clash_has_internal_injuries(patient))

/datum/clash_bot/proc/find_patient()
	var/mob/living/carbon/human/best
	var/best_score
	for(var/mob/living/carbon/human/patient in range(CLASH_BOT_MEDIC_RANGE, body))
		if(!needs_medic(patient) || !can_enter(get_turf(patient)))
			continue
		var/score = get_dist(body, patient) + (patient.stat == DEAD ? 0 : (GLOB.clash_medic_marks[patient] ? 5 : 10))
		if(isnull(best_score) || score < best_score)
			best = patient
			best_score = score
	return best

/datum/clash_bot/proc/medic_tool(mob/living/carbon/human/patient)
	if(patient.stat == DEAD)
		return locate(/obj/item/device/defibrillator) in body.get_contents()
	if(!clash_is_bot(patient) && clash_has_internal_injuries(patient))
		for(var/obj/item/reagent_container/hypospray/autoinjector/clash_fixall/fixall in body.get_contents())
			if(fixall.uses_left > 0)
				return fixall
	return find_medicine()

/datum/clash_bot/proc/find_medicine()
	for(var/obj/item/reagent_container/hypospray/autoinjector/shot in body.get_contents())
		if(shot.uses_left > 0 && !istype(shot, /obj/item/reagent_container/hypospray/autoinjector/clash_fixall))
			return shot
	for(var/obj/item/stack/medical/dressing in body.get_contents())
		return dressing
	return null

/datum/clash_bot/proc/find_loose_magazine()
	var/obj/item/ammo_magazine/closest
	var/closest_distance = CLASH_BOT_SCAVENGE_RANGE + 1
	for(var/obj/item/ammo_magazine/spare in range(CLASH_BOT_SCAVENGE_RANGE, body))
		if(!magazine_fits(spare) || get_dist(body, spare) >= closest_distance || !can_enter(get_turf(spare)))
			continue
		closest = spare
		closest_distance = get_dist(body, spare)
	for(var/mob/living/carbon/human/corpse in range(CLASH_BOT_SCAVENGE_RANGE, body))
		if(corpse.stat != DEAD || get_dist(body, corpse) >= closest_distance || !can_enter(get_turf(corpse)))
			continue
		for(var/obj/item/ammo_magazine/spare in corpse.get_contents())
			if(!magazine_fits(spare) || istype(spare.loc, /obj/item/weapon/gun))
				continue
			closest = spare
			closest_distance = get_dist(body, corpse)
			break
	return closest

/datum/clash_bot/proc/magazine_fits(obj/item/ammo_magazine/spare)
	if(spare.current_rounds <= 0 || istype(spare, /obj/item/ammo_magazine/handful))
		return FALSE
	return primary && (istype(primary, spare.gun_type) || (spare.type in primary.accepted_ammo))

/datum/clash_bot/proc/grab_magazine(obj/item/ammo_magazine/spare)
	var/obj/item/storage/holder = spare.loc
	if(istype(holder))
		holder.remove_from_storage(spare, get_turf(body))
	else if(ishuman(spare.loc))
		var/mob/living/carbon/human/corpse = spare.loc
		corpse.drop_inv_item_to_loc(spare, get_turf(body), force = TRUE)
	body.put_in_hands(spare, FALSE)
	if(spare.loc != body)
		return
	track_clash_bot_gear(spare)
	dry = FALSE
	if(primary && gun == primary)
		INVOKE_ASYNC(src, PROC_REF(reload))

/datum/clash_bot/proc/rearm()
	if(!reachable(primary) && primary_type)
		primary = new primary_type(get_turf(body))
		track_clash_bot_gear(primary)
		set_firemode()
	top_up(primary_magazine, primary_spares)
	if(sidearm_type)
		if(!reachable(sidearm))
			sidearm = supply(sidearm_type)
		top_up(sidearm_magazine, sidearm_spares)
	if(grenade_type && !reachable(grenade))
		grenade = supply(grenade_type)
	dry = FALSE
	ready_gun(primary)
	if(primary && gun == primary && !loaded(primary))
		INVOKE_ASYNC(src, PROC_REF(reload))

/datum/clash_bot/proc/supply(item_type)
	var/obj/item/thing = new item_type(body)
	if(!body.equip_to_appropriate_slot(thing))
		qdel(thing)
		return null
	homes[thing] = thing.loc
	track_clash_bot_gear(thing)
	return thing

/datum/clash_bot/proc/top_up(magazine_type, wanted)
	if(!magazine_type)
		return
	for(var/obj/item/ammo_magazine/spare in body.get_contents())
		if(spare.type == magazine_type && spare.current_rounds > 0 && !istype(spare.loc, /obj/item/weapon/gun))
			wanted--
	for(var/count in 1 to wanted)
		var/obj/item/ammo_magazine/spare = new magazine_type(body)
		if(!body.equip_to_appropriate_slot(spare))
			qdel(spare)
			return
		track_clash_bot_gear(spare)

/datum/clash_bot/proc/find_magazine(obj/item/weapon/gun/weapon)
	for(var/obj/item/ammo_magazine/spare in body.get_contents())
		if(spare.current_rounds <= 0 || spare == weapon.current_mag)
			continue
		if(istype(weapon, spare.gun_type) || (spare.type in weapon.accepted_ammo))
			return spare
	return null

/datum/clash_bot/proc/claim_cover(turf/spot)
	release_cover()
	GLOB.clash_bot_cover_claims[spot] = src
	claimed = spot

/datum/clash_bot/proc/retire()
	var/mob/living/carbon/human/old_body = body
	var/obj/effect/landmark/clash_npc/old_post = post
	if(old_post?.bot == src)
		old_post.bot = null
	qdel(src)
	if(!QDELETED(old_body))
		qdel(old_body)
	if(old_post?.temporary)
		qdel(old_post)

/datum/clash_bot/proc/can_vanish()
	if(QDELETED(body) || body.stat == DEAD)
		return TRUE
	for(var/mob/viewer in viewers(world.view, body))
		if(viewer.client)
			return FALSE
	return TRUE

/datum/clash_bot/proc/get_state()
	. = get_activity()
	if(task)
		. += " ([task])"

/datum/clash_bot/proc/release_cover()
	if(claimed && GLOB.clash_bot_cover_claims[claimed] == src)
		GLOB.clash_bot_cover_claims -= claimed
	claimed = null

/datum/clash_bot/proc/spot_blocked(turf/spot)
	if(spot.density)
		return TRUE
	for(var/atom/movable/thing in spot)
		if(thing.density && !ismob(thing) && !istype(thing, /obj/structure/barricade))
			return TRUE
	return FALSE

/datum/clash_bot/proc/line_clear(turf/from, turf/into)
	for(var/turf/line_turf as anything in get_line(from, into, include_start_atom = FALSE))
		if(line_turf.density || line_turf.opacity)
			return FALSE
		for(var/obj/thing in line_turf)
			if(thing.opacity)
				return FALSE
	return TRUE

/datum/clash_bot/proc/cover_against(turf/spot, turf/enemy)
	var/facing = get_dir(spot, enemy)
	var/best = 0
	for(var/obj/structure/thing in spot)
		var/obj/structure/barricade/cade = thing
		if(!(thing.flags_atom & ON_BORDER) || !thing.density || !thing.throwpass || !(thing.dir & facing) || (istype(cade) && cade.closed))
			continue
		best = max(best, thing.projectile_coverage)
	for(var/obj/structure/thing in get_step(spot, facing))
		if(!(thing.flags_atom & ON_BORDER) && thing.density && thing.throwpass)
			best = max(best, thing.projectile_coverage * 0.7)
	return best / 5

/datum/clash_bot/proc/following()
	if(leader && (QDELETED(leader) || leader.stat == DEAD))
		leader = null
	if(!leader || leader == body)
		return FALSE
	var/inside = zone_allows(get_turf(leader))
	return !zone || !inside

/datum/clash_bot/proc/zone_allows(turf/spot)
	if(zone && QDELETED(zone))
		zone = null
	return !zone || zone.covered[spot]

/datum/clash_bot/proc/leash_centre()
	return following() ? get_turf(leader) : anchor

/datum/clash_bot/proc/leash_radius()
	return following() ? CLASH_BOT_FOLLOW_RANGE + 2 : hold_radius

/datum/clash_bot/proc/set_task(new_task, turf/goal, leash, key, mob/living/carbon/human/new_leader, datum/clash_zone/new_zone, turf/new_via, new_keep_off = 0)
	leader = new_leader
	if(task == new_task && (key ? task_key == key : anchor == goal))
		anchor = goal
		return
	task = new_task
	task_key = key
	anchor = goal
	hold_radius = leash
	zone = new_zone
	via = new_via
	keep_off = new_keep_off
	flag_goal = null
	chase = null
	wait_for = null
	wait_until = 0
	arrived_at = 0
	next_position = 0
	release_cover()
	destination = null
	path = null

/datum/clash_bot/proc/carrying()
	for(var/obj/item/clash_flag/flag in list(body.l_hand, body.r_hand))
		if(flag.faction != body.faction)
			return flag
	return null

/datum/clash_bot/proc/grab_flag(obj/item/clash_flag/flag)
	if(flag.faction == body.faction)
		flag.attack_hand(body)
		return
	stop_volley()
	gun?.unwield(body)
	body.swap_hand()
	if(!body.get_active_hand())
		flag.attack_hand(body)
	body.swap_hand()
	if(carrying())
		var/datum/clash_bot_director/director = clash_bot_director(body.faction)
		director.next_plan = 0

/datum/clash_bot/proc/grab_nearby_flag()
	var/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/mode = SSticker.mode
	if(!istype(mode) || !mode.match_live || carrying())
		return
	for(var/obj/item/clash_flag/flag in range(1, body))
		if(!isturf(flag.loc))
			continue
		if(flag.faction == body.faction ? flag.state == CLASH_FLAG_DROPPED : hands == 2 && !body.get_inactive_hand())
			grab_flag(flag)
			return

/datum/clash_bot/proc/follow_task()
	var/turf/here = get_turf(body)
	if(flag_goal)
		if(QDELETED(flag_goal) || !isturf(flag_goal.loc) || flag_goal.z != body.z)
			flag_goal = null
		else
			if(wait_for && (world.time > wait_until || QDELETED(wait_for) || wait_for.stat == DEAD || get_dist(wait_for, body) <= CLASH_BOT_FOLLOW_RANGE + 1))
				wait_for = null
			if(!via)
				if(wait_for)
					return
				if(get_dist(here, flag_goal) <= 1)
					grab_flag(flag_goal)
					flag_goal = null
					destination = null
				else if(destination != get_turf(flag_goal))
					release_cover()
					set_destination(get_turf(flag_goal))
				return
	if(chase)
		if(QDELETED(chase) || chase.stat == DEAD || chase.z != body.z)
			chase = null
		else
			if(!destination || get_dist(destination, chase) > 2)
				release_cover()
				set_destination(get_turf(chase))
			return
	if(following())
		if(get_dist(here, leader) > CLASH_BOT_FOLLOW_RANGE + 1 && (!destination || get_dist(destination, leader) > 2))
			release_cover()
			set_destination(get_turf(leader))
		return
	if(via)
		if(get_dist(here, via) <= 2)
			via = null
		else
			if(destination != via)
				release_cover()
				set_destination(via)
			return
	if(get_dist(here, anchor) > hold_radius)
		arrived_at = 0
		if(!destination || get_dist(destination, anchor) > hold_radius)
			release_cover()
			set_destination(pick_position() || anchor)
		return
	if(!arrived_at)
		arrived_at = world.time
	if(task == CLASH_BOT_TASK_PATROL && !destination && world.time - arrived_at > 6 SECONDS)
		var/datum/clash_bot_director/director = clash_bot_director(body.faction)
		set_task(CLASH_BOT_TASK_PATROL, director.next_patrol_goal(anchor), hold_radius)
		return
	if(world.time < next_position && !(in_base(here) && !in_base(anchor)))
		return
	next_position = world.time + (task == CLASH_BOT_TASK_DEFEND ? rand(22 SECONDS, 33 SECONDS) : rand(9 SECONDS, 17 SECONDS))
	var/turf/spot = pick_position()
	if(spot)
		claim_cover(spot)
		set_destination(spot)

/datum/clash_bot/proc/pick_position()
	var/datum/clash_bot_director/director = clash_bot_director(body.faction)
	var/turf/facing = director.enemy_base || anchor
	var/turf/best
	var/best_score
	var/avoid_base = !in_base(anchor)
	for(var/turf/open/spot in range(min(hold_radius, CLASH_BOT_POSITION_RANGE), anchor))
		if(!can_enter(spot) || spot_blocked(spot) || !zone_allows(spot) || goal_failed(spot) || (keep_off && get_dist(spot, anchor) < keep_off) || (avoid_base && in_base(spot)))
			continue
		var/datum/clash_bot/owner = GLOB.clash_bot_cover_claims[spot]
		if(owner && owner != src)
			continue
		var/score = cover_against(spot, facing) + rand(0, 3) - get_dist(spot, anchor) * 0.3
		if(spot == anchor)
			score -= 5
		for(var/mob/living/carbon/human/ally in range(1, spot))
			if(ally != body && ally.faction == body.faction && ally.stat != DEAD)
				score -= 4
		if(isnull(best_score) || score > best_score)
			best = spot
			best_score = score
	return best

/datum/clash_bot/proc/in_base(turf/spot)
	var/area/clash_arena/zone = get_area(spot)
	return istype(zone) && zone.clash_faction

/datum/clash_bot/proc/hear(turf/source)
	if(target || get_dist(body, source) > CLASH_BOT_HEARING)
		return
	heard_turf = source
	heard_at = world.time

/datum/clash_bot/proc/mark_danger(turf/center)
	if(!center)
		return
	var/until = world.time + CLASH_BOT_DANGER_TIME
	for(var/turf/spot as anything in RANGE_TURFS(1, center))
		danger[spot] = until
	if(length(danger) > 90)
		for(var/turf/spot as anything in danger.Copy())
			if(danger[spot] < world.time)
				danger -= spot

/datum/clash_bot/proc/danger_cost(turf/spot)
	var/until = danger[spot]
	return until && until > world.time ? CLASH_BOT_DANGER_COST : 0

/datum/clash_bot/proc/watch_grenades()
	var/obj/item/explosive/grenade/live
	for(var/obj/item/explosive/grenade/nade in range(2, body))
		if(nade.active && isturf(nade.loc))
			live = nade
			break
	if(!live)
		dodge_seen = 0
		return
	if(!dodge_seen)
		dodge_seen = world.time
	if(world.time - dodge_seen < CLASH_BOT_DODGE_DELAY || world.time < dodge_until || HAS_TRAIT(body, TRAIT_FLOORED))
		return
	var/turf/away
	var/farthest = 0
	for(var/turf/open/spot in range(4, body))
		var/distance = get_dist(spot, live)
		if(distance > farthest && can_enter(spot) && !spot_blocked(spot))
			away = spot
			farthest = distance
	if(!away)
		return
	dodge_until = world.time + CLASH_BOT_DODGE_TIME
	release_cover()
	set_destination(away)
	next_step = 0

/datum/clash_bot/proc/resupply()
	var/obj/item/ammo_magazine/spare = find_loose_magazine()
	if(spare)
		if(get_dist(body, spare) <= 1)
			grab_magazine(spare)
			destination = null
		else
			set_destination(get_turf(spare))
		return
	var/turf/depot = home || get_turf(post)
	if(!depot)
		return
	if(get_dist(body, depot) <= 1)
		rearm()
		destination = null
		return
	set_destination(depot)

#undef CLASH_BOT_TICK
#undef CLASH_BOT_THINK
#undef CLASH_BOT_SIGHT
#undef CLASH_BOT_ACCURACY
#undef CLASH_BOT_RELOAD_DELAY
#undef CLASH_BOT_COVER_RESCAN
#undef CLASH_BOT_REPATH_DELAY
#undef CLASH_BOT_PATHS_PER_TICK
#undef CLASH_BOT_MEMORY
#undef CLASH_BOT_WOUNDED
#undef CLASH_BOT_RETREAT_HEALTH
#undef CLASH_BOT_STUCK_LIMIT
#undef CLASH_BOT_SEARCH_DELAY
#undef CLASH_BOT_HEAL_DELAY
#undef CLASH_BOT_SCAVENGE_RANGE
#undef CLASH_BOT_CLOSE_RANGE
#undef CLASH_BOT_HEARING
#undef CLASH_BOT_DANGER_TIME
#undef CLASH_BOT_DANGER_COST
#undef CLASH_BOT_DODGE_DELAY
#undef CLASH_BOT_DODGE_TIME
#undef CLASH_BOT_SETTLE_TIME
#undef CLASH_BOT_SUPPRESSED
#undef CLASH_BOT_FOLLOW_RANGE
#undef CLASH_BOT_POSITION_RANGE
#undef CLASH_BOT_PRIORITY_BONUS
#undef CLASH_BOT_CARRIER_BONUS
#undef CLASH_BOT_MEDIC_RANGE
#undef CLASH_BOT_PATIENT_HEALTH
#undef CLASH_BOT_PATIENT_SCAN
#undef CLASH_BOT_TREAT_DELAY
#undef CLASH_BOT_LANE_CLOSE
#undef CLASH_BOT_LANE_NEAR
#undef CLASH_BOT_LANE_FAR
#undef CLASH_BOT_VOLLEY_STALL
#undef CLASH_BOT_COMMIT
#undef CLASH_BOT_RETREAT_TIME
#undef CLASH_BOT_RETREAT_COOLDOWN
#undef CLASH_BOT_RETREAT_RANGE
#undef CLASH_BOT_SEEK_TIME
#undef CLASH_BOT_SEEK_SLACK
#undef CLASH_BOT_COMBAT_STEP
#undef CLASH_BOT_COMBAT_SLACK
#undef CLASH_BOT_COMBAT_RESCAN
#undef CLASH_BOT_BRACE_RETRY
#undef CLASH_BOT_LANE_PATIENCE
#undef CLASH_BOT_FAILED_GOAL_TIME
#undef CLASH_BOT_BLOCKED_STEP_TIME
#undef CLASH_BOT_STATE_OBJECTIVE
#undef CLASH_BOT_STATE_COMBAT
#undef CLASH_BOT_STATE_SEEK
#undef CLASH_BOT_STATE_RETREAT
#undef CLASH_BOT_STATE_RECOVER
#undef CLASH_BOT_STATE_MEDIC
#undef CLASH_BOT_STATE_CARRY
#undef CLASH_BOT_STATE_DODGE

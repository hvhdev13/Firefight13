#define CLASH_BOT_FILL_INTERVAL (10 SECONDS)
#define CLASH_BOT_CORPSE_TIME (90 SECONDS)
#define CLASH_BOT_LITTER_TIME (30 SECONDS)
#define CLASH_BOT_LITTER_SWEEP (5 SECONDS)
#define CLASH_BOT_BLIP_DELAY 5
#define CLASH_BOT_PLAN_DELAY (5 SECONDS)
#define CLASH_BOT_CLASS_MIN 3
#define CLASH_BOT_CLASS_SHARE 5
#define CLASH_BOT_HEAVY_PREFERENCE 10
#define CLASH_BOT_FLANK_DISTANCE 6
#define CLASH_BOT_OVERWATCH_RANGE 6
#define CLASH_BOT_OVERWATCH_LEASH 2
#define CLASH_BOT_STAND_KEEP_OFF 3
#define CLASH_BOT_STAND_GUARD 8
#define CLASH_BOT_STAND_WAIT 4
#define CLASH_BOT_ESCORTS 2
#define CLASH_BOT_INTERCEPTORS 2
#define CLASH_BOT_RUNNER_WAIT (5 SECONDS)
#define CLASH_BOT_FOLLOW_RANGE 3
#define CLASH_BOT_PUSH_SHARE 0.45
#define CLASH_BOT_PATROL_SHARE 0.6
#define CLASH_BOT_PATROL_BEHIND 0.75
#define CLASH_BOT_DEFEND_LEASH 6
#define CLASH_BOT_PATROL_LEASH 4
#define CLASH_BOT_OBJECTIVE_LEASH 5
#define CLASH_BOT_BLIP_COLOR list(0.19, 0.29, 0.42, 0.37, 0.58, 0.83, 0.07, 0.11, 0.15, 0.05, 0.1, 0.25)

GLOBAL_LIST_EMPTY(clash_npc_spawners)
GLOBAL_LIST_EMPTY(clash_bot_rallies)
GLOBAL_VAR(clash_bot_fill_timer)
GLOBAL_LIST_EMPTY(clash_bot_gear)
GLOBAL_VAR(clash_bot_litter_timer)
GLOBAL_LIST_INIT(clash_bot_caps, list(FACTION_MARINE = 10, FACTION_UPP = 10, FACTION_CLF = 10))
GLOBAL_LIST_INIT(clash_bot_fill_targets, list(FACTION_MARINE = 5, FACTION_UPP = 5, FACTION_CLF = 0))
GLOBAL_LIST_EMPTY(clash_bot_sides_off)
GLOBAL_VAR(clash_bot_respawn_delay)
GLOBAL_LIST_EMPTY(clash_bot_directors)
GLOBAL_LIST_INIT(clash_bot_class_jobs, list(
	FACTION_MARINE = list(JOB_SQUAD_MARINE, JOB_SQUAD_SMARTGUN, JOB_SQUAD_MEDIC),
	FACTION_UPP = list(JOB_UPP, JOB_UPP_SPECIALIST, JOB_UPP_MEDIC),
))

/obj/effect/landmark/clash_bot_rally
	name = "Clash bot rally point"
	var/rally_id = "center"
	var/faction

/obj/effect/landmark/clash_bot_rally/uscm
	name = "TDM bot rally (USCM)"
	icon_state = "x3"
	color = "#4a8cff"
	rally_id = null
	faction = FACTION_MARINE

/obj/effect/landmark/clash_bot_rally/upp
	name = "TDM bot rally (UPP)"
	icon_state = "x3"
	color = "#ff4a4a"
	rally_id = null
	faction = FACTION_UPP

/obj/effect/landmark/clash_bot_rally/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_bot_rallies += src

/obj/effect/landmark/clash_bot_rally/Destroy()
	GLOB.clash_bot_rallies -= src
	return ..()

/obj/effect/landmark/clash_npc
	name = "Clash NPC spawner"
	icon_state = "late_join_misc"
	var/faction = FACTION_MARINE
	var/job
	var/equipment_preset
	var/bot_gun
	var/bot_magazine
	var/bot_magazines = 4
	var/bot_firemode
	var/bot_grenade = /obj/item/explosive/grenade/high_explosive
	var/bot_medical = /obj/item/storage/pouch/firstaid/clash
	var/respawn_delay
	var/hold_radius = 6
	var/rally_id
	var/team_fill = FALSE
	var/fill_limit
	var/spawn_in_base = TRUE
	var/active = TRUE
	var/temporary = FALSE
	var/extra = FALSE
	var/spawning = FALSE
	var/datum/clash_bot/bot

/obj/effect/landmark/clash_npc/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_npc_spawners += src
	if(team_fill)
		active = FALSE
	RegisterSignal(SSdcs, COMSIG_GLOB_POST_SETUP, PROC_REF(on_post_setup))

/obj/effect/landmark/clash_npc/Destroy()
	GLOB.clash_npc_spawners -= src
	QDEL_NULL(bot)
	return ..()

/obj/effect/landmark/clash_npc/proc/on_post_setup()
	SIGNAL_HANDLER
	if(team_fill && !GLOB.clash_bot_fill_timer)
		clash_bot_apply_fill_limits()
		GLOB.clash_bot_fill_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_bot_fill)), CLASH_BOT_FILL_INTERVAL, TIMER_LOOP|TIMER_STOPPABLE)
	if(active)
		INVOKE_ASYNC(src, PROC_REF(spawn_npc))

/obj/effect/landmark/clash_npc/proc/get_respawn_delay()
	if(!isnull(GLOB.clash_bot_respawn_delay))
		return GLOB.clash_bot_respawn_delay
	if(!isnull(respawn_delay))
		return respawn_delay
	return clash_respawn_cooldown()

/obj/effect/landmark/clash_npc/proc/get_hold_turf()
	if(!rally_id && length(GLOB.clash_objective_turfs))
		var/turf/best_objective
		var/fewest
		for(var/turf/objective as anything in GLOB.clash_objective_turfs)
			if(objective.z != z)
				continue
			var/held = rand(0, 1)
			for(var/datum/clash_bot/other as anything in GLOB.clash_bots)
				if(other.anchor == objective && other.body?.faction == faction)
					held += 2
			if(isnull(fewest) || held < fewest)
				best_objective = objective
				fewest = held
		if(best_objective)
			return best_objective
	var/turf/best = get_turf(src)
	var/best_count
	for(var/obj/effect/landmark/clash_bot_rally/rally as anything in GLOB.clash_bot_rallies)
		if(rally.z != z || (rally_id ? rally.rally_id != rally_id : rally.faction != faction))
			continue
		var/turf/rally_turf = get_turf(rally)
		var/count = rand(0, 1)
		for(var/datum/clash_bot/other as anything in GLOB.clash_bots)
			if(other.anchor == rally_turf)
				count += 2
		if(isnull(best_count) || count < best_count)
			best = rally_turf
			best_count = count
	return best

/obj/effect/landmark/clash_npc/proc/spawn_npc()
	if(bot || spawning || !active)
		return
	if(!GLOB.clash_bots_enabled || (faction in GLOB.clash_bot_sides_off) || clash_bot_count(faction) >= GLOB.clash_bot_caps[faction])
		if(temporary)
			qdel(src)
			return
		addtimer(CALLBACK(src, PROC_REF(spawn_npc)), get_respawn_delay() || 30 SECONDS, TIMER_UNIQUE)
		return
	spawning = TRUE
	var/turf/home = (spawn_in_base && clash_bot_base_turf(faction)) || get_turf(src)
	var/mob/living/carbon/human/npc = new(home)
	dress_npc(npc, (team_fill && clash_bot_pick_job(faction)) || job)
	npc.statistic_exempt = TRUE
	npc.a_intent = INTENT_HARM
	if(clash_fed_spawns())
		npc.nutrition = NUTRITION_NORMAL
	npc.AddElement(/datum/element/clash_hit_flinch)
	npc.AddElement(/datum/element/clash_combat_log)
	npc.AddElement(/datum/element/clash_suppression)
	if(faction in list(FACTION_MARINE, FACTION_UPP))
		npc.AddElement(/datum/element/clash_iff)
	npc.setDir(dir)
	npc.real_name = "[npc.real_name] \[BOT\]"
	npc.name = npc.real_name
	for(var/obj/item/gear in npc.get_contents())
		track_clash_bot_gear(gear)
	bot = new(npc, src)
	bot.home = home
	spawning = FALSE
	RegisterSignal(npc, list(COMSIG_MOB_DEATH, COMSIG_MOB_STAT_SET_ALIVE, COMSIG_HUMAN_SET_UNDEFIBBABLE, COMSIG_HUMAN_SQUAD_CHANGED), PROC_REF(queue_blip_tint))
	queue_blip_tint(npc)

/obj/effect/landmark/clash_npc/proc/dress_npc(mob/living/carbon/human/npc, spawn_job)
	var/datum/job/role = spawn_job && GLOB.RoleAuthority.roles_by_name[spawn_job]
	if(!role?.gear_preset)
		arm_equipment(npc, equipment_preset, TRUE, FALSE)
		for(var/obj/item/unwanted in npc.get_contents())
			if(istype(unwanted, /obj/item/weapon/gun) || istype(unwanted, /obj/item/ammo_magazine/handful))
				qdel(unwanted)
		npc.put_in_hands(new bot_gun(npc), FALSE)
		for(var/count in 1 to bot_magazines)
			npc.equip_to_appropriate_slot(new bot_magazine(npc))
	else
		arm_equipment(npc, role.gear_preset, TRUE, FALSE)
		npc.job = spawn_job
		if(clash_uses_kits())
			build_clash_kit_catalog()
			issue_clash_role_kit(npc, spawn_job)
			apply_clash_kit(npc, new /datum/clash_kit, CLASH_KIT_SPAWN, spawn_job)
			clash_issue_medic_gear(npc)
	if(bot_grenade && !(locate(/obj/item/explosive/grenade) in npc.get_contents()))
		npc.equip_to_appropriate_slot(new bot_grenade(npc))
	if(bot_medical && !(locate(/obj/item/reagent_container/hypospray/autoinjector) in npc.get_contents()))
		npc.equip_to_appropriate_slot(new bot_medical(npc))

/obj/effect/landmark/clash_npc/proc/stand_down()
	active = FALSE
	bot?.retire()
	if(extra && !QDELETED(src))
		qdel(src)

/obj/effect/landmark/clash_npc/proc/queue_blip_tint(mob/living/carbon/human/body)
	SIGNAL_HANDLER
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(tint_clash_bot_blip), WEAKREF(body)), CLASH_BOT_BLIP_DELAY)

/proc/tint_clash_bot_blip(datum/weakref/body_ref)
	var/mob/living/carbon/human/body = body_ref?.resolve()
	var/image/blip = body && SSminimaps.images_by_source[body]
	if(blip)
		blip.color = CLASH_BOT_BLIP_COLOR

/obj/effect/landmark/clash_npc/proc/bot_died(mob/living/carbon/human/body)
	bot = null
	if(body)
		clash_award_bot_kill(body)
		var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
		if(istype(clash_mode))
			clash_mode.score_bot_death(body)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clear_clash_bot_corpse), WEAKREF(body)), CLASH_BOT_CORPSE_TIME)
	if(temporary)
		qdel(src)
		return
	var/delay = get_respawn_delay()
	if(delay && active)
		addtimer(CALLBACK(src, PROC_REF(spawn_npc)), delay)

/proc/clash_bot_refill()
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(spawner.active && !spawner.bot)
			INVOKE_ASYNC(spawner, TYPE_PROC_REF(/obj/effect/landmark/clash_npc, spawn_npc))

/proc/clear_clash_bot_corpse(datum/weakref/body_ref)
	var/mob/living/carbon/human/body = body_ref?.resolve()
	if(body && !body.client && body.stat == DEAD)
		qdel(body)

/proc/clash_track_player_corpse(mob/living/carbon/human/body)
	for(var/obj/item/gear in body.get_contents())
		track_clash_bot_gear(gear)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clear_clash_bot_corpse), WEAKREF(body)), CLASH_BOT_CORPSE_TIME)

/proc/track_clash_bot_gear(obj/item/gear)
	GLOB.clash_bot_gear[WEAKREF(gear)] = 0
	if(!GLOB.clash_bot_litter_timer)
		GLOB.clash_bot_litter_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(sweep_clash_bot_litter)), CLASH_BOT_LITTER_SWEEP, TIMER_LOOP|TIMER_STOPPABLE)

/proc/sweep_clash_bot_litter()
	for(var/datum/weakref/gear_ref as anything in GLOB.clash_bot_gear.Copy())
		var/obj/item/gear = gear_ref.resolve()
		if(!gear)
			GLOB.clash_bot_gear -= gear_ref
			continue
		if(!isturf(gear.loc))
			var/atom/holder = gear.loc
			while(holder && !ismob(holder) && !isturf(holder))
				holder = holder.loc
			var/mob/owner = holder
			if(ismob(owner) && owner.mind)
				GLOB.clash_bot_gear -= gear_ref
			else
				GLOB.clash_bot_gear[gear_ref] = 0
			continue
		if(!GLOB.clash_bot_gear[gear_ref])
			GLOB.clash_bot_gear[gear_ref] = world.time
		else if(world.time - GLOB.clash_bot_gear[gear_ref] >= CLASH_BOT_LITTER_TIME)
			GLOB.clash_bot_gear -= gear_ref
			qdel(gear)
	if(!length(GLOB.clash_bot_gear))
		deltimer(GLOB.clash_bot_litter_timer)
		GLOB.clash_bot_litter_timer = null

/proc/clash_bot_count(faction)
	. = 0
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.body?.faction == faction)
			.++

/proc/clash_player_count(faction)
	. = 0
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/fighter = player.mob
		if(!ishuman(fighter))
			fighter = player.mob?.mind?.original
		if(ishuman(fighter) && fighter.faction == faction)
			.++

/proc/clash_bot_director(faction)
	var/datum/clash_bot_director/director = GLOB.clash_bot_directors[faction]
	if(!director)
		director = new(faction)
		GLOB.clash_bot_directors[faction] = director
	return director

/proc/clash_bot_replan()
	for(var/faction in GLOB.clash_bot_directors)
		var/datum/clash_bot_director/director = GLOB.clash_bot_directors[faction]
		director.next_plan = 0

/proc/clash_bots_hear(mob/living/carbon/human/shooter)
	var/turf/source = get_turf(shooter)
	if(!source)
		return
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.body && bot.body.faction != shooter.faction && bot.body.z == source.z)
			bot.hear(source)

/datum/clash_bot_director
	var/faction
	var/next_plan = 0
	var/mapped = FALSE
	var/turf/enemy_base
	var/turf/own_base
	var/datum/clash_zone/watch_zone
	var/list/watch_spots = list()
	var/list/fronts = list()
	var/list/pushes = list()

/datum/clash_bot_director/New(new_faction)
	faction = new_faction

/datum/clash_bot_director/proc/get_bots()
	. = list()
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.body?.faction == faction && bot.body.stat == CONSCIOUS && !bot.post?.rally_id)
			. += bot

/datum/clash_bot_director/proc/plan()
	next_plan = world.time + CLASH_BOT_PLAN_DELAY
	learn_map()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		clash_mode.plan_bots(src)
	else
		plan_skirmish()

/datum/clash_bot_director/proc/learn_map()
	if(mapped)
		return
	mapped = TRUE
	var/z = get_clash_ground_z()
	if(!z)
		return
	var/list/centres = get_clash_base_centres(z)
	var/list/own_centre = centres[faction]
	var/list/enemy_centre = centres[faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE]
	for(var/list/spot as anything in get_clash_auto_objective_spots(3, 2))
		fronts += spot[2]
	if(!own_centre || !enemy_centre)
		return
	enemy_base = locate(round(enemy_centre[1]), round(enemy_centre[2]), z)
	own_base = locate(round(own_centre[1]), round(own_centre[2]), z)
	for(var/turf/front as anything in fronts)
		var/turf/push = get_clash_open_turf_near(front.x + (enemy_centre[1] - front.x) * CLASH_BOT_PUSH_SHARE, front.y + (enemy_centre[2] - front.y) * CLASH_BOT_PUSH_SHARE, z)
		if(push)
			pushes |= push

/datum/clash_bot_director/proc/next_patrol_goal(turf/current)
	var/list/options = (prob(60) && length(pushes) ? pushes : fronts) - current
	if(!length(options))
		options = (pushes + fronts) - current
	return length(options) ? pick(options) : current

/datum/clash_bot_director/proc/hold_posts(list/bots)
	for(var/datum/clash_bot/bot as anything in bots)
		bot.set_task(CLASH_BOT_TASK_DEFEND, bot.post ? bot.post.get_hold_turf() : bot.anchor, bot.post?.hold_radius || 6)

/datum/clash_bot_director/proc/enemy_faction()
	return faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE

/datum/clash_bot_director/proc/is_behind()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.get_match_score(faction) < clash_mode.get_match_score(enemy_faction())

/datum/clash_bot_director/proc/is_ahead()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.get_match_score(faction) > clash_mode.get_match_score(enemy_faction())

/datum/clash_bot_director/proc/take_bot(list/free, task, key, turf/near, heavy_first)
	var/datum/clash_bot/best
	for(var/datum/clash_bot/bot as anything in free)
		if(bot.task == task && bot.task_key == key)
			best = bot
			break
	if(!best && key)
		for(var/datum/clash_bot/bot as anything in free)
			if(bot.task_key == key)
				best = bot
				break
	if(!best)
		var/closest
		for(var/datum/clash_bot/bot as anything in free)
			var/distance = (near ? get_dist(bot.body, near) : 0) - (heavy_first && bot.heavy ? CLASH_BOT_HEAVY_PREFERENCE : 0)
			if(isnull(closest) || distance < closest)
				best = bot
				closest = distance
	free -= best
	return best

/datum/clash_bot_director/proc/flank_turf(turf/target, side)
	if(!own_base || !target)
		return null
	var/span_x = target.x - own_base.x
	var/span_y = target.y - own_base.y
	var/span = max(1, sqrt(span_x ** 2 + span_y ** 2))
	var/back = min(CLASH_BOT_FLANK_DISTANCE, span / 2)
	return get_clash_open_turf_near(target.x - span_x / span * back - span_y / span * CLASH_BOT_FLANK_DISTANCE * side, target.y - span_y / span * back + span_x / span * CLASH_BOT_FLANK_DISTANCE * side, target.z)

/datum/clash_bot_director/proc/overwatch_spots(datum/clash_zone/zone)
	. = list()
	var/turf/centre = zone.hold
	var/list/candidates = list()
	for(var/turf/open/spot in range(CLASH_BOT_OVERWATCH_RANGE + 1, centre))
		var/distance = get_dist(spot, centre)
		if(distance < CLASH_BOT_OVERWATCH_RANGE - 1 || zone.covered[spot] || !clash_turf_passable(spot) || clash_in_base(spot))
			continue
		if(own_base && get_dist(spot, own_base) > get_dist(centre, own_base))
			continue
		var/blocked = FALSE
		for(var/turf/line_turf as anything in get_line(spot, centre))
			if(line_turf.opacity || line_turf.density)
				blocked = TRUE
				break
		if(!blocked)
			candidates += spot
	while(length(candidates) && length(.) < 2)
		var/turf/pick = pick_n_take(candidates)
		var/spaced = TRUE
		for(var/turf/other as anything in .)
			if(get_dist(other, pick) < 4)
				spaced = FALSE
		if(spaced)
			. += pick

/datum/clash_bot_director/proc/plan_skirmish()
	var/list/bots = get_bots()
	if(!length(bots))
		return
	if(!length(fronts))
		hold_posts(bots)
		return
	var/wanted = round(length(bots) * (is_behind() ? CLASH_BOT_PATROL_BEHIND : CLASH_BOT_PATROL_SHARE) + 0.5)
	var/list/patrol = list()
	var/list/defend = list()
	for(var/datum/clash_bot/bot as anything in bots)
		if(bot.task == CLASH_BOT_TASK_PATROL && !bot.heavy && length(patrol) < wanted)
			patrol += bot
	for(var/datum/clash_bot/bot as anything in bots - patrol)
		if(length(patrol) < wanted && bot.task != CLASH_BOT_TASK_DEFEND && !bot.heavy)
			patrol += bot
		else
			defend += bot
	for(var/datum/clash_bot/bot as anything in defend.Copy())
		if(length(patrol) >= wanted)
			break
		if(!bot.heavy)
			defend -= bot
			patrol += bot
	spread_defenders(defend, fronts, CLASH_BOT_DEFEND_LEASH)
	pair_patrols(patrol)

/datum/clash_bot_director/proc/spread_defenders(list/bots, list/spots, leash)
	var/list/load = list()
	for(var/turf/spot as anything in spots)
		load[spot] = 0
	var/list/loose = list()
	for(var/datum/clash_bot/bot as anything in bots)
		if(bot.task == CLASH_BOT_TASK_DEFEND && !isnull(load[bot.anchor]))
			load[bot.anchor]++
		else
			loose += bot
	for(var/datum/clash_bot/bot as anything in loose)
		var/turf/least
		for(var/turf/spot as anything in load)
			if(!least || load[spot] < load[least])
				least = spot
		load[least]++
		bot.set_task(CLASH_BOT_TASK_DEFEND, least, leash)

/datum/clash_bot_director/proc/pair_patrols(list/bots)
	var/list/leads = list()
	var/list/paired = list()
	var/list/loose = list()
	for(var/datum/clash_bot/bot as anything in bots)
		if(bot.task == CLASH_BOT_TASK_PATROL && !bot.leader)
			leads += bot
	for(var/datum/clash_bot/bot as anything in bots - leads)
		var/datum/clash_bot/lead
		if(bot.task == CLASH_BOT_TASK_PATROL)
			for(var/datum/clash_bot/other as anything in leads)
				if(other.body == bot.leader && !paired[other])
					lead = other
					break
		if(lead)
			paired[lead] = bot
		else
			loose += bot
	for(var/datum/clash_bot/bot as anything in loose)
		var/datum/clash_bot/lone
		for(var/datum/clash_bot/lead as anything in leads)
			if(!paired[lead])
				lone = lead
				break
		if(lone)
			paired[lone] = bot
			bot.set_task(CLASH_BOT_TASK_PATROL, lone.anchor, CLASH_BOT_PATROL_LEASH, null, lone.body)
		else
			leads += bot
			bot.set_task(CLASH_BOT_TASK_PATROL, next_patrol_goal(null), CLASH_BOT_PATROL_LEASH)

/datum/clash_bot_director/proc/attack_zone(list/bots, datum/clash_zone/zone)
	var/datum/clash_bot/lead
	var/followers = 0
	var/side = 1
	for(var/datum/clash_bot/bot as anything in bots)
		if(!lead || followers >= 2)
			lead = bot
			followers = 0
			bot.set_task(CLASH_BOT_TASK_ATTACK, zone.hold, zone.radius, zone, null, zone, flank_turf(zone.hold, side))
			side = -side
			continue
		followers++
		bot.set_task(CLASH_BOT_TASK_ATTACK, zone.hold, zone.radius, zone, lead.body, zone)

/datum/clash_bot_director/proc/plan_koth(datum/clash_zone/hill, datum/clash_zone/next_hill, moving_soon)
	var/list/free = get_bots()
	if(!length(free))
		return
	var/datum/clash_zone/goal = next_hill && moving_soon ? next_hill : hill
	var/watchers = length(free) >= 6 ? 2 : (length(free) >= 3 ? 1 : 0)
	if(watch_zone != goal || QDELETED(watch_zone))
		watch_zone = goal
		watch_spots = overwatch_spots(goal)
	var/list/spots = watch_spots
	for(var/index in 1 to min(watchers, length(spots)))
		var/turf/spot = spots[index]
		var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_DEFEND, spot, spot, TRUE)
		bot.set_task(CLASH_BOT_TASK_DEFEND, spot, CLASH_BOT_OVERWATCH_LEASH, spot)
	if(next_hill && !moving_soon && length(free) > 2)
		var/list/early = list()
		for(var/count in 1 to round(length(free) / 2))
			early += take_bot(free, CLASH_BOT_TASK_ATTACK, next_hill, next_hill.hold)
		attack_zone(early, next_hill)
	if(goal.owner == faction)
		for(var/datum/clash_bot/bot as anything in free)
			bot.set_task(CLASH_BOT_TASK_DEFEND, goal.hold, goal.radius, goal, null, goal)
		return
	attack_zone(free, goal)

/datum/clash_bot_director/proc/plan_domination(list/zones)
	var/list/free = get_bots()
	if(!length(free))
		return
	var/enemy = enemy_faction()
	for(var/datum/clash_zone/zone as anything in zones)
		if(zone.owner != faction)
			continue
		var/wanted = zone.contested || zone.capturing == enemy ? 2 : 1
		for(var/count in 1 to min(wanted, length(free)))
			var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_DEFEND, zone, zone.hold, TRUE)
			bot.set_task(CLASH_BOT_TASK_DEFEND, zone.hold, zone.radius, zone, null, zone)
	if(!length(free))
		return
	var/list/targets = list()
	for(var/datum/clash_zone/zone as anything in zones)
		if(zone.owner != faction)
			targets += zone
	if(!length(targets))
		var/list/held = list()
		for(var/datum/clash_zone/zone as anything in zones)
			held += zone.hold
		spread_defenders(free, held, CLASH_BOT_OBJECTIVE_LEASH)
		return
	var/list/sorted = list()
	while(length(targets))
		var/datum/clash_zone/best
		for(var/datum/clash_zone/zone as anything in targets)
			if(!best || zone_priority(zone) < zone_priority(best))
				best = zone
		targets -= best
		sorted += best
	targets = sorted
	if(is_ahead() && length(targets) > 1)
		targets.len--
	var/groups = clamp(round(length(free) / 3), 1, length(targets))
	var/list/assigned = list()
	for(var/index in 1 to groups)
		assigned += list(list())
	for(var/datum/clash_bot/bot as anything in free)
		var/slot = 0
		for(var/index in 1 to groups)
			if(bot.task_key == targets[index])
				slot = index
		if(!slot)
			slot = 1
			for(var/index in 2 to groups)
				var/list/candidate = assigned[index]
				var/list/current = assigned[slot]
				if(length(candidate) < length(current))
					slot = index
		var/list/group = assigned[slot]
		group += bot
	for(var/index in 1 to groups)
		attack_zone(assigned[index], targets[index])

/datum/clash_bot_director/proc/zone_priority(datum/clash_zone/zone)
	return (zone.owner ? 10 : 0) + (own_base ? get_dist(zone.hold, own_base) : 0)

/datum/clash_bot_director/proc/plan_ctf(list/stands, list/flags)
	var/list/free = get_bots()
	if(!length(free))
		return
	var/enemy = enemy_faction()
	var/turf/own_stand = stands[faction]
	var/turf/enemy_stand = stands[enemy]
	if(!own_stand || !enemy_stand)
		plan_skirmish()
		return
	var/obj/item/clash_flag/own_flag = flags[faction]
	var/obj/item/clash_flag/enemy_flag = flags[enemy]
	var/mob/living/carbon/human/carrier = enemy_flag?.carrier
	if(carrier)
		for(var/datum/clash_bot/bot as anything in free)
			if(bot.body == carrier)
				free -= bot
				var/home_free = own_flag?.state == CLASH_FLAG_HOME
				bot.set_task(CLASH_BOT_TASK_RUN, own_stand, home_free ? 0 : CLASH_BOT_STAND_WAIT, home_free ? "home" : "wait")
				break
		for(var/count in 1 to min(CLASH_BOT_ESCORTS, length(free)))
			var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_ESCORT, carrier, get_turf(carrier))
			bot.set_task(CLASH_BOT_TASK_ESCORT, get_turf(carrier), CLASH_BOT_FOLLOW_RANGE, carrier, carrier)
	for(var/obj/item/clash_flag/flag as anything in list(enemy_flag, own_flag))
		if(QDELETED(flag) || flag.state != CLASH_FLAG_DROPPED || !length(free))
			continue
		var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_RECOVER, flag, get_turf(flag))
		bot.set_task(CLASH_BOT_TASK_RECOVER, get_turf(flag), 1, flag)
		bot.flag_goal = flag
	if(own_flag?.carrier)
		for(var/count in 1 to min(CLASH_BOT_INTERCEPTORS, length(free)))
			var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_INTERCEPT, own_flag.carrier, get_turf(own_flag.carrier))
			bot.set_task(CLASH_BOT_TASK_INTERCEPT, get_turf(own_flag.carrier), CLASH_BOT_FOLLOW_RANGE, own_flag.carrier)
			bot.chase = own_flag.carrier
	var/defenders = length(get_bots()) >= 5 ? 2 : 1
	for(var/count in 1 to min(defenders, length(free)))
		var/datum/clash_bot/bot = take_bot(free, CLASH_BOT_TASK_DEFEND, own_stand, own_stand, TRUE)
		bot.set_task(CLASH_BOT_TASK_DEFEND, own_stand, CLASH_BOT_STAND_GUARD, own_stand, null, null, null, CLASH_BOT_STAND_KEEP_OFF)
	if(!length(free))
		return
	if(enemy_flag?.state != CLASH_FLAG_HOME)
		if(length(fronts))
			pair_patrols(free)
		else
			hold_posts(free)
		return
	var/datum/clash_bot/runner = take_bot(free, CLASH_BOT_TASK_ATTACK, enemy_flag, enemy_stand)
	var/side = prob(50) ? 1 : -1
	if(runner.task != CLASH_BOT_TASK_ATTACK || runner.task_key != enemy_flag)
		runner.set_task(CLASH_BOT_TASK_ATTACK, enemy_stand, CLASH_BOT_FOLLOW_RANGE, enemy_flag, null, null, flank_turf(enemy_stand, side))
	runner.flag_goal = enemy_flag
	for(var/datum/clash_bot/bot as anything in free)
		bot.set_task(CLASH_BOT_TASK_ESCORT, get_turf(runner.body), CLASH_BOT_FOLLOW_RANGE, runner.body, runner.body)
	if(length(free) && !runner.wait_for && runner.via)
		var/datum/clash_bot/first = free[1]
		runner.wait_for = first.body
		runner.wait_until = world.time + CLASH_BOT_RUNNER_WAIT

/datum/clash_bot_director/proc/plan_objectives(list/spots)
	if(!length(spots))
		plan_skirmish()
		return
	var/list/bots = get_bots()
	if(length(bots))
		spread_defenders(bots, spots, CLASH_BOT_OBJECTIVE_LEASH)

/proc/clash_bot_pick_job(faction)
	var/list/jobs = GLOB.clash_bot_class_jobs[faction]
	if(!jobs)
		return null
	var/total = 1
	var/heavies = 0
	var/medics = 0
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.body?.faction != faction)
			continue
		total++
		if(bot.heavy)
			heavies++
		if(bot.medic)
			medics++
	var/wanted = total >= CLASH_BOT_CLASS_MIN ? max(1, floor(total / CLASH_BOT_CLASS_SHARE)) : 0
	if(heavies < wanted)
		return jobs[2]
	if(medics < wanted)
		return jobs[3]
	return jobs[1]

/proc/clash_bot_base_turf(faction)
	var/list/spots = list()
	switch(faction)
		if(FACTION_MARINE)
			for(var/squad in list(SQUAD_MARINE_1, SQUAD_MARINE_2))
				spots |= GLOB.latejoin_by_squad[squad]
		if(FACTION_UPP)
			spots |= GLOB.latejoin_by_job[JOB_UPP]
	return length(spots) ? get_turf(pick(spots)) : null

/proc/clash_bot_apply_fill_limits()
	var/list/limits = list()
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(spawner.team_fill && !isnull(spawner.fill_limit))
			limits[spawner.faction] = max(limits[spawner.faction] || 0, spawner.fill_limit)
	for(var/faction in limits)
		GLOB.clash_bot_fill_targets[faction] = limits[faction]

/proc/clash_bot_fill()
	var/list/humans = list()
	for(var/faction in GLOB.clash_bot_fill_targets)
		humans[faction] = clash_player_count(faction)
	for(var/faction in GLOB.clash_bot_fill_targets)
		var/total = GLOB.clash_bot_fill_targets[faction]
		if(total && (faction in list(FACTION_MARINE, FACTION_UPP)))
			total = max(total, humans[faction == FACTION_MARINE ? FACTION_UPP : FACTION_MARINE])
		clash_bot_set_fill(faction, clamp(total - humans[faction], 0, GLOB.clash_bot_caps[faction]))

/proc/clash_bot_set_fill(faction, wanted)
	var/list/active = list()
	var/list/idle = list()
	var/obj/effect/landmark/clash_npc/template
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(!spawner.team_fill || spawner.faction != faction)
			continue
		if(!spawner.extra)
			template = spawner
		if(spawner.active)
			active += spawner
		else
			idle += spawner
	while(length(active) < wanted)
		var/obj/effect/landmark/clash_npc/spawner
		if(length(idle))
			spawner = pick_n_take(idle)
		else if(template)
			spawner = new template.type(get_turf(template))
			spawner.extra = TRUE
		else
			return
		spawner.active = TRUE
		active += spawner
		INVOKE_ASYNC(spawner, TYPE_PROC_REF(/obj/effect/landmark/clash_npc, spawn_npc))
	for(var/obj/effect/landmark/clash_npc/spawner as anything in shuffle(active))
		if(length(active) <= wanted)
			return
		if(spawner.bot && !spawner.bot.can_vanish())
			continue
		active -= spawner
		spawner.stand_down()

/obj/effect/landmark/clash_npc/uscm
	name = "Clash NPC spawner (USCM Rifleman)"
	faction = FACTION_MARINE
	job = JOB_SQUAD_MARINE

/obj/effect/landmark/clash_npc/uscm/fill
	name = "Clash NPC team fill spawner (USCM Rifleman)"
	team_fill = TRUE

/obj/effect/landmark/clash_npc/upp
	name = "Clash NPC spawner (UPP Soldier)"
	faction = FACTION_UPP
	job = JOB_UPP

/obj/effect/landmark/clash_npc/upp/fill
	name = "Clash NPC team fill spawner (UPP Soldier)"
	team_fill = TRUE

/obj/effect/landmark/clash_npc/clf
	name = "Clash NPC spawner (CLF Soldier)"
	faction = FACTION_CLF
	equipment_preset = /datum/equipment_preset/clf/soldier
	bot_gun = /obj/item/weapon/gun/rifle/ak4047
	bot_magazine = /obj/item/ammo_magazine/rifle/ak4047
	spawn_in_base = FALSE

#undef CLASH_BOT_FILL_INTERVAL
#undef CLASH_BOT_CORPSE_TIME
#undef CLASH_BOT_LITTER_TIME
#undef CLASH_BOT_LITTER_SWEEP
#undef CLASH_BOT_BLIP_DELAY
#undef CLASH_BOT_BLIP_COLOR
#undef CLASH_BOT_PLAN_DELAY
#undef CLASH_BOT_CLASS_MIN
#undef CLASH_BOT_CLASS_SHARE
#undef CLASH_BOT_HEAVY_PREFERENCE
#undef CLASH_BOT_FLANK_DISTANCE
#undef CLASH_BOT_OVERWATCH_RANGE
#undef CLASH_BOT_OVERWATCH_LEASH
#undef CLASH_BOT_STAND_KEEP_OFF
#undef CLASH_BOT_STAND_GUARD
#undef CLASH_BOT_STAND_WAIT
#undef CLASH_BOT_ESCORTS
#undef CLASH_BOT_INTERCEPTORS
#undef CLASH_BOT_RUNNER_WAIT
#undef CLASH_BOT_FOLLOW_RANGE
#undef CLASH_BOT_PUSH_SHARE
#undef CLASH_BOT_PATROL_SHARE
#undef CLASH_BOT_PATROL_BEHIND
#undef CLASH_BOT_DEFEND_LEASH
#undef CLASH_BOT_PATROL_LEASH
#undef CLASH_BOT_OBJECTIVE_LEASH

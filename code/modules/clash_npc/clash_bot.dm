#define CLASH_BOT_TICK 3
#define CLASH_BOT_SIGHT 7
#define CLASH_BOT_ACCURACY 0.7
#define CLASH_BOT_RELOAD_DELAY 25
#define CLASH_BOT_COVER_RANGE 5
#define CLASH_BOT_COVER_RESCAN 30
#define CLASH_BOT_REPATH_DELAY 20
#define CLASH_BOT_PATHS_PER_TICK 2
#define CLASH_BOT_MEMORY 60
#define CLASH_BOT_WOUNDED 0.45
#define CLASH_BOT_STUCK_LIMIT 3
#define CLASH_BOT_SEARCH_DELAY 6
#define CLASH_BOT_HEAL_DELAY 100
#define CLASH_BOT_SCAVENGE_RANGE 8
#define CLASH_BOT_CLOSE_RANGE 4

GLOBAL_LIST_EMPTY(clash_bots)
GLOBAL_LIST_EMPTY(clash_bot_cover_claims)
GLOBAL_VAR(clash_bot_timer)
GLOBAL_VAR_INIT(clash_bot_paths_this_tick, 0)
GLOBAL_VAR_INIT(clash_bots_enabled, TRUE)

/proc/set_clash_bots_enabled(enabled)
	GLOB.clash_bots_enabled = enabled
	if(enabled)
		return
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		bot.stop_volley()

/proc/think_clash_bots()
	GLOB.clash_bot_paths_this_tick = 0
	if(GLOB.clash_bots_enabled)
		for(var/index = length(GLOB.clash_bots) to 1 step -1)
			var/datum/clash_bot/bot = GLOB.clash_bots[index]
			bot.think()
	if(!length(GLOB.clash_bots))
		deltimer(GLOB.clash_bot_timer)
		GLOB.clash_bot_timer = null

/datum/clash_bot
	var/mob/living/carbon/human/body
	var/obj/effect/landmark/clash_npc/post
	var/obj/item/weapon/gun/gun
	var/mob/living/carbon/human/target
	var/mob/living/carbon/human/threat
	var/threat_at = 0
	var/turf/contact_turf
	var/contact_at = 0
	var/turf/anchor
	var/hold_radius = 6
	var/turf/destination
	var/list/path
	var/turf/claimed
	var/list/watched_turfs = list()
	var/next_fire = 0
	var/next_step = 0
	var/next_repath = 0
	var/next_cover_scan = 0
	var/last_cover_scan = 0
	var/next_search = 0
	var/next_heal = 0
	var/stuck_for = 0
	var/firing = FALSE
	var/shots_left = 0
	var/dry = FALSE

/datum/clash_bot/New(mob/living/carbon/human/new_body, obj/effect/landmark/clash_npc/new_post)
	. = ..()
	body = new_body
	post = new_post
	anchor = new_post ? new_post.get_hold_turf() : get_turf(new_body)
	if(new_post)
		hold_radius = new_post.hold_radius
	arm_up()
	RegisterSignal(body, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(body, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired))
	RegisterSignal(body, COMSIG_MOVABLE_MOVED, PROC_REF(watch_nearby_turfs))
	watch_nearby_turfs()
	GLOB.clash_bots += src
	if(!GLOB.clash_bot_timer)
		GLOB.clash_bot_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(think_clash_bots)), CLASH_BOT_TICK, TIMER_LOOP|TIMER_STOPPABLE)

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
	threat = null
	contact_turf = null
	anchor = null
	destination = null
	path = null
	return ..()

/datum/clash_bot/proc/on_gun_fire(obj/item/weapon/gun/source, obj/projectile/bullet)
	SIGNAL_HANDLER
	bullet.accuracy *= CLASH_BOT_ACCURACY

/datum/clash_bot/proc/on_fired(mob/source, obj/item/weapon/gun/fired)
	SIGNAL_HANDLER
	if(!firing || gun.gun_firemode != GUN_FIREMODE_AUTOMATIC)
		return
	shots_left--
	if(shots_left <= 0)
		stop_volley()

/datum/clash_bot/proc/on_shot(mob/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	note_threat(bullet.firer)

/datum/clash_bot/proc/on_bullet_near(turf/source, atom/movable/entering)
	SIGNAL_HANDLER
	if(istype(entering, /obj/projectile))
		var/obj/projectile/bullet = entering
		note_threat(bullet.firer)

/datum/clash_bot/proc/note_threat(atom/firer)
	var/mob/living/carbon/human/shooter = firer
	if(!istype(shooter) || shooter.faction == body.faction)
		return
	threat = shooter
	threat_at = world.time
	contact_turf = get_turf(shooter)
	contact_at = world.time
	next_cover_scan = min(next_cover_scan, last_cover_scan + 1 SECONDS)

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
	update_target()
	var/obj/item/weapon/gun/wanted = pick_gun()
	charging = !ceasefire && should_charge(wanted)
	bleed_out(HAS_TRAIT(body, TRAIT_FLOORED) && !(wanted && gun_ready(wanted)))
	if(charging)
		stab()
	else
		if(wanted != gun || (wanted && body.get_active_hand() != wanted))
			ready_gun(wanted)
		if(ceasefire)
			stop_volley()
		else if(target)
			body.face_atom(target)
			if(!try_grenade())
				fight()
		else if(firing)
			stop_volley()
		else if(contact_recent() && prob(25))
			suppress()
		else
			try_heal()
	if(!HAS_TRAIT(body, TRAIT_FLOORED))
		handle_movement()

/datum/clash_bot/proc/contact_recent()
	return contact_turf && world.time - contact_at < CLASH_BOT_MEMORY

/datum/clash_bot/proc/update_target()
	var/mob/living/carbon/human/previous = target
	if(QDELETED(threat))
		threat = null
	if(!can_engage(target))
		target = null
	if(world.time >= next_search)
		next_search = world.time + CLASH_BOT_SEARCH_DELAY + rand(0, 3)
		var/mob/living/carbon/human/closest = find_target()
		if(closest && (!target || (get_dist(body, closest) <= CLASH_BOT_CLOSE_RANGE && get_dist(body, closest) < get_dist(body, target))))
			target = closest
	var/close_target = target && get_dist(body, target) <= CLASH_BOT_CLOSE_RANGE
	if(threat && threat != target && !close_target && world.time - threat_at < CLASH_BOT_MEMORY && can_engage(threat))
		target = threat
	if(!target)
		return
	contact_turf = get_turf(target)
	contact_at = world.time
	if(target != previous)
		stop_volley()
		next_fire = max(next_fire, world.time + rand(3, 8))

/datum/clash_bot/proc/can_engage(mob/living/carbon/human/candidate)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate.faction == body.faction)
		return FALSE
	if(candidate.z != body.z || get_dist(body, candidate) > CLASH_BOT_SIGHT)
		return FALSE
	if(!can_enter(get_turf(candidate)))
		return FALSE
	return clear_shot(get_turf(candidate), candidate)

/datum/clash_bot/proc/clear_shot(turf/aim, mob/candidate)
	for(var/turf/line_turf as anything in get_line(body, aim, include_start_atom = FALSE))
		if(line_turf.density || line_turf.opacity)
			return FALSE
		for(var/obj/thing in line_turf)
			if(thing.opacity || (thing.density && thing.projectile_coverage >= PROJECTILE_COVERAGE_HIGH && line_turf != aim))
				return FALSE
		for(var/mob/living/carbon/human/ally in line_turf)
			if(ally != candidate && ally.faction == body.faction && ally.stat != DEAD && ally.body_position != LYING_DOWN)
				return FALSE
	return TRUE

/datum/clash_bot/proc/find_target()
	var/mob/living/carbon/human/closest
	var/closest_distance = CLASH_BOT_SIGHT + 1
	for(var/mob/living/carbon/human/candidate in oview(CLASH_BOT_SIGHT, body))
		var/distance = get_dist(body, candidate)
		if(distance >= closest_distance || !can_engage(candidate))
			continue
		closest = candidate
		closest_distance = distance
	return closest

/datum/clash_bot/proc/has_ammo()
	return gun && (gun.in_chamber || gun.current_mag?.current_rounds > 0)

/datum/clash_bot/proc/fight()
	if(!gun)
		return
	if(firing)
		if(has_ammo() && clear_shot(get_turf(target), target))
			gun.set_target(target)
			body.clash_aim_turf = get_turf(target)
		else
			stop_volley()
		return
	if(world.time < next_fire)
		return
	if(!has_ammo())
		if(!dry && hands == 2)
			next_fire = world.time + CLASH_BOT_RELOAD_DELAY
			INVOKE_ASYNC(src, PROC_REF(reload))
		return
	start_volley(target, rand(4, 8))

/datum/clash_bot/proc/suppress()
	if(firing || world.time < next_fire || !has_ammo())
		return
	if(get_dist(body, contact_turf) > CLASH_BOT_SIGHT || !clear_shot(contact_turf))
		return
	body.face_atom(contact_turf)
	start_volley(contact_turf, rand(2, 4))

/datum/clash_bot/proc/start_volley(atom/aim, rounds)
	firing = TRUE
	if(prob(1))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, emote), "warcry")
	shots_left = rounds
	gun.set_target(aim)
	body.clash_aim_turf = get_turf(aim)
	gun.start_fire(body, aim, get_turf(aim), null, null, TRUE)
	if(gun.gun_firemode == GUN_FIREMODE_AUTOMATIC)
		return
	firing = FALSE
	next_fire = world.time + (gun.gun_firemode == GUN_FIREMODE_BURSTFIRE ? rand(6, 11) : rand(4, 8))

/datum/clash_bot/proc/stop_volley()
	if(!firing)
		return
	firing = FALSE
	if(gun && body?.get_active_hand() == gun)
		gun.stop_fire()
	else
		gun?.reset_fire()
	next_fire = world.time + rand(5, 10)

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
	if(world.time < next_heal || contact_recent() || firing || hands < 2)
		return
	if(body.health >= body.maxHealth * CLASH_BOT_WOUNDED)
		return
	var/obj/item/medicine = find_medicine()
	if(!medicine)
		return
	next_heal = world.time + CLASH_BOT_HEAL_DELAY
	INVOKE_ASYNC(src, PROC_REF(heal_with), medicine)

/datum/clash_bot/proc/heal_with(obj/item/medicine)
	stop_volley()
	busy_until = world.time + 10 SECONDS
	gun?.unwield(body)
	var/obj/item/storage/holder = medicine.loc
	if(istype(holder))
		holder.remove_from_storage(medicine, get_turf(body))
	body.put_in_hands(medicine, FALSE)
	if(medicine.loc == body)
		medicine.attack(body, body)
	busy_until = 0
	if(QDELETED(body) || body.stat == DEAD)
		return
	if(!QDELETED(medicine) && medicine.loc == body && !(istype(holder) && holder.can_be_inserted(medicine, body, TRUE) && holder.handle_item_insertion(medicine, TRUE, body)))
		body.drop_inv_item_to_loc(medicine, get_turf(body))
	if(gun?.flags_item & TWOHANDED)
		gun.wield(body)

/datum/clash_bot/proc/find_medicine()
	for(var/obj/item/reagent_container/hypospray/autoinjector/shot in body.get_contents())
		if(shot.uses_left > 0)
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
	if(!post)
		return
	if(!reachable(primary) && post.bot_gun)
		primary = new post.bot_gun(get_turf(body))
		track_clash_bot_gear(primary)
		set_firemode()
	top_up(post.bot_magazine, post.bot_magazines)
	if(post.bot_sidearm)
		if(!reachable(sidearm))
			sidearm = supply(post.bot_sidearm)
		top_up(post.bot_sidearm_magazine, post.bot_sidearm_magazines)
	if(post.bot_grenade && !reachable(grenade))
		grenade = supply(post.bot_grenade)
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

/datum/clash_bot/proc/get_state()
	if(!GLOB.clash_bots_enabled)
		return "Paused"
	if(stranded_since)
		return "Bleeding out"
	if(charging)
		return "Charging"
	if(target)
		return "Fighting"
	if(hands == 2 && (dry || !primary))
		return "Restocking"
	if(contact_recent())
		return "Alert"
	if(destination)
		return "Moving"
	return "Holding"

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

/datum/clash_bot/proc/known_enemy_turfs()
	var/list/enemies = list()
	if(target)
		enemies |= get_turf(target)
	if(!QDELETED(threat) && world.time - threat_at < CLASH_BOT_MEMORY)
		enemies |= get_turf(threat)
	if(contact_recent())
		enemies |= contact_turf
	enemies -= null
	return enemies

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

/datum/clash_bot/proc/score_spot(turf/spot, list/enemies, hiding)
	var/score = 0
	var/turf/primary = enemies[1]
	for(var/turf/enemy as anything in enemies)
		var/protection = cover_against(spot, enemy)
		if(!line_clear(enemy, spot))
			score += hiding ? 12 : protection * 0.3
			if(!hiding && enemy == primary)
				score -= 10
			continue
		score += hiding ? protection * 0.5 : protection
		if(!protection)
			score -= 6
	var/distance = get_dist(spot, primary)
	if(hiding)
		score += distance
	else if(distance > CLASH_BOT_SIGHT)
		score -= 30
	else if(distance < 3)
		score -= 8
	for(var/mob/living/carbon/human/ally in range(1, spot))
		if(ally != body && ally.faction == body.faction && ally.stat != DEAD)
			score -= 5
	return score

/datum/clash_bot/proc/pick_cover()
	var/turf/here = get_turf(body)
	var/list/enemies = known_enemy_turfs()
	if(!here || !length(enemies))
		return null
	var/hiding = body.health < body.maxHealth * CLASH_BOT_WOUNDED || !has_ammo()
	var/turf/best
	var/best_score = score_spot(here, enemies, hiding) + 4
	for(var/turf/open/spot in range(CLASH_BOT_COVER_RANGE, body))
		if(spot == here || get_dist(spot, anchor) > hold_radius || !can_enter(spot) || spot_blocked(spot))
			continue
		var/datum/clash_bot/owner = GLOB.clash_bot_cover_claims[spot]
		if(owner && owner != src)
			continue
		var/score = score_spot(spot, enemies, hiding) - get_dist(here, spot)
		if(score <= best_score)
			continue
		best = spot
		best_score = score
	return best

/datum/clash_bot/proc/set_destination(turf/spot)
	if(spot == destination)
		return
	destination = spot
	path = null

/datum/clash_bot/proc/choose_destination()
	if(charging)
		var/turf/aim = get_turf(target)
		if(!destination || get_dist(destination, aim) > 2)
			set_destination(aim)
		return
	if(hands == 2 && (dry || !primary))
		resupply()
		return
	if(target || contact_recent())
		if(world.time < next_cover_scan)
			return
		next_cover_scan = world.time + CLASH_BOT_COVER_RESCAN + rand(0, 10)
		last_cover_scan = world.time
		var/turf/spot = pick_cover()
		if(spot)
			claim_cover(spot)
			set_destination(spot)
		return
	if(get_dist(body, anchor) > hold_radius)
		release_cover()
		set_destination(anchor)
	else if(!destination && prob(1))
		var/list/nearby = list()
		for(var/turf/open/spot in range(2, anchor))
			if(!spot_blocked(spot) && can_enter(spot) && !GLOB.clash_bot_cover_claims[spot])
				nearby += spot
		if(length(nearby))
			set_destination(pick(nearby))

/datum/clash_bot/proc/resupply()
	var/obj/item/ammo_magazine/spare = find_loose_magazine()
	if(spare)
		if(get_dist(body, spare) <= 1)
			grab_magazine(spare)
			destination = null
		else
			set_destination(get_turf(spare))
		return
	var/turf/depot = get_turf(post)
	if(!depot)
		return
	if(get_dist(body, depot) <= 1)
		rearm()
		destination = null
		return
	set_destination(depot)

/datum/clash_bot/proc/handle_movement()
	if(world.time < next_step)
		return
	choose_destination()
	var/turf/here = get_turf(body)
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
			destination = null
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
	var/obj/structure/machinery/door/blocking_door = locate() in next
	if(blocking_door?.density && blocking_door.operating == DOOR_OPERATING_OPENING)
		return
	stuck_for++
	if(stuck_for < CLASH_BOT_STUCK_LIMIT)
		return
	stuck_for = 0
	path = null
	if(destination == claimed)
		release_cover()
	destination = null

#undef CLASH_BOT_TICK
#undef CLASH_BOT_SIGHT
#undef CLASH_BOT_ACCURACY
#undef CLASH_BOT_RELOAD_DELAY
#undef CLASH_BOT_COVER_RANGE
#undef CLASH_BOT_COVER_RESCAN
#undef CLASH_BOT_REPATH_DELAY
#undef CLASH_BOT_PATHS_PER_TICK
#undef CLASH_BOT_MEMORY
#undef CLASH_BOT_WOUNDED
#undef CLASH_BOT_STUCK_LIMIT
#undef CLASH_BOT_SEARCH_DELAY
#undef CLASH_BOT_HEAL_DELAY
#undef CLASH_BOT_SCAVENGE_RANGE
#undef CLASH_BOT_CLOSE_RANGE

/// How often a bot looks around, shoots and steps
#define CLASH_BOT_TICK 3
/// Tiles a bot will engage within
#define CLASH_BOT_RANGE 9
/// Accuracy a bot keeps compared to a player firing the same gun
#define CLASH_BOT_ACCURACY 0.7
/// Deciseconds a bot spends swapping a magazine
#define CLASH_BOT_RELOAD_DELAY 25
/// Deciseconds between steps, a bot walks rather than runs
#define CLASH_BOT_STEP_DELAY 4
/// Tiles a bot searches for cover to fight from
#define CLASH_BOT_COVER_RANGE 5
/// Ticks of no progress before a bot gives up on where it was heading
#define CLASH_BOT_STUCK_LIMIT 4

GLOBAL_LIST_EMPTY(clash_bots)
GLOBAL_VAR(clash_bot_timer)

/proc/think_clash_bots()
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
	var/turf/anchor
	var/turf/heading
	var/hold_radius = 6
	var/next_fire
	var/next_step
	var/stuck_for = 0
	var/dry = FALSE

/datum/clash_bot/New(mob/living/carbon/human/new_body, obj/effect/landmark/clash_npc/new_post)
	. = ..()
	body = new_body
	post = new_post
	anchor = get_turf(new_post || new_body)
	if(new_post)
		hold_radius = new_post.hold_radius
	take_out_gun()
	GLOB.clash_bots += src
	if(!GLOB.clash_bot_timer)
		GLOB.clash_bot_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(think_clash_bots)), CLASH_BOT_TICK, TIMER_LOOP|TIMER_STOPPABLE)

/datum/clash_bot/Destroy(force)
	GLOB.clash_bots -= src
	if(!QDELETED(gun))
		UnregisterSignal(gun, COMSIG_GUN_BEFORE_FIRE)
	body = null
	post = null
	gun = null
	target = null
	anchor = null
	heading = null
	return ..()

/datum/clash_bot/proc/take_out_gun()
	for(var/obj/item/weapon/gun/carried in body.contents)
		gun = carried
		break
	if(!gun)
		return
	body.drop_inv_item_to_loc(gun, body, force = TRUE)
	body.put_in_hands(gun, FALSE)
	if(gun.flags_item & TWOHANDED)
		gun.wield(body)
	if(gun.gun_firemode != GUN_FIREMODE_BURSTFIRE && (GUN_FIREMODE_BURSTFIRE in gun.gun_firemode_list))
		gun.do_toggle_firemode(body, null, GUN_FIREMODE_BURSTFIRE)
	RegisterSignal(gun, COMSIG_GUN_BEFORE_FIRE, PROC_REF(on_gun_fire))

/datum/clash_bot/proc/on_gun_fire(obj/item/weapon/gun/source, obj/projectile/bullet)
	SIGNAL_HANDLER
	bullet.accuracy *= CLASH_BOT_ACCURACY

/datum/clash_bot/proc/think()
	if(QDELETED(body) || body.stat == DEAD)
		post?.bot_died()
		qdel(src)
		return
	if(!can_engage(target))
		target = find_target()
	if(target)
		body.setDir(get_dir(body, target))
		fight()
	else
		heading = null
	handle_movement()

/datum/clash_bot/proc/fight()
	if(world.time < next_fire || !gun)
		return
	if(!gun.current_mag || (!gun.current_mag.current_rounds && !gun.in_chamber))
		if(dry)
			return
		next_fire = world.time + CLASH_BOT_RELOAD_DELAY
		INVOKE_ASYNC(src, PROC_REF(reload))
		return
	gun.Fire(target, body)
	next_fire = world.time + rand(3, 8)

/datum/clash_bot/proc/can_engage(mob/living/carbon/human/candidate)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate.faction == body.faction)
		return FALSE
	if(get_dist(body, candidate) > CLASH_BOT_RANGE || candidate.z != body.z)
		return FALSE
	for(var/turf/line_turf as anything in get_line(body, candidate, include_start_atom = FALSE))
		if(line_turf.density || line_turf.opacity)
			return FALSE
		for(var/obj/structure/blocker in line_turf)
			if(blocker.opacity)
				return FALSE
		for(var/mob/living/carbon/human/ally in line_turf)
			if(ally != candidate && ally.faction == body.faction && ally.stat != DEAD)
				return FALSE
	return TRUE

/datum/clash_bot/proc/find_target()
	var/mob/living/carbon/human/closest
	var/closest_distance = CLASH_BOT_RANGE + 1
	for(var/mob/living/carbon/human/candidate in oview(CLASH_BOT_RANGE, body))
		var/distance = get_dist(body, candidate)
		if(distance >= closest_distance || !can_engage(candidate))
			continue
		closest = candidate
		closest_distance = distance
	return closest

/datum/clash_bot/proc/reload()
	if(QDELETED(body) || body.stat == DEAD)
		return
	var/obj/item/ammo_magazine/spare = find_magazine()
	if(!spare)
		dry = TRUE
		return
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

/datum/clash_bot/proc/find_magazine()
	for(var/obj/item/ammo_magazine/spare in body.get_contents())
		if(spare.current_rounds <= 0 || spare == gun.current_mag)
			continue
		if(istype(gun, spare.gun_type) || (spare.type in gun.accepted_ammo))
			return spare
	return null

/// Barricades shield the side their facing points at, so the spot worth holding is the one with cover between the bot and its target
/datum/clash_bot/proc/find_cover()
	var/turf/best
	var/best_distance = CLASH_BOT_COVER_RANGE + 1
	for(var/obj/structure/barricade/cover in orange(CLASH_BOT_COVER_RANGE, body))
		var/turf/spot = get_turf(cover)
		if(cover.closed || get_dist(spot, anchor) > hold_radius)
			continue
		if(!(cover.dir & get_dir(spot, target)))
			continue
		var/distance = get_dist(body, spot)
		if(distance >= best_distance)
			continue
		best = spot
		best_distance = distance
	return best

/datum/clash_bot/proc/handle_movement()
	if(world.time < next_step)
		return
	if(target)
		if(get_turf(body) != heading)
			heading = find_cover()
	else if(get_dist(body, anchor) > hold_radius)
		heading = anchor
	if(!heading || get_turf(body) == heading)
		return
	next_step = world.time + CLASH_BOT_STEP_DELAY
	var/turf/before = get_turf(body)
	step_to(body, heading, 0)
	if(get_turf(body) != before)
		stuck_for = 0
		return
	stuck_for++
	if(stuck_for < CLASH_BOT_STUCK_LIMIT)
		return
	stuck_for = 0
	heading = null

#undef CLASH_BOT_TICK
#undef CLASH_BOT_RANGE
#undef CLASH_BOT_ACCURACY
#undef CLASH_BOT_RELOAD_DELAY
#undef CLASH_BOT_STEP_DELAY
#undef CLASH_BOT_COVER_RANGE
#undef CLASH_BOT_STUCK_LIMIT

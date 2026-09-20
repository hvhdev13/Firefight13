/// How often a bot looks around and shoots
#define CLASH_BOT_TICK 3
/// Tiles a bot will engage within
#define CLASH_BOT_RANGE 9
/// Accuracy a bot keeps compared to a player firing the same gun
#define CLASH_BOT_ACCURACY 0.7
/// Deciseconds a bot spends swapping a magazine
#define CLASH_BOT_RELOAD_DELAY 25

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
	var/next_fire

/datum/clash_bot/New(mob/living/carbon/human/new_body, obj/effect/landmark/clash_npc/new_post)
	. = ..()
	body = new_body
	post = new_post
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
	return ..()

/datum/clash_bot/proc/take_out_gun()
	for(var/obj/item/weapon/gun/carried in body.contents)
		gun = carried
		break
	if(!gun)
		return
	body.drop_inv_item_to_loc(gun, body, force = TRUE)
	body.put_in_hands(gun, FALSE)
	gun.wield(body)
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
	if(!target)
		return
	body.setDir(get_dir(body, target))
	if(world.time < next_fire || !gun)
		return
	if(gun.current_mag && !gun.current_mag.current_rounds)
		next_fire = world.time + CLASH_BOT_RELOAD_DELAY
		INVOKE_ASYNC(src, PROC_REF(reload))
		return
	gun.Fire(target, body)
	if(istype(gun, /obj/item/weapon/gun/shotgun/pump))
		gun.unique_action(body)
	next_fire = world.time + rand(3, 8)

/datum/clash_bot/proc/can_engage(mob/living/carbon/human/candidate)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate.faction == body.faction)
		return FALSE
	if(get_dist(body, candidate) > CLASH_BOT_RANGE || candidate.z != body.z)
		return FALSE
	for(var/turf/step as anything in get_line(body, candidate, include_start_atom = FALSE))
		if(step.density || step.opacity)
			return FALSE
		for(var/obj/structure/blocker in step)
			if(blocker.opacity)
				return FALSE
		for(var/mob/living/carbon/human/ally in step)
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
	var/obj/item/ammo_magazine/spare = find_magazine()
	if(!spare || QDELETED(body) || body.stat == DEAD)
		return
	if(!(gun.flags_gun_features & GUN_INTERNAL_MAG))
		gun.unload(body, TRUE, TRUE)
	gun.reload(body, spare)

/datum/clash_bot/proc/find_magazine()
	for(var/obj/item/ammo_magazine/spare in body.get_contents())
		if(spare.current_rounds <= 0)
			continue
		if(istype(gun, spare.gun_type) || (spare.type in gun.accepted_ammo))
			return spare
	return null

#undef CLASH_BOT_TICK
#undef CLASH_BOT_RANGE
#undef CLASH_BOT_ACCURACY
#undef CLASH_BOT_RELOAD_DELAY

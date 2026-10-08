#define CLASH_BOT_CHARGE_RANGE 5
#define CLASH_BOT_MELEE_DELAY 8
#define CLASH_BOT_GRENADE_MIN 3
#define CLASH_BOT_GRENADE_MAX 7
#define CLASH_BOT_BLEED_OUT (30 SECONDS)

/datum/clash_bot/var/obj/item/weapon/gun/primary
/datum/clash_bot/var/obj/item/weapon/gun/sidearm
/datum/clash_bot/var/obj/item/knife
/datum/clash_bot/var/obj/item/explosive/grenade/grenade
/datum/clash_bot/var/list/homes = list()
/datum/clash_bot/var/hands = 2
/datum/clash_bot/var/stranded_since
/datum/clash_bot/var/charging = FALSE
/datum/clash_bot/var/busy_until = 0
/datum/clash_bot/var/next_melee = 0
/datum/clash_bot/var/primary_type
/datum/clash_bot/var/primary_magazine
/datum/clash_bot/var/primary_spares = 0
/datum/clash_bot/var/sidearm_type
/datum/clash_bot/var/sidearm_magazine
/datum/clash_bot/var/sidearm_spares = 0
/datum/clash_bot/var/grenade_type

/datum/clash_bot/proc/arm_up()
	var/obj/item/weapon/gun/held = body.get_active_hand()
	if(istype(held) && !clash_is_sidearm(held))
		primary = held
	for(var/obj/item/thing as anything in body.get_contents())
		if(istype(thing.loc, /obj/item/weapon/gun))
			continue
		if(!primary && istype(thing, /obj/item/weapon/gun) && !clash_is_sidearm(thing))
			primary = thing
		else if(!sidearm && thing != primary && istype(thing, /obj/item/weapon/gun))
			sidearm = thing
		else if(!knife && istype(thing, /obj/item/attachable/bayonet))
			knife = thing
		else if(!grenade && istype(thing, /obj/item/explosive/grenade))
			grenade = thing
		else
			continue
		homes[thing] = thing.loc
	primary_type = primary?.type
	primary_magazine = primary?.current_mag?.type
	sidearm_type = sidearm?.type
	sidearm_magazine = sidearm?.current_mag?.type
	grenade_type = grenade?.type
	for(var/obj/item/ammo_magazine/spare in body.get_contents())
		if(istype(spare.loc, /obj/item/weapon/gun))
			continue
		if(spare.type == primary_magazine)
			primary_spares++
		else if(spare.type == sidearm_magazine)
			sidearm_spares++
	set_firemode()
	ready_gun(primary)

/datum/clash_bot/proc/set_firemode()
	var/wanted_firemode = post?.bot_firemode
	if(primary && wanted_firemode && primary.gun_firemode != wanted_firemode && (wanted_firemode in primary.gun_firemode_list))
		primary.do_toggle_firemode(body, null, wanted_firemode)

/datum/clash_bot/proc/check_hands()
	var/obj/limb/right = body.get_limb("r_hand")
	var/obj/limb/left = body.get_limb("l_hand")
	hands = (right?.is_usable() ? 1 : 0) + (left?.is_usable() ? 1 : 0)
	if(!hands)
		stop_volley()
		bleed_out(TRUE)
		return FALSE
	var/obj/limb/active = body.hand ? left : right
	if(!active?.is_usable())
		body.swap_hand()
	return TRUE

/datum/clash_bot/proc/bleed_out(stranded)
	if(!stranded)
		stranded_since = null
		return
	if(!stranded_since)
		stranded_since = world.time
	else if(world.time - stranded_since >= CLASH_BOT_BLEED_OUT)
		body.death(create_cause_data("blood loss"))

/datum/clash_bot/proc/carried(obj/item/thing)
	var/atom/holder = thing.loc
	while(istype(holder, /obj/item))
		holder = holder.loc
	return holder == body

/datum/clash_bot/proc/reachable(obj/item/thing)
	return !QDELETED(thing) && (carried(thing) || (isturf(thing.loc) && get_dist(body, thing) <= 1))

/datum/clash_bot/proc/loaded(obj/item/weapon/gun/weapon)
	return weapon.in_chamber || weapon.current_mag?.current_rounds > 0

/datum/clash_bot/proc/gun_ready(obj/item/weapon/gun/weapon)
	return reachable(weapon) && (loaded(weapon) || (hands == 2 && find_magazine(weapon)))

/datum/clash_bot/proc/pick_gun()
	if(!reachable(primary))
		primary = null
		dry = FALSE
	if(!reachable(sidearm))
		sidearm = null
	if(gun_ready(primary))
		return primary
	if(gun_ready(sidearm))
		return sidearm
	if(hands == 2)
		return primary
	return null

/datum/clash_bot/proc/set_gun(obj/item/weapon/gun/weapon)
	if(gun == weapon)
		return
	stop_volley()
	if(!QDELETED(gun))
		UnregisterSignal(gun, COMSIG_GUN_BEFORE_FIRE)
	gun = weapon
	if(gun)
		RegisterSignal(gun, COMSIG_GUN_BEFORE_FIRE, PROC_REF(on_gun_fire))

/datum/clash_bot/proc/ready_gun(obj/item/weapon/gun/weapon)
	set_gun(weapon)
	if(!weapon || !hold(weapon))
		return
	if(hands == 2 && (weapon.flags_item & TWOHANDED))
		weapon.wield(body)

/datum/clash_bot/proc/hold(obj/item/thing)
	var/obj/item/held = body.get_active_hand()
	if(held == thing)
		return TRUE
	if(held)
		stow(held)
	if(istype(thing.loc, /obj/item/clothing/shoes))
		var/obj/item/clothing/shoes/boots = thing.loc
		boots.remove_item(body)
	else
		var/obj/item/storage/holder = thing.loc
		if(istype(holder))
			holder.remove_from_storage(thing, get_turf(body))
		else if(thing.loc == body)
			body.drop_inv_item_to_loc(thing, body, force = TRUE)
		body.put_in_active_hand(thing)
	return body.get_active_hand() == thing

/datum/clash_bot/proc/stow(obj/item/held)
	var/obj/item/clothing/shoes/boots = body.shoes
	if(held == knife && istype(boots) && boots.attempt_insert_item(body, held))
		return
	var/atom/home = homes[held]
	var/obj/item/storage/holder = home
	if(istype(holder) && carried(holder) && holder.can_be_inserted(held, body, TRUE) && holder.handle_item_insertion(held, TRUE, body))
		return
	if(home == body)
		body.drop_inv_item_to_loc(held, body, force = TRUE)
		return
	body.drop_inv_item_to_loc(held, get_turf(body), force = TRUE)
	if(hands == 2 && !body.get_inactive_hand())
		body.put_in_inactive_hand(held)

/datum/clash_bot/proc/should_charge(obj/item/weapon/gun/weapon)
	if(!ismob(target) || HAS_TRAIT(body, TRAIT_FLOORED) || !reachable(knife) || get_dist(body, target) > CLASH_BOT_CHARGE_RANGE)
		return FALSE
	return !(weapon && gun_ready(weapon))

/datum/clash_bot/proc/stab()
	set_gun(null)
	body.face_atom(target)
	if(!hold(knife) || get_dist(body, target) > 1 || world.time < next_melee)
		return
	next_melee = world.time + CLASH_BOT_MELEE_DELAY
	body.a_intent = INTENT_HARM
	knife.attack(target, body)
	body.a_intent = INTENT_HELP

/datum/clash_bot/proc/try_grenade()
	if(!reachable(grenade))
		return FALSE
	var/distance = get_dist(body, target)
	if(distance < CLASH_BOT_GRENADE_MIN || distance > CLASH_BOT_GRENADE_MAX)
		return FALSE
	var/turf/aim = get_turf(target)
	if(!cover_against(aim, get_turf(body)))
		return FALSE
	var/turf/landing = throw_landing(grenade, aim)
	if(get_dist(landing, aim) > 1 || get_dist(landing, body) < CLASH_BOT_GRENADE_MIN)
		return FALSE
	for(var/mob/living/carbon/human/ally in range(2, landing))
		if(ally.faction == body.faction && ally.stat != DEAD)
			return FALSE
	set_gun(null)
	if(!hold(grenade))
		return FALSE
	grenade.activate(body)
	body.drop_inv_item_to_loc(grenade, get_turf(body), force = TRUE)
	grenade.throw_atom(aim, CLASH_BOT_GRENADE_MAX, SPEED_FAST, body, TRUE)
	homes -= grenade
	grenade = null
	return TRUE

/datum/clash_bot/proc/throw_landing(obj/item/thrown, turf/aim)
	var/turf/landed = get_turf(body)
	thrown.add_temp_pass_flags(PASS_OVER_THROW_ITEM)
	for(var/turf/next as anything in get_line(get_step_towards(landed, aim), aim))
		if(get_dist(get_turf(body), next) > CLASH_BOT_GRENADE_MAX || throw_blocked(thrown, landed, next))
			break
		landed = next
	thrown.remove_temp_pass_flags(PASS_OVER_THROW_ITEM)
	return landed

/datum/clash_bot/proc/throw_blocked(obj/item/thrown, turf/from, turf/into)
	var/direction = get_dir(from, into)
	if(!(direction in GLOB.cardinals))
		var/vertical = direction & (NORTH|SOUTH)
		var/horizontal = direction & (EAST|WEST)
		var/turf/side_one = get_step(from, vertical)
		var/turf/side_two = get_step(from, horizontal)
		return (throw_blocked(thrown, from, side_one) || throw_blocked(thrown, side_one, into)) && (throw_blocked(thrown, from, side_two) || throw_blocked(thrown, side_two, into))
	if(!into || into.density)
		return TRUE
	for(var/atom/movable/thing in from)
		if(thing != body && thing.BlockedExitDirs(thrown, direction))
			return TRUE
	for(var/atom/movable/thing in into)
		if(thing.BlockedPassDirs(thrown, direction))
			return TRUE
	return FALSE

#undef CLASH_BOT_CHARGE_RANGE
#undef CLASH_BOT_MELEE_DELAY
#undef CLASH_BOT_GRENADE_MIN
#undef CLASH_BOT_GRENADE_MAX
#undef CLASH_BOT_BLEED_OUT

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
#define CLASH_BOT_HEARING 10
#define CLASH_BOT_HUNT_TIME (10 SECONDS)
#define CLASH_BOT_DANGER_TIME (20 SECONDS)
#define CLASH_BOT_DANGER_COST 6
#define CLASH_BOT_DODGE_DELAY 5
#define CLASH_BOT_DODGE_TIME (2 SECONDS)
#define CLASH_BOT_SETTLE_TIME (3 SECONDS)
#define CLASH_BOT_SUPPRESSED 50
#define CLASH_BOT_FOLLOW_RANGE 3
#define CLASH_BOT_POSITION_RANGE 5
#define CLASH_BOT_PRIORITY_BONUS 3
#define CLASH_BOT_MEDIC_RANGE 12
#define CLASH_BOT_PATIENT_HEALTH 0.6
#define CLASH_BOT_PATIENT_SCAN (2 SECONDS)
#define CLASH_BOT_TREAT_DELAY (2 SECONDS)
#define CLASH_BOT_LANE_CLOSE 50
#define CLASH_BOT_LANE_NEAR 30
#define CLASH_BOT_LANE_FAR 20

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
			bot.think()
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
	var/mob/living/carbon/human/threat
	var/threat_at = 0
	var/turf/contact_turf
	var/contact_at = 0
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
	var/last_cover_scan = 0
	var/next_search = 0
	var/next_heal = 0
	var/stuck_for = 0
	var/firing = FALSE
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
	var/turf/hunt_turf
	var/hunt_until = 0
	var/target_since = 0
	var/dodge_seen = 0
	var/dodge_until = 0
	var/was_suppressed = FALSE
	var/list/danger = list()
	var/heavy = FALSE
	var/medic = FALSE
	var/mob/living/carbon/human/medic_patient
	var/next_patient_scan = 0

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
	threat = null
	contact_turf = null
	heard_turf = null
	hunt_turf = null
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
	if(ally_in_lane(aim))
		return COMPONENT_HARD_CANCEL_GUN_BEFORE_FIRE
	var/settle = 0.8 + 0.3 * min(1, (world.time - target_since) / CLASH_BOT_SETTLE_TIME)
	if(world.time - body.l_move_time < 5)
		settle *= 0.85
	if(was_suppressed)
		settle *= 0.8
	bullet.accuracy *= CLASH_BOT_ACCURACY * settle

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
	mark_danger(get_turf(body))

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
	body.a_intent = target ? INTENT_HARM : INTENT_HELP
	var/suppressed = clash_suppression_now(body) >= CLASH_BOT_SUPPRESSED
	if(suppressed && !was_suppressed)
		next_cover_scan = 0
	was_suppressed = suppressed
	watch_grenades()
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
			if(carrying())
				if(get_dist(body, target) <= CLASH_BOT_CLOSE_RANGE)
					fight()
				else
					stop_volley()
			else if(!try_grenade())
				fight()
		else if(firing)
			stop_volley()
		else if(!try_medic())
			if(contact_recent() && prob(heavy ? 60 : 25))
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
		if(ismob(target) && !QDELETED(target) && target.stat != DEAD)
			hunt_turf = get_turf(target)
			hunt_until = world.time + CLASH_BOT_HUNT_TIME
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
	hunt_turf = null
	heard_turf = null
	if(target != previous)
		stop_volley()
		target_since = world.time
		next_fire = max(next_fire, world.time + rand(3, 8))

/datum/clash_bot/proc/can_engage(mob/living/carbon/human/candidate)
	if(istype(candidate, /obj/structure/machinery/defenses/sentry))
		var/obj/structure/machinery/defenses/sentry/turret = candidate
		if(QDELETED(turret) || !turret.placed || !turret.clash_faction || turret.clash_faction == body.faction || turret.z != body.z || get_dist(body, turret) > CLASH_BOT_SIGHT)
			return FALSE
		return clear_shot(get_turf(turret), null)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate.faction == body.faction || candidate.GetComponent(/datum/component/clash_spawn_guard))
		return FALSE
	if(candidate.z != body.z || get_dist(body, candidate) > CLASH_BOT_SIGHT)
		return FALSE
	if(!can_enter(get_turf(candidate)))
		return FALSE
	return clear_shot(get_turf(candidate), candidate)

/datum/clash_bot/proc/clear_shot(turf/aim, mob/candidate)
	if(locate(/obj/structure/blocker/clash_gate) in get_turf(body))
		return FALSE
	for(var/turf/line_turf as anything in get_line(body, aim, include_start_atom = FALSE))
		if(line_turf.density || line_turf.opacity || (locate(/obj/structure/blocker/clash_gate) in line_turf))
			return FALSE
		for(var/obj/thing in line_turf)
			if(thing.opacity || (thing.density && thing.projectile_coverage >= PROJECTILE_COVERAGE_HIGH && line_turf != aim))
				return FALSE
	return !ally_in_lane(aim)

/datum/clash_bot/proc/ally_in_lane(atom/aim)
	var/turf/start = get_turf(body)
	var/turf/end = get_turf(aim)
	if(!start || !end || start == end)
		return FALSE
	var/reach = get_dist(start, end)
	var/angle = Get_Angle(start, end)
	for(var/mob/living/carbon/human/ally as anything in GLOB.alive_human_list)
		if(ally == body || ally.faction != body.faction || ally.z != start.z)
			continue
		var/distance = get_dist(start, ally)
		if(!distance || distance > max(reach + 1, CLASH_BOT_SIGHT))
			continue
		var/off = abs(Get_Angle(start, ally) - angle)
		if(off > 180)
			off = 360 - off
		if(off <= (distance == 1 ? CLASH_BOT_LANE_CLOSE : (distance == 2 ? CLASH_BOT_LANE_NEAR : CLASH_BOT_LANE_FAR)))
			return TRUE
	return FALSE

/datum/clash_bot/proc/find_target()
	var/mob/living/carbon/human/closest
	var/closest_distance = CLASH_BOT_SIGHT + 1
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	for(var/mob/living/carbon/human/candidate in oview(CLASH_BOT_SIGHT, body))
		var/distance = get_dist(body, candidate)
		if(clash_carries_enemy_flag(candidate) || (istype(clash_mode) && clash_mode.is_objective_turf(get_turf(candidate))))
			distance -= CLASH_BOT_PRIORITY_BONUS
		if(distance >= closest_distance || !can_engage(candidate))
			continue
		closest = candidate
		closest_distance = distance
	if(closest)
		return closest
	for(var/obj/structure/machinery/defenses/sentry/turret in oview(CLASH_BOT_SIGHT, body))
		var/distance = get_dist(body, turret)
		if(distance >= closest_distance || !can_engage(turret))
			continue
		closest = turret
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
	start_volley(target, was_suppressed ? rand(2, 3) : (heavy ? rand(8, 14) : rand(4, 8)))

/datum/clash_bot/proc/suppress()
	if(firing || world.time < next_fire || !has_ammo())
		return
	if(get_dist(body, contact_turf) > CLASH_BOT_SIGHT || !clear_shot(contact_turf))
		return
	body.face_atom(contact_turf)
	start_volley(contact_turf, heavy ? rand(5, 9) : rand(2, 4))

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

/datum/clash_bot/proc/try_medic()
	if(!medic || hands < 2 || carrying())
		return FALSE
	if(medic_patient && !needs_medic(medic_patient))
		medic_patient = null
	if(!medic_patient && world.time >= next_patient_scan)
		next_patient_scan = world.time + CLASH_BOT_PATIENT_SCAN
		medic_patient = find_patient()
	if(!medic_patient)
		return FALSE
	if(get_dist(body, medic_patient) <= 1 && world.time >= next_heal)
		var/obj/item/tool = medic_tool(medic_patient)
		if(!tool)
			medic_patient = null
			return FALSE
		next_heal = world.time + CLASH_BOT_TREAT_DELAY
		INVOKE_ASYNC(src, PROC_REF(heal_with), tool, medic_patient)
	return TRUE

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

/datum/clash_bot/proc/get_activity()
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
	var/hiding = body.health < body.maxHealth * CLASH_BOT_WOUNDED || !has_ammo() || was_suppressed
	var/turf/best
	var/best_score = score_spot(here, enemies, hiding) + 4
	var/turf/centre = leash_centre()
	var/radius = leash_radius()
	for(var/turf/open/spot in range(CLASH_BOT_COVER_RANGE, body))
		if(spot == here || get_dist(spot, centre) > radius || !can_enter(spot) || spot_blocked(spot))
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
	if(world.time < dodge_until)
		return
	if(carrying())
		follow_task()
		return
	if(!target && medic_patient)
		if(get_dist(body, medic_patient) > 1 && (!destination || get_dist(destination, medic_patient) > 1))
			release_cover()
			set_destination(get_turf(medic_patient))
		return
	if(hands == 2 && (dry || !primary))
		resupply()
		return
	if(!target && hunt())
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
	if(heard_turf)
		if(world.time - heard_at < CLASH_BOT_MEMORY && get_dist(heard_turf, leash_centre()) <= leash_radius() + CLASH_BOT_POSITION_RANGE)
			release_cover()
			set_destination(heard_turf)
		heard_turf = null
		return
	follow_task()

/datum/clash_bot/proc/hunt()
	if(!hunt_turf || world.time > hunt_until || get_turf(body) == hunt_turf || body.health < body.maxHealth * CLASH_BOT_WOUNDED || !has_ammo() || get_dist(hunt_turf, leash_centre()) > leash_radius() + CLASH_BOT_SIGHT)
		hunt_turf = null
		return FALSE
	if(destination != hunt_turf)
		release_cover()
		set_destination(hunt_turf)
	return TRUE

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
		if(get_dist(here, leader) > CLASH_BOT_FOLLOW_RANGE && (!destination || get_dist(destination, leader) > 1))
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
	if(task == CLASH_BOT_TASK_PATROL && !destination && world.time - arrived_at > 5 SECONDS)
		var/datum/clash_bot_director/director = clash_bot_director(body.faction)
		set_task(CLASH_BOT_TASK_PATROL, director.next_patrol_goal(anchor), hold_radius)
		return
	if(world.time < next_position)
		return
	next_position = world.time + rand(8 SECONDS, 15 SECONDS)
	var/turf/spot = pick_position()
	if(spot)
		claim_cover(spot)
		set_destination(spot)

/datum/clash_bot/proc/pick_position()
	var/datum/clash_bot_director/director = clash_bot_director(body.faction)
	var/turf/facing = director.enemy_base || anchor
	var/turf/best
	var/best_score
	for(var/turf/open/spot in range(min(hold_radius, CLASH_BOT_POSITION_RANGE), anchor))
		if(!can_enter(spot) || spot_blocked(spot) || !zone_allows(spot) || (keep_off && get_dist(spot, anchor) < keep_off))
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

/datum/clash_bot/proc/hear(turf/source)
	if(target || get_dist(body, source) > CLASH_BOT_HEARING)
		return
	heard_turf = source
	heard_at = world.time
	body.face_atom(source)

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
#undef CLASH_BOT_HEARING
#undef CLASH_BOT_HUNT_TIME
#undef CLASH_BOT_DANGER_TIME
#undef CLASH_BOT_DANGER_COST
#undef CLASH_BOT_DODGE_DELAY
#undef CLASH_BOT_DODGE_TIME
#undef CLASH_BOT_SETTLE_TIME
#undef CLASH_BOT_SUPPRESSED
#undef CLASH_BOT_FOLLOW_RANGE
#undef CLASH_BOT_POSITION_RANGE
#undef CLASH_BOT_PRIORITY_BONUS
#undef CLASH_BOT_MEDIC_RANGE
#undef CLASH_BOT_PATIENT_HEALTH
#undef CLASH_BOT_PATIENT_SCAN
#undef CLASH_BOT_TREAT_DELAY
#undef CLASH_BOT_LANE_CLOSE
#undef CLASH_BOT_LANE_NEAR
#undef CLASH_BOT_LANE_FAR

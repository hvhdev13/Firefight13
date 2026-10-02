/proc/clash_gun_family(gun_type)
	if(ispath(gun_type, /obj/item/weapon/gun/shotgun))
		return CLASH_FAMILY_SHOTGUN
	if(ispath(gun_type, /obj/item/weapon/gun/pistol) || ispath(gun_type, /obj/item/weapon/gun/revolver))
		return CLASH_FAMILY_SIDEARM
	if(ispath(gun_type, /obj/item/weapon/gun/flamer))
		return CLASH_FAMILY_FUEL
	if(ispath(gun_type, /obj/item/weapon/gun/lever_action/xm88))
		return CLASH_FAMILY_LEVER
	return CLASH_FAMILY_MAGAZINE

/proc/clash_weapon_type(obj/item/weapon)
	if(istype(weapon, /obj/item/weapon/gun) || istype(weapon, /obj/item/explosive/grenade))
		return weapon.type
	return null

/proc/clash_grenade_by_name(cause)
	if(!length(GLOB.clash_grenade_names))
		for(var/obj/item/explosive/grenade/grenade_type as anything in typesof(/obj/item/explosive/grenade))
			GLOB.clash_grenade_names[initial(grenade_type.name)] = grenade_type
	return GLOB.clash_grenade_names[cause]

/proc/clash_kill_weapon(mob/living/carbon/human/killer, cause, cause_object, list/hit)
	. = clash_weapon_type(cause_object) || (cause && clash_grenade_by_name(cause)) || hit?["weapon"]
	if(. || !cause)
		return
	for(var/obj/item/weapon/gun/held in list(killer.get_active_hand(), killer.get_inactive_hand()))
		if(held.name == cause || initial(held.name) == cause)
			return held.type

/proc/clash_progression_active()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.progression

/proc/clash_award_xp(mob/living/carbon/human/earner, amount, source, gun_type)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode) || !clash_mode.match_live || earner.statistic_exempt)
		return
	clash_grant_xp(earner.mind?.ckey || earner.ckey, earner.faction, GLOB.clash_job_classes[earner.job || earner.mind?.clash_job], amount, source, gun_type)

/proc/clash_grant_xp(ckey, faction, class, amount, source, gun_type)
	if(!clash_progression_active() || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return
	amount *= GLOB.clash_progression_settings["xp_multiplier"]
	var/bonus = progress.short_side == faction ? round(amount * (CLASH_SHORT_SIDE_BONUS - 1), 1) : 0
	amount = round(amount, 1)
	if(amount + bonus <= 0)
		return
	progress.ledger[source] = (progress.ledger[source] || 0) + amount
	if(bonus)
		progress.ledger["Short side bonus"] = (progress.ledger["Short side bonus"] || 0) + bonus
	clash_score_feed(ckey, amount + bonus, source)
	progress.add_xp(amount + bonus, faction, class, gun_type)

/datum/clash_progress/proc/add_xp(amount, faction, class, gun_type)
	dirty = TRUE
	var/old_level = faction_level(faction)
	var/list/entry = faction_entry(faction)
	entry["xp"] += amount
	check_unlocks("faction", faction, old_level, faction)
	if(class)
		old_level = class_level(class)
		entry = class_entry(class)
		entry["xp"] += amount
		check_unlocks("class", class, old_level, faction)
	var/family = CLASH_FAMILY_GRENADE
	if(!ispath(gun_type, /obj/item/explosive/grenade))
		if(!ispath(gun_type, /obj/item/weapon/gun))
			return
		gun_type = clash_track_type(gun_type)
		old_level = weapon_level(gun_type)
		entry = weapon_entry(gun_type)
		entry["xp"] += amount
		check_unlocks("weapon", gun_type, old_level, faction)
		family = clash_gun_family(gun_type)
	old_level = carrier_step(family)
	entry = carrier_entry(family)
	entry["xp"] += amount
	check_unlocks("carrier", family, old_level, faction)

/datum/clash_progress/proc/check_unlocks(track, key, old_level, faction)
	switch(track)
		if("faction")
			var/list/entry = faction_entry(key)
			entry["best"] = faction_level(key)
			for(var/level in old_level + 1 to entry["best"])
				notify_faction_level(key, level)
		if("class")
			var/list/entry = class_entry(key)
			entry["best"] = class_level(key)
			for(var/level in old_level + 1 to entry["best"])
				notify_class_level(key, level, faction)
		if("weapon")
			var/list/entry = weapon_entry(key)
			entry["best"] = weapon_level(key)
			for(var/level in old_level + 1 to entry["best"])
				notify_weapon_level(key, level)
			if(!entry["mastered"] && entry["xp"] >= CLASH_WEAPON_MASTERY_XP)
				entry["mastered"] = TRUE
				clash_notify_unlock(ckey, CLASH_UNLOCK_MASTERY, clash_item_name(faction, key), "about 100 kills", key)
		if("carrier")
			var/list/entry = carrier_entry(key)
			entry["best"] = carrier_step(key)
			for(var/step in old_level + 1 to entry["best"])
				notify_carrier_step(key, step, faction)

/datum/clash_progress/proc/notify_faction_level(faction, level)
	var/source = "[clash_side_name(faction)] level [level]"
	var/found = FALSE
	for(var/list/rung as anything in GLOB.clash_faction_ladders[faction])
		if(rung[1] != level)
			continue
		found = TRUE
		var/kind = CLASH_UNLOCK_COSMETIC
		if(ispath(rung[2], /obj/item/weapon/gun))
			kind = CLASH_UNLOCK_GUN
		else if(ispath(rung[2], /obj/item/explosive/grenade))
			kind = CLASH_UNLOCK_GEAR
		else if(ispath(rung[2], /obj/item/storage))
			kind = CLASH_UNLOCK_CARRIER
		clash_notify_unlock(ckey, kind, clash_item_name(faction, rung[2]), source, rung[2])
	for(var/title in GLOB.clash_role_levels)
		if(GLOB.clash_role_levels[title] == level && clash_kit_faction_for_job(title) == faction)
			found = TRUE
			clash_notify_unlock(ckey, CLASH_UNLOCK_ROLE, title, source)
	if(!found)
		clash_notify_unlock(ckey, CLASH_UNLOCK_LEVEL, clash_insignia_name(faction, level), source)

/datum/clash_progress/proc/notify_class_level(class, level, faction)
	var/source = "[GLOB.clash_class_names[class]] level [level]"
	var/found = FALSE
	var/index = GLOB.clash_class_gear_levels.Find(level)
	if(index)
		var/gear = GLOB.clash_class_gear[class][index]
		var/item_type = clash_gear_type_for(gear, faction)
		if(item_type)
			found = TRUE
			clash_notify_unlock(ckey, CLASH_UNLOCK_GEAR, capitalize(GLOB.clash_gear_names[gear]), source, item_type)
	if(class != CLASH_CLASS_SUPPORT && level > 1)
		for(var/list/tier as anything in GLOB.clash_shop_tiers)
			if(tier[1] == level)
				found = TRUE
				clash_notify_unlock(ckey, CLASH_UNLOCK_SHOP, tier[2] == INFINITY ? "Every Shop item" : "Shop items up to [tier[2]] points", source)
	if(level == CLASH_LEVEL_CAP)
		found = TRUE
		clash_notify_unlock(ckey, CLASH_UNLOCK_COSMETIC, "Veteran [GLOB.clash_class_names[class]]", source)
	if(!found)
		clash_notify_unlock(ckey, CLASH_UNLOCK_LEVEL, GLOB.clash_class_names[class], source)

/datum/clash_progress/proc/notify_weapon_level(gun_type, level)
	var/list/unlocks = GLOB.clash_weapon_tracks[gun_type]
	if(level < 2 || level - 1 > length(unlocks))
		return
	var/list/unlock = unlocks[level - 1]
	var/obj/item/weapon/gun/gun = gun_type
	var/source = "[initial(gun.name)] level [level]"
	var/list/names = list()
	for(var/obj/item/attachable/attachment_type as anything in unlock["types"])
		names |= initial(attachment_type.name)
	if(!length(names))
		clash_notify_unlock(ckey, CLASH_UNLOCK_COSMETIC, "Engraving", source, gun_type)
		return
	clash_notify_unlock(ckey, CLASH_UNLOCK_ATTACHMENT, capitalize(english_list(names)), source, unlock["types"][1])

/datum/clash_progress/proc/notify_carrier_step(family, step, faction)
	var/list/carrier_step = GLOB.clash_carrier_tracks[family][step]
	if(!carrier_step[1])
		return
	build_clash_option_gates()
	for(var/index in 2 to length(carrier_step))
		var/item_type = carrier_step[index]
		var/list/gate = GLOB.clash_option_gates[clash_gate_key(faction, item_type)]
		if(gate?["level"] && faction_level(faction) >= gate["level"])
			return
		if(clash_item_option(faction, item_type))
			clash_notify_unlock(ckey, CLASH_UNLOCK_CARRIER, clash_item_name(faction, item_type), "[GLOB.clash_family_names[family]] step [step]", item_type)
			return

/proc/clash_progress_kill(mob/living/carbon/human/victim, mob/living/carbon/human/killer, cause, cause_object)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!clash_mode.match_live || !ishuman(killer) || killer.statistic_exempt || killer.faction == victim.faction)
		return
	var/list/attackers = clash_mode.last_attackers[victim.real_name]
	clash_award_xp(killer, CLASH_XP_KILL, CLASH_XP_SOURCE_KILL, clash_kill_weapon(killer, cause, cause_object, attackers?[killer.real_name]))
	clash_progress_leader_assist(killer)

/proc/clash_progress_assist(list/hit)
	clash_grant_xp(hit["ckey"], hit["faction"], GLOB.clash_job_classes[hit["job"]], CLASH_XP_ASSIST, CLASH_XP_SOURCE_ASSIST, hit["weapon"])

/proc/clash_progress_revive(mob/living/carbon/human/revived)
	for(var/mob/living/carbon/human/medic in range(1, revived))
		if(medic == revived || medic.faction != revived.faction || medic.life_revives_total <= medic.clash_revives_seen)
			continue
		medic.clash_revives_seen = medic.life_revives_total
		clash_award_xp(medic, CLASH_XP_REVIVE, CLASH_XP_SOURCE_REVIVE)
		return

/proc/clash_progress_capture(mob/living/carbon/human/runner)
	clash_award_xp(runner, CLASH_XP_CAPTURE, CLASH_XP_SOURCE_CAPTURE)

/proc/clash_progress_zone(datum/clash_zone/zone)
	if(!clash_progression_active())
		return
	for(var/mob/living/carbon/human/fighter as anything in zone.get_occupant_mobs())
		if(fighter.faction != zone.owner)
			continue
		var/datum/clash_progress/progress = clash_progress_of(fighter.ckey)
		if(!progress)
			continue
		progress.zone_seconds++
		if(!(progress.zone_seconds % CLASH_XP_ZONE_SECONDS))
			clash_award_xp(fighter, CLASH_XP_ZONE, CLASH_XP_SOURCE_ZONE)

/proc/clash_award_bot_kill(mob/living/carbon/human/body)
	if(!clash_progression_active() || !GLOB.clash_progression_settings["bot_xp"] || QDELETED(body))
		return
	var/mob/living/carbon/human/killer = body.last_damage_data?.resolve_mob()
	if(!ishuman(killer) || killer.faction == body.faction)
		return
	clash_award_xp(killer, CLASH_XP_BOT_KILL, CLASH_XP_SOURCE_BOT_KILL, clash_kill_weapon(killer, body.last_damage_data.cause_name, body.last_damage_data.resolve_cause()))

/proc/clash_progress_match_end(winner)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!winner || clash_mode.admin_tampered)
		return
	for(var/ckey in GLOB.clash_progress.players)
		var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
		if(progress.side == winner && GLOB.directory[ckey])
			clash_grant_xp(ckey, winner, progress.class_id, CLASH_XP_MATCH_WIN, CLASH_XP_SOURCE_MATCH_WIN)

/proc/clash_progress_round_end()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!clash_mode.admin_tampered)
		for(var/ckey in GLOB.clash_progress.players)
			var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
			if(progress.side && GLOB.directory[ckey])
				clash_grant_xp(ckey, progress.side, progress.class_id, CLASH_XP_ROUND, CLASH_XP_SOURCE_ROUND)
	GLOB.clash_progress.save_dirty()

/proc/clash_progress_join(mob/living/carbon/human/spawned)
	if(!clash_progression_active())
		return
	var/datum/clash_progress/progress = clash_progress_of(spawned.ckey)
	if(!progress)
		return
	progress.side = spawned.faction
	progress.class_id = GLOB.clash_job_classes[spawned.job]
	if(!progress.start_levels[progress.side])
		progress.start_levels[progress.side] = progress.faction_level(progress.side)
	if(progress.class_id && !progress.start_levels[progress.class_id])
		progress.start_levels[progress.class_id] = progress.class_level(progress.class_id)
	var/own = 0
	var/other = 0
	for(var/mob/living/carbon/human/player as anything in GLOB.alive_human_list)
		if(player == spawned || !player.client || !(player.faction in list(FACTION_MARINE, FACTION_UPP)))
			continue
		if(player.faction == spawned.faction)
			own++
		else
			other++
	if(own < other)
		progress.short_side = spawned.faction

/mob/living/carbon/human/var/clash_heal_pool = 0
/mob/living/carbon/human/var/clash_surgery_xp = 0
/obj/limb/var/clash_splint_paid = FALSE
/obj/structure/barricade/var/clash_builder_ckey
/obj/structure/barricade/var/clash_builder_faction
/obj/structure/barricade/var/clash_builder_class
/obj/structure/barricade/var/clash_enemy_damage = 0

/proc/clash_progress_match_start()
	for(var/ckey in GLOB.clash_progress.players)
		var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
		progress.support_xp = list()

/proc/clash_enemy_share(mob/attacker, faction, amount)
	if(!ismob(attacker) || attacker.faction == faction || !(attacker.faction in list(FACTION_MARINE, FACTION_UPP)))
		return 0
	return (attacker.mind?.ckey || attacker.ckey) ? amount : amount * CLASH_BOT_DAMAGE_SHARE

/proc/clash_grant_support_xp(ckey, faction, class, amount, source, route, cap)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!clash_progression_active() || !clash_mode.match_live)
		return
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return
	var/given = progress.support_xp[route] || 0
	amount = min(round(amount), cap - given)
	if(amount <= 0)
		return
	progress.support_xp[route] = given + amount
	clash_grant_xp(ckey, faction, class, amount, source)

/proc/clash_award_support_xp(mob/living/carbon/human/earner, amount, source, route, cap)
	if(earner.statistic_exempt)
		return
	clash_grant_support_xp(earner.mind?.ckey || earner.ckey, earner.faction, GLOB.clash_job_classes[earner.job || earner.mind?.clash_job], amount, source, route, cap)

/proc/clash_progress_leader_assist(mob/living/carbon/human/killer)
	for(var/mob/living/carbon/human/leader in range(CLASH_XP_LEADER_RANGE, killer))
		if(leader != killer && leader.stat == CONSCIOUS && leader.faction == killer.faction && GLOB.clash_job_classes[leader.job] == CLASH_CLASS_LEADER)
			clash_award_xp(leader, CLASH_XP_LEADER_ASSIST, CLASH_XP_SOURCE_LEADER)

/proc/clash_care_snapshot(mob/living/carbon/human/patient, mob/living/carbon/human/medic)
	if(!ishuman(patient) || !ishuman(medic) || patient == medic || patient.faction != medic.faction || patient.clash_heal_pool <= 0)
		return null
	var/list/splinted = list()
	for(var/obj/limb/limb as anything in patient.limbs)
		if(limb.status & LIMB_SPLINTED)
			splinted += limb
	return list("damage" = patient.getBruteLoss() + patient.getFireLoss(), "splinted" = splinted)

/proc/clash_care_settle(mob/living/carbon/human/patient, mob/living/carbon/human/medic, list/before)
	if(!before || QDELETED(patient) || QDELETED(medic))
		return
	var/healed = min(before["damage"] - (patient.getBruteLoss() + patient.getFireLoss()), patient.clash_heal_pool)
	if(healed > 0)
		patient.clash_heal_pool -= healed
		clash_award_support_xp(medic, healed / CLASH_XP_HEAL_HP, CLASH_XP_SOURCE_HEALING, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)
	var/list/splinted = before["splinted"]
	for(var/obj/limb/limb as anything in patient.limbs)
		if(!(limb.status & LIMB_SPLINTED) || !(limb.status & LIMB_BROKEN) || (limb in splinted) || limb.clash_splint_paid)
			continue
		limb.clash_splint_paid = TRUE
		clash_award_support_xp(medic, CLASH_XP_SPLINT, CLASH_XP_SOURCE_SPLINT, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/obj/item/stack/medical/bruise_pack/attack(mob/living/carbon/M, mob/user)
	var/list/before = clash_care_snapshot(M, user)
	. = ..()
	clash_care_settle(M, user, before)

/obj/item/stack/medical/ointment/attack(mob/living/carbon/M, mob/user)
	var/list/before = clash_care_snapshot(M, user)
	. = ..()
	clash_care_settle(M, user, before)

/obj/item/stack/medical/advanced/bruise_pack/attack(mob/living/carbon/M, mob/user)
	var/list/before = clash_care_snapshot(M, user)
	. = ..()
	clash_care_settle(M, user, before)

/obj/item/stack/medical/advanced/ointment/attack(mob/living/carbon/M, mob/user)
	var/list/before = clash_care_snapshot(M, user)
	. = ..()
	clash_care_settle(M, user, before)

/obj/item/stack/medical/splint/attack(mob/living/carbon/M, mob/user)
	var/list/before = clash_care_snapshot(M, user)
	. = ..()
	clash_care_settle(M, user, before)

/obj/item/reagent_container/hypospray/attack(mob/living/M, mob/living/user)
	var/mob/living/carbon/human/patient = M
	var/healing = clash_care_snapshot(patient, user) && patient.clash_heal_pool >= CLASH_HEAL_INJECT_POOL && reagents && (reagents.has_reagent("bicaridine") || reagents.has_reagent("kelotane") || reagents.has_reagent("tricordrazine") || reagents.has_reagent("meralyne") || reagents.has_reagent("dermaline"))
	. = ..()
	if(!. || !healing || QDELETED(patient))
		return
	patient.clash_heal_pool -= CLASH_HEAL_INJECT_POOL
	clash_award_support_xp(user, CLASH_XP_INJECT, CLASH_XP_SOURCE_HEALING, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/proc/clash_progress_surgery(mob/living/carbon/human/patient, mob/living/carbon/human/user)
	if(!clash_care_snapshot(patient, user) || patient.clash_surgery_xp >= CLASH_XP_SURGERY_PATIENT_CAP)
		return
	patient.clash_surgery_xp += CLASH_XP_SURGERY
	clash_award_support_xp(user, CLASH_XP_SURGERY, CLASH_XP_SOURCE_SURGERY, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/obj/structure/barricade/Initialize(mapload, mob/user)
	. = ..()
	var/mob/living/carbon/human/builder = user
	if(!ishuman(builder) || builder.statistic_exempt || !(builder.mind?.ckey || builder.ckey))
		return
	clash_builder_ckey = builder.mind?.ckey || builder.ckey
	clash_builder_faction = builder.faction
	clash_builder_class = GLOB.clash_job_classes[builder.job]

/obj/structure/barricade/proc/clash_absorbed(mob/attacker, damage)
	if(!clash_builder_ckey || damage <= 0)
		return
	var/share = clash_enemy_share(attacker, clash_builder_faction, damage)
	if(share <= 0)
		return
	clash_enemy_damage += share
	clash_grant_support_xp(clash_builder_ckey, clash_builder_faction, clash_builder_class, share / CLASH_XP_COVER_DAMAGE, CLASH_XP_SOURCE_COVER, CLASH_XP_SOURCE_COVER, CLASH_XP_ENGINEERING_CAP)

/obj/structure/barricade/bullet_act(obj/projectile/bullet)
	var/before = health
	. = ..()
	clash_absorbed(bullet.firer, before - max(health, 0))

/obj/structure/barricade/ex_act(severity, direction, datum/cause_data/cause_data)
	var/before = health
	. = ..()
	clash_absorbed(cause_data?.resolve_mob(), before - max(health, 0))

/obj/structure/barricade/update_health(damage, nomessage)
	var/mob/living/carbon/human/repairer = usr
	var/before = health
	. = ..()
	if(damage >= 0 || clash_enemy_damage <= 0 || !ishuman(repairer) || repairer.faction != clash_builder_faction)
		return
	var/repaired = min(health - before, clash_enemy_damage)
	if(repaired <= 0)
		return
	clash_enemy_damage -= repaired
	clash_award_support_xp(repairer, repaired / CLASH_XP_REPAIR_HP, CLASH_XP_SOURCE_REPAIR, CLASH_XP_SOURCE_COVER, CLASH_XP_ENGINEERING_CAP)

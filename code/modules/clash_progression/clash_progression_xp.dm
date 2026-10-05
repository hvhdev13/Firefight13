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

/proc/clash_award_xp(mob/living/carbon/human/earner, amount, source, gun_type, gear_amount)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode) || !clash_mode.match_live || earner.statistic_exempt)
		return
	clash_grant_xp(earner.mind?.ckey || earner.ckey, earner.faction, GLOB.clash_job_classes[earner.job || earner.mind?.clash_job], amount, source, gun_type, gear_amount)

/proc/clash_grant_xp(ckey, faction, class, amount, source, gun_type, gear_amount)
	if(!clash_progression_active() || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return
	var/multiplier = GLOB.clash_progression_settings["xp_multiplier"] * GLOB.clash_xp_boost.current() * (progress.short_side == faction ? CLASH_SHORT_SIDE_BONUS : 1)
	gear_amount = round((isnull(gear_amount) ? amount : gear_amount) * multiplier, 1)
	amount *= GLOB.clash_progression_settings["xp_multiplier"] * GLOB.clash_xp_boost.current()
	var/bonus = progress.short_side == faction ? round(amount * (CLASH_SHORT_SIDE_BONUS - 1), 1) : 0
	amount = round(amount, 1)
	if(amount + bonus <= 0)
		return
	progress.ledger[source] = (progress.ledger[source] || 0) + amount
	if(bonus)
		progress.ledger["Short side bonus"] = (progress.ledger["Short side bonus"] || 0) + bonus
	clash_score_feed(ckey, amount + bonus, source)
	progress.add_xp(amount + bonus, faction, class, gun_type, gear_amount)

/datum/clash_progress/proc/add_xp(amount, faction, class, gun_type, gear_amount)
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
		entry["xp"] += gear_amount
		check_unlocks("weapon", gun_type, old_level, faction)
		family = clash_gun_family(gun_type)
	old_level = carrier_step(family)
	entry = carrier_entry(family)
	entry["xp"] += gear_amount
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
		else if(ispath(rung[2], /obj/item/explosive/grenade) || ispath(rung[2], /obj/item/clothing/head/helmet) || ispath(rung[2], /obj/item/clothing/suit) || ispath(rung[2], /obj/item/clothing/accessory/storage) || ispath(rung[2], /obj/item/clothing/mask/gas))
			kind = CLASH_UNLOCK_GEAR
		else if(ispath(rung[2], /obj/item/storage))
			kind = CLASH_UNLOCK_CARRIER
		clash_notify_unlock(ckey, kind, clash_item_name(faction, rung[2]), source, rung[2])
	for(var/title in GLOB.clash_role_levels)
		if(GLOB.clash_role_levels[title] == level && (title in GLOB.clash_arena_roles) && clash_kit_faction_for_job(title) == faction)
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
	if(class == CLASH_CLASS_MEDIC)
		for(var/list/perk as anything in GLOB.clash_medic_perks)
			if(perk[1] == level)
				found = TRUE
				clash_notify_unlock(ckey, CLASH_UNLOCK_PERK, perk[2], source)
	if(class == CLASH_CLASS_ENGINEER)
		for(var/list/perk as anything in GLOB.clash_engineer_perks)
			if(perk[1] == level)
				found = TRUE
				clash_notify_unlock(ckey, CLASH_UNLOCK_PERK, perk[2], source)
		for(var/tier in GLOB.clash_sentry_tiers)
			var/list/stats = GLOB.clash_sentry_tiers[tier]
			if(stats["level"] == level)
				found = TRUE
				clash_notify_unlock(ckey, CLASH_UNLOCK_SENTRY, stats["name"], source)
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
	clash_progress_payback(killer, CLASH_XP_PAYBACK)

/proc/clash_is_medic(mob/living/carbon/human/fighter)
	return clash_job_is_medic(fighter.job)

/proc/clash_job_is_medic(job)
	return GLOB.clash_job_classes[job] == CLASH_CLASS_MEDIC

/proc/clash_medic_perk(mob/living/carbon/human/medic, level)
	if(!clash_progression_gating())
		return TRUE
	var/datum/clash_progress/progress = clash_progress_of(medic.mind?.ckey || medic.ckey)
	return progress?.class_level(CLASH_CLASS_MEDIC) >= level

/proc/clash_is_engineer(mob/living/carbon/human/fighter)
	return clash_job_is_engineer(fighter.job)

/proc/clash_job_is_engineer(job)
	return GLOB.clash_job_classes[job] == CLASH_CLASS_ENGINEER

/proc/clash_engineer_level(ckey)
	if(!clash_progression_gating())
		return CLASH_LEVEL_CAP
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	return progress ? progress.class_level(CLASH_CLASS_ENGINEER) : 1

/proc/clash_engineer_perk(mob/living/carbon/human/engineer, level)
	return clash_engineer_level(engineer.mind?.ckey || engineer.ckey) >= level

/proc/clash_progress_payback(mob/living/carbon/human/killer, amount)
	var/mob/living/carbon/human/medic = killer.clash_revived_by?.resolve()
	if(!medic || world.time > killer.clash_revived_at + CLASH_PAYBACK_WINDOW)
		return
	killer.clash_revived_by = null
	clash_award_xp(medic, amount, CLASH_XP_SOURCE_PAYBACK)

/proc/clash_progress_assist(list/hit)
	clash_grant_xp(hit["ckey"], hit["faction"], GLOB.clash_job_classes[hit["job"]], CLASH_XP_ASSIST, CLASH_XP_SOURCE_ASSIST, hit["weapon"])

/proc/clash_progress_revive(mob/living/carbon/human/revived)
	if(!revived.clash_enemy_death)
		return
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
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	var/list/hits = clash_mode.recent_damage[body.real_name] || clash_mode.last_attackers[body.real_name]
	clash_award_xp(killer, CLASH_XP_BOT_KILL, CLASH_XP_SOURCE_BOT_KILL, clash_kill_weapon(killer, body.last_damage_data.cause_name, body.last_damage_data.resolve_cause(), hits?[killer.real_name]), CLASH_XP_KILL)
	clash_progress_payback(killer, round(CLASH_XP_PAYBACK * CLASH_BOT_DAMAGE_SHARE))

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
		var/winner
		switch(clash_mode.round_finished)
			if(MODE_INFESTATION_M_MAJOR, MODE_INFESTATION_M_MINOR)
				winner = FACTION_MARINE
			if(MODE_FACTION_CLASH_UPP_MAJOR, MODE_FACTION_CLASH_UPP_MINOR)
				winner = FACTION_UPP
		for(var/ckey in GLOB.clash_progress.players)
			var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
			if(progress.side && GLOB.directory[ckey])
				clash_grant_xp(ckey, progress.side, progress.class_id, CLASH_XP_ROUND, CLASH_XP_SOURCE_ROUND)
				if(progress.side == winner)
					clash_grant_xp(ckey, winner, progress.class_id, CLASH_XP_ROUND_WIN, CLASH_XP_SOURCE_ROUND_WIN)
	GLOB.clash_progress.save_dirty()
	if(clash_progression_active())
		GLOB.clash_xp_boost.round_ended()

/proc/clash_progress_join(mob/living/carbon/human/spawned)
	if(!clash_progression_active())
		return
	var/datum/clash_progress/progress = clash_progress_of(spawned.ckey)
	if(!progress)
		return
	progress.side = spawned.faction
	progress.class_id = GLOB.clash_job_classes[spawned.job]
	GLOB.clash_xp_boost.greet(spawned)
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
/mob/living/carbon/human/var/clash_enemy_hurt = FALSE
/mob/living/carbon/human/var/clash_surgery_xp = 0
/mob/living/carbon/human/var/clash_heal_carry = 0
/mob/living/carbon/human/var/clash_repair_carry = 0
/obj/limb/var/clash_splint_paid = FALSE
/obj/structure/barricade/var/clash_builder_ckey
/obj/structure/barricade/var/clash_builder_faction
/obj/structure/barricade/var/clash_enemy_damage = 0
/obj/structure/barricade/var/clash_cover_carry = 0

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
	if(!(killer.mind?.ckey || killer.ckey))
		return
	for(var/mob/living/carbon/human/leader in range(CLASH_XP_LEADER_RANGE, killer))
		if(leader != killer && leader.stat == CONSCIOUS && leader.faction == killer.faction && GLOB.clash_job_classes[leader.job] == CLASH_CLASS_LEADER)
			clash_award_xp(leader, CLASH_XP_LEADER_ASSIST, CLASH_XP_SOURCE_LEADER)

/proc/clash_hurt_by_enemy(mob/living/carbon/human/patient)
	if(!patient.clash_enemy_hurt && (patient.clash_heal_pool > 0 || clash_enemy_share(patient.last_damage_data?.resolve_mob(), patient.faction, 1)))
		patient.clash_enemy_hurt = TRUE
	return patient.clash_enemy_hurt

/proc/clash_care_snapshot(mob/living/carbon/human/patient, mob/living/carbon/human/medic, obj/item/tool)
	if(!ishuman(patient) || !ishuman(medic) || patient == medic || patient.faction != medic.faction || !clash_hurt_by_enemy(patient))
		return null
	var/list/splinted = list()
	for(var/obj/limb/limb as anything in patient.limbs)
		if(limb.status & LIMB_SPLINTED)
			splinted += limb
	var/obj/item/stack/medical/kit = istype(tool, /obj/item/stack/medical) && !istype(tool, /obj/item/stack/medical/splint) ? tool : null
	var/injector = istype(tool, /obj/item/reagent_container/hypospray) && patient.health < patient.maxHealth
	return list("damage" = patient.getBruteLoss() + patient.getFireLoss(), "splinted" = splinted, "injector" = injector, "kit" = kit, "kit_amount" = kit?.amount)

/proc/clash_care_settle(mob/living/carbon/human/patient, mob/living/carbon/human/medic, list/before, result)
	if(!before || QDELETED(patient) || QDELETED(medic))
		return
	if(before["injector"] && result)
		patient.clash_care_medic = WEAKREF(medic)
		patient.clash_care_until = world.time + CLASH_CARE_WINDOW
		clash_award_support_xp(medic, CLASH_XP_INJECT, CLASH_XP_SOURCE_HEALING, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)
		clash_credit_heal(medic, patient, before["damage"] - (patient.getBruteLoss() + patient.getFireLoss()))
		return
	var/obj/item/stack/medical/kit = before["kit"]
	if(kit && (QDELETED(kit) || kit.amount < before["kit_amount"]))
		clash_award_support_xp(medic, CLASH_XP_TREAT, CLASH_XP_SOURCE_HEALING, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)
	clash_credit_heal(medic, patient, before["damage"] - (patient.getBruteLoss() + patient.getFireLoss()))
	var/list/splinted = before["splinted"]
	for(var/obj/limb/limb as anything in patient.limbs)
		if(!(limb.status & LIMB_SPLINTED) || !(limb.status & LIMB_BROKEN) || (limb in splinted) || limb.clash_splint_paid)
			continue
		limb.clash_splint_paid = TRUE
		clash_award_support_xp(medic, CLASH_XP_SPLINT, CLASH_XP_SOURCE_SPLINT, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/proc/clash_credit_heal(mob/living/carbon/human/medic, mob/living/carbon/human/patient, healed)
	healed = min(healed, patient.clash_heal_pool)
	if(healed <= 0)
		return
	patient.clash_heal_pool -= healed
	medic.clash_heal_carry += healed
	var/xp = round(medic.clash_heal_carry / CLASH_XP_HEAL_HP)
	medic.clash_heal_carry -= xp * CLASH_XP_HEAL_HP
	clash_award_support_xp(medic, xp, CLASH_XP_SOURCE_HEALING, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/proc/clash_progress_surgery(mob/living/carbon/human/patient, mob/living/carbon/human/user)
	if(!clash_care_snapshot(patient, user) || patient.clash_surgery_xp >= CLASH_XP_SURGERY_PATIENT_CAP)
		return
	patient.clash_surgery_xp += CLASH_XP_SURGERY
	clash_award_support_xp(user, CLASH_XP_SURGERY, CLASH_XP_SOURCE_SURGERY, CLASH_XP_SOURCE_HEALING, CLASH_XP_MEDICAL_CAP)

/proc/clash_note_barricade_builder(obj/structure/barricade/barricade, mob/living/carbon/human/builder)
	if(!ishuman(builder) || builder.statistic_exempt || !(builder.mind?.ckey || builder.ckey) || GLOB.clash_job_classes[builder.job] != CLASH_CLASS_ENGINEER)
		return
	barricade.clash_builder_ckey = builder.mind?.ckey || builder.ckey
	barricade.clash_builder_faction = builder.faction
	if(clash_fast_medicine() && clash_engineer_perk(builder, CLASH_PERK_HARDENED))
		barricade.maxhealth = round(barricade.maxhealth * CLASH_HARDENED_MULT)
		barricade.health = barricade.maxhealth

/proc/clash_barricade_absorbed(obj/structure/barricade/barricade, attacker, damage)
	if(istype(attacker, /datum/cause_data))
		var/datum/cause_data/cause = attacker
		attacker = cause.resolve_mob()
	damage = min(damage, barricade.health)
	if(!barricade.clash_builder_ckey || damage <= 0)
		return
	var/share = clash_enemy_share(attacker, barricade.clash_builder_faction, damage)
	if(share <= 0)
		return
	barricade.clash_enemy_damage += share
	barricade.clash_cover_carry += share
	var/xp = round(barricade.clash_cover_carry / CLASH_XP_COVER_DAMAGE)
	barricade.clash_cover_carry -= xp * CLASH_XP_COVER_DAMAGE
	clash_grant_support_xp(barricade.clash_builder_ckey, barricade.clash_builder_faction, CLASH_CLASS_ENGINEER, xp, CLASH_XP_SOURCE_COVER, CLASH_XP_SOURCE_COVER, CLASH_XP_ENGINEERING_CAP)

/proc/clash_barricade_repaired(obj/structure/barricade/barricade, damage)
	var/mob/living/carbon/human/repairer = usr
	if(damage >= 0 || barricade.clash_enemy_damage <= 0 || !ishuman(repairer) || repairer.faction != barricade.clash_builder_faction || GLOB.clash_job_classes[repairer.job] != CLASH_CLASS_ENGINEER)
		return
	var/repaired = min(-damage, barricade.maxhealth - barricade.health, barricade.clash_enemy_damage)
	if(repaired <= 0)
		return
	barricade.clash_enemy_damage -= repaired
	clash_progress_repair(repairer, repaired)

/proc/clash_progress_repair(mob/living/carbon/human/repairer, repaired)
	repairer.clash_repair_carry += repaired
	var/xp = round(repairer.clash_repair_carry / CLASH_XP_REPAIR_HP)
	repairer.clash_repair_carry -= xp * CLASH_XP_REPAIR_HP
	clash_award_support_xp(repairer, xp, CLASH_XP_SOURCE_REPAIR, CLASH_XP_SOURCE_COVER, CLASH_XP_ENGINEERING_CAP)

/proc/clash_progress_resupply(owner_ckey, faction)
	clash_grant_support_xp(owner_ckey, faction, CLASH_CLASS_ENGINEER, CLASH_XP_RESUPPLY, CLASH_XP_SOURCE_RESUPPLY, CLASH_XP_SOURCE_COVER, CLASH_XP_ENGINEERING_CAP)

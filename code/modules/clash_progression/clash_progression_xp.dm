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
	progress.add_xp(amount + bonus, faction, class, gun_type)

/datum/clash_progress/proc/add_xp(amount, faction, class, gun_type)
	dirty = TRUE
	var/list/entry = faction_entry(faction)
	entry["xp"] += amount
	check_unlocks("faction", faction)
	if(class)
		entry = class_entry(class)
		entry["xp"] += amount
		check_unlocks("class", class)
	if(!gun_type)
		return
	if(ispath(gun_type, /obj/item/explosive/grenade))
		entry = carrier_entry(CLASH_FAMILY_GRENADE)
		entry["xp"] += amount
		check_unlocks("carrier", CLASH_FAMILY_GRENADE)
		return
	if(!ispath(gun_type, /obj/item/weapon/gun))
		return
	entry = weapon_entry(gun_type)
	entry["xp"] += amount
	check_unlocks("weapon", gun_type)
	var/family = clash_gun_family(gun_type)
	entry = carrier_entry(family)
	entry["xp"] += amount
	check_unlocks("carrier", family)

/datum/clash_progress/proc/check_unlocks(track, key)
	switch(track)
		if("faction")
			var/list/entry = faction_entry(key)
			entry["best"] = faction_level(key)
		if("class")
			var/list/entry = class_entry(key)
			entry["best"] = class_level(key)
		if("weapon")
			var/list/entry = weapon_entry(key)
			entry["best"] = weapon_level(key)
			entry["mastered"] = entry["mastered"] || entry["xp"] >= CLASH_WEAPON_MASTERY_XP
		if("carrier")
			var/list/entry = carrier_entry(key)
			entry["best"] = carrier_step(key)

/proc/clash_progress_kill(mob/living/carbon/human/victim, mob/living/carbon/human/killer, cause, cause_object)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!clash_mode.match_live || !ishuman(killer) || killer.statistic_exempt || killer.faction == victim.faction)
		return
	var/list/attackers = clash_mode.last_attackers[victim.real_name]
	clash_award_xp(killer, CLASH_XP_KILL, CLASH_XP_SOURCE_KILL, clash_kill_weapon(killer, cause, cause_object, attackers?[killer.real_name]))

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
	var/datum/clash_progress/progress = clash_progress_of(killer.mind?.ckey || killer.ckey)
	if(!progress || progress.bot_xp_match >= CLASH_XP_BOT_CAP)
		return
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(clash_mode) || !clash_mode.match_live || killer.statistic_exempt)
		return
	var/amount = min(CLASH_XP_BOT_KILL, CLASH_XP_BOT_CAP - progress.bot_xp_match)
	progress.bot_xp_match += amount
	clash_award_xp(killer, amount, CLASH_XP_SOURCE_BOT_KILL, clash_kill_weapon(killer, body.last_damage_data.cause_name, body.last_damage_data.resolve_cause()))

/proc/clash_progress_match_start()
	for(var/ckey in GLOB.clash_progress.players)
		var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
		progress.bot_xp_match = 0

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

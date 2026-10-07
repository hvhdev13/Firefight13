/proc/clash_next_unlock_text(ckey, faction, separator = " ")
	if(!clash_progression_gating() || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return null
	var/level = progress.faction_level(faction)
	var/list/entry = progress.factions[faction]
	var/xp = entry ? entry["xp"] : 0
	for(var/next in level + 1 to CLASH_LEVEL_CAP)
		var/list/names = list()
		for(var/list/rung as anything in GLOB.clash_faction_ladders[faction])
			if(rung[1] == next)
				names += clash_item_name(faction, rung[2])
		for(var/title in GLOB.clash_role_levels)
			if(GLOB.clash_role_levels[title] == next && (title in GLOB.clash_arena_roles) && clash_kit_faction_for_job(title) == faction)
				names += "[clash_role_name(title)] role"
		for(var/perk_type in GLOB.clash_perks)
			var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
			if(!perk.class && perk.level == next)
				names += "[perk.name] perk"
		if(length(names))
			return "Your next unlock:[separator]Level [next], [clash_number_text(max(0, clash_faction_xp_for(next) - xp))] XP to go.[separator]Unlocks: [english_list(names)]"
	return null

/proc/clash_scoreboard_level(ckey, faction)
	if(!ckey || !clash_progression_active())
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	return progress?.faction_level(faction)

/proc/clash_progress_report(ckey)
	if(!clash_progression_active())
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress?.side)
		return null
	var/list/sources = list()
	var/total = 0
	for(var/source in progress.ledger)
		sources += list(list("source" = source, "xp" = progress.ledger[source]))
		total += progress.ledger[source]
	var/side = progress.side
	var/faction_level = progress.faction_level(side)
	var/class = progress.class_id
	return list(
		"total" = total,
		"sources" = sources,
		"side" = clash_side_name(side),
		"faction_level" = faction_level,
		"faction_start" = progress.start_levels[side] || faction_level,
		"insignia" = clash_insignia_name(side, faction_level),
		"class" = class ? GLOB.clash_class_names[class] : null,
		"class_level" = class ? progress.class_level(class) : null,
		"class_start" = class ? (progress.start_levels[class] || progress.class_level(class)) : null,
		"unlocks" = progress.unlocked_round,
		"next" = clash_next_unlock_text(ckey, side),
	)

/proc/clash_level_bar(xp, level, base)
	if(level >= CLASH_LEVEL_CAP)
		return list("to_next" = 0, "fill" = 1)
	var/floor_xp = clash_level_xp_for(level, base)
	var/next_xp = clash_level_xp_for(level + 1, base)
	return list("to_next" = max(0, next_xp - xp), "fill" = clamp((xp - floor_xp) / (next_xp - floor_xp), 0, 1))

/proc/clash_progress_ui_data(ckey, job, primary_type, gun_type, sidearm_type)
	if(!clash_progression_gating())
		return null
	build_clash_option_gates()
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	var/faction = clash_kit_faction_for_job(job)
	var/class = GLOB.clash_job_classes[job]
	var/faction_level = progress.faction_level(faction)
	var/class_level = progress.class_level(class)
	var/list/faction_entry = progress.factions[faction]
	var/list/class_entry = progress.classes[class]
	var/list/locks = list()
	var/list/fresh = list()
	var/list/ranks = list()
	for(var/slot in GLOB.clash_kit_menu[faction])
		var/attachment = clash_is_attachment_slot(slot)
		var/slot_gun = clash_is_sidearm_attachment_slot(slot) ? sidearm_type : primary_type
		for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[faction][slot])
			ranks[option.id] = clash_option_rank(progress, option, class, slot_gun)
			var/lock_text = clash_option_lock_text(ckey, option.id, job, slot_gun)
			if(lock_text)
				locks[option.id] = lock_text
				continue
			var/list/gate = GLOB.clash_option_gates[clash_gate_key(faction, option.item_type)]
			if((GLOB.clash_perks[option.item_type] || (attachment ? slot_gun && clash_kit_attachment_fits(option.item_type, slot_gun) : gate && gate["kind"] != CLASH_GATE_FREE)) && !(option.id in progress.seen))
				fresh += option.id
	var/list/role_locks = list()
	var/client/player = GLOB.directory[ckey]
	var/list/roles = get_clash_kit_roles()
	for(var/title in roles[faction])
		var/lock_text = clash_role_lock_text(player, title)
		if(lock_text)
			role_locks[title] = lock_text
	var/list/shop_locks = list()
	var/list/shop_items = get_clash_shop(job)["by_id"]
	for(var/id in shop_items)
		var/lock_text = clash_shop_item_lock_text(ckey, job, shop_items[id]["cost"], text2path(id), gun_type)
		if(lock_text)
			shop_locks[id] = lock_text
	return list(
		"side" = clash_side_name(faction),
		"faction_level" = faction_level,
		"insignia" = clash_insignia_name(faction, faction_level),
		"faction_bar" = clash_level_bar(faction_entry ? faction_entry["xp"] : 0, faction_level, CLASH_FACTION_XP_BASE),
		"class" = GLOB.clash_class_names[class],
		"class_level" = class_level,
		"class_bar" = clash_level_bar(class_entry ? class_entry["xp"] : 0, class_level, CLASH_CLASS_XP_BASE),
		"next" = clash_next_unlock_text(ckey, faction),
		"locks" = locks,
		"ranks" = ranks,
		"fresh" = fresh,
		"role_locks" = role_locks,
		"shop_locks" = shop_locks,
		"gun" = clash_gun_progress(progress, clash_track_type(gun_type)),
		"sidearm_gun" = clash_gun_progress(progress, clash_track_type(sidearm_type)),
	)

/proc/clash_option_rank(datum/clash_progress/progress, datum/clash_kit_option/option, class, primary_type)
	var/datum/clash_perk/perk = GLOB.clash_perks[option.item_type]
	if(perk)
		return perk.level
	if(clash_is_attachment_slot(option.slot))
		return GLOB.clash_weapon_unlock_levels[clash_track_type(primary_type)]?[option.item_type] || 1
	var/list/gate = clash_gate_for(option.faction, option.item_type)
	switch(gate?["kind"])
		if(CLASH_GATE_FACTION)
			return gate["level"]
		if(CLASH_GATE_CLASS)
			return clash_class_gear_level(class, gate["gear"]) || CLASH_LEVEL_CAP
		if(CLASH_GATE_TWIN)
			return max(gate["level"], clash_class_gear_level(class, gate["gear"]) || CLASH_LEVEL_CAP)
		if(CLASH_GATE_CLASS_LEVEL)
			return gate["level"]
		if(CLASH_GATE_CARRIER)
			var/by_xp = progress.level_from_xp(gate["xp"], CLASH_FACTION_XP_BASE)
			return gate["level"] ? min(gate["level"], by_xp) : by_xp
	return 1

/proc/clash_gun_progress(datum/clash_progress/progress, gun_type)
	var/list/unlocks = GLOB.clash_weapon_tracks[gun_type]
	if(!unlocks)
		return null
	var/list/entry = progress.weapons["[gun_type]"]
	var/xp = entry ? entry["xp"] : 0
	var/level = progress.weapon_level(gun_type)
	var/obj/item/weapon/gun/gun = gun_type
	. = list(
		"name" = initial(gun.name),
		"level" = level,
		"max" = length(unlocks) + 1,
		"mastery" = clamp(xp / CLASH_WEAPON_MASTERY_XP, 0, 1),
		"mastered" = !!entry?["mastered"],
	)
	if(level > length(unlocks))
		return
	var/list/unlock = unlocks[level]
	var/list/names = list()
	for(var/obj/item/attachable/attachment_type as anything in unlock["types"])
		names |= initial(attachment_type.name)
	.["next"] = length(names) ? capitalize(english_list(names)) : "Your name engraved on it"
	.["kills_to_go"] = CEILING(max(0, unlock["xp"] - xp) / CLASH_XP_PER_KILL_ESTIMATE, 1)

/proc/clash_career_progress(ckey)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return null
	build_clash_kit_catalog()
	var/list/factions = list()
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/level = progress.faction_level(faction)
		var/list/entry = progress.factions[faction]
		factions += list(list("id" = faction, "side" = clash_side_name(faction), "level" = level, "insignia" = clash_insignia_name(faction, level), "xp" = entry ? entry["xp"] : 0))
	var/list/classes = list()
	var/list/played_classes = list()
	for(var/title in GLOB.clash_arena_roles)
		played_classes |= GLOB.clash_job_classes[title]
	for(var/class in GLOB.clash_class_names)
		if(!(class in played_classes))
			continue
		var/list/entry = progress.classes[class]
		classes += list(list("id" = class, "name" = GLOB.clash_class_names[class], "level" = progress.class_level(class), "xp" = entry ? entry["xp"] : 0))
	var/list/carriers = list()
	for(var/family in GLOB.clash_carrier_tracks)
		var/list/entry = progress.carriers[family]
		carriers += list(list("id" = family, "family" = capitalize(GLOB.clash_family_names[family]), "step" = progress.carrier_step(family), "steps" = length(GLOB.clash_carrier_tracks[family]), "xp" = entry ? entry["xp"] : 0))
	var/list/weapons = list()
	for(var/gun_type in GLOB.clash_weapon_tracks)
		var/obj/item/weapon/gun/gun = gun_type
		var/list/entry = progress.weapons["[gun_type]"]
		weapons += list(list("type" = "[gun_type]", "name" = initial(gun.name), "level" = progress.weapon_level(gun_type), "max" = length(GLOB.clash_weapon_tracks[gun_type]) + 1, "xp" = entry ? entry["xp"] : 0, "mastery" = entry ? clamp(entry["xp"] / CLASH_WEAPON_MASTERY_XP, 0, 1) : 0, "mastered" = !!entry?["mastered"]))
	return list("factions" = factions, "classes" = classes, "carriers" = carriers, "weapons" = weapons)

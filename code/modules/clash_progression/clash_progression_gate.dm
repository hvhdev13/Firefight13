GLOBAL_VAR_INIT(clash_role_gate_bypass, FALSE)
GLOBAL_LIST_INIT(clash_progression_mode_tags, build_clash_progression_mode_tags())
GLOBAL_DATUM_INIT(clash_progress_blank, /datum/clash_progress, new)

/proc/build_clash_progression_mode_tags()
	. = list()
	for(var/datum/game_mode/extended/faction_clash/hvh/mode_type as anything in typesof(/datum/game_mode/extended/faction_clash/hvh))
		if(initial(mode_type.progression) && initial(mode_type.config_tag))
			. += initial(mode_type.config_tag)

/proc/clash_progression_gating()
	if(!GLOB.clash_progression_settings["enabled"])
		return FALSE
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		return clash_mode.progression
	return !SSticker.mode && (GLOB.master_mode in GLOB.clash_progression_mode_tags)

/proc/clash_gate_progress(ckey)
	return clash_progress_of(ckey) || GLOB.clash_progress_blank

/proc/clash_side_name(faction)
	return faction == FACTION_UPP ? "UPP" : "USCM"

/proc/clash_number_text(value)
	. = "[round(value)]"
	for(var/index = length(.) - 3; index > 0; index -= 3)
		. = "[copytext(., 1, index + 1)],[copytext(., index + 1)]"

/proc/clash_option_unlocked(ckey, option_id, job, primary_type)
	return !clash_option_lock_text(ckey, option_id, job, primary_type)

/proc/clash_option_lock_text(ckey, option_id, job, primary_type)
	var/datum/clash_kit_option/option = get_clash_kit_option(option_id)
	if(!option || !clash_progression_gating())
		return null
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	if(option.slot in GLOB.clash_kit_attachment_slots)
		if(!primary_type)
			return null
		var/obj/item/weapon/gun/gun_type = primary_type
		var/list/levels = GLOB.clash_weapon_unlock_levels[primary_type]
		var/needed = levels?[option.item_type]
		if(!needed)
			return "Does not unlock on the [initial(gun_type.name)]"
		if(progress.weapon_level(primary_type) < needed)
			return "Unlocks at [initial(gun_type.name)] level [needed]"
		return null
	build_clash_option_gates()
	var/list/gate = GLOB.clash_option_gates[clash_gate_key(option.faction, option.item_type)]
	if(!gate)
		return null
	switch(gate["kind"])
		if(CLASH_GATE_FACTION)
			if(progress.faction_level(option.faction) < gate["level"])
				return "Unlocks at [clash_side_name(option.faction)] level [gate["level"]]"
		if(CLASH_GATE_CLASS)
			return clash_gear_lock_text(progress, GLOB.clash_job_classes[job], gate["gear"])
		if(CLASH_GATE_TWIN)
			if(progress.faction_level(option.faction) < gate["level"])
				return "Unlocks at [clash_side_name(option.faction)] level [gate["level"]]"
			return clash_gear_lock_text(progress, GLOB.clash_job_classes[job], gate["gear"])
		if(CLASH_GATE_CARRIER)
			if(progress.carrier_step(gate["family"]) < gate["step"])
				return "Unlocks at [clash_number_text(gate["xp"])] [GLOB.clash_family_names[gate["family"]]] XP"
	return null

/proc/clash_gear_lock_text(datum/clash_progress/progress, class, gear)
	var/level = clash_class_gear_level(class, gear)
	if(!level)
		return "Not issued to this role"
	if(progress.class_level(class) < level)
		return "Unlocks at [GLOB.clash_class_names[class]] level [level]"
	return null

/proc/clash_role_lock_text(client/player, title)
	var/level = GLOB.clash_role_levels[title]
	if(!level || !player || GLOB.clash_role_gate_bypass || !clash_progression_gating())
		return null
	var/faction = clash_kit_faction_for_job(title)
	var/datum/clash_progress/progress = clash_gate_progress(player.ckey)
	if(progress.faction_level(faction) >= level)
		return null
	return "Unlocks at [clash_side_name(faction)] level [level]"

/proc/clash_role_unlocked(client/player, title)
	return !clash_role_lock_text(player, title)

/datum/job/can_play_role_in_scenario(client/client)
	. = ..()
	if(. && !clash_role_unlocked(client, title))
		return FALSE

/proc/clash_late_join_lock_text(mob/new_player/player, datum/job/job, faction)
	var/lock_text = clash_role_lock_text(player.client, job.title)
	if(!lock_text)
		return null
	GLOB.clash_role_gate_bypass = TRUE
	var/open = GLOB.RoleAuthority.check_role_entry(player, job, latejoin = TRUE, faction = faction)
	GLOB.clash_role_gate_bypass = FALSE
	return open ? lock_text : null

/proc/clash_shop_item_lock_text(ckey, job, cost)
	if(!clash_progression_gating())
		return null
	var/class = GLOB.clash_job_classes[job]
	if(cost <= clash_shop_cost_limit(clash_gate_progress(ckey).class_level(class)))
		return null
	for(var/list/tier as anything in GLOB.clash_shop_tiers)
		if(tier[2] >= cost)
			return "Unlocks at [GLOB.clash_class_names[class] || "class"] level [tier[1]]"
	return null

/proc/clash_shop_item_unlocked(ckey, job, cost)
	return !clash_shop_item_lock_text(ckey, job, cost)

/proc/clash_shop_budget(ckey, job)
	if(!clash_progression_gating())
		return null
	var/level = clash_gate_progress(ckey).class_level(GLOB.clash_job_classes[job])
	return list(min(CLASH_SHOP_BASE + level, CLASH_SHOP_CAP), CLASH_SHOP_SNOWFLAKE_BASE + CLASH_SHOP_SNOWFLAKE_STEP * level)

/proc/clash_filter_kit(datum/clash_kit/kit, ckey, job)
	if(!kit || !clash_progression_gating())
		return kit
	var/faction = clash_kit_faction_for_job(job)
	var/list/starting = GLOB.clash_starting_kits[faction]
	var/datum/clash_kit/filtered = new
	filtered.name = kit.name
	filtered.extras = kit.extras
	filtered.removed = kit.removed
	filtered.fills = kit.fills
	for(var/slot in kit.choices)
		if(slot in GLOB.clash_kit_attachment_slots)
			continue
		var/id = kit.choices[slot]
		if(clash_option_lock_text(ckey, id, job))
			id = starting[slot] ? clash_kit_option_id(faction, slot, starting[slot]) : null
		if(id)
			filtered.choices[slot] = id
	var/datum/clash_kit_option/primary = filtered.get_option(KIT_SLOT_PRIMARY)
	if(!primary)
		return filtered
	for(var/slot in GLOB.clash_kit_attachment_slots)
		var/id = kit.choices[slot]
		if(id && !clash_option_lock_text(ckey, id, job, primary.item_type))
			filtered.choices[slot] = id
	return filtered

/proc/clash_set_progress_level(ckey, track, key, level)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress || !isnum(level))
		return FALSE
	level = round(level)
	var/list/entry
	switch(track)
		if("faction")
			if(!(key in list(FACTION_MARINE, FACTION_UPP)))
				return FALSE
			level = clamp(level, 1, CLASH_LEVEL_CAP)
			entry = progress.faction_entry(key)
			entry["xp"] = clash_faction_xp_for(level)
		if("class")
			if(!GLOB.clash_class_names[key])
				return FALSE
			level = clamp(level, 1, CLASH_LEVEL_CAP)
			entry = progress.class_entry(key)
			entry["xp"] = clash_class_xp_for(level)
		if("weapon")
			build_clash_kit_catalog()
			key = ispath(key) ? key : text2path(key)
			var/list/unlocks = GLOB.clash_weapon_tracks[key]
			if(!unlocks)
				return FALSE
			level = clamp(level, 1, length(unlocks) + 1)
			entry = progress.weapon_entry(key)
			entry["xp"] = level > 1 ? unlocks[level - 1]["xp"] : 0
			entry["mastered"] = entry["xp"] >= CLASH_WEAPON_MASTERY_XP
		if("carrier")
			var/list/steps = GLOB.clash_carrier_tracks[key]
			if(!steps)
				return FALSE
			level = clamp(level, 0, length(steps))
			entry = progress.carrier_entry(key)
			entry["xp"] = level ? steps[level][1] : 0
		else
			return FALSE
	entry["best"] = level
	progress.save()
	log_admin("[key_name(usr)] set the [track] progression of [ckey] for [key] to [level].")
	message_admins("[key_name_admin(usr)] set the [track] progression of [ckey] for [key] to [level].")
	return TRUE

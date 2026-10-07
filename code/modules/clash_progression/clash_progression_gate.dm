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

/proc/clash_track_type(gun_type)
	var/check = gun_type
	while(ispath(check, /obj/item/weapon/gun))
		if(GLOB.clash_weapon_tracks[check])
			return check
		check = type2parent(check)
	return gun_type

/proc/clash_effective_primary(datum/clash_kit/kit, job)
	var/datum/clash_kit_option/primary = kit?.get_option(KIT_SLOT_PRIMARY)
	if(primary)
		return primary.item_type
	var/list/issue = get_clash_issue_items(job)
	var/list/issued_gun = issue?[KIT_SLOT_PRIMARY]
	return issued_gun ? text2path(issued_gun["type"]) : null

/proc/clash_effective_sidearm(datum/clash_kit/kit, job)
	var/datum/clash_kit_option/sidearm = kit?.get_option(KIT_SLOT_SIDEARM)
	if(sidearm)
		return sidearm.item_type
	var/list/issue = get_clash_issue_items(job)
	var/list/issued_gun = issue?[KIT_SLOT_SIDEARM]
	return issued_gun ? text2path(issued_gun["type"]) : null

/proc/clash_attachment_lock_text(datum/clash_progress/progress, attachment_type, gun_type)
	var/track_type = clash_track_type(gun_type)
	var/obj/item/weapon/gun/gun = track_type
	var/list/levels = GLOB.clash_weapon_unlock_levels[track_type]
	var/needed = levels?[attachment_type]
	if(!needed)
		return "Does not unlock on the [initial(gun.name)]"
	if(progress.weapon_level(track_type) < needed)
		return "Unlocks at [initial(gun.name)] level [needed]"
	return null

/proc/clash_strip_locked_attachments(mob/living/carbon/human/wearer, ckey)
	if(!clash_progression_gating())
		return
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	for(var/obj/item/weapon/gun/gun in wearer.get_contents())
		var/track_type = clash_track_type(gun.type)
		var/list/levels = GLOB.clash_weapon_unlock_levels[track_type]
		if(!levels)
			continue
		var/level = progress.weapon_level(track_type)
		for(var/slot in gun.attachments)
			var/obj/item/attachable/attachment = gun.attachments[slot]
			if(!attachment || !(attachment.flags_attach_features & ATTACH_REMOVABLE) || !levels[attachment.type] || level >= levels[attachment.type])
				continue
			if(get_turf(gun))
				attachment.Detach(null, gun)
			else
				gun.attachments[slot] = null
			gun.update_attachable(slot)
			qdel(attachment)

/proc/clash_strip_locked_grenades(mob/living/carbon/human/wearer, ckey, job)
	if(!clash_progression_gating())
		return
	var/faction = clash_kit_faction_for_job(job)
	for(var/obj/item/explosive/grenade/grenade in wearer.get_contents())
		if(istype(grenade.loc, /obj/item/attachable) || !clash_option_lock_text(ckey, clash_kit_option_id(faction, KIT_SLOT_GRENADE, grenade.type), job))
			continue
		if(grenade.loc == wearer)
			wearer.temp_drop_inv_item(grenade, TRUE)
		qdel(grenade)

/proc/clash_filter_issue(list/issue, ckey, job)
	if(!issue || !clash_progression_gating())
		return issue
	var/list/issued_gun = issue[KIT_SLOT_PRIMARY]
	var/primary_type = issued_gun ? text2path(issued_gun["type"]) : null
	var/track_type = clash_track_type(primary_type)
	var/list/levels = GLOB.clash_weapon_unlock_levels[track_type]
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	var/level = progress.weapon_level(track_type)
	. = issue.Copy()
	var/faction = clash_kit_faction_for_job(job)
	var/list/starting = GLOB.clash_starting_kits[faction]
	for(var/slot in GLOB.clash_kit_worn_slots + KIT_SLOT_WEBBING)
		var/list/info = issue[slot]
		if(!info || !clash_gate_lock_text(progress, faction, text2path(info["type"]), job))
			continue
		var/obj/item/basic = starting[slot]
		if(basic)
			.[slot] = list("name" = initial(basic.name), "type" = "[basic]", "icon" = "[initial(basic.icon)]", "icon_state" = initial(basic.icon_state))
		else
			. -= slot
	var/list/grenade = issue[KIT_SLOT_GRENADE]
	if(grenade && clash_option_lock_text(ckey, clash_kit_option_id(faction, KIT_SLOT_GRENADE, text2path(grenade["type"])), job))
		. -= KIT_SLOT_GRENADE
	for(var/slot in GLOB.clash_kit_attachment_slots)
		var/list/info = issue[slot]
		var/needed = info ? levels?[text2path(info["type"])] : null
		if(needed && level < needed)
			. -= slot
	var/list/issued_sidearm = issue[KIT_SLOT_SIDEARM]
	var/sidearm_track = clash_track_type(issued_sidearm ? text2path(issued_sidearm["type"]) : null)
	var/list/sidearm_levels = GLOB.clash_weapon_unlock_levels[sidearm_track]
	var/sidearm_level = progress.weapon_level(sidearm_track)
	for(var/gun_slot in GLOB.clash_kit_sidearm_attachment_slots)
		var/slot = GLOB.clash_kit_sidearm_attachment_slots[gun_slot]
		var/list/info = issue[slot]
		var/needed = info ? sidearm_levels?[text2path(info["type"])] : null
		if(needed && sidearm_level < needed)
			. -= slot

/proc/clash_option_unlocked(ckey, option_id, job, primary_type)
	return !clash_option_lock_text(ckey, option_id, job, primary_type)

/proc/clash_option_lock_text(ckey, option_id, job, primary_type)
	var/datum/clash_kit_option/option = get_clash_kit_option(option_id)
	if(!option)
		return null
	if(option.only_class && option.only_class != GLOB.clash_job_classes[job])
		return "Only for [GLOB.clash_class_names[option.only_class]]s"
	if(option.slot == KIT_SLOT_ARMOR && ispath(primary_type, /obj/item/weapon/gun/smartgun))
		return "The M56A2 only fires with the M56 harness"
	var/list/blocked = clash_kit_blocked_slots(primary_type)
	if(blocked[option.slot])
		return blocked[option.slot]
	if(option.slot == KIT_SLOT_PRIMARY && option.only_class != GLOB.clash_job_classes[job] && (GLOB.clash_job_classes[job] in GLOB.clash_class_only_primaries))
		return "Machine Gunners carry a machine gun"
	var/datum/clash_perk/perk = GLOB.clash_perks[option.item_type]
	if(perk)
		return perk.lock_text(ckey, job)
	if(!clash_progression_gating())
		return null
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	if(option.slot == KIT_SLOT_SENTRY)
		var/level = GLOB.clash_sentry_tiers[clash_sentry_tier_of(option.item_type)]["level"]
		return progress.class_level(CLASH_CLASS_ENGINEER) < level ? "Unlocks at Engineer level [level]" : null
	if(clash_is_attachment_slot(option.slot))
		if(!primary_type || !clash_kit_attachment_fits(option.item_type, primary_type))
			return null
		return clash_attachment_lock_text(progress, option.item_type, primary_type)
	return clash_gate_lock_text(progress, option.faction, option.item_type, job)

/proc/clash_gate_for(faction, item_type)
	build_clash_option_gates()
	for(var/check = item_type; check; check = type2parent(check))
		var/list/gate = GLOB.clash_option_gates[clash_gate_key(faction, check)]
		if(gate)
			return gate
	return null

/proc/clash_gate_lock_text(datum/clash_progress/progress, faction, item_type, job)
	if(item_type in GLOB.clash_role_free_gear[job])
		return null
	var/list/gate = clash_gate_for(faction, item_type)
	if(!gate)
		return null
	switch(gate["kind"])
		if(CLASH_GATE_FACTION)
			if(progress.faction_level(faction) < gate["level"])
				return "Unlocks at [clash_side_name(faction)] level [gate["level"]]"
		if(CLASH_GATE_CLASS)
			return clash_gear_lock_text(progress, GLOB.clash_job_classes[job], gate["gear"])
		if(CLASH_GATE_TWIN)
			if(progress.faction_level(faction) < gate["level"])
				return "Unlocks at [clash_side_name(faction)] level [gate["level"]]"
			return clash_gear_lock_text(progress, GLOB.clash_job_classes[job], gate["gear"])
		if(CLASH_GATE_CLASS_LEVEL)
			if(progress.class_level(gate["class"]) < gate["level"])
				return "Unlocks at [GLOB.clash_class_names[gate["class"]]] level [gate["level"]]"
		if(CLASH_GATE_CARRIER)
			if(progress.carrier_step(gate["family"]) >= gate["step"] || (gate["level"] && progress.faction_level(faction) >= gate["level"]))
				return null
			var/list/entry = progress.carriers[gate["family"]]
			var/to_go = max(0, gate["xp"] - (entry ? entry["xp"] : 0))
			var/xp_text = "[clash_number_text(gate["xp"])] [GLOB.clash_family_names[gate["family"]]] XP ([clash_number_text(to_go)] to go)"
			return gate["level"] ? "Unlocks at [clash_side_name(faction)] level [gate["level"]] or [xp_text]" : "Unlocks at [xp_text]"
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

/datum/job/marine/can_play_role_in_scenario(client/client)
	return ..() && clash_role_unlocked(client, title)

/datum/job/civilian/can_play_role_in_scenario(client/client)
	return ..() && clash_role_unlocked(client, title)

/datum/job/logistics/can_play_role_in_scenario(client/client)
	return ..() && clash_role_unlocked(client, title)

/datum/job/antag/upp/can_play_role_in_scenario(client/client)
	return ..() && clash_role_unlocked(client, title)

/proc/clash_late_join_lock_text(mob/new_player/player, datum/job/job, faction)
	var/lock_text = clash_role_lock_text(player.client, job.title)
	if(!lock_text)
		return null
	GLOB.clash_role_gate_bypass = TRUE
	var/open = GLOB.RoleAuthority.check_role_entry(player, job, latejoin = TRUE, faction = faction)
	GLOB.clash_role_gate_bypass = FALSE
	return open ? lock_text : null

/proc/clash_shop_item_lock_text(ckey, job, cost, item_type, primary_type)
	if(!clash_progression_gating())
		return null
	if(ispath(item_type, /obj/item/attachable))
		if(!primary_type)
			return "Pick a primary to unlock attachments"
		return clash_attachment_lock_text(clash_gate_progress(ckey), item_type, primary_type)
	var/class = GLOB.clash_job_classes[job]
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	var/gate_text = clash_gate_lock_text(progress, clash_kit_faction_for_job(job), item_type, job)
	if(gate_text)
		return gate_text
	if(cost <= clash_shop_cost_limit(progress.class_level(class)))
		return null
	for(var/list/tier as anything in GLOB.clash_shop_tiers)
		if(tier[2] >= cost)
			return "Unlocks at [GLOB.clash_class_names[class] || "class"] level [tier[1]]"
	return null

/proc/clash_shop_item_unlocked(ckey, job, cost, item_type, primary_type)
	return !clash_shop_item_lock_text(ckey, job, cost, item_type, primary_type)

/proc/clash_shop_budget(ckey, job)
	if(!clash_progression_gating())
		return null
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	var/level = progress.class_level(GLOB.clash_job_classes[job])
	return list(min(CLASH_SHOP_BASE + round(CLASH_SHOP_LEVEL_STEP * level), CLASH_SHOP_CAP), CLASH_SHOP_SNOWFLAKE_BASE + CLASH_SHOP_SNOWFLAKE_STEP * level)

/proc/clash_filter_kit(datum/clash_kit/kit, ckey, job)
	if(!kit)
		return kit
	var/faction = clash_kit_faction_for_job(job)
	var/list/starting = GLOB.clash_starting_kits[faction]
	var/datum/clash_kit/filtered = new
	filtered.name = kit.name
	filtered.extras = kit.extras
	filtered.extra_slots = kit.extra_slots
	filtered.moves = kit.moves
	filtered.removed = kit.removed
	filtered.fills = kit.fills
	for(var/slot in kit.choices)
		if(clash_is_attachment_slot(slot))
			continue
		var/id = kit.choices[slot]
		if(clash_option_lock_text(ckey, id, job))
			id = starting[slot] ? clash_kit_option_id(faction, slot, starting[slot]) : null
			if(id && clash_option_lock_text(ckey, id, job))
				id = null
		if(id)
			filtered.choices[slot] = id
	var/gun_type = clash_effective_primary(filtered, job)
	if(gun_type)
		for(var/slot in GLOB.clash_kit_attachment_slots)
			var/id = kit.choices[slot]
			if(id && !clash_option_lock_text(ckey, id, job, gun_type))
				filtered.choices[slot] = id
	var/sidearm_type = clash_effective_sidearm(filtered, job)
	if(sidearm_type)
		for(var/gun_slot in GLOB.clash_kit_sidearm_attachment_slots)
			var/slot = GLOB.clash_kit_sidearm_attachment_slots[gun_slot]
			var/id = kit.choices[slot]
			if(id && !clash_option_lock_text(ckey, id, job, sidearm_type))
				filtered.choices[slot] = id
	return filtered

/proc/clash_set_progress_level(ckey, track, key, level, mob/admin = usr)
	if(!isnum(level))
		return FALSE
	level = round(level)
	var/xp
	switch(track)
		if("faction")
			level = clamp(level, 1, CLASH_LEVEL_CAP)
			xp = clash_faction_xp_for(level)
		if("class")
			level = clamp(level, 1, CLASH_LEVEL_CAP)
			xp = clash_class_xp_for(level)
		if("weapon")
			build_clash_kit_catalog()
			var/list/unlocks = GLOB.clash_weapon_tracks[ispath(key) ? key : text2path(key)]
			if(!unlocks)
				return FALSE
			level = clamp(level, 1, length(unlocks) + 1)
			xp = level > 1 ? unlocks[level - 1]["xp"] : 0
		if("carrier")
			var/list/steps = GLOB.clash_carrier_tracks[key]
			if(!steps)
				return FALSE
			level = clamp(level, 0, length(steps))
			xp = level ? steps[level][1] : 0
		else
			return FALSE
	return clash_set_progress_xp(ckey, track, key, xp, admin, "level [level]")

/proc/clash_set_progress_xp(ckey, track, key, xp, mob/admin = usr, shown)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress || !isnum(xp))
		return FALSE
	xp = max(round(xp), 0)
	var/faction = progress.side || FACTION_MARINE
	var/old_level
	var/list/entry
	var/track_name
	switch(track)
		if("faction")
			if(!(key in list(FACTION_MARINE, FACTION_UPP)))
				return FALSE
			faction = key
			old_level = progress.faction_level(key)
			entry = progress.faction_entry(key)
			entry["best"] = 1
			track_name = clash_side_name(key)
		if("class")
			if(!GLOB.clash_class_names[key])
				return FALSE
			old_level = progress.class_level(key)
			entry = progress.class_entry(key)
			entry["best"] = 1
			track_name = GLOB.clash_class_names[key]
		if("weapon")
			build_clash_kit_catalog()
			key = ispath(key) ? key : text2path(key)
			if(!GLOB.clash_weapon_tracks[key])
				return FALSE
			old_level = progress.weapon_level(key)
			entry = progress.weapon_entry(key)
			entry["best"] = 1
			entry["mastered"] = FALSE
			var/obj/item/weapon/gun/gun = key
			track_name = initial(gun.name)
		if("carrier")
			if(!GLOB.clash_carrier_tracks[key])
				return FALSE
			old_level = progress.carrier_step(key)
			entry = progress.carrier_entry(key)
			entry["best"] = 0
			track_name = "[capitalize(GLOB.clash_family_names[key])] ammo carrier"
		else
			return FALSE
	entry["xp"] = xp
	progress.check_unlocks(track, key, old_level, faction)
	progress.save()
	var/new_level = entry["best"]
	var/client/target = GLOB.directory[ckey]
	if(target && new_level < old_level)
		to_chat(target, SPAN_NOTICE("An admin set your [track_name] level to [new_level] (from [old_level]). Locked gear in your loadout falls back next spawn."))
	shown = shown || "[xp] XP"
	log_admin("[key_name(admin)] set the [track] progression of [ckey] for [key] to [shown].")
	message_admins("[key_name_admin(admin)] set the [track] progression of [ckey] for [key] to [shown].")
	return TRUE

/proc/clash_downgrade_locked_gear(mob/living/carbon/human/wearer, ckey, job, list/cosmetics)
	if(!clash_progression_gating())
		return
	var/faction = clash_kit_faction_for_job(job)
	var/list/starting = GLOB.clash_starting_kits[faction]
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	for(var/slot in GLOB.clash_kit_worn_slots)
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		var/obj/item/worn = wearer.get_item_by_slot(wear_slot)
		if(!worn || (worn.type in cosmetics) || !clash_gate_lock_text(progress, faction, worn.type, job))
			continue
		if(starting[slot])
			clash_kit_replace_worn(wearer, wear_slot, starting[slot])
			continue
		wearer.temp_drop_inv_item(worn, TRUE)
		qdel(worn)
	var/obj/item/clothing/accessory/storage/webbing = locate() in wearer.w_uniform?.accessories
	if(webbing && clash_gate_lock_text(progress, faction, webbing.type, job))
		clash_kit_fit_webbing(wearer, starting[KIT_SLOT_WEBBING], cosmetics)

GLOBAL_LIST_EMPTY(clash_trial_packs)
GLOBAL_LIST_EMPTY(clash_vendor_hidden)
GLOBAL_VAR_INIT(clash_trial_packs_built, FALSE)

/proc/clash_reset_trials()
	for(var/datum/supply_packs/pack as anything in GLOB.clash_trial_packs)
		GLOB.clash_trial_packs[pack] = FALSE

/proc/clash_vendor_laddered(item_type)
	if(!clash_progression_gating())
		return FALSE
	if(islist(item_type))
		for(var/each_type in item_type)
			if(clash_vendor_laddered(each_type))
				return TRUE
		return FALSE
	if(!ispath(item_type, /obj/item))
		return FALSE
	var/key = "[item_type]"
	if(isnull(GLOB.clash_vendor_hidden[key]))
		GLOB.clash_vendor_hidden[key] = clash_trial_item(item_type)
	return GLOB.clash_vendor_hidden[key]

/proc/clash_attachment_unlock_text(datum/clash_progress/progress, attachment_type)
	build_clash_kit_catalog()
	var/tracked = FALSE
	for(var/gun_type in GLOB.clash_weapon_unlock_levels)
		var/needed = GLOB.clash_weapon_unlock_levels[gun_type][attachment_type]
		if(!needed)
			continue
		if(progress.weapon_level(gun_type) >= needed)
			return null
		tracked = TRUE
	return tracked ? "Unlock it on a gun first" : "Does not unlock on any gun"

/proc/clash_vendor_lock_text(mob/living/carbon/human/user, item_type)
	if(islist(item_type))
		for(var/each_type in item_type)
			. = clash_vendor_lock_text(user, each_type)
			if(.)
				return
		return null
	if(!ispath(item_type, /obj/item))
		return null
	var/tier = clash_sentry_tier_of(item_type)
	if(tier)
		var/level = GLOB.clash_sentry_tiers[tier]["level"]
		return clash_engineer_level(user.mind?.ckey || user.ckey) < level ? "Unlocks at Engineer level [level]" : null
	var/datum/clash_progress/progress = clash_gate_progress(user.mind?.ckey || user.ckey)
	if(ispath(item_type, /obj/item/attachable))
		return clash_attachment_unlock_text(progress, item_type)
	return clash_gate_lock_text(progress, user.faction, item_type, user.job)

/proc/clash_vendor_label(mob/living/carbon/human/user, item_type)
	if(!ishuman(user) || !clash_vendor_laddered(item_type))
		return null
	return clash_vendor_lock_text(user, item_type) || "Unlocked, take it from your loadout"

/proc/clash_vendor_refuses(mob/living/carbon/human/user, list/itemspec)
	var/build_refusal = clash_build_refusal(user, itemspec[3])
	if(build_refusal)
		to_chat(user, SPAN_WARNING(build_refusal))
		return TRUE
	if(!clash_vendor_laddered(itemspec[3]))
		return FALSE
	to_chat(user, SPAN_WARNING("[itemspec[1]] is not sold here. [clash_vendor_label(user, itemspec[3]) || "Unlocked, take it from your loadout"]."))
	return TRUE

/proc/clash_label_vendor_products(obj/structure/machinery/cm_vending/vendor, mob/living/carbon/human/user, list/categories)
	if(!ishuman(user) || !clash_progression_gating())
		return
	var/list/products = vendor.get_available_products(user)
	for(var/list/category as anything in categories)
		for(var/list/display_item as anything in category["items"])
			var/list/itemspec = products[display_item["prod_index"]]
			var/label = clash_vendor_label(user, itemspec[3])
			if(label)
				display_item["prod_name"] = "[display_item["prod_name"]] ([label])"

/proc/clash_block_vendor_listing(obj/structure/machinery/cm_vending/vendor, mob/user, list/data)
	var/list/listing = data["stock_listing"]
	if(!listing || !clash_progression_gating())
		return
	var/list/products = vendor.get_available_products(user)
	for(var/index in 1 to min(length(listing), length(products)))
		var/list/itemspec = products[index]
		if(clash_vendor_laddered(itemspec[3]))
			listing[index] = (vendor.vend_flags & VEND_LIMITED_INVENTORY) ? 0 : FALSE

/proc/clash_attachment_allowed(mob/user, obj/item/attachable/attachment, obj/item/weapon/gun/gun)
	var/ckey = user?.mind?.ckey || user?.ckey
	if(!ishuman(user) || !ckey || !clash_progression_gating())
		return TRUE
	build_clash_kit_catalog()
	if(!GLOB.clash_weapon_unlock_levels[clash_track_type(gun.type)])
		return TRUE
	var/lock_text = clash_attachment_lock_text(clash_gate_progress(ckey), attachment.type, gun.type)
	if(!lock_text)
		return TRUE
	to_chat(user, SPAN_WARNING("[attachment] has not been unlocked on [gun] yet. [lock_text]."))
	return FALSE

/proc/clash_trial_item(item_type)
	if(ispath(item_type, /obj/item/attachable))
		build_clash_kit_catalog()
		for(var/gun_type in GLOB.clash_weapon_unlock_levels)
			if(GLOB.clash_weapon_unlock_levels[gun_type][item_type])
				return TRUE
		return FALSE
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/list/gate = clash_gate_for(faction, item_type)
		if(!gate || gate["kind"] == CLASH_GATE_FREE || (gate["kind"] == CLASH_GATE_CARRIER && !gate["xp"] && !gate["level"]))
			continue
		return TRUE
	return FALSE

/proc/clash_build_trial_packs()
	if(GLOB.clash_trial_packs_built)
		return
	GLOB.clash_trial_packs_built = TRUE
	for(var/pack_type in GLOB.supply_packs_datums)
		var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
		var/list/counts = list()
		var/list/kept = list()
		var/trial = FALSE
		for(var/item_type in pack.contains)
			if(clash_trial_item(item_type))
				trial = TRUE
				counts[item_type] = (counts[item_type] || 0) + 1
				if(counts[item_type] > CLASH_TRIAL_STOCK)
					continue
			kept += item_type
		if(trial)
			pack.contains = kept
			GLOB.clash_trial_packs[pack] = FALSE

/proc/clash_supply_pack_allowed(datum/supply_packs/supply_pack)
	if(!clash_progression_gating())
		return TRUE
	clash_build_trial_packs()
	return !GLOB.clash_trial_packs[supply_pack]

/proc/clash_trim_trial_order(datum/supply_order/order)
	if(!clash_progression_gating())
		return
	clash_build_trial_packs()
	var/list/seen = list()
	for(var/datum/supply_packs/pack as anything in order.objects.Copy())
		if(!(pack in GLOB.clash_trial_packs))
			continue
		if(pack in seen)
			order.objects -= pack
		seen += pack

/proc/clash_mark_trial_packs(list/ordered)
	if(!clash_progression_gating())
		return
	for(var/datum/supply_packs/pack as anything in ordered)
		if(pack in GLOB.clash_trial_packs)
			GLOB.clash_trial_packs[pack] = TRUE

/proc/clash_arena_remove_attachment_vendors()
	for(var/obj/structure/machinery/cm_vending/sorted/attachments/vendor in GLOB.machines)
		if(is_ground_level(vendor.z))
			qdel(vendor)

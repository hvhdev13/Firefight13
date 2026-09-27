/// Saved Faction Clash loadouts, ckey to list of slot name to /datum/clash_loadout
GLOBAL_LIST_EMPTY(clash_loadouts)
/// Loadouts equipped on spawn, ckey to list of job to slot name
GLOBAL_LIST_EMPTY(clash_auto_loadouts)
/// How many slots a player may keep per job
#define CLASH_LOADOUT_SLOTS 3

/datum/clash_loadout
	var/name
	var/job
	var/list/items = list()

/proc/clash_loadout_key(mob/user)
	if(!ishuman(user))
		return null
	var/mob/living/carbon/human/human_user = user
	return human_user.mind?.ckey || human_user.ckey

/proc/get_clash_loadouts(key)
	if(!key)
		return null
	if(!GLOB.clash_loadouts[key])
		GLOB.clash_loadouts[key] = list()
		GLOB.clash_auto_loadouts[key] = list()
		load_clash_loadouts(key)
	return GLOB.clash_loadouts[key]

/// Name of the slot this key equips on spawn as job, if any
/proc/get_clash_auto_slot(key, job)
	if(!get_clash_loadouts(key))
		return null
	var/list/auto = GLOB.clash_auto_loadouts[key]
	return auto[job]

/// Buys and equips a fresh spawn's chosen loadout for their role
/proc/clash_equip_spawn_loadout(mob/living/carbon/human/spawned)
	if(QDELETED(spawned) || spawned.stat == DEAD || !SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH) || clash_uses_kits())
		return
	var/key = clash_loadout_key(spawned)
	var/slot_name = get_clash_auto_slot(key, spawned.job)
	if(!slot_name)
		return
	var/list/slots = get_clash_loadouts_for_job(key, spawned.job)
	var/datum/clash_loadout/loadout = slots[slot_name]
	if(!loadout)
		return
	to_chat(spawned, SPAN_NOTICE("Equipping your saved loadout [slot_name]."))
	loadout.restore(spawned)

/proc/get_clash_loadouts_for_job(key, job)
	var/list/all_slots = get_clash_loadouts(key)
	var/list/matching = list()
	if(!all_slots)
		return matching
	for(var/slot_name in all_slots)
		var/datum/clash_loadout/loadout = all_slots[slot_name]
		if(loadout.job == job)
			matching[slot_name] = loadout
	return matching

/datum/clash_loadout/proc/capture(mob/living/carbon/human/user, slot_name)
	name = slot_name
	job = user.job
	items.Cut()
	for(var/obj/item/thing in user.get_equipped_items() + list(user.s_store, user.l_store, user.r_store, user.l_hand, user.r_hand))
		record(thing, null, user.get_slot_by_item(thing))

/datum/clash_loadout/proc/record(obj/item/thing, parent, slot)
	items += list(list("type" = thing.type, "name" = thing.name, "inner" = !isnull(parent), "parent" = parent, "slot" = slot))
	var/index = length(items)
	for(var/obj/item/inner in thing.contents)
		record(inner, index)

/// Uniform first, then armor, then the rest of the worn gear, then what goes inside it
/proc/clash_equip_order(list/entry)
	if(entry["inner"])
		return 4
	var/item_type = entry["type"]
	if(ispath(item_type, /obj/item/clothing/under))
		return 1
	if(ispath(item_type, /obj/item/clothing/suit))
		return 2
	return 3

/datum/clash_loadout/proc/get_sorted_indexes()
	var/list/sorted = list()
	for(var/rank in 1 to 4)
		for(var/index in 1 to length(items))
			if(clash_equip_order(items[index]) == rank)
				sorted += index
	return sorted

/// Every vendor this user is allowed to buy from
/proc/get_clash_vendors(mob/living/carbon/human/user)
	var/list/vendors = list()
	for(var/obj/structure/machinery/cm_vending/vendor in GLOB.machines)
		if(vendor.z != user.z || vendor.inoperable())
			continue
		if(vendor.squad_tag && (!user.assigned_squad || (!user.assigned_squad.omni_squad_vendor && user.assigned_squad.name != vendor.squad_tag)))
			continue
		if(!vendor.can_access_to_vend(user, FALSE))
			continue
		vendors += vendor
	return vendors

/// Finds a vendor holding this type with stock left, returns list(vendor, itemspec)
/proc/find_clash_product(list/vendors, mob/living/carbon/human/user, item_type)
	for(var/obj/structure/machinery/cm_vending/vendor as anything in vendors)
		for(var/list/itemspec in vendor.get_available_products(user))
			var/prod_type = itemspec[3]
			if(islist(prod_type) ? !(item_type in prod_type) : prod_type != item_type)
				continue
			if(!vendor.use_points && !vendor.use_snowflake_points && itemspec[2] <= 0)
				continue
			return list(vendor, itemspec)
	return null

/datum/clash_loadout/proc/can_afford(mob/living/carbon/human/user, list/vendors)
	var/points_cost = 0
	var/snowflake_cost = 0
	var/list/needed = list()
	for(var/list/entry in items)
		var/item_type = entry["type"]
		needed[item_type] = (needed[item_type] || 0) + 1
		if(clash_count_type(user, item_type) >= needed[item_type])
			continue
		var/list/found = find_clash_product(vendors, user, item_type)
		if(!found)
			continue
		var/obj/structure/machinery/cm_vending/vendor = found[1]
		var/list/itemspec = found[2]
		if(vendor.instanced_vendor_points)
			continue
		if(vendor.use_snowflake_points)
			snowflake_cost += itemspec[2]
		else if(vendor.use_points)
			points_cost += itemspec[2]
	if(points_cost > user.vendor_points)
		return "You need [points_cost] points and have [user.vendor_points]."
	if(snowflake_cost > user.vendor_snowflake_points)
		return "You need [snowflake_cost] specialist points and have [user.vendor_snowflake_points]."
	return null

/proc/clash_count_type(atom/holder, item_type)
	. = 0
	for(var/obj/item/thing in holder.contents)
		if(thing.type == item_type)
			.++
		. += clash_count_type(thing, item_type)

/proc/clash_find_unclaimed(list/candidates, item_type, list/claimed)
	for(var/obj/item/thing in candidates)
		if(thing.type == item_type && !(thing in claimed))
			return thing
	return null

/// Mirrors the checks of the vendor's own vend action, returns the item of item_type that was handed out
/proc/clash_vend(obj/structure/machinery/cm_vending/vendor, list/itemspec, mob/living/carbon/human/user, item_type)
	if(vendor.stat & IN_USE)
		return null
	if(vendor.vend_flags & VEND_CATEGORY_CHECK)
		if(itemspec[4] == MARINE_CAN_BUY_ESSENTIALS)
			return null
		if(itemspec[4] && !vendor.handle_vend(itemspec, user))
			return null
	if((vendor.use_points || vendor.use_snowflake_points) && !vendor.handle_points(user, itemspec))
		return null
	var/turf/drop_turf = get_turf(user)
	var/list/before = drop_turf.contents.Copy()
	var/saved_flags = vendor.vend_flags
	vendor.vend_flags &= ~(VEND_TO_HAND|VEND_UNIFORM_AUTOEQUIP)
	vendor.vendor_successful_vend(itemspec, user, drop_turf)
	vendor.vend_flags = saved_flags
	var/obj/item/bought
	for(var/obj/item/extra in drop_turf.contents - before)
		if(!bought && extra.type == item_type)
			bought = extra
		else if(clash_count_type(user, extra.type))
			qdel(extra)
		else
			user.equip_to_appropriate_slot(extra)
	return bought

/proc/clash_place(obj/item/thing, atom/parent, slot, mob/living/carbon/human/user)
	if(istype(parent, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/weapon = parent
		if(istype(thing, /obj/item/attachable))
			var/obj/item/attachable/attachment = thing
			if(weapon.can_attach_to_gun(user, attachment))
				attachment.Attach(weapon)
				weapon.update_attachable(attachment.slot)
				return
		else if(istype(thing, /obj/item/ammo_magazine))
			var/obj/item/ammo_magazine/magazine = thing
			if(!weapon.current_mag && (istype(weapon, magazine.gun_type) || (magazine.type in weapon.accepted_ammo)))
				weapon.replace_magazine(user, magazine)
				return
	else if(isstorage(parent))
		var/obj/item/storage/holder = parent
		if(holder.can_be_inserted(thing, user, TRUE) && holder.handle_item_insertion(thing, TRUE, user))
			return
	else if(istype(parent, /obj/item/clothing/shoes))
		var/obj/item/clothing/shoes/boots = parent
		if(boots.attempt_insert_item(user, thing))
			return
	else if(istype(parent, /obj/item/clothing) && istype(thing, /obj/item/clothing/accessory))
		var/obj/item/clothing/worn = parent
		if(worn.can_attach_accessory(thing))
			worn.attach_accessory(user, thing)
			return
	if(istype(thing, /obj/item/clothing/accessory))
		for(var/obj/item/clothing/worn in list(user.w_uniform, user.wear_suit, user.head))
			if(worn.can_attach_accessory(thing))
				worn.attach_accessory(user, thing)
				return
	if(slot && user.equip_to_slot_if_possible(thing, slot, TRUE, FALSE, TRUE))
		return
	if(!user.equip_to_appropriate_slot(thing))
		user.put_in_any_hand_if_possible(thing)

/datum/clash_loadout/proc/restore(mob/living/carbon/human/user)
	var/list/vendors = get_clash_vendors(user)
	var/shortfall = can_afford(user, vendors)
	if(shortfall)
		to_chat(user, SPAN_WARNING("Loadout not restored. [shortfall]"))
		return FALSE
	var/list/missing = list()
	var/list/placed = list()
	var/list/claimed = list()
	for(var/index in get_sorted_indexes())
		var/list/entry = items[index]
		var/item_type = entry["type"]
		var/atom/parent = entry["parent"] ? placed["[entry["parent"]]"] : null
		var/obj/item/existing = clash_find_unclaimed(parent ? parent.contents : user.contents, item_type, claimed) || clash_find_unclaimed(user.get_contents(), item_type, claimed)
		if(existing)
			placed["[index]"] = existing
			claimed += existing
			continue
		var/list/found = find_clash_product(vendors, user, item_type)
		var/obj/item/bought = found && clash_vend(found[1], found[2], user, item_type)
		if(!bought)
			missing += entry["name"]
			continue
		placed["[index]"] = bought
		claimed += bought
		clash_place(bought, parent, entry["slot"], user)
	if(length(missing))
		to_chat(user, SPAN_WARNING("Not available, and not restored: [english_list(missing)]."))
	return TRUE

/obj/structure/machinery/cm_vending/proc/add_clash_vendor_data(mob/user, list/data)
	data["clash_loadouts"] = list()
	data["clash_enabled"] = FALSE
	// Arena maps use kits instead, see clash_kit
	if(!SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH) || clash_uses_kits() || !ishuman(user))
		return
	var/mob/living/carbon/human/human_user = user
	data["clash_enabled"] = TRUE
	var/list/slots = get_clash_loadouts_for_job(clash_loadout_key(human_user), human_user.job)
	var/auto_slot = get_clash_auto_slot(clash_loadout_key(human_user), human_user.job)
	for(var/slot_name in slots)
		var/datum/clash_loadout/loadout = slots[slot_name]
		data["clash_loadouts"] += list(list("name" = slot_name, "count" = length(loadout.items), "role" = loadout.job, "faction" = (loadout.job in UPP_JOB_LIST) ? "UPP" : "USCM", "auto" = auto_slot == slot_name))

/obj/structure/machinery/cm_vending/proc/clash_save_loadout(mob/living/carbon/human/user, overwrite_slot)
	var/key = clash_loadout_key(user)
	if(!key)
		return
	var/list/all_slots = get_clash_loadouts(key)
	var/list/job_slots = get_clash_loadouts_for_job(key, user.job)
	var/slot_name = (overwrite_slot && job_slots[overwrite_slot]) ? overwrite_slot : tgui_input_text(user, "Name this loadout.", "Save Loadout", max_length = 24)
	if(!slot_name)
		return
	var/datum/clash_loadout/existing = all_slots[slot_name]
	if(existing && existing.job != user.job)
		to_chat(user, SPAN_WARNING("You already have a loadout called [slot_name] for [existing.job]. Pick another name."))
		return
	if(!existing && length(job_slots) >= CLASH_LOADOUT_SLOTS)
		to_chat(user, SPAN_WARNING("You already have [CLASH_LOADOUT_SLOTS] saved loadouts for this role. Overwrite one instead."))
		return
	var/datum/clash_loadout/loadout = new
	loadout.capture(user, slot_name)
	all_slots[slot_name] = loadout
	save_clash_loadouts(key)
	to_chat(user, SPAN_NOTICE("Loadout saved as [slot_name]."))

/obj/structure/machinery/cm_vending/proc/clash_load_loadout(mob/living/carbon/human/user, slot_name)
	var/list/slots = get_clash_loadouts_for_job(clash_loadout_key(user), user.job)
	var/datum/clash_loadout/loadout = slots[slot_name]
	if(!loadout)
		to_chat(user, SPAN_WARNING("No loadout saved under that name for this role."))
		return
	loadout.restore(user)

/obj/structure/machinery/cm_vending/proc/clash_delete_loadout(mob/living/carbon/human/user, slot_name)
	var/list/all_slots = get_clash_loadouts(clash_loadout_key(user))
	var/datum/clash_loadout/loadout = all_slots?[slot_name]
	if(!loadout || loadout.job != user.job)
		return
	all_slots -= slot_name
	var/list/auto = GLOB.clash_auto_loadouts[clash_loadout_key(user)]
	if(auto?[user.job] == slot_name)
		auto -= user.job
	qdel(loadout)
	save_clash_loadouts(clash_loadout_key(user))
	to_chat(user, SPAN_NOTICE("Loadout [slot_name] deleted."))

/obj/structure/machinery/cm_vending/proc/clash_toggle_auto_loadout(mob/living/carbon/human/user, slot_name)
	var/key = clash_loadout_key(user)
	var/list/slots = get_clash_loadouts_for_job(key, user.job)
	if(!slots[slot_name])
		return
	var/list/auto = GLOB.clash_auto_loadouts[key]
	if(auto[user.job] == slot_name)
		auto -= user.job
		to_chat(user, SPAN_NOTICE("[slot_name] will no longer be equipped when you spawn."))
	else
		auto[user.job] = slot_name
		to_chat(user, SPAN_NOTICE("[slot_name] will be equipped whenever you spawn as [user.job]."))
	save_clash_loadouts(key)

/proc/clash_loadout_path(key)
	return clash_player_save_path(key, "clash_loadouts.sav")

/proc/save_clash_loadouts(key)
	if(!key || IsGuestKey(key))
		return
	var/list/all_slots = GLOB.clash_loadouts[key]
	var/list/payload = list()
	for(var/slot_name in all_slots)
		var/datum/clash_loadout/loadout = all_slots[slot_name]
		payload[slot_name] = list("job" = loadout.job, "items" = loadout.items)
	var/savefile/save = new(clash_loadout_path(key))
	save.cd = "/"
	save["loadouts"] << payload
	save["auto"] << GLOB.clash_auto_loadouts[key]

/proc/load_clash_loadouts(key)
	if(!key || IsGuestKey(key))
		return
	var/path = clash_loadout_path(key)
	if(!fexists(path))
		return
	var/savefile/save = new(path)
	save.cd = "/"
	var/list/stored_auto
	save["auto"] >> stored_auto
	if(islist(stored_auto))
		GLOB.clash_auto_loadouts[key] = stored_auto
	var/list/payload
	save["loadouts"] >> payload
	if(!islist(payload))
		return
	var/list/all_slots = GLOB.clash_loadouts[key]
	for(var/slot_name in payload)
		var/list/stored = payload[slot_name]
		var/datum/clash_loadout/loadout = new
		loadout.name = slot_name
		loadout.job = stored["job"]
		loadout.items = stored["items"]
		all_slots[slot_name] = loadout

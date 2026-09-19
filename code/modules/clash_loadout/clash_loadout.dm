/// Saved Faction Clash loadouts, ckey to list of slot name to /datum/clash_loadout
GLOBAL_LIST_EMPTY(clash_loadouts)
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
		load_clash_loadouts(key)
	return GLOB.clash_loadouts[key]

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
	for(var/obj/item/thing in user.get_equipped_items())
		record(thing)
		for(var/obj/item/inner in thing.contents)
			record(inner)

/datum/clash_loadout/proc/record(obj/item/thing)
	items += list(list("type" = thing.type, "name" = thing.name))

/// Every vendor this user is allowed to buy from
/proc/get_clash_vendors(mob/living/carbon/human/user)
	var/list/vendors = list()
	for(var/obj/structure/machinery/cm_vending/vendor in GLOB.machines)
		if(vendor.inoperable())
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
			if(islist(prod_type))
				continue
			if(prod_type != item_type)
				continue
			if((vendor.vend_flags & VEND_LIMITED_INVENTORY) && itemspec[2] <= 0)
				continue
			return list(vendor, itemspec)
	return null

/datum/clash_loadout/proc/can_afford(mob/living/carbon/human/user, list/vendors)
	var/points_cost = 0
	var/snowflake_cost = 0
	for(var/list/entry in items)
		if(clash_user_has_type(user, entry["type"]))
			continue
		var/list/found = find_clash_product(vendors, user, entry["type"])
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

/proc/clash_user_has_type(mob/living/carbon/human/user, item_type)
	for(var/obj/item/thing in user.contents)
		if(thing.type == item_type)
			return TRUE
		for(var/obj/item/inner in thing.contents)
			if(inner.type == item_type)
				return TRUE
	return FALSE

/datum/clash_loadout/proc/restore(mob/living/carbon/human/user)
	var/list/vendors = get_clash_vendors(user)
	var/shortfall = can_afford(user, vendors)
	if(shortfall)
		to_chat(user, SPAN_WARNING("Loadout not restored. [shortfall]"))
		return FALSE
	var/list/missing = list()
	var/list/granted = list()
	for(var/list/entry in items)
		var/item_type = entry["type"]
		if(!granted[item_type] && clash_user_has_type(user, item_type))
			continue
		var/list/found = find_clash_product(vendors, user, item_type)
		if(!found)
			missing += entry["name"]
			continue
		var/obj/structure/machinery/cm_vending/vendor = found[1]
		var/list/itemspec = found[2]
		if(vendor.stat & IN_USE)
			missing += entry["name"]
			continue
		if(!vendor.handle_vend(itemspec, user))
			missing += entry["name"]
			continue
		if((vendor.use_points || vendor.use_snowflake_points) && !vendor.handle_points(user, itemspec))
			missing += entry["name"]
			continue
		var/saved_delay = vendor.vend_delay
		var/saved_flags = vendor.vend_flags
		vendor.vend_delay = 0
		vendor.vend_flags = (vendor.vend_flags | VEND_UNIFORM_AUTOEQUIP) & ~VEND_TO_HAND
		vendor.vendor_successful_vend(itemspec, user, get_turf(user))
		vendor.vend_delay = saved_delay
		vendor.vend_flags = saved_flags
		granted[item_type] = TRUE
	if(length(missing))
		to_chat(user, SPAN_WARNING("Not available, and not restored: [english_list(missing)]."))
	return TRUE

/obj/structure/machinery/cm_vending/proc/add_clash_vendor_data(mob/user, list/data)
	data["clash_loadouts"] = list()
	data["clash_enabled"] = FALSE
	if(!SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH) || !ishuman(user))
		return
	var/mob/living/carbon/human/human_user = user
	data["clash_enabled"] = TRUE
	var/list/slots = get_clash_loadouts_for_job(clash_loadout_key(human_user), human_user.job)
	for(var/slot_name in slots)
		var/datum/clash_loadout/loadout = slots[slot_name]
		data["clash_loadouts"] += list(list("name" = slot_name, "count" = length(loadout.items), "role" = loadout.job, "faction" = (loadout.job in UPP_JOB_LIST) ? "UPP" : "USCM"))

/obj/structure/machinery/cm_vending/proc/clash_save_loadout(mob/living/carbon/human/user, overwrite_slot)
	var/key = clash_loadout_key(user)
	if(!key)
		return
	var/list/all_slots = get_clash_loadouts(key)
	var/list/job_slots = get_clash_loadouts_for_job(key, user.job)
	var/slot_name = (overwrite_slot && job_slots[overwrite_slot]) ? overwrite_slot : tgui_input_text(user, "Name this loadout.", "Save Loadout", max_length = 24)
	if(!slot_name)
		return
	if(!all_slots[slot_name] && length(job_slots) >= CLASH_LOADOUT_SLOTS)
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
	qdel(loadout)
	save_clash_loadouts(clash_loadout_key(user))
	to_chat(user, SPAN_NOTICE("Loadout [slot_name] deleted."))

/proc/clash_loadout_path(key)
	return "data/player_saves/[copytext(key, 1, 2)]/[key]/clash_loadouts.sav"

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

/proc/load_clash_loadouts(key)
	if(!key || IsGuestKey(key))
		return
	var/path = clash_loadout_path(key)
	if(!fexists(path))
		return
	var/savefile/save = new(path)
	save.cd = "/"
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

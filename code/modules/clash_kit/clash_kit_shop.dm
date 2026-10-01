GLOBAL_LIST_EMPTY(clash_kit_shops)
GLOBAL_LIST_EMPTY(clash_kit_budgets)

/mob/living/carbon/human/var/list/clash_kit_extras = list()

/proc/get_clash_shop_sources(job)
	switch(job)
		if(JOB_SQUAD_MARINE)
			return list(list(GLOB.cm_vending_clothing_marine, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_ENGI)
			return list(list(GLOB.cm_vending_gear_engi, CLASH_SHOP_POINTS), list(GLOB.cm_vending_clothing_engi, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_MEDIC)
			return list(list(GLOB.cm_vending_gear_medic, CLASH_SHOP_POINTS), list(GLOB.cm_vending_clothing_medic, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_SMARTGUN)
			return list(list(GLOB.cm_vending_gear_smartgun, CLASH_SHOP_POINTS), list(GLOB.cm_vending_clothing_smartgun, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_SPECIALIST)
			return list(list(GLOB.cm_vending_gear_spec, CLASH_SHOP_SNOWFLAKE), list(GLOB.cm_vending_clothing_specialist, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_TEAM_LEADER)
			return list(list(GLOB.cm_vending_gear_tl, CLASH_SHOP_POINTS), list(GLOB.cm_vending_clothing_tl, CLASH_SHOP_POINTS))
		if(JOB_SQUAD_LEADER)
			return list(list(GLOB.cm_vending_gear_leader, CLASH_SHOP_POINTS), list(GLOB.cm_vending_clothing_leader, CLASH_SHOP_POINTS))
	if(clash_kit_faction_for_job(job) != FACTION_UPP)
		return list()
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	var/datum/equipment_preset/preset = role?.gear_preset && GLOB.equipment_presets.gear_path_presets_list[role.gear_preset]
	if(!preset)
		return list()
	return list(list(preset.get_antag_gear_equipment(), CLASH_SHOP_POINTS), list(preset.get_antag_clothing_equipment(), CLASH_SHOP_POINTS))

/proc/get_clash_shop(job)
	if(GLOB.clash_kit_shops[job])
		return GLOB.clash_kit_shops[job]
	var/list/sections = list()
	var/list/by_id = list()
	for(var/list/source in get_clash_shop_sources(job))
		var/list/section
		for(var/list/entry in source[1])
			var/entry_type = entry[3]
			if(!entry_type)
				section = list("name" = entry[1], "items" = list())
				sections += list(section)
				continue
			var/id = "[entry_type]"
			if(!section || entry[4] || entry[2] <= 0 || !ispath(entry_type, /obj/item) || by_id[id])
				continue
			var/obj/item/sample = entry_type
			var/list/item = list("id" = id, "name" = entry[1], "cost" = entry[2], "pool" = source[2], "icon" = "[initial(sample.icon)]", "icon_state" = initial(sample.icon_state))
			section["items"] += list(item)
			by_id[id] = item
	for(var/list/section as anything in sections.Copy())
		if(!length(section["items"]))
			sections -= list(section)
	GLOB.clash_kit_shops[job] = list("sections" = sections, "by_id" = by_id)
	return GLOB.clash_kit_shops[job]

/proc/get_clash_kit_budget(job)
	return GLOB.clash_kit_budgets[job] || list(MARINE_TOTAL_BUY_POINTS, MARINE_TOTAL_SNOWFLAKE_POINTS)

/proc/get_clash_kit_spent(datum/clash_kit/kit, job)
	. = list(CLASH_SHOP_POINTS = 0, CLASH_SHOP_SNOWFLAKE = 0)
	var/list/by_id = get_clash_shop(job)["by_id"]
	for(var/id in kit.extras)
		var/list/item = by_id[id]
		if(item)
			.[item["pool"]] += item["cost"]

/proc/clash_kit_storage_of(obj/item/thing)
	if(isstorage(thing))
		return thing
	var/obj/item/clothing/suit/storage/suit = thing
	if(istype(suit))
		return suit.pockets
	return null

/proc/clash_kit_containers(mob/living/carbon/human/wearer)
	. = list()
	for(var/obj/item/worn in list(wearer.back, wearer.belt, wearer.l_store, wearer.r_store, wearer.wear_suit))
		var/obj/item/storage/holder = clash_kit_storage_of(worn)
		if(holder)
			. += holder
	for(var/obj/item/clothing/accessory/storage/webbing in wearer.w_uniform?.accessories)
		. += webbing.hold

/proc/clash_kit_carried(mob/living/carbon/human/wearer, obj/item/thing)
	var/atom/holder = thing.loc
	while(istype(holder, /obj/item))
		holder = holder.loc
	return holder == wearer

/proc/stock_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit, job, mode)
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		var/obj/item/given = given_ref.resolve()
		if(!given || !clash_kit_carried(wearer, given))
			continue
		if(mode == CLASH_KIT_EQUIP)
			var/list/paid = wearer.clash_kit_extras[given_ref]
			if(paid["pool"] == CLASH_SHOP_SNOWFLAKE)
				wearer.vendor_snowflake_points += paid["cost"]
			else
				wearer.vendor_points += paid["cost"]
		qdel(given)
	wearer.clash_kit_extras = list()
	var/list/containers = clash_kit_containers(wearer)
	if(mode == CLASH_KIT_SPAWN || mode == CLASH_KIT_PREVIEW)
		var/list/unwanted = kit.removed.Copy()
		for(var/obj/item/storage/holder as anything in containers)
			for(var/obj/item/thing as anything in holder.contents.Copy())
				if(!("[thing.type]" in unwanted))
					continue
				unwanted -= "[thing.type]"
				holder.remove_from_storage(thing, wearer)
				qdel(thing)
	. = list()
	var/list/by_id = get_clash_shop(job)["by_id"]
	for(var/id in kit.extras)
		var/list/item = by_id[id]
		if(!item)
			. += "gone"
			continue
		var/snowflake = item["pool"] == CLASH_SHOP_SNOWFLAKE
		if((snowflake ? wearer.vendor_snowflake_points : wearer.vendor_points) < item["cost"])
			. += "points"
			continue
		var/item_type = text2path(id)
		var/obj/item/bought = new item_type
		var/placed = FALSE
		for(var/obj/item/storage/holder as anything in containers)
			if(holder.can_be_inserted(bought, wearer, TRUE) && holder.handle_item_insertion(bought, TRUE, wearer))
				placed = TRUE
				break
		if(!placed)
			qdel(bought)
			. += "room"
			continue
		if(snowflake)
			wearer.vendor_snowflake_points -= item["cost"]
		else
			wearer.vendor_points -= item["cost"]
		wearer.clash_kit_extras[WEAKREF(bought)] = item
		. += "ok"

/proc/describe_clash_kit_pack(mob/living/carbon/human/wearer, datum/clash_kit/kit, obj/item/weapon/gun/primary)
	. = list()
	var/list/shells = primary && clash_kit_shells_for(primary)
	var/list/extras = list()
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		extras += given_ref.resolve()
	for(var/obj/item/storage/holder as anything in clash_kit_containers(wearer))
		var/list/items = list()
		var/used = 0
		for(var/obj/item/thing as anything in holder.contents)
			used += thing.get_storage_cost()
			items += list(list("type" = "[thing.type]", "name" = thing.name, "icon" = "[thing.icon]", "icon_state" = thing.icon_state, "extra" = (thing in extras)))
		var/label = istype(holder, /obj/item/storage/internal) ? "[holder.name] pockets" : holder.name
		var/capacity = isnull(holder.storage_slots) ? "[used]/[holder.max_storage_space]" : "[length(holder.contents)]/[holder.storage_slots]"
		var/list/entry = list("name" = capitalize(label), "capacity" = capacity, "items" = items, "type" = "[holder.type]")
		if(shells && clash_kit_holds_ammo(holder) && holder.can_hold_type(shells[shells[1]], wearer))
			entry["shells"] = GLOB.clash_kit_shell_names
			entry["fill"] = kit?.fills["[holder.type]"] || GLOB.clash_kit_shell_names[1]
		. += list(entry)

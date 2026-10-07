GLOBAL_LIST_EMPTY(clash_kit_shops)
GLOBAL_LIST_EMPTY(clash_kit_budgets)
GLOBAL_LIST_EMPTY(clash_item_contents)
GLOBAL_LIST_INIT(clash_role_shop_ammo, list(
	JOB_SQUAD_SMARTGUN = list(/obj/item/ammo_magazine/smartgun = 10),
))

GLOBAL_LIST_INIT(clash_shop_counterparts, list(
	JOB_UPP = JOB_SQUAD_MARINE,
	JOB_UPP_MEDIC = JOB_SQUAD_MEDIC,
	JOB_UPP_ENGI = JOB_SQUAD_ENGI,
	JOB_UPP_SPECIALIST = JOB_SQUAD_SMARTGUN,
	JOB_UPP_LEADER = JOB_SQUAD_LEADER,
))

/mob/living/carbon/human/var/list/clash_kit_extras = list()
/mob/living/carbon/human/var/list/clash_kit_placed = list()
/mob/living/carbon/human/var/list/clash_kit_move_failed = list()

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

/proc/clash_list_contents(obj/item/holder)
	. = list()
	if(!isstorage(holder))
		return
	var/list/counts = list()
	for(var/obj/item/thing in holder.contents)
		var/thing_name = capitalize(strip_improper(thing.name))
		counts[thing_name] = (counts[thing_name] || 0) + 1
	for(var/thing_name in counts)
		. += counts[thing_name] > 1 ? "[thing_name] x[counts[thing_name]]" : thing_name

/proc/clash_type_contents(item_type)
	if(!ispath(item_type, /obj/item/storage))
		return list()
	if(isnull(GLOB.clash_item_contents[item_type]))
		var/obj/item/storage/sample = new item_type
		GLOB.clash_item_contents[item_type] = clash_list_contents(sample)
		qdel(sample)
	return GLOB.clash_item_contents[item_type]

/proc/clash_is_extended_magazine(item_type)
	return ispath(item_type, /obj/item/ammo_magazine) && findtext("[item_type]/", "/extended/")

/proc/get_clash_shop(job)
	if(GLOB.clash_kit_shops[job])
		return GLOB.clash_kit_shops[job]
	build_clash_kit_catalog()
	var/list/sections = list()
	var/list/by_id = list()
	var/list/ammo_items = list()
	var/list/role_ammo = GLOB.clash_role_shop_ammo[job]
	for(var/slot in list(KIT_SLOT_PRIMARY, KIT_SLOT_SIDEARM))
		for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[clash_kit_faction_for_job(job)]?[slot])
			var/obj/item/ammo_type = option.ammo_type
			if(!ammo_type || by_id["[ammo_type]"] || role_ammo?[ammo_type] || (option.only_class && option.only_class != GLOB.clash_job_classes[job]))
				continue
			var/list/item = list("id" = "[ammo_type]", "name" = capitalize(strip_improper(initial(ammo_type.name))), "cost" = CLASH_SHOP_AMMO_COST, "pool" = CLASH_SHOP_POINTS, "icon" = "[initial(ammo_type.icon)]", "icon_state" = initial(ammo_type.icon_state))
			ammo_items += list(item)
			by_id["[ammo_type]"] = item
	for(var/obj/item/ammo_type as anything in role_ammo)
		var/list/item = list("id" = "[ammo_type]", "name" = capitalize(strip_improper(initial(ammo_type.name))), "cost" = role_ammo[ammo_type], "pool" = CLASH_SHOP_POINTS, "icon" = "[initial(ammo_type.icon)]", "icon_state" = initial(ammo_type.icon_state))
		ammo_items += list(item)
		by_id["[ammo_type]"] = item
	if(length(ammo_items))
		sections += list(list("name" = "Weapon ammo", "items" = ammo_items))
	var/list/sources = get_clash_shop_sources(job)
	if(clash_job_is_medic(job))
		sources += list(list(GLOB.clash_medic_shop, CLASH_SHOP_POINTS))
	for(var/list/source in sources)
		var/list/section
		for(var/list/listed in source[1])
			var/list/entry = clash_arena_med_entry(listed, clash_job_is_medic(job), FALSE)
			if(!entry)
				continue
			var/entry_type = entry[3]
			if(!entry_type)
				section = list("name" = entry[1], "items" = list())
				sections += list(section)
				continue
			var/id = "[entry_type]"
			if(!section || entry[4] || entry[2] <= 0 || !ispath(entry_type, /obj/item) || by_id[id] || (ispath(entry_type, /obj/item/ammo_magazine) && findtext("[entry_type]/", "/ap/")) || clash_is_extended_magazine(entry_type))
				continue
			var/obj/item/sample = entry_type
			var/list/item = list("id" = id, "name" = entry[1], "cost" = entry[2], "pool" = source[2], "icon" = "[initial(sample.icon)]", "icon_state" = initial(sample.icon_state), "contents" = clash_type_contents(entry_type))
			section["items"] += list(item)
			by_id[id] = item
	for(var/list/section as anything in sections.Copy())
		if(!length(section["items"]))
			sections -= list(section)
	var/list/optics = clash_shop_optics(sections)
	var/counterpart = GLOB.clash_shop_counterparts[job]
	if(!optics && counterpart)
		var/list/borrowed = clash_shop_optics(get_clash_shop(counterpart)["sections"])
		if(borrowed)
			optics = list("name" = borrowed["name"], "items" = list())
			for(var/list/item as anything in borrowed["items"])
				var/list/copy = item.Copy()
				optics["items"] += list(copy)
				by_id[copy["id"]] = copy
			sections += list(optics)
	if(optics)
		sections -= list(optics)
		sections.Insert(1, list(optics))
	GLOB.clash_kit_shops[job] = list("sections" = sections, "by_id" = by_id)
	return GLOB.clash_kit_shops[job]

/proc/clash_shop_optics(list/sections)
	for(var/list/section as anything in sections)
		if(findtext(section["name"], "OPTICS"))
			return section
	return null

/proc/get_clash_kit_budget(job, ckey)
	var/list/budget = GLOB.clash_kit_budgets[job] || list(MARINE_TOTAL_BUY_POINTS, MARINE_TOTAL_SNOWFLAKE_POINTS)
	var/list/limits = clash_shop_budget(ckey, job)
	return limits ? list(budget[1] ? limits[1] : 0, min(budget[2], limits[2])) : budget

/proc/clash_raise_vendor_points(mob/living/carbon/human/fighter, ckey, job)
	var/list/limits = fighter.vendor_points ? clash_shop_budget(ckey, job) : null
	if(limits)
		fighter.vendor_points = max(fighter.vendor_points, limits[1])

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

/proc/clash_kit_container_slots(mob/living/carbon/human/wearer)
	. = list()
	var/list/worn = list("back" = wearer.back, "belt" = wearer.belt, "l_store" = wearer.l_store, "r_store" = wearer.r_store, "suit" = wearer.wear_suit)
	for(var/key in worn)
		var/obj/item/storage/holder = clash_kit_storage_of(worn[key])
		if(holder)
			.[key] = holder
	var/count = 0
	for(var/obj/item/clothing/accessory/storage/webbing in wearer.w_uniform?.accessories)
		count++
		.[count > 1 ? "webbing_[count]" : "webbing"] = webbing.hold

/proc/clash_kit_containers(mob/living/carbon/human/wearer)
	. = list()
	var/list/holders = clash_kit_container_slots(wearer)
	for(var/key in holders)
		. += holders[key]

/proc/clash_kit_carried(mob/living/carbon/human/wearer, obj/item/thing)
	var/atom/holder = thing.loc
	while(istype(holder, /obj/item))
		holder = holder.loc
	return holder == wearer

/proc/stock_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit, job, mode, ckey)
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		var/obj/item/given = given_ref.resolve()
		if(!given || !clash_kit_carried(wearer, given))
			continue
		qdel(given)
	wearer.clash_kit_extras = list()
	wearer.clash_kit_placed = list()
	var/list/holders = clash_kit_container_slots(wearer)
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
	kit.sync_extra_slots()
	var/list/statuses = new /list(length(kit.extras))
	var/list/by_id = get_clash_shop(job)["by_id"]
	var/list/limits = clash_shop_budget(ckey, job)
	var/list/spent = list(CLASH_SHOP_POINTS = 0, CLASH_SHOP_SNOWFLAKE = 0)
	var/obj/item/weapon/gun/primary = clash_kit_primary_of(wearer)
	var/list/order = list()
	for(var/index in 1 to length(kit.extras))
		if(kit.extra_slots[index])
			order += index
	for(var/index in 1 to length(kit.extras))
		if(!kit.extra_slots[index])
			order += index
	for(var/index in order)
		var/id = kit.extras[index]
		var/list/item = by_id[id]
		if(!item)
			statuses[index] = "gone"
			continue
		if(!clash_shop_item_unlocked(ckey, job, item["cost"], text2path(id), primary?.type))
			statuses[index] = "locked"
			continue
		var/snowflake = item["pool"] == CLASH_SHOP_SNOWFLAKE
		if((snowflake ? wearer.vendor_snowflake_points : wearer.vendor_points) < item["cost"] || (limits && spent[item["pool"]] + item["cost"] > limits[snowflake ? 2 : 1]))
			statuses[index] = "points"
			continue
		var/item_type = text2path(id)
		var/obj/item/bought = new item_type
		var/list/tries = containers.Copy()
		var/wanted = kit.extra_slots[index]
		var/obj/item/storage/target = wanted && holders[wanted]
		if(target)
			tries -= target
			tries.Insert(1, target)
		var/obj/item/storage/placed
		for(var/obj/item/storage/holder as anything in tries)
			if(holder.can_be_inserted(bought, wearer, TRUE) && holder.handle_item_insertion(bought, TRUE, wearer))
				placed = holder
				break
		if(!placed)
			qdel(bought)
			statuses[index] = "room"
			continue
		if(snowflake)
			wearer.vendor_snowflake_points -= item["cost"]
		else
			wearer.vendor_points -= item["cost"]
		spent[item["pool"]] += item["cost"]
		wearer.clash_kit_extras[WEAKREF(bought)] = index
		for(var/key in holders)
			if(holders[key] == placed)
				wearer.clash_kit_placed["[index]"] = key
		statuses[index] = "ok"
	return statuses

/proc/apply_clash_kit_moves(mob/living/carbon/human/wearer, datum/clash_kit/kit)
	. = list()
	var/list/holders = clash_kit_container_slots(wearer)
	var/list/bought = list()
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		bought += given_ref.resolve()
	for(var/index in 1 to length(kit.moves))
		var/list/move = kit.moves[index]
		var/obj/item/storage/source = holders[move[2]]
		var/obj/item/storage/target = holders[move[3]]
		var/item_type = text2path(move[1])
		if(!source || !target || !item_type)
			continue
		var/obj/item/moving
		for(var/obj/item/thing in source.contents)
			if(thing.type == item_type && !(thing in bought))
				moving = thing
				break
		if(!moving)
			continue
		if(!target.can_be_inserted(moving, wearer, TRUE))
			. += index
			continue
		source.remove_from_storage(moving, wearer)
		target.handle_item_insertion(moving, TRUE, wearer)

/proc/describe_clash_kit_pack(mob/living/carbon/human/wearer, datum/clash_kit/kit, obj/item/weapon/gun/primary)
	. = list()
	var/list/shells = primary && clash_kit_shells_for(primary)
	var/list/extras = list()
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		var/obj/item/given = given_ref.resolve()
		if(given)
			extras[given] = wearer.clash_kit_extras[given_ref]
	var/list/holders = clash_kit_container_slots(wearer)
	for(var/key in holders)
		var/obj/item/storage/holder = holders[key]
		var/list/items = list()
		var/used = 0
		var/count = 0
		for(var/obj/item/thing as anything in holder.contents)
			var/extra_index = extras[thing] || 0
			var/unassigned = extra_index && !LAZYACCESS(kit?.extra_slots, extra_index)
			if(!unassigned)
				used += thing.get_storage_cost()
				count++
			var/list/fits = unassigned ? list(key) : list()
			for(var/other_key in holders)
				var/obj/item/storage/other = holders[other_key]
				if(other != holder && other.can_be_inserted(thing, wearer, TRUE))
					fits += other_key
			items += list(list("type" = "[thing.type]", "name" = thing.name, "icon" = "[thing.icon]", "icon_state" = thing.icon_state, "extra" = !!extra_index, "extra_index" = extra_index, "unassigned" = unassigned, "fits" = fits, "contents" = clash_list_contents(thing)))
		var/label = istype(holder, /obj/item/storage/internal) ? "[holder.name] pockets" : holder.name
		var/capacity = isnull(holder.storage_slots) ? "[used]/[holder.max_storage_space]" : "[count]/[holder.storage_slots]"
		var/list/entry = list("name" = capitalize(label), "capacity" = capacity, "items" = items, "type" = "[holder.type]", "slot" = key)
		if(shells && clash_kit_holds_ammo(holder) && holder.can_hold_type(shells[shells[1]], wearer))
			entry["shells"] = GLOB.clash_kit_shell_names
			entry["fill"] = kit?.fills["[holder.type]"] || GLOB.clash_kit_shell_names[1]
		. += list(entry)

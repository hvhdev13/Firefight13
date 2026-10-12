GLOBAL_LIST_EMPTY(clash_kit_shops)
GLOBAL_LIST_EMPTY(clash_kit_budgets)
GLOBAL_LIST_EMPTY(clash_item_contents)
GLOBAL_LIST_INIT(clash_role_shop_ammo, list(
	JOB_SQUAD_SMARTGUN = list(/obj/item/ammo_magazine/smartgun = 10),
))

GLOBAL_LIST_INIT(clash_shop_shells, list(
	/obj/item/ammo_magazine/shotgun/buckshot = list(/obj/item/ammo_magazine/handful/shotgun/buckshot, /obj/item/ammo_magazine/handful/shotgun/slug, /obj/item/ammo_magazine/handful/shotgun/flechette),
	/obj/item/ammo_magazine/shotgun/heavy/buckshot = list(/obj/item/ammo_magazine/handful/shotgun/heavy/buckshot, /obj/item/ammo_magazine/handful/shotgun/heavy/slug, /obj/item/ammo_magazine/handful/shotgun/heavy/flechette),
))

GLOBAL_LIST_INIT(clash_shop_hidden_types, list(
	/obj/item/storage/box/guncase,
	/obj/item/tool/shovel/etool,
	/obj/item/storage/backpack/marine/satchel/rto,
	/obj/item/storage/belt/gun/utility,
	/obj/item/storage/large_holster/machete,
	/obj/item/clothing/suit/storage/marine/medium/leader,
	/obj/item/clothing/suit/storage/marine/medium/rto,
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

/proc/clash_shop_entry(obj/item/item_type, cost, name)
	return list("id" = "[item_type]", "name" = name || capitalize(strip_improper(initial(item_type.name))), "cost" = cost, "pool" = CLASH_SHOP_POINTS, "icon" = "[initial(item_type.icon)]", "icon_state" = initial(item_type.icon_state))

/proc/clash_shop_hidden(item_type)
	return is_path_in_list(item_type, GLOB.clash_shop_hidden_types) || ispath(item_type, /obj/item/device/encryptionkey) || ispath(item_type, /obj/item/pamphlet) || ispath(item_type, /obj/item/attachable) || clash_is_extended_magazine(item_type) || (ispath(item_type, /obj/item/ammo_magazine) && findtext("[item_type]/", "/ap/")) || GLOB.faction_clash_restricted_items[item_type]

/proc/clash_shop_worn_option(faction, item_type)
	var/datum/clash_kit_option/option = clash_item_option(faction, item_type)
	return option && (option.slot in list(KIT_SLOT_BACK, KIT_SLOT_BELT, KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R, KIT_SLOT_WEBBING))

/proc/get_clash_shop(job)
	if(GLOB.clash_kit_shops[job])
		return GLOB.clash_kit_shops[job]
	build_clash_kit_catalog()
	var/list/by_id = list()
	var/list/role_ammo = GLOB.clash_role_shop_ammo[job]
	var/list/primary_ammo = list("name" = "Primary ammo", "items" = list())
	var/list/sidearm_ammo = list("name" = "Sidearm ammo", "items" = list())
	var/list/sections = list(primary_ammo, sidearm_ammo)
	var/list/by_name = list("SIDEARM AMMUNITION" = sidearm_ammo, "SPECIAL AMMUNITION" = primary_ammo)
	for(var/slot in list(KIT_SLOT_PRIMARY, KIT_SLOT_SIDEARM))
		var/list/section = slot == KIT_SLOT_PRIMARY ? primary_ammo : sidearm_ammo
		for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[clash_kit_faction_for_job(job)]?[slot])
			if(!option.ammo_type || (option.only_class && option.only_class != GLOB.clash_job_classes[job]))
				continue
			for(var/obj/item/ammo_type as anything in GLOB.clash_shop_shells[option.ammo_type] || list(option.ammo_type))
				if(by_id["[ammo_type]"] || role_ammo?[ammo_type])
					continue
				var/list/item = clash_shop_entry(ammo_type, CLASH_SHOP_AMMO_COST)
				section["items"] += list(item)
				by_id["[ammo_type]"] = item
	for(var/obj/item/ammo_type as anything in role_ammo)
		var/list/item = clash_shop_entry(ammo_type, role_ammo[ammo_type])
		primary_ammo["items"] += list(item)
		by_id["[ammo_type]"] = item
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
				var/header = uppertext(entry[1])
				section = by_name[header]
				if(!section)
					section = list("name" = entry[1], "items" = list())
					by_name[header] = section
					sections += list(section)
				continue
			var/id = "[entry_type]"
			if(!section || entry[4] || entry[2] <= 0 || !ispath(entry_type, /obj/item) || by_id[id] || clash_shop_hidden(entry_type) || clash_shop_worn_option(clash_kit_faction_for_job(job), entry_type))
				continue
			var/list/item = clash_shop_entry(entry_type, entry[2], entry[1])
			item["pool"] = source[2]
			item["contents"] = clash_type_contents(entry_type)
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

/proc/clash_kit_visor_problem(obj/item/clothing/head/helmet/marine/helmet, obj/item/device/helmet_visor/visor, optic_name, list/inserted)
	if(!istype(helmet))
		return "The [optic_name] needs a combat helmet. It is packed in your gear instead."
	var/helmet_name = strip_improper(helmet.name)
	for(var/obj/item/device/helmet_visor/built_in as anything in helmet.built_in_visors)
		if(built_in.type == visor.type)
			return "The [helmet_name] already has a [optic_name] built in. The one you bought is packed in your gear."
	inserted = inserted || helmet.inserted_visors
	var/taken = length(inserted) >= helmet.max_inserted_visors || !visor.can_attach_to(helmet)
	for(var/obj/item/device/helmet_visor/fitted as anything in inserted)
		if(fitted.type == visor.type)
			taken = TRUE
	if(taken)
		return "The [helmet_name] has no free socket for the [optic_name]. It is packed in your gear instead."
	return null

/proc/clash_kit_fit_visor(mob/living/carbon/human/wearer, obj/item/device/helmet_visor/visor, mode)
	var/obj/item/clothing/head/helmet/marine/helmet = wearer.head
	helmet.inserted_visors += visor
	visor.forceMove(helmet)
	var/datum/action/item_action/cycle_helmet_huds/cycle_action = locate() in helmet.actions
	if(!cycle_action)
		cycle_action = new(helmet)
	cycle_action.give_to(wearer)
	if(!istype(visor, /obj/item/device/helmet_visor/medical) || !visor.can_toggle(wearer))
		return
	helmet.active_visor = visor
	cycle_action.set_action_overlay(visor)
	if(mode == CLASH_KIT_PREVIEW)
		helmet.update_icon()
	else
		helmet.recalculate_visors(wearer)

/proc/clash_kit_unfit_visor(mob/living/carbon/human/wearer, obj/item/clothing/head/helmet/marine/helmet, obj/item/device/helmet_visor/visor)
	if(helmet.active_visor == visor)
		helmet.active_visor = null
		helmet.toggle_visor(wearer, visor, TRUE)
	helmet.inserted_visors -= visor
	var/datum/action/item_action/cycle_helmet_huds/cycle_action = locate() in helmet.actions
	if(!cycle_action)
		return
	if(!length(helmet.built_in_visors) && !length(helmet.inserted_visors))
		qdel(cycle_action)
	else
		cycle_action.set_action_overlay(helmet.active_visor)

/proc/stock_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit, job, mode, ckey)
	for(var/datum/weakref/given_ref as anything in wearer.clash_kit_extras)
		var/obj/item/given = given_ref.resolve()
		if(!given || !clash_kit_carried(wearer, given))
			continue
		if(istype(given.loc, /obj/item/clothing/head/helmet/marine))
			clash_kit_unfit_visor(wearer, given.loc, given)
		qdel(given)
	wearer.clash_kit_extras = list()
	wearer.clash_kit_placed = list()
	var/list/holders = clash_kit_container_slots(wearer)
	var/list/containers = clash_kit_containers(wearer)
	if(mode == CLASH_KIT_SPAWN || mode == CLASH_KIT_PREVIEW)
		kit.sync_removed_slots()
		for(var/index in 1 to length(kit.removed))
			var/from = kit.removed_slots[index]
			var/list/search = from && holders[from] ? list(from) : holders
			for(var/key in search)
				var/obj/item/storage/holder = holders[key]
				var/obj/item/thing
				for(var/obj/item/exact in holder.contents)
					if("[exact.type]" == kit.removed[index])
						thing = exact
						break
				if(!thing)
					continue
				if(!from)
					kit.removed_slots[index] = key
				holder.remove_from_storage(thing, wearer)
				qdel(thing)
				break
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
		var/is_visor = istype(bought, /obj/item/device/helmet_visor)
		var/visor_problem = is_visor && clash_kit_visor_problem(wearer.head, bought, item["name"])
		var/obj/item/placed
		if(is_visor && !visor_problem)
			clash_kit_fit_visor(wearer, bought, mode)
			placed = wearer.head
		else
			var/wanted = kit.extra_slots[index]
			var/obj/item/storage/target = wanted && holders[wanted]
			var/list/tries = target ? list(target) : containers
			for(var/obj/item/storage/holder as anything in tries)
				if(holder.can_be_inserted(bought, wearer, TRUE) && holder.handle_item_insertion(bought, TRUE, wearer))
					placed = holder
					break
		if(!placed)
			qdel(bought)
			statuses[index] = "room"
			continue
		if(visor_problem)
			clash_kit_problem(wearer, KIT_SLOT_HELMET, visor_problem)
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

/proc/describe_clash_kit_pack(mob/living/carbon/human/wearer, datum/clash_kit/kit, obj/item/weapon/gun/shotgun)
	. = list()
	var/list/shells = clash_kit_shells_for(shotgun)
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
			var/assigned_to = LAZYACCESS(kit?.extra_slots, extra_index)
			var/unassigned = extra_index && !(assigned_to && holders[assigned_to])
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
			entry["fill"] = kit?.fills["[holder.type]"] || kit?.fills[CLASH_KIT_GUN_FILL] || GLOB.clash_kit_shell_names[1]
		. += list(entry)

/proc/describe_clash_kit_left_behind(mob/living/carbon/human/wearer, datum/clash_kit/kit)
	. = list()
	var/list/holders = clash_kit_container_slots(wearer)
	kit.sync_removed_slots()
	for(var/index in 1 to length(kit.removed))
		var/item_type = text2path(kit.removed[index])
		var/from = kit.removed_slots[index]
		var/list/fits = list()
		if(from && holders[from])
			var/obj/item/sample = new item_type
			fits += from
			for(var/key in holders)
				var/obj/item/storage/holder = holders[key]
				if(key != from && holder.can_be_inserted(sample, wearer, TRUE))
					fits += key
			qdel(sample)
		var/obj/item/shown = item_type
		. += list(list("index" = index, "type" = kit.removed[index], "name" = capitalize(strip_improper(initial(shown.name))), "icon" = "[initial(shown.icon)]", "icon_state" = initial(shown.icon_state), "from" = from, "fits" = fits))

/proc/describe_clash_kit_failed_moves(mob/living/carbon/human/wearer, datum/clash_kit/kit)
	. = list()
	var/list/holders = clash_kit_container_slots(wearer)
	for(var/index in wearer.clash_kit_move_failed)
		var/list/move = kit.moves[index]
		var/obj/item/moving = text2path(move[1])
		var/obj/item/storage/source = holders[move[2]]
		. += list(list("index" = index, "name" = capitalize(strip_improper(initial(moving.name))), "icon" = "[initial(moving.icon)]", "icon_state" = initial(moving.icon_state), "from" = source ? capitalize(source.name) : null, "to" = move[3]))

GLOBAL_LIST_EMPTY(clash_rack_cache)
GLOBAL_LIST_EMPTY(clash_rack_entries)
GLOBAL_LIST_INIT(clash_rack_swaps, list(
	/obj/item/storage/pouch/bayonet/upp = /obj/item/storage/pouch/bayonet,
))
GLOBAL_LIST_INIT(clash_squad_headsets, list(
	SQUAD_MARINE_1 = /obj/item/device/radio/headset/almayer/marine/alpha,
	SQUAD_MARINE_2 = /obj/item/device/radio/headset/almayer/marine/bravo,
))

GLOBAL_LIST_INIT(clash_uscm_rack_extras, list(
	list("POUCHES", list("Explosive Pouch", 0, /obj/item/storage/pouch/explosive, MARINE_CAN_BUY_POUCH, VENDOR_ITEM_REGULAR)),
	list("POUCHES", list("Large Pistol Magazine Pouch", 0, /obj/item/storage/pouch/magazine/pistol/large, MARINE_CAN_BUY_POUCH, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Firearm Lubricant", 0, /obj/item/prop/helmetgarb/gunoil, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Attachable Dogtags", 0, /obj/item/clothing/accessory/dogtags, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Diving Ospreys Shoulder Patch", 0, /obj/item/clothing/accessory/patch/falcon, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Diving Ospreys UA Shoulder Patch", 0, /obj/item/clothing/accessory/patch/falconalt, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("USCM Large Chest Patch", 0, /obj/item/clothing/accessory/patch/uscmlarge, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("USCM Shoulder Patch", 0, /obj/item/clothing/accessory/patch/uscmpatch, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("United Americas Shoulder Patch", 0, /obj/item/clothing/accessory/patch/ua, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("United Americas Flag Shoulder Patch", 0, /obj/item/clothing/accessory/patch/uasquare, null, VENDOR_ITEM_REGULAR)),
))

GLOBAL_LIST_INIT(clash_upp_rack_extras, list(
	list("HELMET", list("UL3 Armored Beret", 0, /obj/item/clothing/head/uppcap/beret, MARINE_CAN_BUY_HELMET, VENDOR_ITEM_REGULAR)),
	list("MASK", list("Rebreather", 0, /obj/item/clothing/mask/rebreather, MARINE_CAN_BUY_MASK, VENDOR_ITEM_REGULAR)),
	list("POUCHES", list("Explosive Pouch", 0, /obj/item/storage/pouch/explosive, MARINE_CAN_BUY_POUCH, VENDOR_ITEM_REGULAR)),
	list("POUCHES", list("Large Pistol Magazine Pouch", 0, /obj/item/storage/pouch/magazine/pistol/large, MARINE_CAN_BUY_POUCH, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Firearm Lubricant", 0, /obj/item/prop/helmetgarb/gunoil, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("Attachable Dogtags", 0, /obj/item/clothing/accessory/dogtags, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("UPP Patch", 0, /obj/item/clothing/accessory/patch/upp, null, VENDOR_ITEM_REGULAR)),
	list("COSMETICS", list("UPP Naval Infantry Patch", 0, /obj/item/clothing/accessory/patch/upp/naval, null, VENDOR_ITEM_REGULAR)),
))

GLOBAL_LIST_INIT(clash_gear_rack_extras, list(
	list("FLARE AND LIGHT", list("Combat Flashlight", 0, /obj/item/device/flashlight/combat, CLASH_CAN_BUY_FLASHLIGHT, VENDOR_ITEM_REGULAR)),
	list("FLARE AND LIGHT", list("M94 Marking Flare Pack", 0, /obj/item/storage/box/m94, CLASH_CAN_BUY_FLARES, VENDOR_ITEM_REGULAR)),
))

GLOBAL_LIST_INIT(clash_rack_role_extras, list(
	JOB_SQUAD_SMARTGUN = list(
		list("SPECIAL AMMUNITION", list("M41AE2 Box Magazine (10x24mm)", 5, /obj/item/ammo_magazine/rifle/lmg, null, VENDOR_ITEM_REGULAR)),
		list("SPECIAL AMMUNITION", list("M56 Smartgun Drum", 10, /obj/item/ammo_magazine/smartgun, null, VENDOR_ITEM_REGULAR)),
	),
	JOB_UPP_SPECIALIST = list(
		list("SPECIAL AMMUNITION", list("QYJ-72 Ammo Box (7.62x54mmR)", 5, /obj/item/ammo_magazine/pkp, null, VENDOR_ITEM_REGULAR)),
		list("SPECIAL AMMUNITION", list("Rotating Ammo Drum (7.62x51mm)", 5, /obj/item/ammo_magazine/minigun, null, VENDOR_ITEM_REGULAR)),
	),
))

GLOBAL_LIST_INIT(clash_clothing_role_extras, list(
	JOB_UPP_ENGI = list(list("BACKPACK (CHOOSE 1)", list("Combat Pack", 0, /obj/item/storage/backpack/lightpack/upp, MARINE_CAN_BUY_BACKPACK, VENDOR_ITEM_REGULAR))),
))

GLOBAL_LIST_INIT(clash_rack_dropped_categories, list(MARINE_CAN_BUY_ESSENTIALS, MARINE_CAN_BUY_KIT))

GLOBAL_LIST_INIT(clash_gun_rack_ammo, list(
	/obj/item/ammo_magazine/shotgun/flechette,
	/obj/item/ammo_magazine/shotgun/buckshot,
	/obj/item/ammo_magazine/shotgun/slugs,
	/obj/item/ammo_magazine/rifle/m4ra,
//	/obj/item/ammo_magazine/smg/m39,
	/obj/item/ammo_magazine/rifle,
	/obj/item/ammo_magazine/flamer_tank,
	/obj/item/ammo_magazine/pistol/m10,
	/obj/item/ammo_magazine/pistol/mod88/normalpoint,
	/obj/item/ammo_magazine/revolver,
	/obj/item/ammo_magazine/pistol,
	/obj/item/ammo_magazine/pistol/vp78,
	/obj/item/ammo_magazine/pistol/m1911,
	/obj/item/ammo_magazine/handful/lever_action/xm88,
	/obj/item/ammo_magazine/rifle/type71,
	/obj/item/ammo_magazine/rifle/type71/carbine,
	/obj/item/ammo_magazine/rifle/ak4047,
//	/obj/item/ammo_magazine/smg/bizon,
	/obj/item/ammo_magazine/shotgun/heavy/buckshot,
	/obj/item/ammo_magazine/shotgun/heavy/slug,
	/obj/item/ammo_magazine/shotgun/heavy/flechette,
	/obj/item/ammo_magazine/pistol/t73,
	/obj/item/ammo_magazine/revolver/upp,
	/obj/item/ammo_magazine/pistol/np92,
	/obj/item/ammo_magazine/sniper/svd,
))

/proc/clash_drop_vendor_sections(list/products, list/headers)
	. = list()
	var/dropping = FALSE
	for(var/list/entry as anything in products)
		if(!entry[3])
			dropping = (entry[1] in headers)
		if(!dropping)
			. += list(entry)

/proc/clash_drop_vendor_types(list/products, list/types)
	. = list()
	for(var/list/entry as anything in products)
		if(!(entry[3] in types))
			. += list(entry)

/proc/clash_vendor_insert(list/products, section, list/entry, list/header, merge_stock)
	var/at = 0
	for(var/index in 1 to length(products))
		var/list/listed = products[index]
		if(listed[3] == entry[3])
			if(merge_stock)
				listed[2] += entry[2]
			return
		if(!at && !listed[3] && findtext(uppertext(listed[1]), section))
			at = index
	if(!at)
		products += list(header, entry)
		return
	at++
	while(at <= length(products) && products[at][3])
		at++
	products.Insert(at, list(entry))

/proc/clash_uscm_role_list(job, gear)
	switch(job)
		if(JOB_SQUAD_MARINE)
			return gear ? list() : GLOB.cm_vending_clothing_marine
		if(JOB_SQUAD_ENGI)
			return gear ? GLOB.cm_vending_gear_engi : GLOB.cm_vending_clothing_engi
		if(JOB_SQUAD_MEDIC)
			return gear ? GLOB.cm_vending_gear_medic : GLOB.cm_vending_clothing_medic
		if(JOB_SQUAD_SMARTGUN)
			return gear ? GLOB.cm_vending_gear_smartgun : GLOB.cm_vending_clothing_smartgun
		if(JOB_SQUAD_LEADER)
			return gear ? GLOB.cm_vending_gear_leader : GLOB.cm_vending_clothing_leader
	return list()

/proc/clash_uscm_rack_all(gear)
	. = list()
	for(var/job in list(JOB_SQUAD_MARINE, JOB_SQUAD_ENGI, JOB_SQUAD_MEDIC, JOB_SQUAD_SMARTGUN, JOB_SQUAD_LEADER))
		. += clash_uscm_role_list(job, gear)

/proc/clash_rack_icon_entries()
	. = list()
	for(var/item_type in GLOB.clash_arena_med_swaps)
		var/list/swap = GLOB.clash_arena_med_swaps[item_type]
		. += list(list(swap[1], 0, swap[2]))
	for(var/list/extra as anything in GLOB.clash_uscm_rack_extras + GLOB.clash_upp_rack_extras + GLOB.clash_gear_rack_extras)
		. += list(extra[2])
	for(var/list/role_extras as anything in list(GLOB.clash_rack_role_extras, GLOB.clash_clothing_role_extras))
		for(var/job in role_extras)
			for(var/list/extra as anything in role_extras[job])
				. += list(extra[2])

/proc/clash_rack_paid(list/entry)
	return ispath(entry[3]) && !entry[4] && entry[2] > 0

/proc/clash_rack_source(kind, job)
	var/list/clothing
	var/list/gear
	if(kind == "uscm_clothing" || kind == "uscm_gear")
		clothing = clash_uscm_role_list(job, FALSE)
		gear = clash_uscm_role_list(job, TRUE)
	else
		var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
		var/datum/equipment_preset/preset = role?.gear_preset && GLOB.equipment_presets.gear_path_presets_list[role.gear_preset]
		if(!preset)
			return list()
		clothing = preset.get_antag_clothing_equipment()
		gear = preset.get_antag_gear_equipment()
	. = list()
	if(kind == "uscm_clothing" || kind == "upp_clothing")
		for(var/list/entry as anything in clothing)
			if(!clash_rack_paid(entry))
				. += list(entry)
		return
	. += gear
	var/list/header
	for(var/list/entry as anything in clothing)
		if(!entry[3])
			header = entry
		else if(clash_rack_paid(entry))
			clash_vendor_insert(., uppertext(header[1]), entry, header)

/proc/clash_rack_entry(list/listed, list/shop, medic)
	if(listed[4] in GLOB.clash_rack_dropped_categories)
		return null
	var/list/entry = listed.Copy()
	entry[3] = GLOB.clash_rack_swaps[entry[3]] || entry[3]
	if(!ispath(entry[3]))
		return entry
	entry = clash_arena_med_entry(entry, medic, FALSE)
	if(!entry || !clash_rack_paid(entry))
		return entry
	var/list/item = !(entry[3] in GLOB.clash_gun_rack_ammo) && shop["[entry[3]]"]
	if(!item)
		return null
	entry[2] = item["cost"]
	GLOB.clash_rack_entries[entry] = TRUE
	return entry

/proc/clash_rack_products(list/source, job, list/extras)
	var/list/shop = get_clash_shop(job)["by_id"]
	var/medic = clash_job_is_medic(job)
	var/list/products = list()
	for(var/list/listed as anything in source)
		var/list/entry = clash_rack_entry(listed, shop, medic)
		if(entry)
			products += list(entry)
	for(var/list/extra as anything in extras)
		var/list/entry = clash_rack_entry(extra[2], shop, medic)
		if(entry)
			clash_vendor_insert(products, extra[1], entry, list(extra[1], 0, null, null, null))
	. = list()
	for(var/index in 1 to length(products))
		var/list/entry = products[index]
		if(entry[3] || (index < length(products) && products[index + 1][3]))
			. += list(entry)

/proc/clash_rack_for(mob/living/carbon/human/user, kind)
	if(!ishuman(user))
		return list()
	var/key = "[kind]|[user.job]"
	if(!GLOB.clash_rack_cache[key])
		var/list/extras
		switch(kind)
			if("uscm_clothing")
				extras = (GLOB.clash_clothing_role_extras[user.job] || list()) + GLOB.clash_uscm_rack_extras
			if("upp_clothing")
				extras = (GLOB.clash_clothing_role_extras[user.job] || list()) + GLOB.clash_upp_rack_extras
			else
				extras = GLOB.clash_gear_rack_extras + (GLOB.clash_rack_role_extras[user.job] || list())
		GLOB.clash_rack_cache[key] = clash_rack_products(clash_rack_source(kind, user.job), user.job, extras)
	return GLOB.clash_rack_cache[key]

/proc/clash_rack_lock_text(mob/living/carbon/human/user, list/itemspec)
	if(!ishuman(user) || !GLOB.clash_rack_entries[itemspec])
		return null
	return clash_shop_item_lock_text(user.mind?.ckey || user.ckey, user.job, itemspec[2], itemspec[3])

/obj/structure/machinery/cm_vending/clothing/marine/clash
	req_access = list(ACCESS_MARINE_PREP)
	vendor_role = list()

/obj/structure/machinery/cm_vending/clothing/marine/clash/get_listed_products(mob/user)
	if(!user)
		return clash_uscm_rack_all(FALSE) + clash_rack_icon_entries()
	return clash_rack_for(user, "uscm_clothing")

/obj/structure/machinery/cm_vending/clothing/marine/clash/vendor_successful_vend_one(prod_type, mob/living/carbon/human/user, turf/target_turf, insignas_override, stack_amount)
	headset_type = GLOB.clash_squad_headsets[user.assigned_squad?.name] || initial(headset_type)
	return ..()

/obj/structure/machinery/cm_vending/gear/clash
	req_access = list(ACCESS_MARINE_PREP)

/obj/structure/machinery/cm_vending/gear/clash/get_listed_products(mob/user)
	if(!user)
		return clash_uscm_rack_all(TRUE)
	return clash_rack_for(user, "uscm_gear")

/obj/structure/machinery/cm_vending/clothing/antag/upp/clash/get_listed_products(mob/user)
	if(!user)
		return ..() + clash_rack_icon_entries()
	return clash_rack_for(user, "upp_clothing")

/obj/structure/machinery/cm_vending/gear/antag/clash/get_listed_products(mob/user)
	if(!user)
		return ..()
	return clash_rack_for(user, "upp_gear")

/obj/structure/machinery/cm_vending/sorted/cargo_guns/squad_prep/clash/populate_product_list(scale)
	..()
	listed_products = clash_drop_vendor_types(listed_products, list(/obj/item/storage/box/m94, /obj/item/weapon/gun/smg/m39, /obj/item/ammo_magazine/smg/m39))
	var/list/extras = list(
		list("PRIMARY AMMUNITION", list("M4RA Magazine (10x24mm)", 1.8, /obj/item/ammo_magazine/rifle/m4ra, VENDOR_ITEM_REGULAR)),
//		list("PRIMARY AMMUNITION", list("M39 Magazine (10x20mm)", 1.8, /obj/item/ammo_magazine/smg/m39, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("M41A Magazine (10x24mm)", 1.9, /obj/item/ammo_magazine/rifle, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("M240 Incinerator Tank", floor(scale * 3), /obj/item/ammo_magazine/flamer_tank, VENDOR_ITEM_REGULAR)),
		list("SIDEARM AMMUNITION", list("M10 HV Magazine (10x20mm-APC)", floor(scale * 4), /obj/item/ammo_magazine/pistol/m10, VENDOR_ITEM_REGULAR)),
		list("SIDEARM AMMUNITION", list("VP78 Magazine", floor(scale * 5), /obj/item/ammo_magazine/pistol/vp78, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("XM88 .458 SOCOM Rounds", floor(scale * 10), /obj/item/ammo_magazine/handful/lever_action/xm88, VENDOR_ITEM_REGULAR)),
		list("SIDEARM AMMUNITION", list("M1911 Magazine (.45)", floor(scale * 10), /obj/item/ammo_magazine/pistol/m1911, VENDOR_ITEM_REGULAR)),
	)
	for(var/list/extra as anything in extras)
		clash_vendor_insert(listed_products, extra[1], extra[2], list(extra[1], -1, null, null), TRUE)

/obj/structure/machinery/cm_vending/sorted/cargo_guns/upp_squad_guns/clash/populate_product_list(scale)
	..()
	listed_products = clash_drop_vendor_types(listed_products, list(/obj/item/storage/box/m94, /obj/item/weapon/gun/smg/bizon/upp, /obj/item/ammo_magazine/smg/bizon))
	var/list/extras = list(
		list("PRIMARY AMMUNITION", list("Type 71 Magazine (5.45x39mm)", 1.9, /obj/item/ammo_magazine/rifle/type71, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("Type 71 Carbine Magazine (5.45x39mm)", 1.8, /obj/item/ammo_magazine/rifle/type71/carbine, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("AK-4047 Magazine (10x24mm)", 1.8, /obj/item/ammo_magazine/rifle/ak4047, VENDOR_ITEM_REGULAR)),
//		list("PRIMARY AMMUNITION", list("Type 64 Helical Magazine (7.62x19mm)", 1.8, /obj/item/ammo_magazine/smg/bizon, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("M240 Incinerator Tank", floor(scale * 8), /obj/item/ammo_magazine/flamer_tank, VENDOR_ITEM_REGULAR)),
		list("PRIMARY AMMUNITION", list("Type 88 Magazine (7.62x54mmR)", floor(scale * 10), /obj/item/ammo_magazine/sniper/svd, VENDOR_ITEM_REGULAR)),
	)
	for(var/list/extra as anything in extras)
		clash_vendor_insert(listed_products, extra[1], extra[2], list(extra[1], -1, null, null), TRUE)

/proc/clash_tool_products(list/products, mob/living/carbon/human/user)
	if(!user)
		return products + clash_engineer_build_icons()
	if(!ishuman(user) || !clash_is_engineer(user))
		return products
	return products + clash_engineer_vendor_entries(user)

/proc/clash_engineer_vendor_access(obj/structure/machinery/cm_vending/vendor, mob/user, display)
	if(!ishuman(user) || clash_is_engineer(user))
		return TRUE
	if(display)
		to_chat(user, SPAN_WARNING("Access denied."))
		vendor.vend_fail()
	return FALSE

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/clash
	req_access = list()
	req_one_access = list(ACCESS_MARINE_PREP)
	vendor_theme = VENDOR_THEME_USCM

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/clash/populate_product_list(scale)
	..()
	listed_products = clash_drop_vendor_sections(listed_products, list("SCANNERS"))

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/clash/get_available_products(mob/user)
	return clash_tool_products(..(), user)

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/clash/can_access_to_vend(mob/user, display = TRUE, ignore_hack = FALSE)
	return clash_engineer_vendor_access(src, user, display) && ..()

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/antag/clash/populate_product_list(scale)
	..()
	listed_products = clash_drop_vendor_sections(listed_products, list("SCANNERS"))

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/antag/clash/get_available_products(mob/user)
	return clash_tool_products(..(), user)

/obj/structure/machinery/cm_vending/sorted/tech/tool_storage/antag/clash/can_access_to_vend(mob/user, display = TRUE, ignore_hack = FALSE)
	return clash_engineer_vendor_access(src, user, display) && ..()

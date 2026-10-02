GLOBAL_LIST_INIT(clash_attachment_groups, list(
	list(/obj/item/attachable/reflex),
	list(/obj/item/attachable/reddot),
	list(/obj/item/attachable/flashlight),
	list(/obj/item/attachable/magnetic_harness, /obj/item/attachable/extended_barrel),
	list(/obj/item/attachable/angledgrip, /obj/item/attachable/flashlight/grip),
	list(/obj/item/attachable/stock),
	list(/obj/item/attachable/verticalgrip),
	list(/obj/item/attachable/scope/mini),
	list(/obj/item/attachable/lasersight),
	list(/obj/item/attachable/compensator, /obj/item/attachable/burstfire_assembly, /obj/item/attachable/shotgun_choke),
	list(/obj/item/attachable/gyro, /obj/item/attachable/heavy_barrel, /obj/item/attachable/suppressor, /obj/item/attachable/bipod),
	list(/obj/item/attachable/attached_gun/shotgun, /obj/item/attachable/attached_gun/extinguisher, /obj/item/attachable/attached_gun/flare_launcher, /obj/item/attachable/attached_gun/flamer_nozzle),
	list(/obj/item/attachable/attached_gun/grenade),
	list(/obj/item/attachable/attached_gun/flamer),
	list(/obj/item/attachable/scope),
	list(/obj/item/attachable/bayonet),
))

GLOBAL_LIST_EMPTY(clash_weapon_tracks)
GLOBAL_LIST_EMPTY(clash_weapon_unlock_levels)

/proc/clash_attachment_group(attachment_type)
	var/best_depth = 0
	for(var/group in 1 to length(GLOB.clash_attachment_groups))
		for(var/root in GLOB.clash_attachment_groups[group])
			var/depth = length("[root]")
			if(depth > best_depth && ispath(attachment_type, root))
				best_depth = depth
				. = group

/proc/clash_weapon_unlock_xp(index, count)
	return round(CLASH_WEAPON_XP_FIRST + CLASH_WEAPON_XP_SPAN * (index - 1) / count, 1)

/proc/build_clash_weapon_tracks()
	for(var/faction in GLOB.clash_kit_menu)
		for(var/slot in list(KIT_SLOT_PRIMARY, KIT_SLOT_SIDEARM))
			for(var/datum/clash_kit_option/gun as anything in GLOB.clash_kit_menu[faction][slot])
				if(!GLOB.clash_weapon_tracks[gun.item_type])
					build_clash_weapon_track(gun.item_type)

/proc/build_clash_weapon_track(gun_type)
	var/list/by_group = list()
	for(var/attachment_type in get_clash_gun_attachables(gun_type))
		var/group = clash_attachment_group(attachment_type)
		if(group)
			LAZYADD(by_group["[group]"], attachment_type)
	var/list/unlocks = list()
	for(var/group in 1 to length(GLOB.clash_attachment_groups))
		if(by_group["[group]"])
			unlocks += list(list("group" = group, "types" = by_group["[group]"]))
	unlocks += list(list("group" = 0, "types" = list()))
	var/count = length(unlocks)
	var/grip_group = clash_attachment_group(/obj/item/attachable/verticalgrip)
	for(var/index in 1 to count)
		if(unlocks[index]["group"] != grip_group)
			continue
		var/floor_index = index
		while(floor_index < count && clash_weapon_unlock_xp(floor_index, count) < CLASH_GRIP_FLOOR_XP)
			floor_index++
		if(floor_index != index)
			var/list/grip = unlocks[index]
			unlocks.Cut(index, index + 1)
			unlocks.Insert(floor_index, list(grip))
		break
	var/list/levels = list()
	for(var/index in 1 to count)
		var/list/unlock = unlocks[index]
		unlock["xp"] = clash_weapon_unlock_xp(index, count)
		for(var/attachment_type in unlock["types"])
			levels[attachment_type] = index + 1
	GLOB.clash_weapon_tracks[gun_type] = unlocks
	GLOB.clash_weapon_unlock_levels[gun_type] = levels

/datum/clash_progress/proc/weapon_level(gun_type)
	var/list/entry = weapons["[gun_type]"]
	if(!entry)
		return 1
	var/level = 1
	for(var/list/unlock as anything in GLOB.clash_weapon_tracks[gun_type])
		if(entry["xp"] >= unlock["xp"])
			level++
	return max(entry["best"], level)

/datum/clash_progress/proc/carrier_step(family)
	var/list/entry = carriers[family]
	var/xp = entry ? entry["xp"] : 0
	var/step = 0
	for(var/list/carrier_step as anything in GLOB.clash_carrier_tracks[family])
		if(xp >= carrier_step[1])
			step++
	return max(entry ? entry["best"] : 0, step)

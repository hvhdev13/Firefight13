GLOBAL_LIST_EMPTY(clash_kits)
GLOBAL_LIST_EMPTY(clash_active_kits)
GLOBAL_LIST_EMPTY(clash_kit_issue_items)
GLOBAL_LIST_EMPTY(clash_kit_issue_pending)

/datum/clash_kit
	var/name
	var/list/choices = list()
	var/list/extras = list()
	var/list/removed = list()
	var/list/fills = list()

/datum/clash_kit/proc/get_option(slot)
	return get_clash_kit_option(choices[slot])

GLOBAL_LIST_INIT(clash_kit_mode_tags, build_clash_kit_mode_tags())

/proc/build_clash_kit_mode_tags()
	. = list()
	for(var/datum/game_mode/extended/faction_clash/hvh/mode_type as anything in typesof(/datum/game_mode/extended/faction_clash/hvh))
		if(initial(mode_type.use_kits) && initial(mode_type.config_tag))
			. += initial(mode_type.config_tag)

/proc/clash_uses_kits()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		return clash_mode.use_kits
	return !SSticker.mode && (GLOB.master_mode in GLOB.clash_kit_mode_tags)

/proc/clash_player_save_path(ckey, filename)
	return "data/player_saves/[copytext(ckey, 1, 2)]/[ckey]/[filename]"

/proc/clash_kit_faction_for_job(job)
	return (job in UPP_JOB_LIST) ? FACTION_UPP : FACTION_MARINE

/proc/clash_role_list()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		return clash_mode.get_roles_list()
	return (GLOB.master_mode in GLOB.clash_kit_mode_tags) ? GLOB.clash_arena_roles : GLOB.ROLES_CM_VS_UPP

/proc/get_clash_kit_roles()
	. = list(FACTION_MARINE = list(), FACTION_UPP = list())
	for(var/title in clash_role_list())
		.[clash_kit_faction_for_job(title)] += title

/proc/clash_kit_path(ckey)
	return clash_player_save_path(ckey, "clash_kits.sav")

GLOBAL_LIST_INIT(clash_kit_old_presets, list("Rifleman", "Assault", "Carbineer", "Breacher", "Marksman", "Gunner"))

/proc/get_clash_kits(ckey, job)
	if(!ckey || !job)
		return null
	build_clash_kit_catalog()
	var/list/by_job = GLOB.clash_kits[ckey]
	if(!by_job)
		by_job = list()
		GLOB.clash_kits[ckey] = by_job
		GLOB.clash_active_kits[ckey] = list()
		load_clash_kits(ckey)
	var/list/kits = by_job[job]
	if(!kits)
		kits = list()
		by_job[job] = kits
	while(length(kits) < CLASH_KIT_COUNT)
		var/datum/clash_kit/kit = new
		if(!length(kits))
			kit.name = "Default"
		else
			kit.name = clash_kit_custom_name(kits)
		kits += kit
	return kits

/proc/clash_kit_custom_name(list/kits)
	var/customs = 1
	for(var/datum/clash_kit/other as anything in kits)
		if(findtext(other.name, "Custom") == 1)
			customs++
	return customs > 1 ? "Custom [customs]" : "Custom"

/proc/get_clash_active_kit_index(ckey, job)
	var/list/kits = get_clash_kits(ckey, job)
	if(!kits)
		return 1
	var/list/active = GLOB.clash_active_kits[ckey]
	return clamp(active[job] || 1, 1, length(kits))

/proc/get_clash_active_kit(ckey, job)
	var/list/kits = get_clash_kits(ckey, job)
	if(!kits)
		return null
	return kits[get_clash_active_kit_index(ckey, job)]

/proc/save_clash_kits(ckey)
	if(!ckey || IsGuestKey(ckey))
		return
	var/list/by_job = GLOB.clash_kits[ckey]
	var/list/payload = list()
	for(var/job in by_job)
		var/list/stored = list()
		for(var/datum/clash_kit/kit as anything in by_job[job])
			stored += list(list("name" = kit.name, "choices" = kit.choices, "extras" = kit.extras, "removed" = kit.removed, "fills" = kit.fills))
		payload[job] = stored
	var/savefile/save = new(clash_kit_path(ckey))
	save.cd = "/"
	save["kits"] << payload
	save["active"] << GLOB.clash_active_kits[ckey]

/proc/load_clash_kits(ckey)
	if(!ckey || IsGuestKey(ckey))
		return
	var/path = clash_kit_path(ckey)
	if(!fexists(path))
		return
	var/savefile/save = new(path)
	save.cd = "/"
	var/list/payload
	save["kits"] >> payload
	var/list/active
	save["active"] >> active
	if(islist(active))
		GLOB.clash_active_kits[ckey] = active
	if(!islist(payload))
		return
	var/list/by_job = GLOB.clash_kits[ckey]
	for(var/job in payload)
		var/list/kits = list()
		for(var/list/stored in payload[job])
			if(length(kits) >= CLASH_KIT_COUNT)
				break
			var/datum/clash_kit/kit = new
			if(stored["name"] in GLOB.clash_kit_old_presets)
				kit.name = "Custom"
				kits += kit
				continue
			kit.name = stored["name"] == "Standard issue" ? "Default" : stored["name"]
			for(var/slot in stored["choices"])
				var/id = replacetext(stored["choices"][slot], "/obj/item/storage/pouch/firstaid/ert", "/obj/item/storage/pouch/firstaid/clash")
				if(!get_clash_kit_option(id) && ispath(text2path(id)))
					id = clash_kit_option_id(clash_kit_faction_for_job(job), slot, text2path(id))
				if(get_clash_kit_option(id))
					kit.choices[slot] = id
			for(var/extra in stored["extras"])
				if(ispath(text2path(extra), /obj/item))
					kit.extras += extra
			for(var/unwanted in stored["removed"])
				if(ispath(text2path(unwanted), /obj/item))
					kit.removed += unwanted
			for(var/container in stored["fills"])
				if(ispath(text2path(container), /obj/item/storage) && (stored["fills"][container] in GLOB.clash_kit_shell_names))
					kit.fills[container] = stored["fills"][container]
			kits += kit
		var/static/regex/default_name = regex(@"^Custom( \d+)?$")
		var/customs = 0
		for(var/datum/clash_kit/kit as anything in kits)
			if(default_name.Find(kit.name))
				customs++
				kit.name = customs > 1 ? "Custom [customs]" : "Custom"
		by_job[job] = kits

/proc/issue_clash_role_kit(mob/living/carbon/human/fighter, job)
	var/kit_path = GLOB.clash_kit_role_kits[job]
	var/datum/equipment_preset/full_kit = kit_path && GLOB.equipment_presets.gear_path_presets_list[kit_path]
	if(full_kit)
		var/obj/item/pack = fighter.back
		if(pack && !length(pack.contents))
			fighter.temp_drop_inv_item(pack, TRUE)
			qdel(pack)
		try
			full_kit.load_gear(fighter, fighter.client)
		catch(var/exception/error)
			stack_trace("Clash kit could not issue [job] their full kit: [error]")
	clash_kit_default_webbing(fighter)

/proc/clash_kit_default_webbing(mob/living/carbon/human/fighter)
	var/obj/item/clothing/under/uniform = fighter.w_uniform
	if(!uniform || (locate(/obj/item/clothing/accessory/storage) in uniform.accessories))
		return
	var/obj/item/clothing/accessory/storage/webbing = new /obj/item/clothing/accessory/storage/webbing/black(fighter)
	if(uniform.can_attach_accessory(webbing))
		uniform.attach_accessory(fighter, webbing, TRUE)
	else
		qdel(webbing)

/proc/clash_kit_replace_worn(mob/living/carbon/human/wearer, wear_slot, item_type)
	var/obj/item/old = wearer.get_item_by_slot(wear_slot)
	var/list/carried = list()
	if(old)
		var/obj/item/storage/old_storage = clash_kit_storage_of(old)
		if(old_storage)
			for(var/obj/item/thing in old_storage.contents)
				carried += thing
				thing.forceMove(wearer)
		wearer.temp_drop_inv_item(old, TRUE)
		qdel(old)
	var/obj/item/fresh = new item_type(wearer)
	if(!wearer.equip_to_slot_if_possible(fresh, wear_slot, TRUE, FALSE, TRUE))
		qdel(fresh)
		fresh = null
	var/obj/item/storage/holder = clash_kit_storage_of(fresh)
	for(var/obj/item/thing as anything in carried)
		if(istype(thing, /obj/item/device/flashlight/flare) && !istype(holder, /obj/item/storage/pouch/flare))
			qdel(thing)
			continue
		if(holder?.can_be_inserted(thing, wearer, TRUE) && holder.handle_item_insertion(thing, TRUE, wearer))
			continue
		if(!wearer.equip_to_appropriate_slot(thing))
			qdel(thing)
	return fresh

/proc/clash_kit_hand_or_floor(mob/living/carbon/human/wearer, obj/item/thing)
	if(wearer.put_in_hands(thing, FALSE))
		return
	var/turf/floor = get_turf(wearer)
	if(floor)
		thing.forceMove(floor)
	else
		qdel(thing)

/proc/clash_fit_attachment(obj/item/weapon/gun/gun, obj/item/attachable/attachment, mob/living/carbon/human/wearer, discard_old)
	if(!gun.can_attach_to_gun(wearer, attachment))
		return FALSE
	var/obj/item/attachable/old = gun.attachments[attachment.slot]
	if(old && !get_turf(gun))
		gun.attachments[attachment.slot] = null
		qdel(old)
	attachment.Attach(gun)
	gun.update_attachable(attachment.slot)
	if(!QDELETED(old) && (discard_old || (old.type in gun.starting_attachment_types)))
		if(old.loc == wearer)
			wearer.temp_drop_inv_item(old, TRUE)
		qdel(old)
	return TRUE

/proc/clash_kit_fit_webbing(mob/living/carbon/human/wearer, item_type, list/cosmetics)
	var/obj/item/clothing/under/uniform = wearer.w_uniform
	if(!uniform)
		return
	usr = get_turf(wearer) ? null : wearer
	var/obj/item/clothing/accessory/storage/wanted = item_type
	var/wanted_slot = initial(wanted.worn_accessory_slot)
	var/list/carried = list()
	for(var/obj/item/clothing/accessory/storage/old in uniform.accessories?.Copy())
		if(old.worn_accessory_slot != wanted_slot)
			continue
		if(old.type in cosmetics)
			return
		for(var/obj/item/thing in old.hold.contents)
			carried += thing
			thing.forceMove(wearer)
		uniform.remove_accessory(wearer, old)
		var/mob/holder = old.loc
		if(ismob(holder))
			holder.temp_drop_inv_item(old, TRUE)
		qdel(old)
	var/obj/item/clothing/accessory/storage/fresh = new item_type(wearer)
	if(uniform.can_attach_accessory(fresh))
		uniform.attach_accessory(wearer, fresh, TRUE)
	else
		qdel(fresh)
		fresh = null
	for(var/obj/item/thing as anything in carried)
		if(fresh?.hold.can_be_inserted(thing, wearer, TRUE) && fresh.hold.handle_item_insertion(thing, TRUE, wearer))
			continue
		if(!wearer.equip_to_appropriate_slot(thing))
			qdel(thing)

/proc/clash_trim_icon(icon/source)
	var/width = source.Width()
	var/height = source.Height()
	var/left = width + 1
	var/right = 0
	var/bottom = height + 1
	var/top = 0
	for(var/x in 1 to width)
		for(var/y in 1 to height)
			if(!source.GetPixel(x, y))
				continue
			left = min(left, x)
			right = max(right, x)
			bottom = min(bottom, y)
			top = max(top, y)
	if(right)
		source.Crop(left, bottom, right, top)
	return source

/proc/clash_kit_primary_of(mob/living/carbon/human/wearer)
	var/obj/item/weapon/gun/stored = wearer.s_store
	if(istype(stored) && !clash_is_sidearm(stored))
		return stored
	for(var/obj/item/weapon/gun/carried in wearer.get_contents())
		if(!clash_is_sidearm(carried) && !istype(carried.loc, /obj/item/weapon/gun))
			return carried
	return null

/proc/clash_is_sidearm(obj/item/weapon/gun/gun)
	return istype(gun, /obj/item/weapon/gun/pistol) || istype(gun, /obj/item/weapon/gun/revolver)

/proc/clash_kit_purge_guns(mob/living/carbon/human/wearer, sidearms)
	for(var/obj/item/weapon/gun/gun in wearer.get_contents())
		if(clash_is_sidearm(gun) != sidearms)
			continue
		if(gun.loc == wearer)
			wearer.temp_drop_inv_item(gun, TRUE)
		qdel(gun)

/proc/clash_kit_purge_stray_magazines(mob/living/carbon/human/wearer)
	var/list/guns = list()
	for(var/obj/item/weapon/gun/gun in wearer.get_contents())
		guns += gun
	for(var/obj/item/ammo_magazine/magazine in wearer.get_contents())
		if(istype(magazine.loc, /obj/item/weapon/gun))
			continue
		var/fits = FALSE
		for(var/obj/item/weapon/gun/gun as anything in guns)
			if((magazine.gun_type && istype(gun, magazine.gun_type)) || (magazine.type in gun.accepted_ammo))
				fits = TRUE
				break
		if(!fits)
			qdel(magazine)

/proc/clash_kit_shells_for(obj/item/weapon/gun/gun)
	var/obj/item/weapon/gun/shotgun/shotgun = gun
	return istype(shotgun) ? GLOB.clash_kit_shells[shotgun.gauge] : null

/proc/clash_kit_magazine_for(obj/item/weapon/gun/gun)
	for(var/id in GLOB.clash_kit_options)
		var/datum/clash_kit_option/option = GLOB.clash_kit_options[id]
		if(option.item_type == gun.type && option.ammo_type)
			return option.ammo_type
	var/obj/item/weapon/gun/base = gun.type
	var/magazine = initial(base.current_mag)
	return (ispath(magazine, /obj/item/ammo_magazine) && !ispath(magazine, /obj/item/ammo_magazine/internal)) ? magazine : null

/proc/clash_kit_sidearm_of(mob/living/carbon/human/wearer)
	for(var/obj/item/weapon/gun/carried in wearer.get_contents())
		if(clash_is_sidearm(carried) && !istype(carried.loc, /obj/item/weapon/gun))
			return carried
	return null

/proc/clash_kit_holds_ammo(obj/item/storage/holder)
	for(var/path in holder.can_hold)
		if(ispath(path, /obj/item/ammo_magazine))
			return TRUE
	return FALSE

/proc/clash_kit_top_up(obj/item/storage/holder, ammo_type, mob/living/carbon/human/wearer)
	. = FALSE
	for(var/count in 1 to CLASH_KIT_FILL_LIMIT)
		var/obj/item/ammo = new ammo_type
		if(!holder.can_be_inserted(ammo, wearer, TRUE) || !holder.handle_item_insertion(ammo, TRUE, wearer))
			qdel(ammo)
			return
		. = TRUE

/proc/clash_kit_spare_ammo(mob/living/carbon/human/wearer, ammo_type, count)
	var/list/containers = clash_kit_containers(wearer)
	for(var/index in 1 to count)
		var/obj/item/ammo = new ammo_type(wearer)
		if(wearer.equip_to_appropriate_slot(ammo))
			continue
		var/placed = FALSE
		for(var/obj/item/storage/holder as anything in containers)
			if(holder.can_be_inserted(ammo, wearer, TRUE) && holder.handle_item_insertion(ammo, TRUE, wearer))
				placed = TRUE
				break
		if(!placed)
			qdel(ammo)
			return

/proc/clash_kit_fit_pouches(mob/living/carbon/human/wearer, datum/clash_kit/kit, faction)
	var/obj/item/weapon/gun/primary = clash_kit_primary_of(wearer)
	var/obj/item/weapon/gun/sidearm = clash_kit_sidearm_of(wearer)
	var/list/shells = primary && clash_kit_shells_for(primary)
	var/list/ammo_types = list()
	for(var/shell_name in shells)
		ammo_types += shells[shell_name]
	if(primary && !shells)
		ammo_types += clash_kit_magazine_for(primary)
	if(sidearm)
		ammo_types += clash_kit_magazine_for(sidearm)
	ammo_types -= null
	if(!length(ammo_types))
		return
	var/list/starting = GLOB.clash_starting_kits[faction]
	for(var/slot in list(KIT_SLOT_BELT, KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R))
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		var/obj/item/storage/holder = clash_kit_storage_of(wearer.get_item_by_slot(wear_slot))
		if(!holder || !clash_kit_holds_ammo(holder))
			continue
		var/fits = FALSE
		for(var/ammo_type in ammo_types)
			if(holder.can_hold_type(ammo_type, wearer))
				fits = TRUE
				break
		if(fits)
			continue
		var/replacement = slot == KIT_SLOT_BELT ? starting[slot] : (shells ? /obj/item/storage/pouch/shotgun : /obj/item/storage/pouch/magazine)
		if(replacement && holder.type != replacement)
			clash_kit_replace_worn(wearer, wear_slot, replacement)
	if(!primary)
		return
	var/list/primary_ammo = list()
	for(var/shell_name in shells)
		primary_ammo += shells[shell_name]
	if(!shells)
		primary_ammo += clash_kit_magazine_for(primary)
	primary_ammo -= null
	for(var/obj/item/storage/holder as anything in clash_kit_containers(wearer))
		if(!clash_kit_holds_ammo(holder))
			continue
		for(var/ammo_type in primary_ammo)
			if(holder.can_hold_type(ammo_type, wearer))
				return
	var/replacement = shells ? /obj/item/storage/pouch/shotgun : /obj/item/storage/pouch/magazine
	var/obj/item/storage/probe = new replacement
	var/useful = FALSE
	for(var/ammo_type in primary_ammo)
		if(probe.can_hold_type(ammo_type, wearer))
			useful = TRUE
			break
	qdel(probe)
	if(!useful)
		return
	for(var/slot in list(KIT_SLOT_POUCH_R, KIT_SLOT_POUCH_L))
		if(kit.get_option(slot))
			continue
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		var/obj/item/worn = wearer.get_item_by_slot(wear_slot)
		if(istype(worn, /obj/item/storage/pouch/firstaid) || istype(worn, /obj/item/storage/pouch/medical))
			continue
		clash_kit_replace_worn(wearer, wear_slot, replacement)
		return

/proc/clash_kit_fill_ammo(mob/living/carbon/human/wearer, datum/clash_kit/kit, mode)
	var/obj/item/weapon/gun/primary = clash_kit_primary_of(wearer)
	var/obj/item/weapon/gun/sidearm = clash_kit_sidearm_of(wearer)
	var/list/shells = primary && clash_kit_shells_for(primary)
	var/primary_ammo = shells ? null : (primary && clash_kit_magazine_for(primary))
	var/sidearm_ammo = sidearm && clash_kit_magazine_for(sidearm)
	var/primary_filled = FALSE
	var/sidearm_filled = FALSE
	for(var/obj/item/storage/holder as anything in clash_kit_containers(wearer))
		if(!clash_kit_holds_ammo(holder))
			continue
		var/shell_type = shells && shells[kit.fills["[holder.type]"] || shells[1]]
		var/ammo_type = shell_type || primary_ammo
		if(ammo_type && holder.can_hold_type(ammo_type, wearer))
			clash_kit_top_up(holder, ammo_type, wearer)
			primary_filled = TRUE
		else if(sidearm_ammo && holder.can_hold_type(sidearm_ammo, wearer))
			clash_kit_top_up(holder, sidearm_ammo, wearer)
			sidearm_filled = TRUE
	if(mode != CLASH_KIT_SPAWN && mode != CLASH_KIT_PREVIEW)
		return
	if(!primary_filled && (shells || primary_ammo))
		clash_kit_spare_ammo(wearer, shells ? shells[shells[1]] : primary_ammo, CLASH_KIT_SPARE_PRIMARY)
	if(!sidearm_filled && sidearm_ammo)
		clash_kit_spare_ammo(wearer, sidearm_ammo, CLASH_KIT_SPARE_SIDEARM)

/proc/apply_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit, mode = CLASH_KIT_SPAWN, job, datum/preferences/prefs, ckey)
	if(!kit || QDELETED(wearer))
		return
	job = job || wearer.job
	ckey = ckey || wearer.ckey
	kit = clash_filter_kit(kit, ckey, job)
	if(mode != CLASH_KIT_RESET)
		wearer.clash_perks = clash_kit_perks(kit)
	var/list/cosmetics = clash_cosmetic_paths(prefs || wearer.client?.prefs || GLOB.preferences_datums[wearer.ckey])
	var/faction = wearer.faction
	var/datum/clash_kit_option/primary = kit.get_option(KIT_SLOT_PRIMARY)
	var/datum/clash_kit_option/sidearm = kit.get_option(KIT_SLOT_SIDEARM)
	if(primary?.faction != faction)
		primary = null
	if(sidearm?.faction != faction)
		sidearm = null

	var/list/base_outfit = GLOB.clash_kit_base_outfits[faction]
	for(var/wear_slot in base_outfit)
		if(wearer.get_item_by_slot(wear_slot))
			continue
		var/base_type = base_outfit[wear_slot]
		var/obj/item/base_item = new base_type(wearer)
		if(!wearer.equip_to_slot_if_possible(base_item, wear_slot, TRUE, FALSE, TRUE))
			qdel(base_item)
	clash_kit_default_webbing(wearer)
	if(faction == FACTION_UPP && istype(wearer.w_uniform, /obj/item/clothing/under/marine/veteran/UPP) && !(locate(/obj/item/clothing/accessory/patch/upp) in wearer.w_uniform.accessories))
		wearer.equip_to_slot_if_possible(new /obj/item/clothing/accessory/patch/upp(wearer), WEAR_ACCESSORY, TRUE, TRUE, TRUE)

	var/obj/item/issue_primary = wearer.s_store
	if(issue_primary)
		wearer.temp_drop_inv_item(issue_primary, TRUE)
		issue_primary.forceMove(wearer)
	for(var/slot in GLOB.clash_kit_worn_slots)
		var/datum/clash_kit_option/option = kit.get_option(slot)
		if(!option || option.faction != faction)
			continue
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		var/obj/item/worn = wearer.get_item_by_slot(wear_slot)
		if(worn && (worn.type in cosmetics))
			continue
		clash_kit_replace_worn(wearer, wear_slot, option.item_type)

	var/datum/clash_kit_option/webbing = kit.get_option(KIT_SLOT_WEBBING)
	if(webbing?.faction == faction)
		clash_kit_fit_webbing(wearer, webbing.item_type, cosmetics)
	clash_downgrade_locked_gear(wearer, ckey, job, cosmetics)

	var/obj/item/weapon/gun/main_gun
	if(primary)
		clash_kit_purge_guns(wearer, FALSE)
		main_gun = new primary.item_type(wearer)
		if(!wearer.equip_to_slot_if_possible(main_gun, WEAR_J_STORE, TRUE, FALSE, TRUE) && !wearer.equip_to_appropriate_slot(main_gun))
			clash_kit_hand_or_floor(wearer, main_gun)
		for(var/slot in GLOB.clash_kit_attachment_slots)
			var/datum/clash_kit_option/option = kit.get_option(slot)
			if(!option || !clash_kit_attachment_fits(option.item_type, main_gun.type))
				continue
			var/obj/item/attachable/attachment = new option.item_type(main_gun)
			if(!clash_fit_attachment(main_gun, attachment, wearer, TRUE))
				qdel(attachment)
	else if(!QDELETED(issue_primary))
		if(!wearer.equip_to_slot_if_possible(issue_primary, WEAR_J_STORE, TRUE, FALSE, TRUE) && !wearer.equip_to_appropriate_slot(issue_primary))
			clash_kit_hand_or_floor(wearer, issue_primary)
	if(sidearm)
		clash_kit_purge_guns(wearer, TRUE)
		var/obj/item/weapon/gun/side_gun = new sidearm.item_type(wearer)
		if(!(wearer.belt && wearer.equip_to_slot_if_possible(side_gun, WEAR_IN_BELT, TRUE, FALSE, TRUE)) && !wearer.equip_to_appropriate_slot(side_gun))
			clash_kit_hand_or_floor(wearer, side_gun)
	if(primary || sidearm)
		clash_kit_purge_stray_magazines(wearer)
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/storage/issued_medkit = wearer.get_item_by_slot(wear_slot)
		if((istype(issued_medkit, /obj/item/storage/pouch/firstaid) && !istype(issued_medkit, /obj/item/storage/pouch/firstaid/clash)) || istype(issued_medkit, /obj/item/storage/pouch/autoinjector))
			QDEL_LIST(issued_medkit.contents)
			clash_kit_replace_worn(wearer, wear_slot, /obj/item/storage/pouch/firstaid/clash)
	clash_kit_fit_pouches(wearer, kit, faction)
	var/datum/clash_kit_option/grenades = kit.get_option(KIT_SLOT_GRENADE)
	if(grenades && grenades.faction == faction)
		for(var/obj/item/explosive/grenade/issued in wearer.get_contents())
			if(issued.loc == wearer)
				wearer.temp_drop_inv_item(issued, TRUE)
			qdel(issued)
		for(var/count in 1 to grenades.ammo_count)
			var/obj/item/grenade = new grenades.item_type(wearer)
			if(!wearer.equip_to_appropriate_slot(grenade))
				qdel(grenade)
	clash_strip_locked_attachments(wearer, ckey)
	clash_strip_locked_grenades(wearer, ckey, job)
	if(mode != CLASH_KIT_RESET && clash_has_perk(wearer, /datum/clash_perk/extra_grenade))
		clash_give_extra_grenade(wearer)
	clash_kit_fill_ammo(wearer, kit, mode)
	. = stock_clash_kit(wearer, kit, job, mode, ckey)
	wearer.regenerate_icons()

/proc/clash_cosmetic_paths(datum/preferences/prefs)
	. = list()
	for(var/gear_type in prefs?.gear)
		var/datum/gear/cosmetic = GLOB.gear_datums_by_type[gear_type]
		if(cosmetic)
			. += cosmetic.path

/proc/regear_clash_fighter(mob/living/carbon/human/fighter, datum/clash_kit/kit)
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[fighter.job]
	var/datum/equipment_preset/preset = role?.gear_preset && GLOB.equipment_presets.gear_path_presets_list[role.gear_preset]
	if(!preset)
		apply_clash_kit(fighter, kit, CLASH_KIT_RESET)
		return
	var/list/kept = list(fighter.wear_id, fighter.w_uniform, fighter.wear_l_ear, fighter.wear_r_ear)
	for(var/obj/item/thing as anything in fighter.get_equipped_items() + list(fighter.l_hand, fighter.r_hand, fighter.l_store, fighter.r_store, fighter.s_store))
		if(!thing || (thing in kept) || QDELETED(thing))
			continue
		fighter.temp_drop_inv_item(thing, TRUE)
		qdel(thing)
	try
		preset.load_gear(fighter, fighter.client)
	catch(var/exception/error)
		stack_trace("Clash kit could not re-gear [fighter.job]: [error]")
	for(var/gear_type in fighter.client?.prefs?.gear)
		var/datum/gear/cosmetic = GLOB.gear_datums_by_type[gear_type]
		cosmetic?.equip_to_user(fighter, FALSE, FALSE)
	issue_clash_role_kit(fighter, fighter.job)
	apply_clash_kit(fighter, kit, CLASH_KIT_SPAWN)
	clash_issue_medic_gear(fighter)
	clash_issue_engineer_gear(fighter)

/proc/describe_clash_kit_item(obj/item/item)
	return item ? list("name" = item.name, "type" = "[item.type]", "icon" = "[item.icon]", "icon_state" = item.icon_state) : null

/proc/get_clash_issue_items(job)
	return GLOB.clash_kit_issue_items[job]

/proc/queue_clash_issue_items(job, datum/requester)
	if(!job || GLOB.clash_kit_issue_items[job])
		return
	var/list/waiting = GLOB.clash_kit_issue_pending[job]
	if(waiting)
		waiting |= requester
		return
	GLOB.clash_kit_issue_pending[job] = list(requester)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(build_clash_issue_items), job), 1)

/proc/build_clash_issue_items(job)
	var/list/found = list()
	var/failed = FALSE
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	if(role?.gear_preset)
		var/mob/living/carbon/human/dummy/model = new /mob/living/carbon/human/dummy
		try
			model.set_species()
			model.faction = clash_kit_faction_for_job(job)
			arm_equipment(model, role.gear_preset, FALSE, FALSE, null, TRUE)
			issue_clash_role_kit(model, job)
			for(var/slot in GLOB.clash_kit_worn_slots)
				var/list/info = describe_clash_kit_item(model.get_item_by_slot(GLOB.clash_kit_slots[slot]["wear"]))
				if(info)
					found[slot] = info
			for(var/obj/item/weapon/gun/gun in model.get_contents())
				var/slot = clash_is_sidearm(gun) ? KIT_SLOT_SIDEARM : KIT_SLOT_PRIMARY
				if(found[slot])
					continue
				found[slot] = describe_clash_kit_item(gun)
				if(slot == KIT_SLOT_PRIMARY)
					for(var/attachment_slot in GLOB.clash_kit_attachment_slots)
						var/list/info = describe_clash_kit_item(gun.attachments[attachment_slot])
						if(info)
							found[attachment_slot] = info
			var/obj/item/clothing/accessory/storage/issued_webbing = locate() in model.w_uniform?.accessories
			if(issued_webbing)
				found[KIT_SLOT_WEBBING] = describe_clash_kit_item(issued_webbing)
			var/obj/item/explosive/grenade/grenade = locate() in model.get_contents()
			if(grenade)
				found[KIT_SLOT_GRENADE] = describe_clash_kit_item(grenade)
		catch(var/exception/error)
			failed = TRUE
			stack_trace("Clash kit could not read the issue gear of [job]: [error]")
		qdel(model)
	if(!failed)
		GLOB.clash_kit_issue_items[job] = found
	var/list/waiting = GLOB.clash_kit_issue_pending[job]
	GLOB.clash_kit_issue_pending -= job
	for(var/datum/requester as anything in waiting)
		if(!QDELETED(requester))
			SStgui.update_uis(requester)

/proc/render_clash_kit_doll(datum/clash_kit/kit, job, client/viewer, draw = TRUE)
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	if(!role?.gear_preset)
		return null
	var/mob/living/carbon/human/dummy/model = new /mob/living/carbon/human/dummy
	try
		model.set_species()
		if(viewer?.prefs)
			viewer.prefs.copy_appearance_to(model)
		model.faction = clash_kit_faction_for_job(job)
		model.update_body()
		model.update_hair()
		arm_equipment(model, role.gear_preset, FALSE, FALSE, null, TRUE)
		model.job = job
		for(var/gear_type in viewer?.prefs?.gear)
			var/datum/gear/cosmetic = GLOB.gear_datums_by_type[gear_type]
			cosmetic?.equip_to_user(model, FALSE, FALSE)
		issue_clash_role_kit(model, job)
		GLOB.clash_kit_budgets[job] = list(model.vendor_points, model.vendor_snowflake_points)
		clash_raise_vendor_points(model, viewer?.ckey, job)
		var/list/statuses = apply_clash_kit(model, kit, CLASH_KIT_PREVIEW, job, viewer?.prefs, viewer?.ckey)
		if(!draw)
			qdel(model)
			return list("statuses" = statuses)
		for(var/obj/limb/limb in model.limbs)
			limb.blocks_emissive = EMISSIVE_BLOCK_NONE
		model.regenerate_icons()
		var/icon/flat = getFlatIcon(model)
		var/obj/item/weapon/gun/primary = clash_kit_primary_of(model)
		var/icon/gun_flat = primary && clash_trim_icon(getFlatIcon(primary))
		. = list("doll" = flat ? icon2base64(flat) : null, "gun" = gun_flat ? icon2base64(gun_flat) : null, "pack" = describe_clash_kit_pack(model, kit, primary), "statuses" = statuses)
	catch(var/exception/error)
		stack_trace("Clash kit could not draw a [job] doll: [error]")
	qdel(model)

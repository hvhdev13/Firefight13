#define CLASH_DOLL_MARKER "#ff00fe"
#define CLASH_DOLL_MARKER_LAYER 1000

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
	var/list/extra_slots = list()
	var/list/moves = list()
	var/list/removed_slots = list()

/datum/clash_kit/proc/get_option(slot)
	return get_clash_kit_option(choices[slot])

/datum/clash_kit/proc/wants_nothing(slot)
	return choices[slot] == CLASH_KIT_NOTHING

/datum/clash_kit/proc/sync_extra_slots()
	extra_slots.len = length(extras)

/datum/clash_kit/proc/sync_removed_slots()
	removed_slots.len = length(removed)

/datum/clash_kit/proc/add_removed(type_text, from)
	sync_removed_slots()
	removed += type_text
	removed_slots += from

/datum/clash_kit/proc/add_extra(id)
	extras += id
	sync_extra_slots()

/datum/clash_kit/proc/remove_extra(index)
	sync_extra_slots()
	extras.Cut(index, index + 1)
	extra_slots.Cut(index, index + 1)

/datum/clash_kit/proc/copy_from(datum/clash_kit/source)
	choices = source.choices.Copy()
	extras = source.extras.Copy()
	extra_slots = source.extra_slots.Copy()
	removed = source.removed.Copy()
	removed_slots = source.removed_slots.Copy()
	fills = source.fills.Copy()
	moves = source.moves.Copy()

/datum/clash_kit/proc/clear()
	choices = list()
	extras = list()
	extra_slots = list()
	removed = list()
	removed_slots = list()
	fills = list()
	moves = list()

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
			kit.sync_extra_slots()
			kit.sync_removed_slots()
			stored += list(list("name" = kit.name, "choices" = kit.choices, "extras" = kit.extras, "extra_slots" = kit.extra_slots, "removed" = kit.removed, "removed_slots" = kit.removed_slots, "fills" = kit.fills, "moves" = kit.moves))
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
				var/id = replacetext(replacetext(stored["choices"][slot], "/obj/item/storage/pouch/firstaid/ert", "/obj/item/storage/pouch/firstaid/clash"), "/obj/item/storage/pouch/bayonet/upp", "/obj/item/storage/pouch/bayonet")
				if(id == CLASH_KIT_NOTHING && (slot in GLOB.clash_kit_slots))
					kit.choices[slot] = id
					continue
				if(!get_clash_kit_option(id) && ispath(text2path(id)))
					id = clash_kit_option_id(clash_kit_faction_for_job(job), slot, text2path(id))
				if(get_clash_kit_option(id))
					kit.choices[slot] = id
			var/list/stored_slots = stored["extra_slots"]
			var/list/stored_extras = stored["extras"]
			for(var/index in 1 to length(stored_extras))
				if(!ispath(text2path(stored_extras[index]), /obj/item))
					continue
				kit.add_extra(stored_extras[index])
				var/wanted = LAZYACCESS(stored_slots, index)
				if(istext(wanted))
					kit.extra_slots[length(kit.extra_slots)] = wanted
			for(var/list/move in stored["moves"])
				if(length(move) == 3 && ispath(text2path(move[1]), /obj/item) && istext(move[2]) && istext(move[3]))
					kit.moves += list(move)
			var/list/stored_removed_slots = stored["removed_slots"]
			var/list/stored_removed = stored["removed"]
			for(var/index in 1 to length(stored_removed))
				if(ispath(text2path(stored_removed[index]), /obj/item))
					var/from = LAZYACCESS(stored_removed_slots, index)
					kit.add_removed(stored_removed[index], istext(from) ? from : null)
			for(var/container in stored["fills"])
				if((container == CLASH_KIT_GUN_FILL || ispath(text2path(container), /obj/item/storage)) && (stored["fills"][container] in GLOB.clash_kit_shell_names))
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
	clash_issue_specialist_armor(fighter)
	clash_issue_machinegunner_kit(fighter)
	clash_swap_c4_pouches(fighter)
	clash_kit_default_webbing(fighter)

/proc/clash_issue_specialist_armor(mob/living/carbon/human/fighter)
	var/found = FALSE
	for(var/obj/item/spec_kit/token in fighter.get_contents())
		found = TRUE
		if(token.loc == fighter)
			fighter.temp_drop_inv_item(token, TRUE)
		qdel(token)
	if(!found)
		return
	var/list/armor_set = list(
		WEAR_JACKET = /obj/item/clothing/suit/storage/marine/specialist,
		WEAR_HEAD = /obj/item/clothing/head/helmet/marine/specialist,
		WEAR_HANDS = /obj/item/clothing/gloves/marine/specialist,
	)
	for(var/wear_slot in armor_set)
		clash_kit_replace_worn(fighter, wear_slot, armor_set[wear_slot])

/proc/clash_issue_machinegunner_kit(mob/living/carbon/human/fighter)
	var/found = FALSE
	for(var/obj/item/weapon/gun/smartgun/smartgun in fighter.get_contents())
		found = TRUE
		if(smartgun.loc == fighter)
			fighter.temp_drop_inv_item(smartgun, TRUE)
		qdel(smartgun)
	if(!found)
		return
	for(var/obj/item/ammo_magazine/smartgun/drum in fighter.get_contents())
		qdel(drum)
	clash_kit_replace_worn(fighter, WEAR_JACKET, /obj/item/clothing/suit/storage/marine/medium)
	clash_kit_replace_worn(fighter, WEAR_WAIST, /obj/item/storage/belt/gun/m4a3)
	var/obj/item/weapon/gun/rifle/lmg/machinegun = new(fighter)
	if(!fighter.equip_to_slot_if_possible(machinegun, WEAR_J_STORE, TRUE, FALSE, TRUE))
		clash_kit_hand_or_floor(fighter, machinegun)

/proc/clash_swap_c4_pouches(mob/living/carbon/human/fighter)
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/storage/pouch/explosive/C4/pouch = fighter.get_item_by_slot(wear_slot)
		if(!istype(pouch))
			continue
		QDEL_LIST(pouch.contents)
		clash_kit_replace_worn(fighter, wear_slot, /obj/item/storage/pouch/general/medium)

/proc/clash_kit_heavy_pouch(mob/living/carbon/human/wearer, job)
	var/obj/item/weapon/gun/primary = clash_kit_primary_of(wearer)
	var/ammo_type = primary && clash_job_is_heavy(job) && clash_kit_magazine_for(primary)
	if(!ammo_type)
		return
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/storage/pouch/general/pouch = wearer.get_item_by_slot(wear_slot)
		if(istype(pouch) && !length(pouch.contents))
			clash_kit_top_up(pouch, ammo_type, wearer)

/proc/clash_kit_blocked_slots(primary_type)
	. = list()
	if(ispath(primary_type, /obj/item/weapon/gun/smartgun))
		.[KIT_SLOT_BACK] = "You cannot use a backpack with the M56 harness"

/proc/clash_kit_smartgun_rig(mob/living/carbon/human/wearer, datum/clash_kit/kit)
	var/obj/item/pack = wearer.back
	if(pack && !(pack.flags_item & SMARTGUNNER_BACKPACK_OVERRIDE))
		wearer.temp_drop_inv_item(pack, TRUE)
		qdel(pack)
	clash_kit_replace_worn(wearer, WEAR_JACKET, /obj/item/clothing/suit/storage/marine/smartgunner)
	if(!kit.get_option(KIT_SLOT_BELT))
		clash_kit_replace_worn(wearer, WEAR_WAIST, /obj/item/storage/belt/gun/smartgunner)

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

/proc/clash_kit_remove_worn(mob/living/carbon/human/wearer, obj/item/worn, list/cosmetics)
	if(!worn || (worn.type in cosmetics))
		return
	var/list/guns = list()
	var/obj/item/storage/holder = clash_kit_storage_of(worn)
	var/obj/item/clothing/accessory/storage/webbing = worn
	if(istype(webbing))
		holder = webbing.hold
	for(var/obj/item/weapon/gun/gun in holder?.contents)
		holder.remove_from_storage(gun, wearer)
		guns += gun
	if(worn.loc == wearer)
		wearer.temp_drop_inv_item(worn, TRUE)
	qdel(worn)
	for(var/obj/item/weapon/gun/gun as anything in guns)
		if(!wearer.equip_to_appropriate_slot(gun))
			clash_kit_hand_or_floor(wearer, gun)

/proc/clash_kit_strip_unwanted_attachments(obj/item/weapon/gun/gun, datum/clash_kit/kit)
	var/sidearm = clash_is_sidearm(gun)
	for(var/gun_slot in GLOB.clash_kit_attachment_slots)
		var/obj/item/attachable/attachment = gun.attachments[gun_slot]
		if(!attachment || !(attachment.flags_attach_features & ATTACH_REMOVABLE) || !kit.wants_nothing(sidearm ? GLOB.clash_kit_sidearm_attachment_slots[gun_slot] : gun_slot))
			continue
		if(get_turf(gun))
			attachment.Detach(null, gun)
		else
			gun.attachments[gun_slot] = null
		gun.update_attachable(gun_slot)
		qdel(attachment)

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

/proc/clash_kit_fit_sidearm_attachments(mob/living/carbon/human/wearer, obj/item/weapon/gun/gun, datum/clash_kit/kit, ckey, job, check_locks, list/slot_map = GLOB.clash_kit_sidearm_attachment_slots)
	for(var/gun_slot in slot_map)
		var/datum/clash_kit_option/option = kit.get_option(slot_map[gun_slot])
		if(!option || !clash_kit_attachment_fits(option.item_type, gun.type) || (check_locks && clash_option_lock_text(ckey, option.id, job, gun.type)))
			continue
		var/obj/item/attachable/attachment = new option.item_type(gun)
		if(!clash_fit_attachment(gun, attachment, wearer, TRUE))
			qdel(attachment)

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
			var/pixel = source.GetPixel(x, y)
			if(!pixel || (length(pixel) == 9 && text2num(copytext(pixel, 8), 16) < 16))
				continue
			left = min(left, x)
			right = max(right, x)
			bottom = min(bottom, y)
			top = max(top, y)
	if(right)
		source.Crop(left, bottom, right, top)
	return source

/proc/clash_doll_icon(mob/living/carbon/human/model)
	var/static/icon/marker_icon
	if(!marker_icon)
		marker_icon = icon('icons/effects/effects.dmi', "nothing")
		marker_icon.DrawBox(CLASH_DOLL_MARKER, 1, 1)
		marker_icon.DrawBox(CLASH_DOLL_MARKER, world.icon_size, world.icon_size)
	var/image/marker = image(marker_icon, icon_state = icon_states(marker_icon)[1], layer = CLASH_DOLL_MARKER_LAYER)
	model.overlays += marker
	var/icon/flat = getFlatIcon(model, no_anim = TRUE)
	model.overlays -= marker
	var/left = 1
	var/bottom = 1
	if(flat.Width() != world.icon_size || flat.Height() != world.icon_size)
		left = 0
		for(var/x in 1 to flat.Width() - world.icon_size + 1)
			for(var/y in 1 to flat.Height() - world.icon_size + 1)
				if(lowertext(flat.GetPixel(x, y)) == CLASH_DOLL_MARKER && lowertext(flat.GetPixel(x + world.icon_size - 1, y + world.icon_size - 1)) == CLASH_DOLL_MARKER)
					left = x
					bottom = y
					break
			if(left)
				break
		if(!left)
			return flat
		flat.Crop(left, bottom, left + world.icon_size - 1, bottom + world.icon_size - 1)
	flat.DrawBox(null, 1, 1)
	flat.DrawBox(null, world.icon_size, world.icon_size)
	return flat

/proc/clash_kit_primary_of(mob/living/carbon/human/wearer)
	var/obj/item/weapon/gun/stored = wearer.s_store
	if(istype(stored) && !clash_is_sidearm(stored))
		return stored
	for(var/obj/item/weapon/gun/carried in wearer.get_contents())
		if(!clash_is_sidearm(carried) && !istype(carried.loc, /obj/item/weapon/gun) && !istype(carried.loc, /obj/item/storage/large_holster))
			return carried
	return null

/proc/clash_kit_back_gun_of(mob/living/carbon/human/wearer)
	var/obj/item/storage/large_holster/scabbard = wearer.back
	return istype(scabbard) ? (locate(/obj/item/weapon/gun) in scabbard) : null

/proc/clash_kit_shotgun_of(mob/living/carbon/human/wearer)
	var/obj/item/weapon/gun/primary = clash_kit_primary_of(wearer)
	return clash_kit_shells_for(primary) ? primary : clash_kit_back_gun_of(wearer)

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
	var/list/shells = clash_kit_shells_for(clash_kit_shotgun_of(wearer))
	var/list/primary_shells = clash_kit_shells_for(primary)
	var/list/ammo_types = list()
	for(var/shell_name in shells)
		ammo_types += shells[shell_name]
	if(primary && !clash_kit_shells_for(primary))
		ammo_types += clash_kit_magazine_for(primary)
	if(sidearm)
		ammo_types += clash_kit_magazine_for(sidearm)
	ammo_types -= null
	if(!length(ammo_types))
		return
	var/list/starting = GLOB.clash_starting_kits[faction]
	for(var/slot in list(KIT_SLOT_BELT, KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R))
		if(kit.get_option(slot))
			continue
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
		var/replacement = slot == KIT_SLOT_BELT ? starting[slot] : (primary_shells ? /obj/item/storage/pouch/shotgun : /obj/item/storage/pouch/magazine)
		if(replacement && holder.type != replacement)
			var/old_name = holder.name
			var/obj/item/fresh = clash_kit_replace_worn(wearer, wear_slot, replacement)
			if(fresh)
				clash_kit_note(wearer, slot, "Your issued [old_name] can't hold your [clash_kit_gun_names(wearer)] ammo, so it was swapped for \a [fresh.name].")
	if(!primary)
		return
	var/list/primary_ammo = list()
	for(var/shell_name in primary_shells)
		primary_ammo += primary_shells[shell_name]
	if(!primary_shells)
		primary_ammo += clash_kit_magazine_for(primary)
	primary_ammo -= null
	for(var/obj/item/storage/holder as anything in clash_kit_containers(wearer))
		if(!clash_kit_holds_ammo(holder))
			continue
		for(var/ammo_type in primary_ammo)
			if(holder.can_hold_type(ammo_type, wearer))
				return
	var/replacement = primary_shells ? /obj/item/storage/pouch/shotgun : /obj/item/storage/pouch/magazine
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
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		if(kit.get_option(slot) || kit.wants_nothing(slot) || wearer.get_item_by_slot(wear_slot))
			continue
		var/obj/item/fresh = clash_kit_replace_worn(wearer, wear_slot, replacement)
		if(fresh)
			clash_kit_note(wearer, slot, "Nothing you wear could carry your [primary.name] ammo, so you were given \a [fresh.name].")
		return

/proc/clash_kit_fit_back_gun(mob/living/carbon/human/wearer, datum/clash_kit/kit, faction, job, ckey)
	var/datum/clash_kit_option/back_gun = kit.get_option(KIT_SLOT_BACK_GUN)
	var/obj/item/storage/large_holster/scabbard = wearer.back
	if(back_gun?.faction != faction || !istype(scabbard) || !clash_job_carries_back_gun(job))
		return
	var/obj/item/weapon/gun/gun = new back_gun.item_type(wearer)
	clash_kit_fit_sidearm_attachments(wearer, gun, kit, ckey, job, FALSE, GLOB.clash_kit_back_attachment_slots)
	if(!scabbard.can_be_inserted(gun, wearer, TRUE) || !scabbard.handle_item_insertion(gun, TRUE, wearer))
		qdel(gun)

/proc/clash_kit_load_shells(obj/item/weapon/gun/shotgun/shotgun, datum/clash_kit/kit)
	var/list/shells = clash_kit_shells_for(shotgun)
	var/obj/item/ammo_magazine/handful/shell_type = shells?[kit.fills[CLASH_KIT_GUN_FILL]]
	if(!shell_type || !shotgun.current_mag || shotgun.in_chamber)
		return
	shotgun.current_mag.default_ammo = initial(shell_type.default_ammo)
	shotgun.replace_tube(shotgun.current_mag.current_rounds)

/proc/clash_kit_shell_names_for(gun_type)
	if(!ispath(gun_type, /obj/item/weapon/gun/shotgun))
		return null
	var/obj/item/weapon/gun/shotgun/shotgun = gun_type
	var/list/shells = GLOB.clash_kit_shells[initial(shotgun.gauge)]
	return shells ? GLOB.clash_kit_shell_names & shells : null

/proc/clash_kit_fill_ammo(mob/living/carbon/human/wearer, datum/clash_kit/kit, mode)
	var/list/shells = clash_kit_shells_for(clash_kit_shotgun_of(wearer))
	var/shell_pick = kit.fills[CLASH_KIT_GUN_FILL] || GLOB.clash_kit_shell_names[1]
	var/list/needs = list()
	var/list/guns = list(KIT_SLOT_PRIMARY = clash_kit_primary_of(wearer), KIT_SLOT_BACK_GUN = clash_kit_back_gun_of(wearer), KIT_SLOT_SIDEARM = clash_kit_sidearm_of(wearer))
	for(var/gun_slot in guns)
		var/obj/item/weapon/gun/gun = guns[gun_slot]
		if(!gun)
			continue
		var/ammo = clash_kit_shells_for(gun) ? CLASH_KIT_GUN_FILL : clash_kit_magazine_for(gun)
		if(ammo && !needs[ammo])
			needs[ammo] = clash_is_sidearm(gun) ? CLASH_KIT_SPARE_SIDEARM : CLASH_KIT_SPARE_PRIMARY
	var/list/filled = list()
	for(var/obj/item/storage/holder as anything in clash_kit_containers(wearer))
		if(!clash_kit_holds_ammo(holder))
			continue
		for(var/ammo in needs)
			var/ammo_type = ammo == CLASH_KIT_GUN_FILL ? shells[kit.fills["[holder.type]"] || shell_pick] : ammo
			if(holder.can_hold_type(ammo_type, wearer))
				clash_kit_top_up(holder, ammo_type, wearer)
				filled[ammo] = TRUE
				break
	if(mode != CLASH_KIT_SPAWN && mode != CLASH_KIT_PREVIEW)
		return
	for(var/ammo in needs)
		if(!filled[ammo])
			clash_kit_spare_ammo(wearer, ammo == CLASH_KIT_GUN_FILL ? shells[shell_pick] : ammo, needs[ammo])

/proc/apply_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit, mode = CLASH_KIT_SPAWN, job, datum/preferences/prefs, ckey)
	if(!kit || QDELETED(wearer))
		return
	job = job || wearer.job
	ckey = ckey || wearer.ckey
	wearer.clash_kit_problems = list()
	wearer.clash_kit_notes = list()
	var/datum/clash_kit/chosen = kit
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
	if(!kit.wants_nothing(KIT_SLOT_WEBBING))
		clash_kit_default_webbing(wearer)
	if(faction == FACTION_UPP && istype(wearer.w_uniform, /obj/item/clothing/under/marine/veteran/UPP) && !(locate(/obj/item/clothing/accessory/patch/upp) in wearer.w_uniform.accessories))
		wearer.equip_to_slot_if_possible(new /obj/item/clothing/accessory/patch/upp(wearer), WEAR_ACCESSORY, TRUE, TRUE, TRUE)

	var/obj/item/issue_primary = wearer.s_store
	if(issue_primary)
		wearer.temp_drop_inv_item(issue_primary, TRUE)
		issue_primary.forceMove(wearer)
	clash_swap_issued_flare_pouches(wearer)
	for(var/slot in GLOB.clash_kit_worn_slots)
		var/wear_slot = GLOB.clash_kit_slots[slot]["wear"]
		if(kit.wants_nothing(slot))
			clash_kit_remove_worn(wearer, wearer.get_item_by_slot(wear_slot), cosmetics)
			continue
		var/datum/clash_kit_option/option = kit.get_option(slot)
		if(!option || option.faction != faction || ((slot == KIT_SLOT_ARMOR || slot == KIT_SLOT_BACK) && ispath(primary?.item_type, /obj/item/weapon/gun/smartgun)))
			continue
		var/obj/item/worn = wearer.get_item_by_slot(wear_slot)
		if(worn && (worn.type in cosmetics))
			clash_kit_problem(wearer, slot, "Your [worn.name] from Setup Character is worn instead of this.")
			continue
		clash_kit_replace_worn(wearer, wear_slot, option.item_type)

	var/datum/clash_kit_option/webbing = kit.get_option(KIT_SLOT_WEBBING)
	if(webbing?.faction == faction)
		clash_kit_fit_webbing(wearer, webbing.item_type, cosmetics)
	else if(kit.wants_nothing(KIT_SLOT_WEBBING))
		usr = get_turf(wearer) ? null : wearer
		for(var/obj/item/clothing/accessory/storage/old in wearer.w_uniform?.accessories?.Copy())
			if(!(old.type in cosmetics))
				wearer.w_uniform.remove_accessory(wearer, old)
				clash_kit_remove_worn(wearer, old, cosmetics)
	clash_downgrade_locked_gear(wearer, ckey, job, cosmetics)

	if(primary || kit.wants_nothing(KIT_SLOT_PRIMARY))
		clash_kit_purge_guns(wearer, FALSE)
	clash_kit_fit_back_gun(wearer, kit, faction, job, ckey)
	var/obj/item/weapon/gun/main_gun
	if(primary)
		if(ispath(primary.item_type, /obj/item/weapon/gun/smartgun))
			clash_kit_smartgun_rig(wearer, kit)
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
	else if(kit.wants_nothing(KIT_SLOT_PRIMARY))
		qdel(issue_primary)
	else if(!QDELETED(issue_primary))
		if(!wearer.equip_to_slot_if_possible(issue_primary, WEAR_J_STORE, TRUE, FALSE, TRUE) && !wearer.equip_to_appropriate_slot(issue_primary))
			clash_kit_hand_or_floor(wearer, issue_primary)
		if(isgun(issue_primary))
			for(var/slot in GLOB.clash_kit_attachment_slots)
				var/datum/clash_kit_option/option = chosen.get_option(slot)
				if(!option || !clash_kit_attachment_fits(option.item_type, issue_primary.type) || clash_option_lock_text(ckey, option.id, job, issue_primary.type))
					continue
				var/obj/item/attachable/attachment = new option.item_type(issue_primary)
				if(!clash_fit_attachment(issue_primary, attachment, wearer, TRUE))
					qdel(attachment)
	if(sidearm)
		clash_kit_purge_guns(wearer, TRUE)
		var/obj/item/weapon/gun/side_gun = new sidearm.item_type(wearer)
		clash_kit_fit_sidearm_attachments(wearer, side_gun, kit, ckey, job, FALSE)
		if(!(wearer.belt && wearer.equip_to_slot_if_possible(side_gun, WEAR_IN_BELT, TRUE, FALSE, TRUE)) && !wearer.equip_to_appropriate_slot(side_gun))
			clash_kit_hand_or_floor(wearer, side_gun)
	else if(kit.wants_nothing(KIT_SLOT_SIDEARM))
		clash_kit_purge_guns(wearer, TRUE)
	else
		var/obj/item/weapon/gun/issued_sidearm = clash_kit_sidearm_of(wearer)
		if(issued_sidearm)
			clash_kit_fit_sidearm_attachments(wearer, issued_sidearm, chosen, ckey, job, TRUE)
	for(var/obj/item/weapon/gun/kept in list(clash_kit_primary_of(wearer), clash_kit_sidearm_of(wearer)))
		clash_kit_strip_unwanted_attachments(kept, kit)
	if(primary || sidearm || kit.wants_nothing(KIT_SLOT_PRIMARY) || kit.wants_nothing(KIT_SLOT_SIDEARM))
		clash_kit_purge_stray_magazines(wearer)
	clash_swap_issued_medpouches(wearer)
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
	else if(kit.wants_nothing(KIT_SLOT_GRENADE))
		for(var/obj/item/explosive/grenade/issued in wearer.get_contents())
			if(istype(issued.loc, /obj/item/attachable))
				continue
			if(issued.loc == wearer)
				wearer.temp_drop_inv_item(issued, TRUE)
			qdel(issued)
	if(clash_fast_medicine())
		clash_remove_arena_items(wearer)
		if(clash_job_is_medic(job))
			clash_strip_medic_kit(wearer)
	clash_swap_extended_magazines(wearer)
	if(mode != CLASH_KIT_PREVIEW)
		clash_engrave_guns(wearer, ckey)
	clash_strip_locked_attachments(wearer, ckey)
	clash_strip_locked_grenades(wearer, ckey, job)
	if(mode != CLASH_KIT_RESET && clash_has_perk(wearer, /datum/clash_perk/extra_grenade))
		clash_give_extra_grenade(wearer)
	clash_kit_heavy_pouch(wearer, job)
	clash_kit_load_shells(clash_kit_primary_of(wearer), kit)
	clash_kit_load_shells(clash_kit_back_gun_of(wearer), kit)
	clash_kit_fill_ammo(wearer, kit, mode)
	. = stock_clash_kit(wearer, kit, job, mode, ckey)
	wearer.clash_kit_move_failed = apply_clash_kit_moves(wearer, kit)
	clash_kit_check_carriers(wearer)
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

/proc/clash_swap_issued_flare_pouches(mob/living/carbon/human/wearer)
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		if(istype(wearer.get_item_by_slot(wear_slot), /obj/item/storage/pouch/flare))
			clash_kit_replace_worn(wearer, wear_slot, /obj/item/storage/pouch/magazine)

/proc/clash_swap_extended_magazines(mob/living/carbon/human/wearer)
	for(var/obj/item/ammo_magazine/extended in wearer.get_contents())
		if(!clash_is_extended_magazine(extended.type))
			continue
		var/regular_type = text2path(replacetext("[extended.type]", "/extended", ""))
		if(!ispath(regular_type, /obj/item/ammo_magazine))
			continue
		var/atom/holder = extended.loc
		var/obj/item/ammo_magazine/regular = new regular_type
		if(isgun(holder))
			var/obj/item/weapon/gun/loaded = holder
			loaded.current_mag = regular
			regular.forceMove(loaded)
			qdel(extended)
			loaded.update_icon()
			continue
		if(isstorage(holder))
			var/obj/item/storage/storage = holder
			storage.remove_from_storage(extended, wearer)
			qdel(extended)
			if(storage.can_be_inserted(regular, wearer, TRUE) && storage.handle_item_insertion(regular, TRUE, wearer))
				continue
		else
			qdel(extended)
		if(!wearer.equip_to_appropriate_slot(regular))
			qdel(regular)

/proc/clash_swap_issued_medpouches(mob/living/carbon/human/wearer)
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/storage/issued = wearer.get_item_by_slot(wear_slot)
		if(istype(issued, /obj/item/storage/pouch/firstaid/clash) || !istype(issued, /obj/item/storage/pouch/firstaid) && !istype(issued, /obj/item/storage/pouch/autoinjector) && !istype(issued, /obj/item/storage/pouch/medkit) && !istype(issued, /obj/item/storage/pouch/medical))
			continue
		QDEL_LIST(issued.contents)
		clash_kit_replace_worn(wearer, wear_slot, /obj/item/storage/pouch/firstaid/clash)

/proc/describe_clash_kit_item(obj/item/item)
	if(!item)
		return null
	var/blurb = item.desc
	var/sentence_end = findtext(blurb, ". ")
	if(sentence_end)
		blurb = copytext(blurb, 1, sentence_end + 1)
	if(istype(item, /obj/item/storage/belt/medical/lifesaver))
		blurb = "Holds everything a medic needs."
	else if(istype(item, /obj/item/storage) && length(item.contents))
		var/list/counts = list()
		for(var/obj/item/thing in item.contents)
			counts[thing.name] = (counts[thing.name] || 0) + 1
		var/list/parts = list()
		for(var/thing_name in counts)
			parts += counts[thing_name] > 1 ? "[thing_name] ([counts[thing_name]])" : thing_name
		blurb = "Holds [english_list(parts)]"
	return list("name" = capitalize(item.name), "desc" = blurb, "type" = "[item.type]", "icon" = "[item.icon]", "icon_state" = item.icon_state)

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
			clash_swap_issued_flare_pouches(model)
			if(clash_fast_medicine())
				clash_swap_issued_medpouches(model)
			for(var/slot in GLOB.clash_kit_worn_slots)
				var/list/info = describe_clash_kit_item(model.get_item_by_slot(GLOB.clash_kit_slots[slot]["wear"]))
				if(info)
					found[slot] = info
			for(var/obj/item/weapon/gun/gun in model.get_contents())
				var/slot = clash_is_sidearm(gun) ? KIT_SLOT_SIDEARM : KIT_SLOT_PRIMARY
				if(found[slot])
					continue
				found[slot] = describe_clash_kit_item(gun)
				for(var/attachment_slot in GLOB.clash_kit_attachment_slots)
					var/list/info = describe_clash_kit_item(gun.attachments[attachment_slot])
					if(info)
						var/obj/item/attachable/issued_attachment = gun.attachments[attachment_slot]
						info["fixed"] = !(issued_attachment.flags_attach_features & ATTACH_REMOVABLE)
						found[slot == KIT_SLOT_PRIMARY ? attachment_slot : GLOB.clash_kit_sidearm_attachment_slots[attachment_slot]] = info
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

/proc/render_clash_kit_doll(datum/clash_kit/kit, job, client/viewer, draw = TRUE, datum/preferences/prefs, ckey)
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	if(!role?.gear_preset)
		return null
	prefs = prefs || viewer?.prefs
	ckey = ckey || viewer?.ckey
	var/mob/living/carbon/human/dummy/model = new /mob/living/carbon/human/dummy
	try
		model.set_species()
		if(prefs)
			prefs.copy_appearance_to(model)
		model.faction = clash_kit_faction_for_job(job)
		model.update_body()
		model.update_hair()
		arm_equipment(model, role.gear_preset, FALSE, FALSE, null, TRUE)
		model.job = job
		for(var/gear_type in prefs?.gear)
			var/datum/gear/cosmetic = GLOB.gear_datums_by_type[gear_type]
			cosmetic?.equip_to_user(model, FALSE, FALSE)
		issue_clash_role_kit(model, job)
		GLOB.clash_kit_budgets[job] = list(model.vendor_points, model.vendor_snowflake_points)
		clash_raise_vendor_points(model, ckey, job)
		var/list/statuses = apply_clash_kit(model, kit, CLASH_KIT_PREVIEW, job, prefs, ckey)
		if(!draw)
			. = list("statuses" = statuses, "placed" = model.clash_kit_placed, "moves_failed" = model.clash_kit_move_failed)
			qdel(model)
			return
		for(var/obj/limb/limb in model.limbs)
			limb.blocks_emissive = EMISSIVE_BLOCK_NONE
		model.regenerate_icons()
		var/icon/flat = clash_doll_icon(model)
		var/obj/item/weapon/gun/primary = clash_kit_primary_of(model)
		var/icon/gun_flat = primary && clash_trim_icon(getFlatIcon(primary, no_anim = TRUE))
		var/obj/item/weapon/gun/sidearm = clash_kit_sidearm_of(model)
		var/icon/sidearm_flat = sidearm && clash_trim_icon(getFlatIcon(sidearm, no_anim = TRUE))
		var/obj/item/weapon/gun/back_gun = clash_kit_back_gun_of(model)
		var/icon/back_flat = back_gun && clash_trim_icon(getFlatIcon(back_gun, no_anim = TRUE))
		. = list("doll" = flat ? icon2base64(flat) : null, "gun" = gun_flat ? icon2base64(gun_flat) : null, "sidearm" = sidearm_flat ? icon2base64(sidearm_flat) : null, "back_gun" = back_flat ? icon2base64(back_flat) : null, "pack" = describe_clash_kit_pack(model, kit, clash_kit_shotgun_of(model)), "left_behind" = describe_clash_kit_left_behind(model, kit), "failed_moves" = describe_clash_kit_failed_moves(model, kit), "problems" = model.clash_kit_problems, "notes" = model.clash_kit_notes, "statuses" = statuses)
	catch(var/exception/error)
		stack_trace("Clash kit could not draw a [job] doll: [error]")
	qdel(model)

#undef CLASH_DOLL_MARKER
#undef CLASH_DOLL_MARKER_LAYER

/mob/living/carbon/human/var/list/clash_kit_problems = list()
/mob/living/carbon/human/var/list/clash_kit_notes = list()

/proc/clash_kit_problem(mob/living/carbon/human/wearer, slot, text)
	if(!wearer.clash_kit_problems[slot])
		wearer.clash_kit_problems[slot] = text

/proc/clash_kit_note(mob/living/carbon/human/wearer, slot, text)
	wearer.clash_kit_notes[slot] = text

/proc/clash_kit_gun_names(mob/living/carbon/human/wearer)
	var/list/names = list()
	for(var/obj/item/weapon/gun/gun as anything in list(clash_kit_primary_of(wearer), clash_kit_back_gun_of(wearer), clash_kit_sidearm_of(wearer)))
		if(gun)
			names += gun.name
	return english_list(names, "")

/proc/clash_kit_ammo_types_of(obj/item/weapon/gun/gun)
	var/list/shells = clash_kit_shells_for(gun)
	if(shells)
		. = list()
		for(var/shell_name in shells)
			. += shells[shell_name]
		return
	var/magazine = gun && clash_kit_magazine_for(gun)
	return magazine ? list(magazine) : list()

/proc/clash_kit_carrier_problem(obj/item/storage/holder, list/guns, mob/living/carbon/human/wearer, predict = FALSE)
	var/holsters = FALSE
	var/ammo_holder = FALSE
	var/grenade_holder = FALSE
	for(var/path in holder.can_hold)
		if(ispath(path, /obj/item/weapon/gun))
			holsters = TRUE
		else if(ispath(path, /obj/item/ammo_magazine))
			ammo_holder = TRUE
		else if(ispath(path, /obj/item/explosive/grenade))
			grenade_holder = TRUE
	if(holsters)
		var/obj/item/weapon/gun/sidearm
		for(var/obj/item/weapon/gun/gun as anything in guns)
			if(clash_is_sidearm(gun))
				sidearm = gun
		if(!sidearm)
			return "You have no sidearm for it."
		if(!holder.can_hold_type(sidearm.type, wearer))
			return "Your [sidearm.name] doesn't fit in it."
	if(ammo_holder && !grenade_holder)
		for(var/obj/item/weapon/gun/gun as anything in guns)
			for(var/ammo_type in clash_kit_ammo_types_of(gun))
				if(holder.can_hold_type(ammo_type, wearer))
					return null
		if(length(guns))
			var/list/names = list()
			for(var/obj/item/weapon/gun/gun as anything in guns)
				names += gun.name
			return "It cannot hold ammo for your [english_list(names, "", " or ")]."
	if(!predict && grenade_holder && !ammo_holder && !length(holder.contents) && !(locate(/obj/item/explosive/grenade) in wearer.get_contents()))
		return "You have no grenades for it."
	return null

/proc/clash_kit_check_carriers(mob/living/carbon/human/wearer)
	var/list/guns = list()
	for(var/obj/item/weapon/gun/gun as anything in list(clash_kit_primary_of(wearer), clash_kit_back_gun_of(wearer), clash_kit_sidearm_of(wearer)))
		if(gun)
			guns += gun
	var/list/carriers = list(KIT_SLOT_BELT = wearer.belt, KIT_SLOT_POUCH_L = wearer.l_store, KIT_SLOT_POUCH_R = wearer.r_store, KIT_SLOT_BACK = wearer.back)
	var/obj/item/clothing/accessory/storage/webbing = locate() in wearer.w_uniform?.accessories
	carriers[KIT_SLOT_WEBBING] = webbing?.hold
	for(var/slot in carriers)
		var/obj/item/storage/holder = clash_kit_storage_of(carriers[slot]) || carriers[slot]
		if(!istype(holder))
			continue
		if(istype(holder, /obj/item/storage/large_holster))
			if(!(locate(/obj/item/weapon/gun) in holder))
				clash_kit_problem(wearer, slot, clash_job_carries_back_gun(wearer.job) ? "It's empty. Pick a shotgun for the scabbard." : "It's empty. Machine Gunners carry no shotgun in it.")
			continue
		var/text = clash_kit_carrier_problem(holder, guns, wearer)
		if(text)
			clash_kit_problem(wearer, slot, text)

GLOBAL_LIST_EMPTY(clash_kit_samples)

/proc/clash_kit_sample(item_type)
	var/obj/item/sample = GLOB.clash_kit_samples[item_type]
	if(QDELETED(sample))
		sample = new item_type
		GLOB.clash_kit_samples[item_type] = sample
	return sample

/proc/clash_kit_option_problems(datum/clash_kit/kit, job, mob/user)
	. = list()
	var/list/guns = list()
	for(var/gun_type in list(clash_effective_primary(kit, job), clash_effective_back_gun(kit, job), clash_effective_sidearm(kit, job)))
		if(ispath(gun_type, /obj/item/weapon/gun))
			guns += clash_kit_sample(gun_type)
	for(var/slot in list(KIT_SLOT_BELT, KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R, KIT_SLOT_WEBBING))
		for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[clash_kit_faction_for_job(job)]?[slot])
			var/obj/item/sample = clash_kit_sample(option.item_type)
			var/obj/item/clothing/accessory/storage/webbing = sample
			var/obj/item/storage/holder = istype(webbing) ? webbing.hold : clash_kit_storage_of(sample)
			var/text = holder && clash_kit_carrier_problem(holder, guns, user, TRUE)
			if(text)
				.[option.id] = text

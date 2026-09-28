GLOBAL_LIST_EMPTY(clash_kits)
GLOBAL_LIST_EMPTY(clash_active_kits)
#define CLASH_KIT_DUMMY "clash_kit"
#define CLASH_KIT_ISSUE_DUMMY "clash_kit_issue"
GLOBAL_LIST_EMPTY(clash_kit_issue_items)
GLOBAL_LIST_EMPTY(clash_kit_issue_pending)

/datum/clash_kit
	var/name
	var/list/choices = list()

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

/proc/get_clash_kit_roles()
	. = list(FACTION_MARINE = list(), FACTION_UPP = list())
	for(var/title in GLOB.ROLES_CM_VS_UPP)
		.[clash_kit_faction_for_job(title)] += title

/proc/clash_kit_path(ckey)
	return clash_player_save_path(ckey, "clash_kits.sav")

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
	var/list/presets = kits ? list() : get_clash_kit_role_presets(job)
	if(!kits)
		kits = list()
		by_job[job] = kits
	while(length(kits) < CLASH_KIT_COUNT)
		var/datum/clash_kit/kit = new
		var/list/preset = length(presets) > length(kits) ? presets[length(kits) + 1] : null
		if(preset)
			var/list/preset_choices = preset[2]
			kit.name = preset[1]
			kit.choices = preset_choices.Copy()
		else
			var/customs = 1
			for(var/datum/clash_kit/other as anything in kits)
				if(findtext(other.name, "Custom") == 1)
					customs++
			kit.name = customs > 1 ? "Custom [customs]" : "Custom"
		kits += kit
	return kits

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
			stored += list(list("name" = kit.name, "choices" = kit.choices))
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
			kit.name = stored["name"]
			for(var/slot in stored["choices"])
				var/id = stored["choices"][slot]
				if(!get_clash_kit_option(id) && ispath(text2path(id)))
					id = clash_kit_option_id(clash_kit_faction_for_job(job), slot, text2path(id))
				if(get_clash_kit_option(id))
					kit.choices[slot] = id
			kits += kit
		by_job[job] = kits

/**
 * Hands a fighter their role's full kit, over the bare job preset they spawned from.
 * The job's empty pack makes way for the kit's packed one; anything else already worn stays.
 */
/proc/issue_clash_role_kit(mob/living/carbon/human/fighter, job)
	var/kit_path = GLOB.clash_kit_role_kits[job]
	var/datum/equipment_preset/full_kit = kit_path && GLOB.equipment_presets.gear_path_presets_list[kit_path]
	if(!full_kit)
		return
	var/obj/item/pack = fighter.back
	if(pack && !length(pack.contents))
		fighter.temp_drop_inv_item(pack, TRUE)
		qdel(pack)
	try
		full_kit.load_gear(fighter, fighter.client)
	catch(var/exception/error)
		stack_trace("Clash kit could not issue [job] their full kit: [error]")

/proc/clash_kit_replace_worn(mob/living/carbon/human/wearer, wear_slot, item_type)
	var/obj/item/old = wearer.get_item_by_slot(wear_slot)
	var/list/carried = list()
	if(old)
		if(isstorage(old))
			for(var/obj/item/thing in old.contents)
				carried += thing
				thing.forceMove(wearer)
		wearer.temp_drop_inv_item(old, TRUE)
		qdel(old)
	var/obj/item/fresh = new item_type(wearer)
	if(!wearer.equip_to_slot_if_possible(fresh, wear_slot, TRUE, FALSE, TRUE))
		qdel(fresh)
		fresh = null
	for(var/obj/item/thing as anything in carried)
		if(isstorage(fresh))
			var/obj/item/storage/holder = fresh
			if(holder.can_be_inserted(thing, wearer, TRUE) && holder.handle_item_insertion(thing, TRUE, wearer))
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

/proc/clash_kit_give_magazines(mob/living/carbon/human/wearer, datum/clash_kit_option/gun_option)
	for(var/count in 1 to gun_option.ammo_count)
		var/obj/item/magazine = new gun_option.ammo_type(wearer)
		if(!wearer.equip_to_appropriate_slot(magazine))
			qdel(magazine)

/**
 * Dresses wearer in a kit over what their job issued. Picks that are not this side's are skipped.
 * A picked gun replaces every gun of its kind the wearer has, so re-kitting cannot stack weapons;
 * unpicked slots keep the issue item, and magazines that fit nothing left are removed.
 */
/proc/apply_clash_kit(mob/living/carbon/human/wearer, datum/clash_kit/kit)
	if(!kit || QDELETED(wearer))
		return
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
		clash_kit_replace_worn(wearer, GLOB.clash_kit_slots[slot]["wear"], option.item_type)

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
			if(main_gun.can_attach_to_gun(wearer, attachment))
				attachment.Attach(main_gun)
				main_gun.update_attachable(attachment.slot)
			else
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
		if(primary)
			clash_kit_give_magazines(wearer, primary)
		if(sidearm)
			clash_kit_give_magazines(wearer, sidearm)
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
	wearer.regenerate_icons()

/proc/describe_clash_kit_item(obj/item/item)
	return item ? list("name" = item.name, "icon" = "[item.icon]", "icon_state" = item.icon_state) : null

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
		var/mob/living/carbon/human/dummy/model = generate_or_wait_for_human_dummy(CLASH_KIT_ISSUE_DUMMY)
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
			var/obj/item/explosive/grenade/grenade = locate() in model.get_contents()
			if(grenade)
				found[KIT_SLOT_GRENADE] = describe_clash_kit_item(grenade)
		catch(var/exception/error)
			failed = TRUE
			stack_trace("Clash kit could not read the issue gear of [job]: [error]")
		unset_busy_human_dummy(CLASH_KIT_ISSUE_DUMMY)
	if(!failed)
		GLOB.clash_kit_issue_items[job] = found
	var/list/waiting = GLOB.clash_kit_issue_pending[job]
	GLOB.clash_kit_issue_pending -= job
	for(var/datum/requester as anything in waiting)
		if(!QDELETED(requester))
			SStgui.update_uis(requester)

/proc/render_clash_kit_doll(datum/clash_kit/kit, job, client/viewer)
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	if(!role?.gear_preset)
		return null
	var/mob/living/carbon/human/dummy/model = generate_or_wait_for_human_dummy(CLASH_KIT_DUMMY)
	try
		model.set_species()
		if(viewer?.prefs)
			viewer.prefs.copy_appearance_to(model)
		model.faction = clash_kit_faction_for_job(job)
		model.update_body()
		model.update_hair()
		arm_equipment(model, role.gear_preset, FALSE, FALSE, null, TRUE)
		issue_clash_role_kit(model, job)
		apply_clash_kit(model, kit)
		for(var/obj/limb/limb in model.limbs)
			limb.blocks_emissive = EMISSIVE_BLOCK_NONE
		model.regenerate_icons()
		var/icon/flat = getFlatIcon(model)
		. = flat ? icon2base64(flat) : null
	catch(var/exception/error)
		stack_trace("Clash kit could not draw a [job] doll: [error]")
	unset_busy_human_dummy(CLASH_KIT_DUMMY)

#undef CLASH_KIT_DUMMY
#undef CLASH_KIT_ISSUE_DUMMY

/// Saved kits, ckey to job to list of kits
GLOBAL_LIST_EMPTY(clash_kits)
/// Which kit spawns with a role, ckey to job to index
GLOBAL_LIST_EMPTY(clash_active_kits)
/// Key of the pooled dummy every doll is drawn on
#define CLASH_KIT_DUMMY "clash_kit"

/// One saved kit: slot to option id. A slot with no pick keeps the job's issue item.
/datum/clash_kit
	var/name
	var/list/choices = list()

/datum/clash_kit/proc/get_option(slot)
	return get_clash_kit_option(choices[slot])

/// Whether the arena kit system runs this round, else Faction Clash keeps its vendor loadouts
/proc/clash_uses_kits()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.use_kits

/// A file in a player's save folder
/proc/clash_player_save_path(ckey, filename)
	return "data/player_saves/[copytext(ckey, 1, 2)]/[ckey]/[filename]"

/proc/clash_kit_faction_for_job(job)
	return (job in UPP_JOB_LIST) ? FACTION_UPP : FACTION_MARINE

/// Roles a kit can be made for, faction to job titles
/proc/get_clash_kit_roles()
	. = list(FACTION_MARINE = list(), FACTION_UPP = list())
	for(var/title in GLOB.ROLES_CM_VS_UPP)
		.[clash_kit_faction_for_job(title)] += title

/proc/clash_kit_path(ckey)
	return clash_player_save_path(ckey, "clash_kits.sav")

/// A player's kits for a role, loading them first time and filling out the slots
/proc/get_clash_kits(ckey, job)
	if(!ckey || !job)
		return null
	// Loading drops picks the catalogue does not know, so it has to exist first
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
		kit.name = "Kit [length(kits) + 1]"
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
			// Drop picks the catalogue no longer has
			for(var/slot in stored["choices"])
				if(get_clash_kit_option(stored["choices"][slot]))
					kit.choices[slot] = stored["choices"][slot]
			kits += kit
		by_job[job] = kits

/// Takes out whatever is worn in a slot and puts the kit's item there. What the old one held moves across where it fits.
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

/proc/clash_is_sidearm(obj/item/weapon/gun/gun)
	return istype(gun, /obj/item/weapon/gun/pistol) || istype(gun, /obj/item/weapon/gun/revolver)

/// Deletes every gun the wearer has anywhere that is (or is not) a sidearm
/proc/clash_kit_purge_guns(mob/living/carbon/human/wearer, sidearms)
	for(var/obj/item/weapon/gun/gun in wearer.get_contents())
		if(clash_is_sidearm(gun) != sidearms)
			continue
		if(gun.loc == wearer)
			wearer.temp_drop_inv_item(gun, TRUE)
		qdel(gun)

/// Deletes loose magazines no gun the wearer has can take
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

	// Armor first, holding the issue gun out of the way, since a new suit would drop it
	var/obj/item/issue_primary = wearer.s_store
	if(issue_primary)
		wearer.temp_drop_inv_item(issue_primary, TRUE)
		issue_primary.forceMove(wearer)
	for(var/slot in list(KIT_SLOT_HELMET, KIT_SLOT_ARMOR, KIT_SLOT_MASK, KIT_SLOT_BACK, KIT_SLOT_BELT, KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R))
		var/datum/clash_kit_option/option = kit.get_option(slot)
		if(!option || option.faction != faction)
			continue
		clash_kit_replace_worn(wearer, GLOB.clash_kit_slots[slot]["wear"], option.item_type)

	var/obj/item/weapon/gun/main_gun
	if(primary)
		clash_kit_purge_guns(wearer, FALSE)
		main_gun = new primary.item_type(wearer)
		if(!wearer.equip_to_slot_if_possible(main_gun, WEAR_J_STORE, TRUE, FALSE, TRUE) && !wearer.equip_to_appropriate_slot(main_gun))
			wearer.put_in_hands(main_gun)
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
			wearer.put_in_hands(issue_primary)
	if(sidearm)
		clash_kit_purge_guns(wearer, TRUE)
		var/obj/item/weapon/gun/side_gun = new sidearm.item_type(wearer)
		if(!(wearer.belt && wearer.equip_to_slot_if_possible(side_gun, WEAR_IN_BELT, TRUE, FALSE, TRUE)) && !wearer.equip_to_appropriate_slot(side_gun))
			wearer.put_in_hands(side_gun)
	if(primary || sidearm)
		clash_kit_purge_stray_magazines(wearer)
		if(primary)
			clash_kit_give_magazines(wearer, primary)
		if(sidearm)
			clash_kit_give_magazines(wearer, sidearm)
	wearer.regenerate_icons()

/// A picture of a fighter of this role wearing this kit, as a base64 PNG for the kit screen
/proc/render_clash_kit_doll(datum/clash_kit/kit, job, client/viewer)
	var/datum/job/role = GLOB.RoleAuthority.roles_by_name[job]
	if(!role?.gear_preset)
		return null
	var/mob/living/carbon/human/dummy/model = generate_or_wait_for_human_dummy(CLASH_KIT_DUMMY)
	model.set_species()
	if(viewer?.prefs)
		viewer.prefs.copy_appearance_to(model)
	model.faction = clash_kit_faction_for_job(job)
	model.update_body()
	model.update_hair()
	arm_equipment(model, role.gear_preset, FALSE, FALSE, viewer, TRUE)
	apply_clash_kit(model, kit)
	for(var/obj/limb/limb in model.limbs)
		limb.blocks_emissive = EMISSIVE_BLOCK_NONE
	model.regenerate_icons()
	var/icon/flat = getFlatIcon(model)
	. = flat ? icon2base64(flat) : null
	unset_busy_human_dummy(CLASH_KIT_DUMMY)

#undef CLASH_KIT_DUMMY

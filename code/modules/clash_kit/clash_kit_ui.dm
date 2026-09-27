/// One kit screen per player, kept so the doll and choices survive reopening
GLOBAL_LIST_EMPTY(clash_kit_screens)

/proc/get_clash_kit_screen(mob/user)
	var/ckey = user.ckey
	if(!ckey)
		return null
	var/datum/clash_kit_screen/screen = GLOB.clash_kit_screens[ckey]
	if(!screen)
		screen = new(ckey)
		GLOB.clash_kit_screens[ckey] = screen
	return screen

/// Opens the kit screen. deploy makes its main button respawn the viewer wearing the kit.
/proc/open_clash_kit_screen(mob/user, deploy = FALSE)
	if(!clash_uses_kits())
		to_chat(user, SPAN_WARNING("Kits are only used on arena maps. Faction Clash keeps the vendor loadouts."))
		return
	var/datum/clash_kit_screen/screen = get_clash_kit_screen(user)
	if(!screen)
		return
	screen.deploy_mode = deploy
	screen.pick_job_for(user)
	screen.tgui_interact(user)

/mob/verb/clash_loadout()
	set name = "Loadout"
	set category = "OOC"
	open_clash_kit_screen(src)

/datum/clash_kit_screen
	var/ckey
	var/job
	var/kit_index = 1
	var/deploy_mode = FALSE
	/// Base64 PNG of the doll, redrawn when a pick changes
	var/doll
	var/doll_dirty = TRUE
	/// Re-kitting in place mints fresh gear, so it is rate limited
	COOLDOWN_DECLARE(equip_cooldown)

/datum/clash_kit_screen/New(ckey)
	. = ..()
	src.ckey = ckey
	build_clash_kit_catalog()

/// Starts on the viewer's own role, else what they last looked at, else the first marine role
/datum/clash_kit_screen/proc/pick_job_for(mob/user)
	var/mob/living/carbon/human/fighter = ishuman(user) ? user : user.mind?.original
	if(ishuman(fighter) && fighter.job && (fighter.job in GLOB.ROLES_CM_VS_UPP))
		set_job(fighter.job)
	else if(!job)
		set_job(GLOB.ROLES_CM_VS_UPP[1])

/datum/clash_kit_screen/proc/set_job(new_job)
	if(job == new_job)
		return
	job = new_job
	kit_index = get_clash_active_kit_index(ckey, job)
	doll_dirty = TRUE

/datum/clash_kit_screen/proc/get_kit()
	var/list/kits = get_clash_kits(ckey, job)
	return kits ? kits[clamp(kit_index, 1, length(kits))] : null

/datum/clash_kit_screen/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashKit", "Loadout")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/clash_kit_screen/ui_state(mob/user)
	return GLOB.always_state

/datum/clash_kit_screen/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/inventory))

/datum/clash_kit_screen/ui_static_data(mob/user)
	var/list/slots = list()
	for(var/slot in GLOB.clash_kit_slots)
		var/list/info = GLOB.clash_kit_slots[slot]
		slots += list(list("id" = slot, "name" = info["name"], "image" = info["image"], "attachment" = (slot in GLOB.clash_kit_attachment_slots)))
	var/list/menus = list()
	for(var/faction in GLOB.clash_kit_menu)
		var/list/by_slot = list()
		for(var/slot in GLOB.clash_kit_menu[faction])
			var/list/options = list()
			for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[faction][slot])
				var/atom/item = option.item_type
				options += list(list(
					"id" = option.id,
					"name" = option.name,
					"blurb" = option.blurb,
					"icon" = "[initial(item.icon)]",
					"icon_state" = initial(item.icon_state),
					"ammo" = option.ammo_count,
				))
			by_slot[slot] = options
		menus[faction] = by_slot
	var/list/roles = get_clash_kit_roles()
	return list(
		"slots" = slots,
		"menus" = menus,
		"roles" = list(list("faction" = FACTION_MARINE, "name" = "USCM", "jobs" = roles[FACTION_MARINE]), list("faction" = FACTION_UPP, "name" = "UPP", "jobs" = roles[FACTION_UPP])),
		"kit_count" = CLASH_KIT_COUNT,
	)

/datum/clash_kit_screen/ui_data(mob/user)
	var/list/kits = get_clash_kits(ckey, job)
	var/datum/clash_kit/kit = get_kit()
	if(doll_dirty)
		doll = render_clash_kit_doll(kit, job, user.client)
		doll_dirty = FALSE
	var/list/kit_data = list()
	for(var/datum/clash_kit/each as anything in kits)
		var/set_count = 0
		for(var/slot in each.choices)
			if(each.choices[slot])
				set_count++
		kit_data += list(list("name" = each.name, "set" = set_count))
	var/datum/clash_kit_option/primary = kit?.get_option(KIT_SLOT_PRIMARY)
	var/list/fits = list()
	if(primary)
		for(var/slot in GLOB.clash_kit_attachment_slots)
			for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[primary.faction][slot])
				if(clash_kit_attachment_fits(option.item_type, primary.item_type))
					fits += option.id
	var/mob/living/carbon/human/fighter = ishuman(user) ? user : null
	var/area/clash_arena/here = fighter ? get_area(fighter) : null
	var/can_equip_now = fighter && fighter.stat == CONSCIOUS && fighter.job == job && istype(here) && here.clash_faction == fighter.faction
	return list(
		"job" = job,
		"faction" = clash_kit_faction_for_job(job),
		"kits" = kit_data,
		"kit_index" = kit_index,
		"active_index" = get_clash_active_kit_index(ckey, job),
		"choices" = kit?.choices || list(),
		"fits" = fits,
		"doll" = doll,
		"can_equip_now" = can_equip_now,
		"deploy_mode" = deploy_mode && (isobserver(user) || (fighter && fighter.stat == DEAD)),
		"live" = !!fighter && fighter.stat != DEAD,
	)

/datum/clash_kit_screen/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	var/datum/clash_kit/kit = get_kit()
	switch(action)
		if("role")
			if(params["job"] in GLOB.ROLES_CM_VS_UPP)
				set_job(params["job"])
		if("kit")
			var/index = text2num(params["index"])
			if(index >= 1 && index <= CLASH_KIT_COUNT)
				kit_index = index
				doll_dirty = TRUE
		if("pick")
			var/datum/clash_kit_option/option = get_clash_kit_option(params["id"])
			if(!kit || !option || option.faction != clash_kit_faction_for_job(job) || option.slot != params["slot"])
				return TRUE
			kit.choices[option.slot] = option.id
			doll_dirty = TRUE
			save_clash_kits(ckey)
		if("clear")
			if(!kit || !(params["slot"] in GLOB.clash_kit_slots))
				return TRUE
			kit.choices -= params["slot"]
			doll_dirty = TRUE
			save_clash_kits(ckey)
		if("reset")
			if(!kit)
				return TRUE
			kit.choices = list()
			doll_dirty = TRUE
			save_clash_kits(ckey)
		if("rename")
			var/new_name = sanitize(copytext(trim("[params["name"]]"), 1, 25))
			if(!kit || !length(new_name))
				return TRUE
			kit.name = new_name
			save_clash_kits(ckey)
		if("set_active")
			var/list/active = GLOB.clash_active_kits[ckey]
			active[job] = kit_index
			save_clash_kits(ckey)
			to_chat(user, SPAN_NOTICE("[kit.name] will be your kit whenever you spawn as [job]."))
		if("equip_now")
			var/mob/living/carbon/human/fighter = user
			var/area/clash_arena/here = ishuman(fighter) ? get_area(fighter) : null
			if(!ishuman(fighter) || fighter.stat != CONSCIOUS || fighter.job != job || !istype(here) || here.clash_faction != fighter.faction)
				to_chat(user, SPAN_WARNING("You can only re-kit inside your own base, as the role the kit is for."))
				return TRUE
			if(!COOLDOWN_FINISHED(src, equip_cooldown))
				to_chat(user, SPAN_WARNING("Give it a moment before re-kitting again."))
				return TRUE
			COOLDOWN_START(src, equip_cooldown, 10 SECONDS)
			apply_clash_kit(fighter, kit)
			to_chat(user, SPAN_NOTICE("Re-kitted as [kit.name]."))
		if("deploy")
			if(!(isobserver(user) || (isliving(user) && user.stat == DEAD)))
				return TRUE
			var/list/active = GLOB.clash_active_kits[ckey]
			active[job] = kit_index
			save_clash_kits(ckey)
			SStgui.close_uis(src)
			user.abandon_mob()
			return TRUE
	return TRUE

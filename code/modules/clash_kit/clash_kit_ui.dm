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

/// Opens the kit screen. From the lobby, a ghost or a body it doubles as the spawn menu.
/proc/open_clash_kit_screen(mob/user)
	if(!clash_uses_kits())
		to_chat(user, SPAN_WARNING("Kits are only used on arena maps. Faction Clash keeps the vendor loadouts."))
		return
	var/datum/clash_kit_screen/screen = get_clash_kit_screen(user)
	if(!screen)
		return
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
	/// Base64 PNG of the doll last shown
	var/doll
	/// Job and choices the shown doll was drawn for
	var/doll_key
	/// Drawn dolls by key, so flipping between kits is instant
	var/list/doll_cache = list()
	var/render_queued = FALSE
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

/datum/clash_kit_screen/proc/get_kit()
	var/list/kits = get_clash_kits(ckey, job)
	return kits ? kits[clamp(kit_index, 1, length(kits))] : null

/datum/clash_kit_screen/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashKit", "Loadout")
		// Pushed on change only: the doll is heavy and the respawn countdown runs in the client
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
					"stats" = option.stats,
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
	// The doll is drawn off the tick so a pick answers at once, then pushed when ready
	var/wanted = get_doll_key(kit)
	var/doll_pending = FALSE
	if(doll_cache[wanted])
		doll = doll_cache[wanted]
		doll_key = wanted
	else if(doll_key != wanted)
		doll_pending = TRUE
		queue_doll(user.client)
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
	var/mob/living/carbon/human/fighter = ishuman(user) && user.stat != DEAD ? user : null
	var/area/clash_arena/here = fighter ? get_area(fighter) : null
	var/in_base = istype(here) && here.clash_faction == fighter?.faction
	var/can_equip_now = fighter && fighter.stat == CONSCIOUS && fighter.job == job && in_base
	var/deploy_state = get_deploy_state(user)
	var/respawn_in = deploy_state == "dead" ? get_respawn_wait(user) : 0
	if(respawn_in)
		// One push when the wait is over, so Deploy lights up without polling
		addtimer(CALLBACK(SStgui, TYPE_PROC_REF(/datum/controller/subsystem/tgui, update_uis), src), respawn_in + 1, TIMER_UNIQUE|TIMER_OVERRIDE)
	var/list/issue = get_clash_issue_items(job)
	if(isnull(issue))
		queue_clash_issue_items(job, src)
	var/hint
	if(fighter)
		if(fighter.job != job)
			hint = "Editing [job]. You are playing [fighter.job]."
		else if(in_base)
			hint = "Equip now to swap into this kit, or it goes on at your next spawn."
		else
			hint = "Goes on at your next spawn. Head back to base to swap now."
	else if(deploy_state)
		hint = "Choose a role and a kit, then deploy."
	return list(
		"job" = job,
		"faction" = clash_kit_faction_for_job(job),
		"kits" = kit_data,
		"kit_index" = kit_index,
		"choices" = kit?.choices || list(),
		"issue" = issue || list(),
		"fits" = fits,
		"doll" = doll,
		"doll_pending" = doll_pending,
		"can_equip_now" = can_equip_now,
		"live" = !!fighter,
		"deploy_state" = deploy_state,
		"respawn_in" = CEILING(respawn_in / 10, 1),
		"deploy_block" = deploy_state ? get_deploy_block(user) : null,
		"revivable" = deploy_state == "dead" && !!user.get_revivable_body(),
		"hint" = hint,
	)

/// "lobby" or "dead" when the viewer can spawn from this screen, else null
/datum/clash_kit_screen/proc/get_deploy_state(mob/user)
	if(isnewplayer(user))
		return "lobby"
	if(isobserver(user) || (isliving(user) && user.stat == DEAD))
		return "dead"
	return null

/// Deciseconds until a dead viewer may respawn
/datum/clash_kit_screen/proc/get_respawn_wait(mob/user)
	if(!user.timeofdeath || check_client_rights(user.client, R_ADMIN, FALSE))
		return 0
	return max(0, user.timeofdeath + clash_respawn_cooldown() - world.time)

/// Why deploying as the shown role would fail right now, or null. Checked before anything is given up.
/datum/clash_kit_screen/proc/get_deploy_block(mob/user)
	if(!user.client)
		return "Not connected"
	if(SSticker.current_state != GAME_STATE_PLAYING)
		return "The round has not started"
	if(!GLOB.enter_allowed)
		return "Joining is locked right now"
	if(get_deploy_state(user) == "dead" && !CONFIG_GET(flag/respawn) && !check_client_rights(user.client, R_ADMIN, FALSE))
		return "Respawning is off"
	var/datum/job/role = GLOB.RoleAuthority.roles_for_mode[job]
	if(!role)
		return "That role is not in this round"
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode) && !clash_mode.can_join_side(job))
		return "Your side is full. Even the teams by joining the other side"
	// Respawning frees the seat the player held, and they already passed the role's checks to take it
	if(get_held_job(user) == job)
		return null
	if(!GLOB.RoleAuthority.check_role_entry(user, role, TRUE))
		return "That role is full or not open to you"
	return null

/// The role a dead viewer was playing, which respawning gives up
/datum/clash_kit_screen/proc/get_held_job(mob/user)
	if(isnewplayer(user))
		return null
	var/mob/body = isobserver(user) ? user.mind?.original : user
	return body?.job

/datum/clash_kit_screen/proc/get_doll_key(datum/clash_kit/kit)
	return json_encode(list(job, kit?.choices))

/datum/clash_kit_screen/proc/queue_doll(client/viewer)
	if(render_queued)
		return
	render_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(render_doll), viewer), 1)

/datum/clash_kit_screen/proc/render_doll(client/viewer)
	render_queued = FALSE
	var/datum/clash_kit/kit = get_kit()
	var/key = get_doll_key(kit)
	if(!doll_cache[key])
		doll_cache[key] = render_clash_kit_doll(kit, job, viewer)
		if(length(doll_cache) > 24)
			doll_cache.Cut(1, 2)
	doll = doll_cache[key]
	doll_key = key
	SStgui.update_uis(src)

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
				// The kit you pick is the kit you spawn with
				kit_index = index
				var/list/active = GLOB.clash_active_kits[ckey]
				active[job] = kit_index
				save_clash_kits(ckey)
		if("pick")
			var/datum/clash_kit_option/option = get_clash_kit_option(params["id"])
			if(!kit || !option || option.faction != clash_kit_faction_for_job(job) || option.slot != params["slot"])
				return TRUE
			kit.choices[option.slot] = option.id
			save_clash_kits(ckey)
		if("clear")
			if(!kit || !(params["slot"] in GLOB.clash_kit_slots))
				return TRUE
			kit.choices -= params["slot"]
			save_clash_kits(ckey)
		if("reset")
			if(!kit)
				return TRUE
			kit.choices = list()
			save_clash_kits(ckey)
		if("rename")
			var/new_name = sanitize(copytext(trim("[params["name"]]"), 1, 25))
			if(!kit || !length(new_name))
				return TRUE
			kit.name = new_name
			save_clash_kits(ckey)
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
			deploy(user)
			return TRUE
	return TRUE

/// Spawns the viewer as the shown role wearing the shown kit: straight from the lobby, or through a respawn
/datum/clash_kit_screen/proc/deploy(mob/user)
	var/state = get_deploy_state(user)
	if(!state)
		return
	var/block = get_deploy_block(user)
	if(block)
		to_chat(user, SPAN_WARNING("[block]."))
		return
	if(state == "dead" && get_respawn_wait(user))
		return
	var/client/player = user.client
	var/role = job
	if(state == "dead")
		// Respawning lands the player in the lobby, from where they join as the chosen role.
		// The screen already asked everything the respawn verb would.
		user.respawn_to_lobby(TRUE)
	var/mob/new_player/lobby = player?.mob
	if(!istype(lobby))
		return
	SStgui.close_uis(src)
	if(!lobby.late_spawn(role))
		// Whatever stopped it has been told to them; put them back on the screen rather than leave them in the lobby
		open_clash_kit_screen(lobby)

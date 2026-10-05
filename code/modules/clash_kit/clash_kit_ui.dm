GLOBAL_LIST_EMPTY(clash_kit_screens)

/client/var/clash_deploying = FALSE

/proc/get_clash_kit_screen(mob/user)
	var/ckey = user.ckey
	if(!ckey)
		return null
	var/datum/clash_kit_screen/screen = GLOB.clash_kit_screens[ckey]
	if(!screen)
		screen = new(ckey)
		GLOB.clash_kit_screens[ckey] = screen
	return screen

/proc/open_clash_kit_screen(mob/user, faction)
	if(!clash_uses_kits())
		to_chat(user, SPAN_WARNING("Kits are only used on arena maps. Faction Clash keeps the vendor loadouts."))
		return
	var/datum/clash_kit_screen/screen = get_clash_kit_screen(user)
	if(!screen)
		return
	close_clash_scoreboard(user)
	screen.pick_job_for(user)
	if(faction)
		screen.show_side(faction)
	screen.tgui_interact(user)

/proc/get_open_clash_kit_screen(mob/user)
	var/datum/clash_kit_screen/screen = user.ckey && GLOB.clash_kit_screens[user.ckey]
	return screen && SStgui.get_open_ui(user, screen)

/proc/close_clash_kit_screen(mob/user)
	var/datum/tgui/open_ui = get_open_clash_kit_screen(user)
	open_ui?.close()

/mob/verb/clash_loadout()
	set name = "Loadout"
	set category = "OOC"
	open_clash_kit_screen(src)

/datum/clash_kit_screen
	var/ckey
	var/job
	var/kit_index = 1
	var/list/render
	var/doll_key
	var/list/doll_cache = list()
	var/render_queued = FALSE
	var/list/side_jobs = list()
	var/list/named_kits = list()

/datum/clash_kit_screen/New(ckey)
	. = ..()
	src.ckey = ckey
	build_clash_kit_catalog()

/datum/clash_kit_screen/proc/pick_job_for(mob/user)
	var/mob/living/carbon/human/fighter = ishuman(user) ? user : user.mind?.original
	if(ishuman(fighter) && fighter.job && (fighter.job in clash_role_list()))
		set_job(fighter.job)
	else if(!job)
		set_job(clash_role_list()[1])

/datum/clash_kit_screen/proc/set_job(new_job)
	if(job == new_job)
		return
	job = new_job
	side_jobs[clash_kit_faction_for_job(job)] = job
	kit_index = get_clash_active_kit_index(ckey, job)

/datum/clash_kit_screen/proc/show_side(faction)
	var/list/roles = get_clash_kit_roles()
	var/list/side_roles = roles[faction]
	if(length(side_roles) && clash_kit_faction_for_job(job) != faction)
		set_job(side_jobs[faction] || side_roles[1])

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
					"type" = "[option.item_type]",
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
	clear_locked_attachments(kit)
	var/wanted = get_doll_key(kit)
	var/doll_pending = FALSE
	if(doll_cache[wanted])
		render = doll_cache[wanted]
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
				if(clash_kit_attachment_fits(option.item_type, primary.item_type) && (!clash_progression_gating() || GLOB.clash_weapon_unlock_levels[clash_track_type(primary.item_type)]?[option.item_type]))
					fits += option.id
	var/mob/living/carbon/human/fighter = ishuman(user) && user.stat != DEAD ? user : null
	var/deploy_state = get_deploy_state(user)
	var/respawn_in = deploy_state == "dead" ? clash_respawn_wait(user) : 0
	if(respawn_in)
		addtimer(CALLBACK(SStgui, TYPE_PROC_REF(/datum/controller/subsystem/tgui, update_uis), src), respawn_in + 1, TIMER_UNIQUE|TIMER_OVERRIDE)
	var/list/issue = get_clash_issue_items(job)
	if(isnull(issue))
		queue_clash_issue_items(job, src)
	var/gun_type = clash_effective_primary(kit, job)
	var/hint
	if(fighter)
		if(fighter.job != job)
			hint = "Editing [job]. You are playing [fighter.job]."
		else
			hint = "Changes go on at your next spawn."
	else if(deploy_state)
		hint = "Choose a role and a kit, then deploy."
	return list(
		"job" = job,
		"faction" = clash_kit_faction_for_job(job),
		"kits" = kit_data,
		"kit_index" = kit_index,
		"choices" = kit?.choices || list(),
		"issue" = clash_sentry_issue(clash_filter_issue(issue, ckey, job) || list(), job),
		"sentry_slot" = clash_job_is_engineer(job),
		"fits" = fits,
		"doll" = render?["doll"],
		"gun" = render?["gun"],
		"doll_pending" = doll_pending,
		"pack" = render?["pack"] || list(),
		"extras" = describe_extras(kit, doll_key == wanted ? render?["statuses"] : null),
		"removed" = describe_removed(kit),
		"shop" = get_clash_shop(job)["sections"],
		"budget" = get_clash_kit_budget(job, ckey),
		"spent" = kit ? get_clash_kit_spent(kit, job) : list(),
		"deploy_state" = deploy_state,
		"respawn_in" = CEILING(respawn_in / 10, 1),
		"deploy_block" = deploy_state ? get_deploy_block(user) : null,
		"revivable" = deploy_state == "dead" && !!clash_revivable_body(user),
		"hint" = hint,
		"progress" = clash_progress_ui_data(ckey, job, primary?.item_type, gun_type),
	)

/datum/clash_kit_screen/proc/clear_locked_attachments(datum/clash_kit/kit)
	var/datum/clash_kit_option/primary = kit?.get_option(KIT_SLOT_PRIMARY)
	if(!primary)
		return
	var/cleared = FALSE
	for(var/slot in GLOB.clash_kit_attachment_slots)
		if(kit.choices[slot] && clash_option_lock_text(ckey, kit.choices[slot], job, primary.item_type))
			kit.choices -= slot
			cleared = TRUE
	if(cleared)
		save_clash_kits(ckey)

/datum/clash_kit_screen/proc/get_deploy_state(mob/user)
	if(isnewplayer(user))
		return "lobby"
	if(isobserver(user) || (isliving(user) && user.stat == DEAD))
		return "dead"
	return null

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
	if(get_held_job(user) == job)
		return null
	var/lock_text = clash_role_lock_text(user.client, job)
	if(lock_text)
		return lock_text
	if(!GLOB.RoleAuthority.check_role_entry(user, role, TRUE))
		return "That role is full or not open to you"
	return null

/datum/clash_kit_screen/proc/get_held_job(mob/user)
	if(isnewplayer(user))
		return null
	var/mob/body = isobserver(user) ? user.mind?.original : user
	return body?.job

/datum/clash_kit_screen/proc/get_doll_key(datum/clash_kit/kit)
	var/datum/preferences/prefs = GLOB.preferences_datums[ckey]
	var/datum/clash_kit/filtered = clash_filter_kit(kit, ckey, job)
	return json_encode(list(job, filtered?.choices, kit?.extras, kit?.removed, kit?.fills, prefs?.gear))

/datum/clash_kit_screen/proc/describe_extras(datum/clash_kit/kit, list/statuses)
	. = list()
	if(!kit)
		return
	var/list/by_id = get_clash_shop(job)["by_id"]
	for(var/index in 1 to length(kit.extras))
		var/list/item = by_id[kit.extras[index]]
		. += list(list("id" = kit.extras[index], "name" = item ? item["name"] : "Not sold to this role", "status" = LAZYACCESS(statuses, index) || "pending"))

/datum/clash_kit_screen/proc/describe_removed(datum/clash_kit/kit)
	. = list()
	if(!kit)
		return
	for(var/type_text in kit.removed)
		var/obj/item/item_type = text2path(type_text)
		. += list(list("type" = type_text, "name" = initial(item_type.name)))

/datum/clash_kit_screen/proc/pack_holds(type_text)
	for(var/list/holder in render?["pack"])
		for(var/list/item in holder["items"])
			if(item["type"] == type_text && !item["extra"])
				return TRUE
	return FALSE

/datum/clash_kit_screen/proc/render_now(client/viewer)
	var/datum/clash_kit/kit = get_kit()
	var/key = get_doll_key(kit)
	if(!doll_cache[key])
		var/list/rendered = render_clash_kit_doll(kit, job, viewer)
		if(!rendered)
			return null
		doll_cache[key] = rendered
		if(length(doll_cache) > 24)
			doll_cache.Cut(1, 2)
	render = doll_cache[key]
	doll_key = key
	return render

/datum/clash_kit_screen/proc/queue_doll(client/viewer)
	if(render_queued)
		return
	render_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(render_doll), viewer), 1)

/datum/clash_kit_screen/proc/render_doll(client/viewer)
	render_queued = FALSE
	render_now(viewer)
	SStgui.update_uis(src)

/datum/clash_kit_screen/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	var/datum/clash_kit/kit = get_kit()
	switch(action)
		if("role")
			if(params["job"] in clash_role_list())
				set_job(params["job"])
		if("side")
			show_side(params["faction"])
		if("kit")
			var/index = round(text2num(params["index"]))
			if(index >= 1 && index <= CLASH_KIT_COUNT)
				kit_index = index
				var/list/active = GLOB.clash_active_kits[ckey]
				active[job] = kit_index
				save_clash_kits(ckey)
				var/datum/clash_kit/picked = get_kit()
				if(findtext(picked.name, "Custom") == 1 && !length(picked.choices) && !(picked in named_kits))
					named_kits += picked
					INVOKE_ASYNC(src, PROC_REF(name_new_kit), user, picked)
		if("pick")
			var/datum/clash_kit_option/option = get_clash_kit_option(params["id"])
			if(!kit || !option || option.faction != clash_kit_faction_for_job(job) || option.slot != params["slot"])
				return TRUE
			var/datum/clash_kit_option/primary = option.slot == KIT_SLOT_PRIMARY ? option : kit.get_option(KIT_SLOT_PRIMARY)
			var/lock_text = clash_option_lock_text(ckey, option.id, job, primary?.item_type)
			if(lock_text)
				to_chat(user, SPAN_WARNING("[option.name] is locked. [lock_text]."))
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
			kit.extras = list()
			kit.removed = list()
			kit.fills = list()
			save_clash_kits(ckey)
		if("buy")
			var/list/item = get_clash_shop(job)["by_id"][params["id"]]
			if(!kit || !item)
				return TRUE
			var/lock_text = clash_shop_item_lock_text(ckey, job, item["cost"], text2path(item["id"]), clash_effective_primary(kit, job))
			if(lock_text)
				to_chat(user, SPAN_WARNING("[item["name"]] is locked. [lock_text]."))
				return TRUE
			var/list/spent = get_clash_kit_spent(kit, job)
			var/list/budget = get_clash_kit_budget(job, ckey)
			var/left = item["pool"] == CLASH_SHOP_SNOWFLAKE ? budget[2] - spent[CLASH_SHOP_SNOWFLAKE] : budget[1] - spent[CLASH_SHOP_POINTS]
			if(left < item["cost"])
				to_chat(user, SPAN_WARNING("Not enough points left for [item["name"]]."))
				return TRUE
			kit.extras += item["id"]
			var/list/trial = render_clash_kit_doll(kit, job, user.client, FALSE)
			var/list/statuses = trial?["statuses"]
			if(!length(statuses) || statuses[length(statuses)] != "ok")
				kit.extras.Cut(length(kit.extras))
				to_chat(user, SPAN_WARNING("[item["name"]] does not fit in your gear. Make room, or buy it from a vendor once you spawn."))
				return TRUE
			save_clash_kits(ckey)
		if("unbuy_id")
			if(!kit)
				return TRUE
			for(var/index in length(kit.extras) to 1 step -1)
				if(kit.extras[index] == params["id"])
					kit.extras.Cut(index, index + 1)
					save_clash_kits(ckey)
					break
		if("copy")
			var/list/kits = get_clash_kits(ckey, job)
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kits)) || index == kit_index)
				return TRUE
			var/datum/clash_kit/source = kits[index]
			kit.choices = source.choices.Copy()
			kit.extras = source.extras.Copy()
			kit.removed = source.removed.Copy()
			kit.fills = source.fills.Copy()
			save_clash_kits(ckey)
			to_chat(user, SPAN_NOTICE("Copied [source.name] into [kit.name]."))
		if("unbuy")
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kit.extras)))
				return TRUE
			kit.extras.Cut(index, index + 1)
			save_clash_kits(ckey)
		if("drop_item")
			if(!kit || !params["type"])
				return TRUE
			var/extra_index = kit.extras.Find(params["type"])
			if(extra_index && params["extra"])
				kit.extras.Cut(extra_index, extra_index + 1)
			else if(pack_holds(params["type"]))
				kit.removed += params["type"]
			save_clash_kits(ckey)
		if("fill")
			if(!kit || !(params["shell"] in GLOB.clash_kit_shell_names) || !ispath(text2path(params["container"]), /obj/item/storage))
				return TRUE
			kit.fills[params["container"]] = params["shell"]
			save_clash_kits(ckey)
		if("restore_item")
			if(!kit || !(params["type"] in kit.removed))
				return TRUE
			kit.removed -= params["type"]
			save_clash_kits(ckey)
		if("rename")
			var/new_name = sanitize(copytext(trim("[params["name"]]"), 1, 25))
			if(!kit || !length(new_name))
				return TRUE
			kit.name = new_name
			save_clash_kits(ckey)
		if("deploy")
			deploy(user)
			return TRUE
		if("seen")
			var/datum/clash_progress/progress = clash_progress_of(ckey)
			if(!progress || !islist(params["ids"]))
				return TRUE
			for(var/id in params["ids"])
				if(get_clash_kit_option(id) && !(id in progress.seen))
					progress.seen += id
					progress.dirty = TRUE
	return TRUE

/datum/clash_kit_screen/proc/name_new_kit(mob/user, datum/clash_kit/kit)
	var/entered = tgui_input_text(user, "Name your new loadout.", "New loadout", "", 24, encode = FALSE)
	var/new_name = sanitize(copytext(trim("[entered]"), 1, 25))
	if(!length(new_name))
		return
	kit.name = new_name
	save_clash_kits(ckey)
	SStgui.update_uis(src)

/datum/clash_kit_screen/proc/deploy(mob/user)
	var/state = get_deploy_state(user)
	if(!state)
		return
	var/block = get_deploy_block(user)
	if(block)
		to_chat(user, SPAN_WARNING("[block]."))
		return
	if(state == "dead" && clash_respawn_wait(user))
		return
	var/client/player = user.client
	if(state == "dead")
		player.clash_deploying = TRUE
		user.respawn_to_lobby(TRUE)
		player.clash_deploying = FALSE
	spawn_from_lobby(player, job)

/datum/clash_kit_screen/proc/spawn_from_lobby(client/player, role)
	var/mob/new_player/lobby = player?.mob
	if(!istype(lobby))
		return
	SStgui.close_uis(src)
	if(lobby.late_spawn(role))
		return
	if(!SStgui.get_open_ui(lobby, lobby))
		INVOKE_ASYNC(lobby, TYPE_PROC_REF(/mob/new_player, lobby))
	open_clash_kit_screen(lobby)

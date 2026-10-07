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
	var/naming = FALSE

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
		slots += list(list("id" = slot, "name" = info["name"], "image" = info["image"], "attachment" = clash_is_attachment_slot(slot)))
	var/list/menus = list()
	for(var/faction in GLOB.clash_kit_menu)
		var/list/by_slot = list()
		for(var/slot in GLOB.clash_kit_menu[faction])
			var/list/options = list()
			for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[faction][slot])
				var/datum/clash_perk/perk = GLOB.clash_perks[option.item_type]
				var/atom/item = perk ? perk.icon_type : option.item_type
				options += list(list(
					"id" = option.id,
					"name" = option.name,
					"blurb" = option.blurb,
					"icon" = "[initial(item.icon)]",
					"icon_state" = initial(item.icon_state),
					"type" = "[option.item_type]",
					"ammo" = option.ammo_count,
					"stats" = option.stats,
					"only_class" = perk ? perk.class : option.only_class,
					"contents" = clash_type_contents(option.item_type),
				))
			by_slot[slot] = options
		menus[faction] = by_slot
	var/list/roles = get_clash_kit_roles()
	return list(
		"slots" = slots,
		"menus" = menus,
		"roles" = list(list("faction" = FACTION_MARINE, "name" = "USCM", "jobs" = roles[FACTION_MARINE]), list("faction" = FACTION_UPP, "name" = "UPP", "jobs" = roles[FACTION_UPP])),
		"kit_count" = CLASH_KIT_COUNT,
		"role_names" = GLOB.clash_role_names,
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
	var/list/issue = get_clash_issue_items(job)
	if(isnull(issue))
		queue_clash_issue_items(job, src)
	var/gun_type = clash_effective_primary(kit, job)
	var/sidearm_type = clash_effective_sidearm(kit, job)
	var/back_type = clash_effective_back_gun(kit, job)
	var/list/fits = list()
	for(var/slot in GLOB.clash_kit_slots)
		if(!clash_is_attachment_slot(slot))
			continue
		var/slot_gun = clash_is_sidearm_attachment_slot(slot) ? sidearm_type : (clash_is_back_attachment_slot(slot) ? back_type : gun_type)
		if(!slot_gun)
			continue
		for(var/datum/clash_kit_option/option as anything in GLOB.clash_kit_menu[clash_kit_faction_for_job(job)][slot])
			if(clash_kit_attachment_fits(option.item_type, slot_gun) && (!clash_progression_gating() || GLOB.clash_weapon_unlock_levels[clash_track_type(slot_gun)]?[option.item_type]))
				fits += option.id
	var/mob/living/carbon/human/fighter = ishuman(user) && user.stat != DEAD ? user : null
	var/deploy_state = get_deploy_state(user)
	var/respawn_in = deploy_state == "dead" ? clash_respawn_wait(user) : 0
	if(respawn_in)
		addtimer(CALLBACK(SStgui, TYPE_PROC_REF(/datum/controller/subsystem/tgui, update_uis), src), respawn_in + 1, TIMER_UNIQUE|TIMER_OVERRIDE)
	var/hint
	if(fighter)
		if(fighter.job != job)
			hint = "Editing [clash_role_name(job)]. You are playing [clash_role_name(fighter.job)]."
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
		"job_class" = GLOB.clash_job_classes[job],
		"class_primaries" = (GLOB.clash_job_classes[job] in GLOB.clash_class_only_primaries),
		"fits" = fits,
		"blocked_slots" = clash_kit_blocked_slots(gun_type),
		"option_problems" = clash_kit_option_problems(kit, job, user),
		"problems" = clash_kit_current_marks(render?["problems"], render?["choices"], kit),
		"notes" = clash_kit_current_marks(render?["notes"], render?["choices"], kit),
		"primary_shells" = clash_kit_shell_names_for(gun_type),
		"back_shells" = clash_kit_shell_names_for(back_type),
		"back_gun_slot" = clash_job_carries_back_gun(job) && ispath(kit?.get_option(KIT_SLOT_BACK)?.item_type, /obj/item/storage/large_holster) && !length(clash_kit_blocked_slots(gun_type)),
		"primary_shell" = kit?.fills[CLASH_KIT_GUN_FILL] || GLOB.clash_kit_shell_names[1],
		"doll" = render?["doll"],
		"gun" = render?["gun"],
		"sidearm" = render?["sidearm"],
		"back_gun" = render?["back_gun"],
		"doll_pending" = doll_pending,
		"pack" = render?["pack"] || list(),
		"extras" = describe_extras(kit, doll_key == wanted ? render?["statuses"] : null),
		"removed" = doll_key == wanted && render?["left_behind"] || describe_removed(kit),
		"failed_moves" = doll_key == wanted && render?["failed_moves"] || list(),
		"shop" = get_clash_shop(job)["sections"],
		"budget" = get_clash_kit_budget(job, ckey),
		"spent" = kit ? get_clash_kit_spent(kit, job) : list(),
		"deploy_state" = deploy_state,
		"respawn_in" = CEILING(respawn_in / 10, 1),
		"deploy_block" = deploy_state ? get_deploy_block(user) : null,
		"revivable" = deploy_state == "dead" && !!clash_revivable_body(user),
		"hint" = hint,
		"progress" = clash_progress_ui_data(ckey, job, gun_type, gun_type, sidearm_type, back_type),
	)

/datum/clash_kit_screen/proc/clear_locked_attachments(datum/clash_kit/kit)
	var/cleared = FALSE
	for(var/slot in kit.choices.Copy())
		if(!clash_is_attachment_slot(slot) || kit.wants_nothing(slot))
			continue
		var/slot_gun = clash_kit_slot_gun(kit, job, slot)
		var/datum/clash_kit_option/option = get_clash_kit_option(kit.choices[slot])
		if(slot_gun && (!option || !clash_kit_attachment_fits(option.item_type, slot_gun) || clash_option_lock_text(ckey, option.id, job, slot_gun)))
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
		return SSticker.current_state == GAME_STATE_FINISHED ? "The round is over" : "The round has not started"
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
	return json_encode(list(job, filtered?.choices, kit?.extras, kit?.extra_slots, kit?.removed, kit?.removed_slots, kit?.fills, kit?.moves, prefs?.gear))

/datum/clash_kit_screen/proc/describe_extras(datum/clash_kit/kit, list/statuses)
	. = list()
	if(!kit)
		return
	var/list/by_id = get_clash_shop(job)["by_id"]
	kit.sync_extra_slots()
	for(var/index in 1 to length(kit.extras))
		var/list/item = by_id[kit.extras[index]]
		. += list(list("id" = kit.extras[index], "index" = index, "name" = item ? item["name"] : "Not sold to this role", "icon" = item?["icon"], "icon_state" = item?["icon_state"], "slot" = kit.extra_slots[index], "status" = LAZYACCESS(statuses, index) || "pending"))

/datum/clash_kit_screen/proc/describe_removed(datum/clash_kit/kit)
	. = list()
	if(!kit)
		return
	kit.sync_removed_slots()
	for(var/index in 1 to length(kit.removed))
		var/obj/item/item_type = text2path(kit.removed[index])
		. += list(list("index" = index, "type" = kit.removed[index], "name" = capitalize(strip_improper(initial(item_type.name))), "icon" = "[initial(item_type.icon)]", "icon_state" = initial(item_type.icon_state), "from" = kit.removed_slots[index], "fits" = list()))

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
		var/list/rendered = render_clash_kit_doll(kit, job, viewer, TRUE, GLOB.preferences_datums[ckey], ckey)
		if(!rendered)
			return null
		rendered["choices"] = kit.choices.Copy()
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
				if(!naming && findtext(picked.name, regex(@"^Custom( \d+)?$")))
					naming = TRUE
					INVOKE_ASYNC(src, PROC_REF(name_new_kit), user, picked)
		if("pick")
			var/datum/clash_kit_option/option = get_clash_kit_option(params["id"])
			if(!kit || !option || option.faction != clash_kit_faction_for_job(job) || option.slot != params["slot"])
				return TRUE
			var/lock_text = clash_option_lock_text(ckey, option.id, job, (option.slot in list(KIT_SLOT_PRIMARY, KIT_SLOT_BACK_GUN)) ? option.item_type : clash_kit_slot_gun(kit, job, option.slot))
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
		if("nothing")
			if(!kit || !(params["slot"] in GLOB.clash_kit_slots) || (params["slot"] in list(KIT_SLOT_CLASS_PERK, KIT_SLOT_GENERAL_PERK)))
				return TRUE
			kit.choices[params["slot"]] = CLASH_KIT_NOTHING
			save_clash_kits(ckey)
		if("reset")
			if(!kit)
				return TRUE
			INVOKE_ASYNC(src, PROC_REF(confirm_reset), user, kit)
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
			kit.add_extra(item["id"])
			var/list/trial = render_clash_kit_doll(kit, job, user.client, FALSE, GLOB.preferences_datums[ckey], ckey)
			var/list/statuses = trial?["statuses"]
			if(!length(statuses) || statuses[length(statuses)] != "ok")
				kit.remove_extra(length(kit.extras))
				to_chat(user, SPAN_WARNING("[item["name"]] does not fit in your gear. Make room, or buy it from a vendor once you spawn."))
				return TRUE
			save_clash_kits(ckey)
		if("unbuy_id")
			if(!kit)
				return TRUE
			for(var/index in length(kit.extras) to 1 step -1)
				if(kit.extras[index] == params["id"])
					kit.remove_extra(index)
					save_clash_kits(ckey)
					break
		if("copy")
			var/list/kits = get_clash_kits(ckey, job)
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kits)) || index == kit_index)
				return TRUE
			var/datum/clash_kit/source = kits[index]
			kit.copy_from(source)
			save_clash_kits(ckey)
			to_chat(user, SPAN_NOTICE("Copied [source.name] into [kit.name]."))
		if("unbuy")
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kit.extras)))
				return TRUE
			kit.remove_extra(index)
			save_clash_kits(ckey)
		if("drop_item")
			if(!kit || !params["type"])
				return TRUE
			var/extra_index = round(text2num(params["extra_index"]))
			if(!(extra_index in 1 to length(kit.extras)) || kit.extras[extra_index] != params["type"])
				extra_index = kit.extras.Find(params["type"])
			if(extra_index && params["extra"])
				kit.remove_extra(extra_index)
			else if(pack_holds(params["type"]))
				var/from = istext(params["from"]) ? params["from"] : null
				for(var/index in length(kit.moves) to 1 step -1)
					var/list/move = kit.moves[index]
					if(from && move[1] == params["type"] && move[3] == from)
						from = move[2]
						kit.moves.Cut(index, index + 1)
				kit.add_removed(params["type"], from)
			save_clash_kits(ckey)
		if("fill")
			if(!kit || !(params["shell"] in GLOB.clash_kit_shell_names) || !ispath(text2path(params["container"]), /obj/item/storage))
				return TRUE
			kit.fills[params["container"]] = params["shell"]
			save_clash_kits(ckey)
		if("gun_fill")
			if(!kit || !(params["shell"] in GLOB.clash_kit_shell_names))
				return TRUE
			kit.fills = list(CLASH_KIT_GUN_FILL = params["shell"])
			save_clash_kits(ckey)
		if("assign_extra")
			var/index = round(text2num(params["index"]))
			var/target = params["to"]
			if(!kit || !(index in 1 to length(kit.extras)) || (target && !istext(target)))
				return TRUE
			kit.sync_extra_slots()
			var/previous = kit.extra_slots[index]
			kit.extra_slots[index] = target || null
			if(target)
				var/list/trial = render_clash_kit_doll(kit, job, user.client, FALSE, GLOB.preferences_datums[ckey], ckey)
				if(LAZYACCESS(trial?["statuses"], index) == "room")
					kit.extra_slots[index] = previous
					var/list/item = get_clash_shop(job)["by_id"][kit.extras[index]]
					to_chat(user, SPAN_WARNING("[item ? item["name"] : "That"] does not fit there. Make room first."))
					return TRUE
			save_clash_kits(ckey)
		if("move_item")
			var/item_type = params["type"]
			var/from = params["from"]
			var/target = params["to"]
			if(!kit || !istext(item_type) || !ispath(text2path(item_type), /obj/item) || !istext(from) || !istext(target) || from == target)
				return TRUE
			var/reverse = 0
			for(var/index in length(kit.moves) to 1 step -1)
				var/list/move = kit.moves[index]
				if(move[1] == item_type && move[2] == target && move[3] == from)
					reverse = index
					break
			if(reverse)
				kit.moves.Cut(reverse, reverse + 1)
				save_clash_kits(ckey)
				return TRUE
			kit.moves += list(list(item_type, from, target))
			if(length(kit.moves) > CLASH_KIT_MOVE_LIMIT)
				kit.moves.Cut(1, 2)
			var/list/trial = render_clash_kit_doll(kit, job, user.client, FALSE, GLOB.preferences_datums[ckey], ckey)
			if(length(kit.moves) in trial?["moves_failed"])
				kit.moves.Cut(length(kit.moves))
				var/obj/item/moving = text2path(item_type)
				to_chat(user, SPAN_WARNING("[capitalize(initial(moving.name))] does not fit there. Make room first."))
				return TRUE
			save_clash_kits(ckey)
		if("restore_item")
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kit.removed)))
				return TRUE
			kit.sync_removed_slots()
			var/item_type = kit.removed[index]
			var/from = kit.removed_slots[index]
			var/target = params["to"]
			kit.removed.Cut(index, index + 1)
			kit.removed_slots.Cut(index, index + 1)
			if(istext(target) && from && target != from)
				kit.moves += list(list(item_type, from, target))
				if(length(kit.moves) > CLASH_KIT_MOVE_LIMIT)
					kit.moves.Cut(1, 2)
				var/list/trial = render_clash_kit_doll(kit, job, user.client, FALSE, GLOB.preferences_datums[ckey], ckey)
				if(length(kit.moves) in trial?["moves_failed"])
					kit.moves.Cut(length(kit.moves))
					kit.removed.Insert(index, item_type)
					kit.removed_slots.Insert(index, from)
					var/obj/item/moving = text2path(item_type)
					to_chat(user, SPAN_WARNING("[capitalize(initial(moving.name))] does not fit there. Make room first."))
					return TRUE
			save_clash_kits(ckey)
		if("cancel_move")
			var/index = round(text2num(params["index"]))
			if(!kit || !(index in 1 to length(kit.moves)))
				return TRUE
			kit.moves.Cut(index, index + 1)
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

/datum/clash_kit_screen/proc/confirm_reset(mob/user, datum/clash_kit/kit)
	if(tgui_alert(user, "Are you sure you want to reset your loadout?", "Reset loadout", list("Reset", "Cancel")) != "Reset")
		return
	kit.clear()
	save_clash_kits(ckey)
	SStgui.update_uis(src)
	var/datum/clash_kit_screen/own = GLOB.clash_kit_screens[ckey]
	if(own && own != src)
		SStgui.update_uis(own)

/datum/clash_kit_screen/proc/name_new_kit(mob/user, datum/clash_kit/kit)
	var/entered = tgui_input_text(user, "Name your new loadout.", "New loadout", "", 24, encode = FALSE)
	naming = FALSE
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

/datum/clash_kit_screen/admin

/datum/clash_kit_screen/admin/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashKit", "Loadout of [ckey]")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/clash_kit_screen/admin/ui_state(mob/user)
	return GLOB.admin_state

/datum/clash_kit_screen/admin/get_deploy_state(mob/user)
	return null

/datum/clash_kit_screen/admin/ui_data(mob/user)
	. = ..()
	.["hint"] = "Editing the [job] loadout of [ckey]. Changes save to their loadout and apply at their next spawn."

/datum/clash_kit_screen/admin/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action in list("deploy", "seen", "refresh"))
		return TRUE
	if(!CLIENT_HAS_RIGHTS(ui.user.client, R_EVENT))
		return TRUE
	. = ..()
	if(action in list("role", "side"))
		return
	log_admin("[key_name(ui.user)] edited the [job] loadout of [ckey]: [action].")
	var/datum/clash_kit_screen/own = GLOB.clash_kit_screens[ckey]
	if(own)
		if(own.job == job)
			own.kit_index = get_clash_active_kit_index(ckey, job)
		SStgui.update_uis(own)

/proc/clash_kit_current_marks(list/marks, list/drawn_choices, datum/clash_kit/kit)
	. = list()
	for(var/slot in marks)
		if(kit && drawn_choices?[slot] == kit.choices[slot])
			.[slot] = marks[slot]

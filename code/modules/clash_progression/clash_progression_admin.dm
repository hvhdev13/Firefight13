#define CLASH_PROGRESSION_MAX_MULTIPLIER 5

GLOBAL_DATUM_INIT(clash_progression_admin, /datum/clash_progression_admin, new)

/client/proc/clash_progression_panel()
	set name = "Progression Panel"
	set desc = "Look up and edit a player's levels, XP, loadouts and perks, the XP multiplier, XP boosts, bot XP and the locks."
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return
	GLOB.clash_progression_admin.tgui_interact(mob)

/datum/clash_progression_admin
	var/list/lookups = list()
	var/list/loadout_jobs = list()
	var/list/editors = list()

/datum/clash_progression_admin/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashProgressionAdmin", "Progression Panel")
		ui.open()

/datum/clash_progression_admin/ui_state(mob/user)
	return GLOB.admin_state

/datum/clash_progression_admin/ui_static_data(mob/user)
	var/list/perks = list()
	for(var/perk_type in GLOB.clash_perks)
		var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
		perks += list(list("type" = "[perk_type]", "name" = perk.name, "class" = perk.class ? GLOB.clash_class_names[perk.class] : "General"))
	var/list/roles = list()
	for(var/title in GLOB.clash_arena_roles)
		var/class = GLOB.clash_job_classes[title]
		roles += list(list("title" = title, "side" = clash_side_name(clash_kit_faction_for_job(title)), "class" = class, "level" = GLOB.clash_role_levels[title] || 1))
	return list(
		"max_multiplier" = CLASH_PROGRESSION_MAX_MULTIPLIER,
		"level_cap" = CLASH_LEVEL_CAP,
		"perks" = perks,
		"roles" = roles,
		"medical_cap" = CLASH_XP_MEDICAL_CAP,
		"engineering_cap" = CLASH_XP_ENGINEERING_CAP,
	)

/datum/clash_progression_admin/ui_data(mob/user)
	var/ckey = lookups[user.ckey]
	return list(
		"enabled" = GLOB.clash_progression_settings["enabled"],
		"multiplier" = GLOB.clash_progression_settings["xp_multiplier"],
		"bot_xp" = GLOB.clash_progression_settings["bot_xp"],
		"boost" = GLOB.clash_xp_boost.panel_data(),
		"gating" = clash_progression_gating(),
		"online" = get_online_players(),
		"ckey" = ckey,
		"saved" = ckey ? fexists(clash_player_save_path(ckey, CLASH_PROGRESS_FILE)) : FALSE,
		"progress" = ckey ? clash_career_progress(ckey) : null,
		"player" = ckey ? get_player_data(ckey, user) : null,
	)

/datum/clash_progression_admin/proc/get_online_players()
	. = list()
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/fighter = player.mob
		var/is_fighter = ishuman(fighter)
		. += list(list(
			"ckey" = player.ckey,
			"name" = is_fighter ? fighter.real_name : player.mob?.name,
			"job" = is_fighter ? fighter.job : null,
			"side" = is_fighter && (fighter.faction in list(FACTION_MARINE, FACTION_UPP)) ? clash_side_name(fighter.faction) : null,
		))

/datum/clash_progression_admin/proc/get_player_data(ckey, mob/user)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return null
	var/list/ledger = list()
	for(var/source in progress.ledger)
		ledger += list(list("source" = source, "xp" = progress.ledger[source]))
	var/list/start_levels = list()
	for(var/key in progress.start_levels)
		start_levels += list(list("name" = GLOB.clash_class_names[key] || clash_side_name(key), "level" = progress.start_levels[key]))
	var/list/career = GLOB.clash_career.get_entry(ckey)
	return list(
		"live" = get_live_data(ckey),
		"toasts" = progress.toasts,
		"radar" = progress.radar,
		"round" = list(
			"ledger" = ledger,
			"medical" = progress.support_xp[CLASH_XP_SOURCE_HEALING] || 0,
			"engineering" = progress.support_xp[CLASH_XP_SOURCE_COVER] || 0,
			"unlocks" = progress.unlocked_round,
			"start_levels" = start_levels,
			"short_side" = progress.short_side ? clash_side_name(progress.short_side) : null,
		),
		"career" = islist(career) ? clash_career_row(ckey, career) : null,
		"loadout" = get_loadout_data(ckey, user),
	)

/datum/clash_progression_admin/proc/get_live_data(ckey)
	var/client/player = GLOB.directory[ckey]
	var/mob/body = player?.mob
	if(!body)
		return null
	var/mob/living/carbon/human/fighter = ishuman(body) ? body : null
	var/state = "Alive"
	if(isnewplayer(body))
		state = "In the lobby"
	else if(isobserver(body))
		state = "Observing"
	else if(body.stat == DEAD)
		state = "Dead"
	var/list/perks = list()
	for(var/perk_type in fighter?.clash_perks)
		var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
		perks += list(list("type" = "[perk_type]", "name" = perk.name))
	return list(
		"name" = fighter ? fighter.real_name : body.name,
		"state" = state,
		"job" = fighter?.job,
		"side" = fighter && (fighter.faction in list(FACTION_MARINE, FACTION_UPP)) ? clash_side_name(fighter.faction) : null,
		"class" = fighter ? GLOB.clash_class_names[GLOB.clash_job_classes[fighter.job]] : null,
		"perks" = perks,
		"can_edit" = !!clash_admin_body(ckey),
		"can_regear" = !!clash_admin_body(ckey) && clash_uses_kits() && (fighter.job in GLOB.clash_arena_roles),
	)

/datum/clash_progression_admin/proc/get_loadout_job(ckey, mob/user)
	var/job = loadout_jobs[user.ckey]
	if(job in GLOB.clash_arena_roles)
		return job
	var/client/player = GLOB.directory[ckey]
	var/mob/living/carbon/human/fighter = player?.mob
	if(ishuman(fighter) && (fighter.job in GLOB.clash_arena_roles))
		return fighter.job
	return GLOB.clash_arena_roles[1]

/datum/clash_progression_admin/proc/get_loadout_data(ckey, mob/user)
	var/job = get_loadout_job(ckey, user)
	var/list/kits = get_clash_kits(ckey, job)
	var/active = get_clash_active_kit_index(ckey, job)
	var/list/kit_rows = list()
	for(var/index in 1 to length(kits))
		var/datum/clash_kit/kit = kits[index]
		var/datum/clash_kit/spawned = clash_filter_kit(kit, ckey, job)
		var/gun_type = clash_effective_primary(spawned, job)
		var/list/picks = list()
		for(var/slot in GLOB.clash_kit_slots)
			var/datum/clash_kit_option/option = kit.get_option(slot)
			if(!option)
				continue
			var/lock
			if(spawned.choices[slot] != option.id)
				var/datum/clash_kit_option/replacement = spawned.get_option(slot)
				var/slot_gun = clash_is_sidearm_attachment_slot(slot) ? clash_effective_sidearm(spawned, job) : gun_type
				lock = "[clash_option_lock_text(ckey, option.id, job, slot_gun) || "Does not fit the gun"], spawns with [replacement ? replacement.name : "nothing"]"
			picks += list(list("slot" = GLOB.clash_kit_slots[slot]["name"], "name" = option.name, "lock" = lock))
		kit_rows += list(list("name" = kit.name, "active" = index == active, "picks" = picks, "extras" = length(kit.extras)))
	return list("job" = job, "kits" = kit_rows)

/proc/clash_admin_body(ckey)
	var/client/player = GLOB.directory[ckey]
	var/mob/living/carbon/human/fighter = player?.mob
	return ishuman(fighter) && fighter.stat != DEAD ? fighter : null

/datum/clash_progression_admin/proc/refresh_player(ckey)
	var/datum/clash_kit_screen/screen = GLOB.clash_kit_screens[ckey]
	if(screen)
		SStgui.update_uis(screen)
	var/datum/clash_kit_screen/editor = editors[ckey]
	if(editor)
		SStgui.update_uis(editor)

/datum/clash_progression_admin/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!CLIENT_HAS_RIGHTS(user.client, R_EVENT))
		return
	var/note = GLOB.clash_xp_boost.admin_act(action, params, user)
	var/player_ckey = lookups[user.ckey]
	switch(action)
		if("lookup")
			var/wanted = ckey(params["ckey"])
			lookups[user.ckey] = length(wanted) ? wanted : null
			loadout_jobs -= user.ckey
			return TRUE
		if("set_level")
			var/level = text2num(params["level"])
			if(!player_ckey || !clash_set_progress_level(player_ckey, params["track"], params["key"], level, user))
				to_chat(user, SPAN_WARNING("That level could not be set."))
			refresh_player(player_ckey)
			return TRUE
		if("set_xp")
			var/xp = text2num(params["xp"])
			if(!player_ckey || !clash_set_progress_xp(player_ckey, params["track"], params["key"], xp, user))
				to_chat(user, SPAN_WARNING("That XP could not be set."))
			refresh_player(player_ckey)
			return TRUE
		if("fill_all", "reset_all")
			if(!player_ckey)
				return TRUE
			var/full = action == "fill_all"
			var/confirm = full ? "Max everything" : "Reset everything"
			var/what = full ? "Max every level, weapon and carrier for [player_ckey]? They will be told: \"An admin unlocked every level, weapon and carrier for you.\"" : "Reset every level, XP, weapon and carrier of [player_ckey] back to the start? They will be told: \"An admin reset all your levels and XP. Locked gear in your loadout falls back next spawn.\" Only the previous save survives, as a .bak file."
			if(tgui_alert(user, what, confirm, list("Cancel", confirm)) != confirm || lookups[user.ckey] != player_ckey)
				return TRUE
			clash_admin_fill_progress(player_ckey, full)
			refresh_player(player_ckey)
			note = full ? "maxed every level, weapon and carrier for [player_ckey]" : "reset every level, weapon and carrier for [player_ckey]"
		if("loadout_job")
			if(params["job"] in GLOB.clash_arena_roles)
				loadout_jobs[user.ckey] = params["job"]
			return TRUE
		if("open_loadout")
			if(!player_ckey)
				return TRUE
			var/datum/clash_kit_screen/admin/editor = editors[player_ckey]
			if(!editor)
				editor = new(player_ckey)
				editors[player_ckey] = editor
			editor.set_job(get_loadout_job(player_ckey, user))
			editor.tgui_interact(user)
			return TRUE
		if("perk_add", "perk_remove")
			var/mob/living/carbon/human/fighter = clash_admin_body(player_ckey)
			var/perk_type = text2path(params["type"])
			var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
			if(!fighter || !perk)
				return TRUE
			if(action == "perk_add")
				LAZYOR(fighter.clash_perks, perk_type)
				to_chat(fighter, SPAN_NOTICE("An admin gave you the [perk.name] perk until your next spawn."))
				note = "gave [player_ckey] the [perk.name] perk until their next spawn"
			else
				LAZYREMOVE(fighter.clash_perks, perk_type)
				to_chat(fighter, SPAN_NOTICE("An admin removed your [perk.name] perk until your next spawn."))
				note = "removed the [perk.name] perk from [player_ckey] until their next spawn"
		if("regear")
			var/mob/living/carbon/human/fighter = clash_admin_body(player_ckey)
			if(!fighter || !clash_uses_kits())
				return TRUE
			var/datum/clash_kit/kit = get_clash_active_kit(player_ckey, fighter.job)
			if(!kit)
				return TRUE
			INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(regear_clash_fighter), fighter, kit)
			to_chat(fighter, SPAN_NOTICE("An admin re-issued your loadout."))
			note = "re-issued the [fighter.job] loadout of [player_ckey]"
		if("multiplier")
			var/value = text2num(params["value"])
			if(!isnum(value))
				return
			GLOB.clash_progression_settings["xp_multiplier"] = clamp(round(value, 0.25), 0, CLASH_PROGRESSION_MAX_MULTIPLIER)
			note = "set the progression XP multiplier to [GLOB.clash_progression_settings["xp_multiplier"]]"
		if("bot_xp")
			GLOB.clash_progression_settings["bot_xp"] = !GLOB.clash_progression_settings["bot_xp"]
			note = "turned bot XP [GLOB.clash_progression_settings["bot_xp"] ? "on" : "off"]"
		if("enabled")
			GLOB.clash_progression_settings["enabled"] = !GLOB.clash_progression_settings["enabled"]
			note = "turned progression locks [GLOB.clash_progression_settings["enabled"] ? "on" : "off"]"
	if(!note)
		return
	message_admins("[key_name_admin(user)] [note].")
	log_admin("[key_name(user)] [note].")
	return TRUE

/proc/clash_admin_fill_progress(ckey, full)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return
	build_clash_kit_catalog()
	if(!full)
		progress.factions = list()
		progress.classes = list()
		progress.weapons = list()
		progress.carriers = list()
		progress.seen = list()
		progress.save()
		var/client/target = GLOB.directory[ckey]
		if(target)
			to_chat(target, SPAN_NOTICE("An admin reset all your levels and XP. Locked gear in your loadout falls back next spawn."))
		return
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/list/entry = progress.faction_entry(faction)
		entry["xp"] = max(entry["xp"], clash_faction_xp_for(CLASH_LEVEL_CAP))
		entry["best"] = CLASH_LEVEL_CAP
	for(var/class in GLOB.clash_class_names)
		var/list/entry = progress.class_entry(class)
		entry["xp"] = max(entry["xp"], clash_class_xp_for(CLASH_LEVEL_CAP))
		entry["best"] = CLASH_LEVEL_CAP
	for(var/gun_type in GLOB.clash_weapon_tracks)
		var/list/unlocks = GLOB.clash_weapon_tracks[gun_type]
		var/list/entry = progress.weapon_entry(gun_type)
		entry["xp"] = max(entry["xp"], CLASH_WEAPON_MASTERY_XP, length(unlocks) ? unlocks[length(unlocks)]["xp"] : 0)
		entry["best"] = length(unlocks) + 1
		entry["mastered"] = TRUE
	for(var/family in GLOB.clash_carrier_tracks)
		var/list/steps = GLOB.clash_carrier_tracks[family]
		var/list/entry = progress.carrier_entry(family)
		entry["xp"] = max(entry["xp"], length(steps) ? steps[length(steps)][1] : 0)
		entry["best"] = length(steps)
	progress.save()
	var/client/target = GLOB.directory[ckey]
	if(target)
		to_chat(target, SPAN_NOTICE("An admin unlocked every level, weapon and carrier for you."))

#undef CLASH_PROGRESSION_MAX_MULTIPLIER

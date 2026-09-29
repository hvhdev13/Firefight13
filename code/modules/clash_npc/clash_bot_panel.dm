#define CLASH_BOT_PANEL_MAX_TEAM 30
#define CLASH_BOT_PANEL_MAX_SPAWN 10
#define CLASH_BOT_PANEL_MAX_RESPAWN 600

GLOBAL_DATUM_INIT(clash_bot_panel, /datum/clash_bot_panel, new)
GLOBAL_LIST_INIT(clash_bot_sides, list(FACTION_MARINE, FACTION_UPP, FACTION_CLF))
GLOBAL_LIST_INIT(clash_bot_side_spawners, list(
	FACTION_MARINE = /obj/effect/landmark/clash_npc/uscm,
	FACTION_UPP = /obj/effect/landmark/clash_npc/upp,
	FACTION_CLF = /obj/effect/landmark/clash_npc/clf,
))

/client/proc/clash_bot_panel()
	set name = "Bot Control Panel"
	set desc = "Spawn, clear, pause and tune the HvH bots."
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return
	GLOB.clash_bot_panel.tgui_interact(mob)

/proc/clash_bot_clear(faction)
	. = 0
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots.Copy())
		if(faction && bot.body?.faction != faction)
			continue
		bot.retire()
		.++

/proc/clash_bot_room(faction)
	return max(0, GLOB.clash_bot_caps[faction] - clash_bot_count(faction))

/proc/clash_bot_spawn_side(faction, count)
	. = 0
	var/wanted = min(count, clash_bot_room(faction))
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(. >= wanted)
			return
		if(spawner.faction != faction || spawner.temporary || spawner.bot || spawner.spawning)
			continue
		spawner.active = TRUE
		INVOKE_ASYNC(spawner, TYPE_PROC_REF(/obj/effect/landmark/clash_npc, spawn_npc))
		.++

/proc/clash_bot_spawn_at(faction, count, turf/spot)
	. = 0
	var/spawner_type = GLOB.clash_bot_side_spawners[faction]
	for(var/count_index in 1 to min(count, clash_bot_room(faction)))
		var/obj/effect/landmark/clash_npc/spawner = new spawner_type(spot)
		spawner.temporary = TRUE
		spawner.respawn_delay = 0
		INVOKE_ASYNC(spawner, TYPE_PROC_REF(/obj/effect/landmark/clash_npc, spawn_npc))
		.++

/datum/clash_bot_panel

/datum/clash_bot_panel/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashBotPanel", "Bot Control Panel")
		ui.open()

/datum/clash_bot_panel/ui_state(mob/user)
	return GLOB.admin_state

/datum/clash_bot_panel/ui_static_data(mob/user)
	return list(
		"max_team" = CLASH_BOT_PANEL_MAX_TEAM,
		"max_spawn" = CLASH_BOT_PANEL_MAX_SPAWN,
		"max_respawn" = CLASH_BOT_PANEL_MAX_RESPAWN,
	)

/datum/clash_bot_panel/ui_data(mob/user)
	var/list/data = list()
	data["enabled"] = GLOB.clash_bots_enabled
	data["respawn_delay"] = isnull(GLOB.clash_bot_respawn_delay) ? null : GLOB.clash_bot_respawn_delay / 10
	data["hvh_round"] = istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh)
	var/list/sides = list()
	for(var/faction in GLOB.clash_bot_sides)
		var/spawners = 0
		var/idle = 0
		var/fill = 0
		for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
			if(spawner.faction != faction || spawner.temporary)
				continue
			spawners++
			if(spawner.team_fill)
				fill++
			if(!spawner.bot)
				idle++
		sides += list(list(
			"faction" = faction,
			"on" = !(faction in GLOB.clash_bot_sides_off),
			"bots" = clash_bot_count(faction),
			"players" = clash_player_count(faction),
			"spawners" = spawners,
			"idle" = idle,
			"fill_spawners" = fill,
			"fill_target" = GLOB.clash_bot_fill_targets[faction],
			"cap" = GLOB.clash_bot_caps[faction],
		))
	data["sides"] = sides
	var/list/bots = list()
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		var/mob/living/carbon/human/body = bot.body
		if(QDELETED(body) || body.stat == DEAD)
			continue
		var/area/place = get_area(body)
		bots += list(list(
			"ref" = REF(bot),
			"name" = body.real_name,
			"faction" = body.faction,
			"health" = round(clamp(body.health / body.maxHealth, 0, 1) * 100),
			"state" = bot.get_state(),
			"area" = place?.name,
		))
	data["bots"] = bots
	return data

/datum/clash_bot_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!CLIENT_HAS_RIGHTS(user.client, R_EVENT))
		return
	var/faction = params["faction"]
	if(faction && !(faction in GLOB.clash_bot_sides))
		return
	var/note
	switch(action)
		if("toggle_all")
			set_clash_bots_enabled(!GLOB.clash_bots_enabled)
			note = "[GLOB.clash_bots_enabled ? "resumed" : "paused"] all bots"
		if("toggle_side")
			if(!faction)
				return
			if(faction in GLOB.clash_bot_sides_off)
				GLOB.clash_bot_sides_off -= faction
			else
				GLOB.clash_bot_sides_off += faction
			note = "turned [faction] bot spawning [(faction in GLOB.clash_bot_sides_off) ? "off" : "on"]"
		if("set_fill", "set_cap")
			var/value = text2num(params["value"])
			if(!faction || isnull(value))
				return
			value = clamp(round(value), 0, CLASH_BOT_PANEL_MAX_TEAM)
			if(action == "set_fill")
				GLOB.clash_bot_fill_targets[faction] = value
				note = "set the [faction] team fill to [value]"
			else
				GLOB.clash_bot_caps[faction] = value
				note = "set the [faction] bot cap to [value]"
		if("set_respawn")
			var/value = text2num(params["value"])
			if(isnull(value))
				GLOB.clash_bot_respawn_delay = null
				note = "reset the bot respawn delay to each spawner's own"
			else
				value = clamp(round(value), 0, CLASH_BOT_PANEL_MAX_RESPAWN)
				GLOB.clash_bot_respawn_delay = value SECONDS
				note = "set the bot respawn delay to [value] seconds"
		if("spawn", "spawn_here")
			var/count = text2num(params["count"])
			if(!faction || isnull(count))
				return
			count = clamp(round(count), 1, CLASH_BOT_PANEL_MAX_SPAWN)
			if(!GLOB.clash_bots_enabled || (faction in GLOB.clash_bot_sides_off))
				to_chat(user, SPAN_WARNING("[faction] bots can't spawn while bots are paused or that side's spawning is off."))
				return
			var/spawned
			if(action == "spawn")
				spawned = clash_bot_spawn_side(faction, count)
			else
				var/turf/spot = get_turf(user)
				if(!spot || spot.density)
					to_chat(user, SPAN_WARNING("Stand on an open tile to spawn bots there."))
					return
				spawned = clash_bot_spawn_at(faction, count, spot)
			if(!spawned)
				to_chat(user, SPAN_WARNING("No [faction] bot spawned. The side is at its cap[action == "spawn" ? " or every spawner already has a bot" : ""]."))
				return
			note = "spawned [spawned] [faction] bot\s [action == "spawn" ? "at their spawners" : "at [AREACOORD(user)]"]"
		if("clear")
			note = "cleared [clash_bot_clear(faction)] [faction || "HvH"] bot\s"
		if("jump", "remove")
			var/datum/clash_bot/bot = locate(params["ref"]) in GLOB.clash_bots
			if(QDELETED(bot?.body))
				return
			if(action == "jump")
				var/client/admin = user.client
				if(!isobserver(admin.mob))
					admin.admin_ghost()
				admin.mob.forceMove(get_turf(bot.body))
				return TRUE
			note = "removed the bot [bot.body.real_name]"
			bot.retire()
		else
			return
	message_admins("[key_name_admin(user)] [note].")
	log_admin("[key_name(user)] [note].")
	return TRUE

#undef CLASH_BOT_PANEL_MAX_TEAM
#undef CLASH_BOT_PANEL_MAX_SPAWN
#undef CLASH_BOT_PANEL_MAX_RESPAWN

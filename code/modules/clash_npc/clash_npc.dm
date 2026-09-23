/// Most bots one faction may have alive at once
#define CLASH_BOT_TEAM_CAP 10
/// Team fill tops each side up to this many fighters, counting players and bots
#define CLASH_BOT_TEAM_SIZE 10
/// Deciseconds between team fill checks
#define CLASH_BOT_FILL_INTERVAL (10 SECONDS)
/// Deciseconds a dead bot's body stays before it is cleared away
#define CLASH_BOT_CORPSE_TIME (90 SECONDS)

GLOBAL_LIST_EMPTY(clash_npc_spawners)
GLOBAL_LIST_EMPTY(clash_bot_rallies)
GLOBAL_VAR(clash_bot_fill_timer)

/obj/effect/landmark/clash_bot_rally
	name = "Clash bot rally point"
	var/rally_id = "center"

/obj/effect/landmark/clash_bot_rally/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_bot_rallies += src

/obj/effect/landmark/clash_bot_rally/Destroy()
	GLOB.clash_bot_rallies -= src
	return ..()

/obj/effect/landmark/clash_npc
	name = "Clash NPC spawner"
	icon_state = "late_join_misc"
	var/faction = FACTION_MARINE
	var/equipment_preset
	var/bot_gun
	var/bot_magazine
	var/bot_magazines = 4
	var/bot_firemode
	var/bot_medical = /obj/item/storage/pouch/firstaid/full
	/// Deciseconds before a replacement is sent out, 0 to never respawn
	var/respawn_delay = 30 SECONDS
	/// Tiles the bot will stray from its hold point to take cover
	var/hold_radius = 6
	/// Bots from this spawner walk out and hold at a rally point with this id instead of the spawner
	var/rally_id
	/// Only sends a bot while this side is short of players
	var/team_fill = FALSE
	var/active = TRUE
	var/datum/clash_bot/bot

/obj/effect/landmark/clash_npc/Initialize(mapload, ...)
	. = ..()
	GLOB.clash_npc_spawners += src
	if(team_fill)
		active = FALSE
	RegisterSignal(SSdcs, COMSIG_GLOB_POST_SETUP, PROC_REF(on_post_setup))

/obj/effect/landmark/clash_npc/Destroy()
	GLOB.clash_npc_spawners -= src
	QDEL_NULL(bot)
	return ..()

/obj/effect/landmark/clash_npc/proc/on_post_setup()
	SIGNAL_HANDLER
	if(team_fill && !GLOB.clash_bot_fill_timer)
		GLOB.clash_bot_fill_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_bot_fill)), CLASH_BOT_FILL_INTERVAL, TIMER_LOOP|TIMER_STOPPABLE)
	if(active)
		INVOKE_ASYNC(src, PROC_REF(spawn_npc))

/obj/effect/landmark/clash_npc/proc/get_hold_turf()
	if(!rally_id)
		return get_turf(src)
	var/list/rallies = list()
	for(var/obj/effect/landmark/clash_bot_rally/rally as anything in GLOB.clash_bot_rallies)
		if(rally.rally_id == rally_id && rally.z == z)
			rallies += rally
	return length(rallies) ? get_turf(pick(rallies)) : get_turf(src)

/obj/effect/landmark/clash_npc/proc/spawn_npc()
	if(bot || !active)
		return
	if(!GLOB.clash_bots_enabled || clash_bot_count(faction) >= CLASH_BOT_TEAM_CAP)
		addtimer(CALLBACK(src, PROC_REF(spawn_npc)), respawn_delay || 30 SECONDS)
		return
	var/mob/living/carbon/human/npc = new(get_turf(src))
	arm_equipment(npc, equipment_preset, TRUE, FALSE)
	npc.statistic_exempt = TRUE
	npc.setDir(dir)
	npc.real_name = "[npc.real_name] \[BOT\]"
	npc.name = npc.real_name
	for(var/obj/item/unwanted in npc.get_contents())
		if(istype(unwanted, /obj/item/weapon/gun) || istype(unwanted, /obj/item/ammo_magazine/handful))
			qdel(unwanted)
	npc.put_in_hands(new bot_gun(npc), FALSE)
	for(var/count in 1 to bot_magazines)
		npc.equip_to_appropriate_slot(new bot_magazine(npc))
	if(bot_medical && !(locate(/obj/item/reagent_container/hypospray/autoinjector) in npc.get_contents()))
		npc.equip_to_appropriate_slot(new bot_medical(npc))
	bot = new(npc, src)

/obj/effect/landmark/clash_npc/proc/bot_died(mob/living/carbon/human/body)
	bot = null
	if(body)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clear_clash_bot_corpse), WEAKREF(body)), CLASH_BOT_CORPSE_TIME)
	if(respawn_delay && active)
		addtimer(CALLBACK(src, PROC_REF(spawn_npc)), respawn_delay)

/proc/clear_clash_bot_corpse(datum/weakref/body_ref)
	var/mob/living/carbon/human/body = body_ref?.resolve()
	if(body && !body.client && body.stat == DEAD)
		qdel(body)

/proc/clash_bot_count(faction)
	. = 0
	for(var/datum/clash_bot/bot as anything in GLOB.clash_bots)
		if(bot.body?.faction == faction)
			.++

/proc/clash_player_count(faction)
	. = 0
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/fighter = player.mob
		if(!ishuman(fighter))
			fighter = player.mob?.mind?.original
		if(ishuman(fighter) && fighter.faction == faction)
			.++

/// Sends fill bots to whichever side has fewer players, and stops replacing them as players arrive
/proc/clash_bot_fill()
	var/list/wanted = list()
	wanted[FACTION_MARINE] = CLASH_BOT_TEAM_SIZE - clash_player_count(FACTION_MARINE)
	wanted[FACTION_UPP] = CLASH_BOT_TEAM_SIZE - clash_player_count(FACTION_UPP)
	for(var/obj/effect/landmark/clash_npc/spawner as anything in GLOB.clash_npc_spawners)
		if(!spawner.team_fill)
			continue
		var/still_wanted = wanted[spawner.faction]
		wanted[spawner.faction] = still_wanted - 1
		var/should_fill = still_wanted > 0
		if(should_fill == spawner.active)
			continue
		spawner.active = should_fill
		if(should_fill)
			INVOKE_ASYNC(spawner, TYPE_PROC_REF(/obj/effect/landmark/clash_npc, spawn_npc))

/obj/effect/landmark/clash_npc/uscm
	name = "Clash NPC spawner (USCM Rifleman)"
	faction = FACTION_MARINE
	equipment_preset = /datum/equipment_preset/uscm/private_equipped
	bot_gun = /obj/item/weapon/gun/rifle/m41a
	bot_magazine = /obj/item/ammo_magazine/rifle

/obj/effect/landmark/clash_npc/uscm/fill
	name = "Clash NPC team fill spawner (USCM Rifleman)"
	team_fill = TRUE

/obj/effect/landmark/clash_npc/upp
	name = "Clash NPC spawner (UPP Soldier)"
	faction = FACTION_UPP
	equipment_preset = /datum/equipment_preset/upp/soldier/dressed
	bot_gun = /obj/item/weapon/gun/rifle/type71
	bot_magazine = /obj/item/ammo_magazine/rifle/type71
	bot_firemode = GUN_FIREMODE_BURSTFIRE

/obj/effect/landmark/clash_npc/upp/fill
	name = "Clash NPC team fill spawner (UPP Soldier)"
	team_fill = TRUE

/obj/effect/landmark/clash_npc/clf
	name = "Clash NPC spawner (CLF Soldier)"
	faction = FACTION_CLF
	equipment_preset = /datum/equipment_preset/clf/soldier
	bot_gun = /obj/item/weapon/gun/rifle/ak4047
	bot_magazine = /obj/item/ammo_magazine/rifle/ak4047

#undef CLASH_BOT_TEAM_CAP
#undef CLASH_BOT_TEAM_SIZE
#undef CLASH_BOT_FILL_INTERVAL
#undef CLASH_BOT_CORPSE_TIME

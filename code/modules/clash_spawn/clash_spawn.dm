GLOBAL_LIST_EMPTY(clash_welcomed)
GLOBAL_VAR_INIT(clash_feedback_contact, "")
GLOBAL_VAR_INIT(clash_discord_link, "https://discord.gg/XyTBFQRKRk")

GLOBAL_LIST_INIT(clash_arena_removed_items, list(/obj/item/storage/box/mre, /obj/item/ammo_box/magazine/misc/mre, /obj/item/storage/box/attachments))

/proc/clash_fed_spawns()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.fed_spawns

/proc/clash_is_arena_removed(item_type)
	for(var/removed_type in GLOB.clash_arena_removed_items)
		if(ispath(item_type, removed_type))
			return TRUE
	return FALSE

/proc/clash_remove_arena_items(mob/living/carbon/human/wearer)
	for(var/obj/item/carried in wearer.get_contents())
		if(clash_is_arena_removed(carried.type))
			qdel(carried)

/proc/clash_keep_fed()
	for(var/mob/living/carbon/human/fighter as anything in GLOB.alive_human_list)
		if(fighter.nutrition < NUTRITION_NORMAL)
			fighter.nutrition = NUTRITION_NORMAL

/proc/clash_welcome_path(ckey)
	return clash_player_save_path(ckey, "clash_welcome.sav")

SUBSYSTEM_DEF(clash_spawn)
	name = "Clash Spawn"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_spawn/Initialize()
	GLOB.join_motd = file2text("strings/hvh_motd.txt")
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(on_mob_logged_in))
	RegisterSignal(SSdcs, COMSIG_GLOB_MODE_PREGAME_LOBBY, PROC_REF(fill_missing_spawns))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_spawn/proc/fill_missing_spawns()
	SIGNAL_HANDLER
	var/list/uscm_base = list()
	for(var/squad in list(SQUAD_MARINE_1, SQUAD_MARINE_2, SQUAD_MARINE_3, SQUAD_MARINE_4))
		if(length(GLOB.latejoin_by_squad[squad]))
			uscm_base |= GLOB.latejoin_by_squad[squad]
	var/list/bases = list(FACTION_MARINE = uscm_base, FACTION_UPP = GLOB.latejoin_by_job[JOB_UPP])
	if(length(uscm_base) && !length(GLOB.latejoin_by_squad[SQUAD_MARINE_CRYO]))
		GLOB.latejoin_by_squad[SQUAD_MARINE_CRYO] = uscm_base.Copy()
	for(var/title in clash_role_list())
		var/datum/job/role = GLOB.RoleAuthority.roles_by_name[title]
		if(!role || (role.flags_startup_parameters & ROLE_ADD_TO_SQUAD))
			continue
		var/list/base = bases[clash_kit_faction_for_job(title)]
		if(!length(base))
			continue
		if(!length(GLOB.latejoin_by_job[title]))
			GLOB.latejoin_by_job[title] = base.Copy()
			log_game("HvH: [title] has no late join spawn on this map, using its side's base.")
		if(!length(GLOB.spawns_by_job[role.type]) && !length(GLOB.spawns_by_job[title]))
			GLOB.spawns_by_job[title] = base.Copy()
			log_game("HvH: [title] has no round start spawn on this map, using its side's base.")

/datum/controller/subsystem/clash_spawn/proc/on_mob_logged_in(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(ishuman(new_mob) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		RegisterSignal(new_mob, COMSIG_POST_SPAWN_UPDATE, PROC_REF(on_spawned), override = TRUE)
	clash_refresh_all_ammo_bars()

/datum/controller/subsystem/clash_spawn/proc/on_spawned(mob/living/carbon/human/spawned)
	SIGNAL_HANDLER
	UnregisterSignal(spawned, COMSIG_POST_SPAWN_UPDATE)
	if(spawned.mind)
		spawned.mind.clash_job = spawned.job
	spawned.add_language(LANGUAGE_ENGLISH)
	spawned.add_language(LANGUAGE_RUSSIAN)
	if(clash_fed_spawns())
		spawned.nutrition = NUTRITION_NORMAL
	if(spawned.faction == FACTION_UPP && !(spawned.job in list(JOB_UPP_MEDIC, JOB_UPP_LT_DOKTOR)))
		spawned.skills?.set_skill(SKILL_MEDICAL, SKILL_MEDICAL_DEFAULT)
	if(clash_uses_kits())
		clash_set_vendor_points(spawned, spawned.ckey, spawned.job)
		spawned.vendor_buyable_categories[CLASH_CAN_BUY_FLASHLIGHT] = 1
		spawned.vendor_buyable_categories[CLASH_CAN_BUY_FLARES] = 1
	spawned.clash_spawn_points = list(spawned.vendor_points, spawned.vendor_snowflake_points)
	clash_progress_join(spawned)
	clash_refresh_all_ammo_bars()
	if(istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh) && spawned.faction == FACTION_MARINE && spawned.assigned_squad && !(spawned.assigned_squad.name in list(SQUAD_MARINE_1, SQUAD_MARINE_2)))
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(clash_move_to_arena_squad), spawned)
	spawned.AddElement(/datum/element/clash_iff)
	if(istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		spawned.AddElement(/datum/element/clash_move_carry)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		var/turf/side_spawn = clash_mode.get_side_spawn_turf(spawned.faction)
		if(side_spawn)
			spawned.forceMove(side_spawn)
		clash_mode.on_fighter_spawned(spawned)
		if(clash_mode.spawn_protection)
			spawned.AddComponent(/datum/component/clash_spawn_guard, clash_mode.spawn_protection)
	if(clash_uses_kits())
		issue_clash_role_kit(spawned, spawned.job)
		var/datum/clash_kit/kit = get_clash_active_kit(spawned.ckey, spawned.job)
		if(kit)
			apply_clash_kit(spawned, kit)
			to_chat(spawned, SPAN_NOTICE("Kitted out as [kit.name]. [clash_perk_spawn_text(spawned)]Use the Loadout verb to change it for your next spawn."))
			for(var/slot in spawned.clash_kit_notes)
				to_chat(spawned, SPAN_NOTICE(spawned.clash_kit_notes[slot]))
	else
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_equip_spawn_loadout), spawned), 1 SECONDS)
	var/ckey = spawned.ckey
	if(!ckey || (ckey in GLOB.clash_welcomed))
		return
	GLOB.clash_welcomed += ckey
	if(!fexists(clash_welcome_path(ckey)))
		INVOKE_ASYNC(src, PROC_REF(show_welcome), spawned)

/mob/living/carbon/human/var/list/clash_spawn_points
/datum/mind/var/clash_job

/proc/get_clash_home_turf(mob/living/carbon/human/fighter)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	var/turf/side_spawn = istype(clash_mode) && clash_mode.get_side_spawn_turf(fighter.faction)
	if(side_spawn)
		return side_spawn
	var/datum/job/job = GLOB.RoleAuthority.roles_by_name[fighter.job]
	var/squad = fighter.assigned_squad?.name
	var/list/candidates
	if(job && squad && GLOB.spawns_by_squad_and_job[squad])
		candidates = GLOB.spawns_by_squad_and_job[squad][job.type]
	if(!length(candidates) && job)
		candidates = GLOB.spawns_by_job[job.type] || GLOB.spawns_by_job[job.title]
	if(!length(candidates) && squad)
		candidates = GLOB.latejoin_by_squad[squad]
	if(!length(candidates) && job)
		candidates = GLOB.latejoin_by_job[job.title]
	if(!length(candidates))
		candidates = GLOB.latejoin
	return length(candidates) ? get_turf(pick(candidates)) : null

/datum/controller/subsystem/clash_spawn/proc/show_welcome(mob/viewer)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	var/list/page = list()
	page += "<style>"
	page += "body{background:repeating-linear-gradient(0deg,#141715 0 1px,#111412 1px 4px);color:#e4e8de;font-family:Bahnschrift,'Segoe UI',sans-serif;font-size:13px;margin:0}"
	page += ".head{padding:20px 18px 14px;background:#171b18 repeating-linear-gradient(-55deg,#2e2919 0 10px,transparent 10px 28px) no-repeat;background-size:100% 7px;border-bottom:4px solid #ffb840}"
	page += ".head h1{margin:0;font-size:26px;font-weight:bold;text-transform:uppercase;color:#e4e8de}"
	page += ".head .sub{color:#848e80;font-size:12px;font-weight:600;margin-top:4px}"
	page += ".body{padding:4px 18px 14px}"
	page += "h2{font-size:14px;font-weight:bold;letter-spacing:.5px;color:#ffb840;text-transform:uppercase;margin:16px 0 7px;border-bottom:1px solid #384137;padding-bottom:4px}"
	page += "ul{margin:0;padding-left:16px}li{margin:4px 0;line-height:1.35}li::marker{color:#848e80}b{color:#ffb840;font-weight:bold}"
	page += ".keys td{padding:3px 8px 3px 0;vertical-align:top}"
	page += ".key{display:inline-block;min-width:58px;text-align:center;border:1px solid #384137;border-radius:4px;background:#1c211d;color:#e4e8de;font-size:12px;font-weight:bold;text-transform:uppercase;padding:2px 6px}"
	page += ".foot{display:flex;justify-content:space-between;align-items:center;padding:12px 18px;border-top:1px solid #384137;background:#171b18;color:#848e80;font-weight:600}"
	page += "button{background:#ffb840;color:#1e180a;border:0;border-radius:4px;padding:7px 22px;font-family:inherit;font-size:14px;font-weight:bold;letter-spacing:.5px;cursor:pointer}"
	page += "button:hover{box-shadow:0 0 14px rgba(255,184,64,.45)}input.contact{width:100%;background:#1c211d;color:#e4e8de;border:1px solid #384137;padding:3px}"
	page += ".tagline{margin:0 0 6px;color:#e4e8de;font-size:15px;font-weight:bold;text-transform:uppercase}"
	page += ".discord{margin-top:8px;color:#848e80;font-weight:600}.discord a{color:#ffb840;font-weight:bold;text-decoration:none}"
	page += "</style>"
	page += "<div class='head'><h1>Welcome to the Firefight13 playtest</h1>"
	page += "<div class='discord'>Join us on Discord: <a href='byond://?src=[REF(src)];clash_discord=1'>[GLOB.clash_discord_link]</a></div>"
	page += "<div class='sub'>Tell us what you think.</div></div>"
	page += "<div class='body'>"
	if(istype(clash_mode))
		page += "<h2>[clash_mode.name]</h2>"
		var/tagline = clash_mode.get_welcome_tagline()
		if(tagline)
			page += "<p class='tagline'>[tagline]</p>"
		page += "<ul>"
		for(var/line in clash_mode.get_welcome_rules())
			page += "<li>[line]</li>"
		page += "</ul>"
	page += "<h2>Overview</h2><ul>"
	page += "<li>USCM vs UPP. PvP TDM server.</li>"
	page += "<li>Bots fill empty slots and wear a grey \[BOT\] tag.</li>"
	page += "<li>Start as Rifleman.</li>"
	page += "<li>Hospital Corpsman unlocks at USCM and UPP level 3</li>"
	page += "<li>Combat Technician at 5</li>"
	page += "<li>Machine Gunner at 7</li>"
	page += "<li>Squad Leader at 11</li>"
	page += "</ul>"
	page += "<h2>Loadout</h2><ul>"
	page += "<li>Select your gear in the Loadout screen</li>"
	page += "</ul>"
	page += "<h2>Health</h2><ul>"
	page += "<li>Your injuries show top right. You can treat everything yourself except organ damage, which needs a medic's Fix-all Injector.</li>"
	page += "<li>Healing Injectors: Heal damage and stabilize organs.</li>"
	page += "<li>Field Dressings: stop bleeding.</li>"
	page += "<li>Splints: hold broken bones.</li>"
	page += "<li>Downed: press Call Medic and wait, or Give Up. Dead: press Deploy after 15 to 30 seconds.</li>"
	page += "<li>Death card shows who killed you, with what, and their perks.</li>"
	page += "<li>Friendly fire is on. Explosions often tear off limbs.</li>"
	page += "</ul>"
	page += "<h2>HUD</h2><ul>"
	page += "<li>Tab opens the scoreboard.</li>"
	page += "<li>The radar (top left) shows teammates, your Squad Leader, friendly sentries and ammo crates, and enemies who give themselves away.</li>"
	page += "<li>Markers over players: chevron = bot, diamond = player. Icons show bleeding, breaks, splints and suppression.</li>"
	page += "<li>Chat: T talks to people nearby, U to your team, Y to everyone. The radar and chat can be minimized.</li>"
	page += "</ul>"
	page += "<h2>Leveling</h2><ul>"
	page += "<li>XP: kill 100, assist 50, revive 100, match win 500, round win 1000, plus objectives.</li>"
	page += "<li>Faction level unlocks roles and general perks. Class level unlocks armor, grenades, guns and class perks.</li>"
	page += "<li>Pick one class perk and one general perk in your loadout.</li>"
	page += "<li>Firing without a suppressor, or firing a flamer or underbarrel weapon, puts you on the radar of enemies with the Keen Ears perk.</li>"
	page += "</ul>"
	page += "<h2>Playtest</h2><ul>"
	page += "<li>This is a playtest. Everything can change. Levels and unlocks will be reset as systems are reworked.</li>"
	page += "</ul>"
	if(GLOB.clash_feedback_contact)
		page += "<h2>Feedback</h2><input class='contact' type='text' readonly value='[GLOB.clash_feedback_contact]' onclick='this.select()'>"
	page += "</div>"
	page += "<div class='foot'><label><input type='checkbox' id='hide'> Do not show again</label>"
	page += "<button onclick=\"location.href='byond://?src=[REF(src)];clash_welcome=1;hide=' + (document.getElementById('hide').checked ? 1 : 0)\">GOT IT</button></div>"
	show_browser(viewer, page.Join(), "Welcome to Firefight13", "clash_welcome", width = 500, height = 560)

/datum/controller/subsystem/statpanels/set_status_tab(client/target)
	var/discord = "Discord: [GLOB.clash_discord_link]"
	if(global_data && !(discord in global_data))
		global_data.Insert(1, discord)
	return ..()

/datum/controller/subsystem/clash_spawn/Topic(href, list/href_list)
	if(href_list["clash_discord"] && usr?.client)
		usr << link(GLOB.clash_discord_link)
		return
	if(!href_list["clash_welcome"] || !usr?.client)
		return
	close_browser(usr, "clash_welcome")
	if(href_list["hide"] == "1" && usr.ckey)
		var/savefile/save = new(clash_welcome_path(usr.ckey))
		save["hide"] << TRUE

/proc/clash_move_to_arena_squad(mob/living/carbon/human/fighter)
	var/datum/squad/target
	for(var/squad_name in list(SQUAD_MARINE_1, SQUAD_MARINE_2))
		var/datum/squad/squad = get_squad_by_name(squad_name)
		if(squad && (!target || length(squad.marines_list) < length(target.marines_list)))
			target = squad
	if(!target || QDELETED(fighter))
		return
	fighter.assigned_squad.remove_marine_from_squad(fighter)
	target.put_marine_in_squad(fighter)

/datum/job/announce_entry_message(mob/living/carbon/human/new_human, datum/money_account/account, whitelist_status)
	set waitfor = FALSE
	if(!clash_uses_kits())
		return ..()
	sleep(1 SECONDS)
	if(!new_human?.loc || !new_human.client)
		return
	var/role_name = clash_role_name(title)
	var/list/lines = list(
		SPAN_ROLE_BODY("|______________________|"),
		SPAN_ROLE_HEADER("You are \a [lowertext(role_name)]"),
		SPAN_ROLE_BODY("You are the [role_name]."),
	)
	var/brief_key = "[new_human.ckey]|[title]"
	if(clash_fast_medicine() && !(brief_key in GLOB.clash_class_briefed))
		GLOB.clash_class_briefed += brief_key
		for(var/line in clash_class_brief(GLOB.clash_job_classes[title]))
			lines += SPAN_ROLE_BODY(line)
	lines += SPAN_ROLE_BODY("|______________________|")
	to_chat_spaced(new_human, html = boxed_message(lines.Join(" \n")))

GLOBAL_LIST_EMPTY(clash_class_briefed)

/proc/clash_class_brief(class)
	switch(class)
		if(CLASH_CLASS_MEDIC)
			return list(
				"Your job is to heal and revive your teammates.",
				"Revive: Hold defibrillator, use it in hand (\"Z\" by default) to take out paddles, click on dead teammate to revive. No need to remove their armor. Reviving restores blood, heals organs, and stops bleeding, and heals them to 50 health, then 35, then 20 if revived again within 60 seconds. Does not fix broken bones.",
				"Healing: Use a Field Dressing, Advanced Healing Kit, Splint, or Injectors to heal a teammate. Healing treats the worst injury first with no need to aim at body parts.",
				"Field Dressing: Stops bleeding, heals 10 on one body part. Instant for you.",
				"Advanced Healing Kit: Stops bleeding, heals 20 on one body part. Instant for you.",
				"Splint: Treats broken bones. 1 second for you.",
				"Healing Injector: 2 doses. Heals wounds and burns over time and gives Stabilized for 15 seconds: organs and blood loss paused, no suffocation. Reinjecting resets the timer.",
				"Oxycodone/Tramadol Injectors: Painkillers. Pain slows you and makes you drop things. Oxycodone is the strong one.",
				"Fix-All Injector: 1 dose. Restores blood, heals organs, eyes and brain, clears oxygen and toxin damage. Does not fix bones or bleeding.",
				"Internal injuries: Use your Fix-all injector. Teammates who need an injection have a pink heart over them.",
				"Call Medic: Teammates who press \"Call Medic\" or cry for a *medic get a red cross and show up on your radar. Revive them.",
				"XP gain: Objectives, killing, healing, splints, revives and Fix-all all give XP.",
			)
		if(CLASH_CLASS_ENGINEER)
			return list(
				"Your job is to construct defenses, replenish ammo, and take down enemy defenses.",
				"Sentry: Use it in hand to place it in front of you.",
				"Machine Gun: Use it in hand to set it up where you stand. Any teammate can man it. The M56D is accurate and its bullets pass through teammates. The T37 hits harder but overheats and hits teammates.",
				"Sentry Gun (CT level 4): covers 6 tiles the way it faces, 250 health, 200 rounds.",
				"Flamer Sentry (CT level 8): burns 4 tiles the way it faces, 20 shots.",
				"Repair: Click the sentry or machine gun with a welder.",
				"Reload: Click the sentry or machine gun with metal, 10 sheets for a full load. Flamer Sentry takes a flamer fuel tank instead.",
				"Turn or pack up: Click the sentry with a wrench. Drag a machine gun onto yourself to pack it up.",
				"New sentry: One sentry or machine gun out at a time unless you have the Twin Sentries perk (CT level 18). When it is destroyed, weld its wreck back up with 10 metal, or a new one arrives in your backpack after 45 seconds. The Tool Storage Machine in your base also has them.",
				"Ammo Crate: You spawn with one. Use it in hand to place it. Teammates click it with their gun or an empty hand for a magazine. Holds 10, refills 1 every 15 seconds. One out at a time, new one from the Tool Storage Machine when destroyed.",
				"Barricades: Only engineers build them. Metal and plasteel from your pouch.",
				"Sentries cannot see through smoke. Grenades wreck them.",
				"XP gain: Objectives, killing, repairs, resupplies from your crate and damage your barricades soak all give XP.",
			)
		if(CLASH_CLASS_HEAVY)
			return list(
				"Your job is to suppress the enemy by raining down bullets on them.",
				"Suppression: Your bullets suppress. A hit adds 20 suppression points, a bullet passing within 1.5 tiles of the target adds 10. Up to 100 suppression. Starts fading 1.5 seconds after you stop firing.",
				"Suppression effect on enemies: Screen darkens, they cower and move up to 25% slower. Past 50 a Suppressed icon (red chevron) shows on them.",
				"Bipod: Deploy it on the ground to hold fire with less recoil and scatter.",
				"Guns: Smartgun (USCM) and minigun (UPP) unlock at Machine Gunner level 8.",
				"XP gain: Objectives, killing and suppression give XP, plus a suppression assist when a teammate kills someone you suppressed.",
			)
		if(CLASH_CLASS_LEADER)
			return list(
				"Your job is to issue orders to your team to buff them.",
				"Orders: Issue Order verb, or the button on your HUD. Reach 7 tiles around you, last 25 seconds (30 for the UPP), one order every 80 seconds.",
				"Move Order: Your team runs faster and dodges more bullets. Use it to cross open ground or push a position.",
				"Hold Order: Your team takes less wound damage and shrugs off pain. Use it when you are dug in and getting hammered.",
				"Focus Order: Your team shoots tighter and further. Use it when you have the firing line and they are coming to you.",
				"Stay with your team. Orders only reach who is near you and your assist XP only counts kills within 7 tiles.",
				"Perks: Wide Orders (level 4, 10 tiles), Long Orders (level 7, last 50% longer), Quick Orders (level 10, ready after 50 seconds).",
				"XP gain: Objectives and killing give XP, plus an assist for every kill by a teammate within 7 tiles.",
			)
		if(CLASH_CLASS_RIFLEMAN)
			return list(
				"Your job is to kill.",
				"Gear: Pick your gear in the Loadout window. Pouches, belts, webbing, masks and packs are all free. Guns, grenades and armor unlock as you level up. Use the Loadout Shop to spend points on extra gear.",
				"Armor: Light armor is fast, heavy armor is slow but shrugs off blasts.",
				"Grenades: Blasts easily tear off limbs. Cook them with care, friendly fire is on.",
				"Ammo: Out? Get more from your base vendor or a friendly Combat Technician's ammo crate.",
				"Healing: Use a Healing Injector to heal yourself, use a Field Dressing to stop bleeding and heal for a small amount, use a Splint to treat a broken bone. All healing automatically treats the worst wound first. Injuries appear top-right of your screen.",
				"Call Medic: Type *medic to call for a medic. Down? Press \"Call Medic\" and wait to be revived, medics see you on the radar, or just respawn.",
				"Perks: Pick one class perk and one general perk in the Loadout window.",
				"Other classes unlock with faction level: Medic 3, Engineer 5, Machine Gunner 7, Squad Leader 11.",
				"XP gain: Objectives, kills and assists give XP.",
			)
	return list()

GLOBAL_LIST_EMPTY(clash_welcomed)
GLOBAL_VAR_INIT(clash_feedback_contact, "")

GLOBAL_LIST_INIT(clash_arena_rations, list(/obj/item/storage/box/mre, /obj/item/ammo_box/magazine/misc/mre))

/proc/clash_fed_spawns()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.fed_spawns

/proc/clash_is_ration(item_type)
	for(var/ration_type in GLOB.clash_arena_rations)
		if(ispath(item_type, ration_type))
			return TRUE
	return FALSE

/proc/clash_remove_rations(mob/living/carbon/human/wearer)
	for(var/obj/item/carried in wearer.get_contents())
		if(clash_is_ration(carried.type))
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
		clash_raise_vendor_points(spawned, spawned.ckey, spawned.job)
	spawned.clash_spawn_points = list(spawned.vendor_points, spawned.vendor_snowflake_points)
	clash_progress_join(spawned)
	if(istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh) && spawned.faction == FACTION_MARINE && spawned.assigned_squad && !(spawned.assigned_squad.name in list(SQUAD_MARINE_1, SQUAD_MARINE_2)))
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(clash_move_to_arena_squad), spawned)
	spawned.AddElement(/datum/element/clash_iff)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode) && clash_mode.spawn_protection)
		spawned.AddComponent(/datum/component/clash_spawn_guard, clash_mode.spawn_protection)
	if(clash_uses_kits())
		issue_clash_role_kit(spawned, spawned.job)
		var/datum/clash_kit/kit = get_clash_active_kit(spawned.ckey, spawned.job)
		if(kit)
			apply_clash_kit(spawned, kit)
			to_chat(spawned, SPAN_NOTICE("Kitted out as [kit.name]. [clash_perk_spawn_text(spawned)]Use the Loadout verb to change it for your next spawn."))
		clash_issue_medic_gear(spawned)
		clash_issue_engineer_gear(spawned)
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
	var/kits = clash_uses_kits()
	var/list/page = list()
	page += "<style>"
	page += "body{background:#0e1115;color:#d6dbe0;font-family:Verdana,sans-serif;font-size:12px;margin:0}"
	page += ".head{padding:14px 16px 10px;background:linear-gradient(90deg,rgba(90,143,230,.25),rgba(230,25,25,.25));border-bottom:2px solid #2a3038}"
	page += ".head h1{margin:0;font-size:18px;letter-spacing:2px;color:#fff}"
	page += ".head .sub{color:#9aa3ab;font-size:11px;margin-top:3px}"
	page += ".body{padding:6px 16px 12px}"
	page += "h2{font-size:11px;letter-spacing:2px;color:#ffcf4d;text-transform:uppercase;margin:12px 0 6px;border-bottom:1px solid #2a3038;padding-bottom:3px}"
	page += "ul{margin:0;padding-left:16px}li{margin:3px 0;line-height:1.35}"
	page += ".keys td{padding:3px 8px 3px 0;vertical-align:top}"
	page += ".key{display:inline-block;min-width:52px;text-align:center;border:1px solid #4a525c;border-radius:3px;background:#1a1f25;color:#fff;font-size:11px;padding:1px 6px}"
	page += ".foot{display:flex;justify-content:space-between;align-items:center;padding:10px 16px;border-top:1px solid #2a3038;background:#12161b}"
	page += "button{background:#2d5a9e;color:#fff;border:0;padding:6px 18px;font-weight:bold;letter-spacing:1px;cursor:pointer}"
	page += "button:hover{background:#3a6fc0}input.contact{width:100%;background:#1a1f25;color:#fff;border:1px solid #4a525c;padding:3px}"
	page += ".tagline{margin:0 0 6px;color:#fff;font-weight:bold;letter-spacing:1px}"
	page += "</style>"
	page += "<div class='head'><h1>Welcome to Firefight13.</h1><div class='sub'>\[The server is actively being playtested and updated. Everything is subject to change without notice.\]</div></div>"
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
	page += "<h2>Controls/Verbs</h2><table class='keys'>"
	page += "<tr><td><span class='key'>Tab</span></td><td>Show/hide the scoreboard.</td></tr>"
	if(kits)
		page += "<tr><td><span class='key'>Loadout</span></td><td>Build custom kits. The selected kit is on you every time you spawn as that role. Open it from the lobby, the Deploy button when you are down, or the Loadout verb.</td></tr>"
	else
		page += "<tr><td><span class='key'>Respawn</span></td><td>The button in the middle of the screen when you are down.</td></tr>"
		page += "<tr><td><span class='key'>Vendors</span></td><td>Save your loadout with Save current in the Saved Loadouts section, 3 slots per role.</td></tr>"
	page += "<tr><td><span class='key'>Stats</span></td><td>The Career Stats verb, or the button on the scoreboard, shows your career and the leaderboard.</td></tr>"
	page += "</table>"
	if(clash_fast_medicine())
		page += "<h2>Medical</h2><ul>"
		page += "<li>Click a teammate or yourself with a dressing, kit or splint. It treats the worst injury, no need to aim at body parts.</li>"
		page += "<li>Hurt? Shout <b>*medic</b>. Down but revivable? Press <b>Call Medic</b>. A red cross shows over you for your team.</li>"
		page += "<li>Medics revive teammates with a quick defibrillator zap.</li>"
		page += "</ul>"
		page += "<h2>Engineering</h2><ul>"
		page += "<li>Engineers carry a sentry and an ammo crate. Use either in hand to set it down in front of you. Once one is destroyed, the engineer vendor in your base gives you a new one.</li>"
		page += "<li>Out of ammo? Click a friendly ammo crate with your gun or an empty hand to take a magazine for that gun.</li>"
		page += "<li>On a sentry, a wrench packs it up, a welder repairs it, metal reloads it and a flamer fuel tank refuels the Flamer Sentry. Stronger sentries unlock with Engineer level.</li>"
		page += "<li>Sentries cannot see through smoke and grenades wreck them. Only engineers can build barricades.</li>"
		page += "</ul>"
		page += "<h2>Perks</h2><ul>"
		page += "<li>Pick one class perk and one general perk in your loadout. Class perks unlock with class level, general perks with faction level. Your killer's perks show on your death card.</li>"
		page += "<li>Firing without a suppressor, or firing a flamer or underbarrel weapon, shows you as a red mark on the radar of enemies with the Keen Ears perk.</li>"
		page += "</ul>"
	page += "<h2>Other notes</h2><ul>"
	page += "<li>Friendly fire is on and explosions have a high chance of taking off limbs.</li>"
	page += "<li>Two end-of-round votes: one for the next mode and then one for the map that can run it.</li>"
	page += "<li>Only rounds that finish on their own count toward career stats.</li>"
	page += "</ul>"
	page += "<h2>Playtest notes</h2><ul>"
	page += "<li>This is a playtest, <i>everything</i> is subject to change and accrued player unlocks, levels, and ranks will be changed and reset eventually because mechanics are being worked and reworked.</li>"
	page += "</ul>"
	if(GLOB.clash_feedback_contact)
		page += "<h2>Feedback</h2><input class='contact' type='text' readonly value='[GLOB.clash_feedback_contact]' onclick='this.select()'>"
	page += "</div>"
	page += "<div class='foot'><label><input type='checkbox' id='hide'> Do not show again</label>"
	page += "<button onclick=\"location.href='byond://?src=[REF(src)];clash_welcome=1;hide=' + (document.getElementById('hide').checked ? 1 : 0)\">GOT IT</button></div>"
	show_browser(viewer, page.Join(), "Welcome to Firefight13", "clash_welcome", width = 500, height = 560)

/datum/controller/subsystem/clash_spawn/Topic(href, list/href_list)
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

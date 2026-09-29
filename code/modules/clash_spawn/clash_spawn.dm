GLOBAL_LIST_EMPTY(clash_welcomed)
GLOBAL_VAR_INIT(clash_feedback_contact, "")

/proc/clash_fed_spawns()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.fed_spawns

/proc/clash_welcome_path(ckey)
	return clash_player_save_path(ckey, "clash_welcome.sav")

SUBSYSTEM_DEF(clash_spawn)
	name = "Clash Spawn"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_spawn/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(on_mob_logged_in))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_spawn/proc/on_mob_logged_in(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(ishuman(new_mob) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		RegisterSignal(new_mob, COMSIG_POST_SPAWN_UPDATE, PROC_REF(on_spawned), override = TRUE)

/datum/controller/subsystem/clash_spawn/proc/on_spawned(mob/living/carbon/human/spawned)
	SIGNAL_HANDLER
	UnregisterSignal(spawned, COMSIG_POST_SPAWN_UPDATE)
	if(spawned.mind)
		spawned.mind.clash_job = spawned.job
	if(clash_fed_spawns())
		spawned.nutrition = NUTRITION_NORMAL
	spawned.clash_spawn_points = list(spawned.vendor_points, spawned.vendor_snowflake_points)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode) && clash_mode.spawn_protection)
		spawned.AddComponent(/datum/component/clash_spawn_guard, clash_mode.spawn_protection)
	if(clash_uses_kits())
		issue_clash_role_kit(spawned, spawned.job)
		var/datum/clash_kit/kit = get_clash_active_kit(spawned.ckey, spawned.job)
		if(kit)
			apply_clash_kit(spawned, kit)
			to_chat(spawned, SPAN_NOTICE("Kitted out as [kit.name]. Use the Loadout verb to change it."))
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
	page += "</style>"
	page += "<div class='head'><h1>[istype(clash_mode) ? uppertext(clash_mode.name) : "WELCOME"]</h1><div class='sub'>USCM vs UPP. The server is being playtested and updated continuously.</div></div>"
	page += "<div class='body'>"
	page += "<h2>This round</h2><ul>"
	if(istype(clash_mode))
		for(var/line in clash_mode.get_welcome_rules())
			page += "<li>[line]</li>"
	page += "</ul>"
	page += "<h2>Controls</h2><table class='keys'>"
	page += "<tr><td><span class='key'>Tab</span></td><td>Show or hide the scoreboard.</td></tr>"
	if(kits)
		page += "<tr><td><span class='key'>Loadout</span></td><td>Build up to [CLASH_KIT_COUNT] kits per role, like classes. The selected kit is on you every time you spawn as that role. Open it from the lobby, the Deploy button when you are down, or the Loadout verb.</td></tr>"
		page += "<tr><td><span class='key'>Deploy</span></td><td>The button in the middle of the screen when you are down. It counts down your respawn, then sends you back in.</td></tr>"
	else
		page += "<tr><td><span class='key'>Respawn</span></td><td>The button in the middle of the screen when you are down.</td></tr>"
		page += "<tr><td><span class='key'>Vendors</span></td><td>Save your loadout with Save current in the Saved Loadouts section, 3 slots per role.</td></tr>"
	page += "<tr><td><span class='key'>Stats</span></td><td>The Career Stats verb, or the button on the scoreboard, shows your career and the leaderboard.</td></tr>"
	page += "</table>"
	page += "<h2>Good to know</h2><ul>"
	page += "<li>Friendly fire is on, and explosions can take off limbs.</li>"
	page += "<li>Near the end of each round you vote for the next mode, then for a map that can run it.</li>"
	page += "<li>Only rounds that finish on their own count toward career stats.</li>"
	page += "</ul>"
	if(GLOB.clash_feedback_contact)
		page += "<h2>Feedback</h2><input class='contact' type='text' readonly value='[GLOB.clash_feedback_contact]' onclick='this.select()'>"
	page += "</div>"
	page += "<div class='foot'><label><input type='checkbox' id='hide'> Do not show again</label>"
	page += "<button onclick=\"location.href='byond://?src=[REF(src)];clash_welcome=1;hide=' + (document.getElementById('hide').checked ? 1 : 0)\">GOT IT</button></div>"
	show_browser(viewer, page.Join(), "Welcome", "clash_welcome", width = 500, height = 560)

/datum/controller/subsystem/clash_spawn/Topic(href, list/href_list)
	if(!href_list["clash_welcome"] || !usr?.client)
		return
	close_browser(usr, "clash_welcome")
	if(href_list["hide"] == "1" && usr.ckey)
		var/savefile/save = new(clash_welcome_path(usr.ckey))
		save["hide"] << TRUE

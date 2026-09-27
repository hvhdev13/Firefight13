GLOBAL_LIST_EMPTY(clash_welcomed)
GLOBAL_VAR_INIT(clash_feedback_contact, "")

/// Whether fresh spawns and bots start with a full stomach this round
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
			// Even an empty kit dresses the base outfit, which the vendors used to hand out
			apply_clash_kit(spawned, kit)
			to_chat(spawned, SPAN_NOTICE("Kitted out as [kit.name]. Use the Loadout verb to change it."))
	else
		// Let the spawn finish settling in before buying gear onto it
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_equip_spawn_loadout), spawned), 1 SECONDS)
	var/ckey = spawned.ckey
	if(!ckey || (ckey in GLOB.clash_welcomed))
		return
	GLOB.clash_welcomed += ckey
	if(!fexists(clash_welcome_path(ckey)))
		INVOKE_ASYNC(src, PROC_REF(show_welcome), spawned)

/// Vendor points a fighter spawned with, restored when a new match starts
/mob/living/carbon/human/var/list/clash_spawn_points

/// Where a fighter's job spawns them, the same lookup a fresh spawn uses
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
	var/list/page = list()
	page += "<h2>Welcome!</h2>"
	page += "<p>The server is currently being playtested and updated continuously.</p>"
	page += "<p><b>Recommended maps:</b></p>"
	page += "<ul><li>TDM_Jungle</li><li>TDM_Deathmatch2000</li></ul>"
	page += "<p>The map vote decides the mode. Faction Clash (FC_) maps run the traditional CM-SS13 UPP vs USCM gamemode, Team Deathmatch (TDM_) maps run the small arena mode.</p>"
	page += "<p><b>How it works:</b></p>"
	page += "<ul>"
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		for(var/line in clash_mode.get_welcome_rules())
			page += "<li>[line]</li>"
	if(clash_uses_kits())
		page += "<li>Your loadout is picked per role, like a class: open it from the Loadout button in the lobby, the Deploy button when you are down, or the Loadout verb. The kit you select is on you every time you spawn as that role. Up to [CLASH_KIT_COUNT] kits per role, starting from ready-made classes.</li>"
	else
		page += "<li>You can save your loadouts. At a vendor, use Save current in the Saved Loadouts section. Each role has 3 slots.</li>"
	page += "<li>The enemy base is locked. Enemies cannot walk or throw grenades into it.</li>"
	page += "<li>Players named \[BOT\] are bots. Kills on bots and by bots never count toward the score.</li>"
	page += "<li>Explosions can take off limbs.</li>"
	page += "<li>Friendly fire is on.</li>"
	page += "</ul>"
	if(GLOB.clash_feedback_contact)
		page += "<p>Report bugs and feedback: <input type='text' readonly value='[GLOB.clash_feedback_contact]' onclick='this.select()' style='width: 100%'></p>"
	page += "<hr><label><input type='checkbox' id='hide'> Do not show again</label> "
	page += "<button onclick=\"location.href='byond://?src=[REF(src)];clash_welcome=1;hide=' + (document.getElementById('hide').checked ? 1 : 0)\">OK</button>"
	show_browser(viewer, page.Join(), "Welcome", "clash_welcome", width = 460, height = 480)

/datum/controller/subsystem/clash_spawn/Topic(href, list/href_list)
	if(!href_list["clash_welcome"] || !usr?.client)
		return
	close_browser(usr, "clash_welcome")
	if(href_list["hide"] == "1" && usr.ckey)
		var/savefile/save = new(clash_welcome_path(usr.ckey))
		save["hide"] << TRUE

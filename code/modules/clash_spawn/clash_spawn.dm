GLOBAL_LIST_INIT(clash_fed_spawn_maps, list(MAP_TDM_JUNGLE))
GLOBAL_LIST_EMPTY(clash_welcomed)
GLOBAL_VAR_INIT(clash_feedback_contact, "")

/proc/clash_fed_spawns()
	return (SSmapping.configs[GROUND_MAP]?.map_name in GLOB.clash_fed_spawn_maps)

/proc/clash_welcome_path(ckey)
	return "data/player_saves/[copytext(ckey, 1, 2)]/[ckey]/clash_welcome.sav"

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
	var/ckey = spawned.ckey
	if(!ckey || (ckey in GLOB.clash_welcomed))
		return
	GLOB.clash_welcomed += ckey
	if(!fexists(clash_welcome_path(ckey)))
		INVOKE_ASYNC(src, PROC_REF(show_welcome), spawned)

/datum/controller/subsystem/clash_spawn/proc/show_welcome(mob/viewer)
	var/list/page = list()
	page += "<h2>Welcome!</h2>"
	page += "<p>The server is currently being playtested and updated continuously.</p>"
	page += "<p><b>Recommended maps:</b></p>"
	page += "<ul><li>TDM_Jungle</li><li>TDM_Deathmatch2000</li></ul>"
	page += "<p>Eventually players will be able to select either Faction Clash (FC_) or Team Deathmatch (TDM_) maps.</p>"
	page += "<ul><li>FC maps will have the traditional CM-SS13 UPP vs USCM gamemode.</li><li>TDM maps will have the small arena TDM maps.</li></ul>"
	page += "<p><b>How it works:</b></p>"
	page += "<ul>"
	page += "<li>Rounds last 30 minutes. The team with the most kills wins. The map vote opens with 5 minutes left.</li>"
	page += "<li>You can respawn 40 seconds after dying, using the Respawn button in the centre of the screen.</li>"
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

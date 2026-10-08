GLOBAL_DATUM_INIT(clash_progress, /datum/clash_progress_store, new)
GLOBAL_LIST_INIT(clash_progression_settings, list("enabled" = TRUE, "xp_multiplier" = 1, "bot_xp" = TRUE))

/datum/clash_progress_store
	var/list/players = list()

/datum/clash_progress_store/proc/get(ckey)
	if(!ckey || IsGuestKey(ckey))
		return null
	var/datum/clash_progress/progress = players[ckey]
	if(!progress)
		progress = new(ckey)
		progress.load()
		players[ckey] = progress
	return progress

/datum/clash_progress_store/proc/save_dirty()
	for(var/ckey in players)
		var/datum/clash_progress/progress = players[ckey]
		if(progress.dirty)
			progress.save()

/proc/clash_progress_of(ckey)
	return GLOB.clash_progress.get(ckey)

/proc/clash_level_xp_for(level, base)
	return base * (level - 1) + CLASH_LEVEL_XP_STEP * level * (level - 1)

/proc/clash_faction_xp_for(level)
	return clash_level_xp_for(level, CLASH_FACTION_XP_BASE)

/proc/clash_class_xp_for(level)
	return clash_level_xp_for(level, CLASH_CLASS_XP_BASE)

/datum/clash_progress
	var/ckey
	var/list/factions = list()
	var/list/classes = list()
	var/list/weapons = list()
	var/list/carriers = list()
	var/list/seen = list()
	var/toasts = TRUE
	var/radar = TRUE
	var/chatbox = TRUE
	var/prestige = 0
	var/zone_seconds = 0
	var/list/support_xp = list()
	var/list/ledger = list()
	var/list/unlocked_round = list()
	var/list/start_levels = list()
	var/short_side
	var/side
	var/class_id
	var/dirty = FALSE

/datum/clash_progress/New(ckey)
	src.ckey = ckey

/datum/clash_progress/proc/save_path()
	return clash_player_save_path(ckey, CLASH_PROGRESS_FILE)

/datum/clash_progress/proc/read_file(path)
	if(!fexists(path))
		return null
	var/list/decoded
	try
		decoded = json_decode(file2text(path))
	catch(var/exception/e)
		log_world("Clash progress: could not read [path]: [e]")
		return null
	return islist(decoded) ? decoded : null

/datum/clash_progress/proc/load()
	var/path = save_path()
	var/list/decoded = read_file(path)
	if(isnull(decoded) && fexists(path))
		fcopy(path, "[path].bad")
		decoded = read_file("[path].bak")
		log_world("Clash progress: [path] was unreadable, kept it as .bad and [decoded ? "restored the backup" : "found no usable backup"]")
	if(!decoded)
		return
	for(var/name in list("factions", "classes", "weapons", "carriers"))
		var/list/saved = decoded[name]
		if(!islist(saved))
			continue
		var/list/target = vars[name]
		for(var/key in saved)
			var/list/entry = saved[key]
			if(!islist(entry))
				continue
			if(name == "factions" || name == "classes")
				entry["best"] = min(entry["best"], CLASH_LEVEL_CAP)
			else if(name == "carriers")
				entry["best"] = min(entry["best"], length(GLOB.clash_carrier_tracks[key]))
			target[key] = entry
	if(islist(decoded["seen"]))
		seen = decoded["seen"]
	if(!isnull(decoded["toasts"]))
		toasts = !!decoded["toasts"]
	if(!isnull(decoded["radar"]))
		radar = !!decoded["radar"]
	if(!isnull(decoded["chatbox"]))
		chatbox = !!decoded["chatbox"]
	prestige = decoded["prestige"] || 0

/datum/clash_progress/proc/save()
	var/path = save_path()
	var/temp_path = "[path].tmp"
	fdel(temp_path)
	text2file(json_encode(list(
		"version" = CLASH_PROGRESS_VERSION,
		"prestige" = prestige,
		"factions" = factions,
		"classes" = classes,
		"weapons" = weapons,
		"carriers" = carriers,
		"seen" = seen,
		"toasts" = toasts,
		"radar" = radar,
		"chatbox" = chatbox,
	)), temp_path)
	if(!read_file(temp_path))
		log_world("Clash progress: the new save for [ckey] did not read back, keeping the old file")
		return
	if(read_file(path))
		fcopy(path, "[path].bak")
	fcopy(temp_path, path)
	fdel(temp_path)
	dirty = FALSE

/datum/clash_progress/proc/get_entry(list/track, key, list/blank)
	var/list/entry = track[key]
	if(!entry)
		entry = blank
		track[key] = entry
	return entry

/datum/clash_progress/proc/faction_entry(faction)
	return get_entry(factions, faction, list("xp" = 0, "best" = 1))

/datum/clash_progress/proc/class_entry(class)
	return get_entry(classes, class, list("xp" = 0, "best" = 1))

/datum/clash_progress/proc/weapon_entry(gun_type)
	return get_entry(weapons, "[gun_type]", list("xp" = 0, "best" = 1, "mastered" = 0))

/datum/clash_progress/proc/carrier_entry(family)
	return get_entry(carriers, family, list("xp" = 0, "best" = 0))

/datum/clash_progress/proc/level_from_xp(xp, base)
	var/level = 1
	while(level < CLASH_LEVEL_CAP && xp >= clash_level_xp_for(level + 1, base))
		level++
	return level

/datum/clash_progress/proc/faction_level(faction)
	var/list/entry = factions[faction]
	return entry ? max(entry["best"], level_from_xp(entry["xp"], CLASH_FACTION_XP_BASE)) : 1

/datum/clash_progress/proc/class_level(class)
	var/list/entry = classes[class]
	return entry ? max(entry["best"], level_from_xp(entry["xp"], CLASH_CLASS_XP_BASE)) : 1

#define CLASH_CAREER_PATH "data/clash_career.json"
#define CLASH_CAREER_KD_FLOOR 25
#define CLASH_CAREER_BOARD_SIZE 25

GLOBAL_DATUM_INIT(clash_career, /datum/clash_career, new)

/datum/clash_career
	var/list/players
	var/recorded_round = FALSE

/datum/clash_career/proc/load()
	if(islist(players))
		return
	players = list()
	var/list/decoded = read_file(CLASH_CAREER_PATH)
	if(isnull(decoded) && fexists(CLASH_CAREER_PATH))
		fcopy(CLASH_CAREER_PATH, "[CLASH_CAREER_PATH].bad")
		decoded = read_file("[CLASH_CAREER_PATH].bak")
		log_world("Clash career: [CLASH_CAREER_PATH] was unreadable, kept it as .bad and [decoded ? "restored the backup" : "found no usable backup"]")
	if(islist(decoded))
		players = decoded

/datum/clash_career/proc/read_file(path)
	if(!fexists(path))
		return null
	var/list/decoded
	try
		decoded = json_decode(file2text(path))
	catch(var/exception/e)
		log_world("Clash career: could not read [path]: [e]")
		return null
	return islist(decoded) ? decoded : null

/datum/clash_career/proc/save()
	if(!islist(players))
		return
	var/temp_path = "[CLASH_CAREER_PATH].tmp"
	fdel(temp_path)
	text2file(json_encode(players), temp_path)
	if(!read_file(temp_path))
		log_world("Clash career: the new save did not read back, keeping the old file")
		return
	if(read_file(CLASH_CAREER_PATH))
		fcopy(CLASH_CAREER_PATH, "[CLASH_CAREER_PATH].bak")
	fcopy(temp_path, CLASH_CAREER_PATH)
	fdel(temp_path)

/datum/clash_career/proc/get_entry(ckey)
	load()
	return players[ckey]

/datum/clash_career/proc/record_round(list/scores, winner, list/mvp_names, mode_name)
	if(recorded_round)
		return
	recorded_round = TRUE
	load()
	var/list/by_ckey = list()
	for(var/name in scores)
		var/list/round_entry = scores[name]
		var/ckey = round_entry["ckey"]
		if(!ckey)
			continue
		var/list/total = by_ckey[ckey]
		if(!total)
			total = list("name" = name, "faction" = round_entry["faction"], "mvps" = 0, "best_streak" = 0)
			by_ckey[ckey] = total
		for(var/stat in list("kills", "assists", "deaths", "captures", "shots", "hits"))
			total[stat] = (total[stat] || 0) + (round_entry[stat] || 0)
		total["best_streak"] = max(total["best_streak"], round_entry["best_streak"] || 0)
		for(var/mvp in mvp_names)
			if(mvp == name)
				total["mvps"] += 1
		if((round_entry["kills"] || 0) > (total["name_kills"] || -1))
			total["name"] = name
			total["name_kills"] = round_entry["kills"] || 0
			total["faction"] = round_entry["faction"]
	var/count = 0
	for(var/ckey in by_ckey)
		var/list/total = by_ckey[ckey]
		var/list/career = players[ckey]
		if(!islist(career))
			career = list()
			players[ckey] = career
		for(var/stat in list("kills", "assists", "deaths", "captures", "shots", "hits", "mvps"))
			career[stat] = (career[stat] || 0) + (total[stat] || 0)
		career["rounds"] = (career["rounds"] || 0) + 1
		if(winner && total["faction"] == winner)
			career["wins"] = (career["wins"] || 0) + 1
		career["best_streak"] = max(career["best_streak"] || 0, total["best_streak"])
		career["best_round_kills"] = max(career["best_round_kills"] || 0, total["kills"] || 0)
		career["name"] = total["name"]
		career["last_mode"] = mode_name
		career["last_played"] = time2text(world.realtime, "YYYY-MM-DD")
		count++
	save()
	update_static_data_for_all_viewers()
	log_game("Clash career: recorded [count] players for [mode_name]")

/proc/clash_career_row(ckey, list/career)
	var/kills = career["kills"] || 0
	var/deaths = career["deaths"] || 0
	var/shots = career["shots"] || 0
	var/rounds = career["rounds"] || 0
	return list(
		"ckey" = ckey,
		"name" = career["name"] || ckey,
		"kills" = kills,
		"deaths" = deaths,
		"assists" = career["assists"] || 0,
		"captures" = career["captures"] || 0,
		"kd" = round(kills / max(1, deaths), 0.01),
		"accuracy" = shots ? round((career["hits"] || 0) / shots * 100, 0.1) : 0,
		"rounds" = rounds,
		"wins" = career["wins"] || 0,
		"win_rate" = rounds ? round((career["wins"] || 0) / rounds * 100) : 0,
		"mvps" = career["mvps"] || 0,
		"best_streak" = career["best_streak"] || 0,
		"best_round_kills" = career["best_round_kills"] || 0,
		"last_played" = career["last_played"],
	)

/datum/clash_career/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashStats", "Career Stats")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/clash_career/ui_state(mob/user)
	return GLOB.always_state

/datum/clash_career/ui_static_data(mob/user)
	load()
	var/list/board = list()
	for(var/ckey in players)
		var/list/career = players[ckey]
		if(islist(career) && career["rounds"])
			board += list(clash_career_row(ckey, career))
	var/list/own = players[user.ckey]
	return list(
		"viewer" = user.ckey,
		"own" = islist(own) ? clash_career_row(user.ckey, own) : null,
		"board" = board,
		"kd_floor" = CLASH_CAREER_KD_FLOOR,
		"board_size" = CLASH_CAREER_BOARD_SIZE,
	)

/mob/verb/clash_stats()
	set name = "Career Stats"
	set category = "OOC"
	GLOB.clash_career.tgui_interact(src)

#undef CLASH_CAREER_PATH
#undef CLASH_CAREER_KD_FLOOR
#undef CLASH_CAREER_BOARD_SIZE

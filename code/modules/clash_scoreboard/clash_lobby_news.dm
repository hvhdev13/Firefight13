GLOBAL_LIST_INIT(clash_lobby_news, list(
	"USCM AND UPP FORCES CLASH OVER THE COLONY",
	"CIVILIANS WARNED TO STAY CLEAR OF THE FIGHTING",
	"BOTH SIDES CALL FOR REINFORCEMENTS",
))

GLOBAL_LIST_INIT(lobby_music_credits, list(
	"sound/lobby/firefight13_main_menu.ogg" = "TACTICAL CARNAGE - SPUTNIK",
))

GLOBAL_LIST_EMPTY(clash_lobby_news_lines)
GLOBAL_VAR_INIT(clash_lobby_news_time, -1)

/proc/clash_lobby_news()
	if(GLOB.clash_lobby_news_time != world.time)
		GLOB.clash_lobby_news_time = world.time
		GLOB.clash_lobby_news_lines = build_clash_lobby_news()
	return GLOB.clash_lobby_news_lines

/proc/build_clash_lobby_news()
	var/place = uppertext(SSmapping.configs?[GROUND_MAP]?.map_name)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	. = list()
	if(!istype(clash_mode))
		. += "[uppertext(GLOB.master_mode)] ON [place]: TEAMS ASSEMBLING"
		return . + GLOB.clash_lobby_news
	var/mode_name = uppertext(clash_mode.name)
	var/series = clash_mode.matches_per_round > 1
	if(clash_mode.round_finished)
		. += clash_mode.lobby_final_line(place)
	else if(clash_mode.intermission_end_time)
		. += "MATCH [clash_mode.match_number] OVER, NEXT MATCH SOON"
	else if(clash_mode.countdown_end_time)
		. += "[mode_name] ON [place]: [series ? "MATCH [clash_mode.get_display_match()] OF [clash_mode.matches_per_round]" : "MATCH"] STARTS SOON"
	else if(clash_mode.match_live)
		. += "LIVE: [mode_name] ON [place]"
		. += "USCM [clash_mode.get_match_score(FACTION_MARINE)] : [clash_mode.get_match_score(FACTION_UPP)] UPP [uppertext(clash_mode.score_label)]"
		if(series)
			. += "MATCH [clash_mode.match_number] OF [clash_mode.matches_per_round]"
		. += "[clash_mode.count_side(FACTION_MARINE)] MARINES AND [clash_mode.count_side(FACTION_UPP)] UPP IN THE FIELD"
	else
		. += "[mode_name] ON [place]: TEAMS ASSEMBLING"
	if(series)
		for(var/index in 1 to length(clash_mode.match_results))
			var/list/result = clash_mode.match_results[index]
			. += "MATCH [index]: USCM [result["uscm"]] : [result["upp"]] UPP, [result["winner"] ? "[clash_side_name(result["winner"])] WON" : "DRAW"]"
	. += GLOB.clash_lobby_news

/datum/game_mode/extended/faction_clash/hvh/proc/lobby_final_line(place)
	if(matches_per_round > 1)
		var/uscm = match_wins[FACTION_MARINE] || 0
		var/upp = match_wins[FACTION_UPP] || 0
		if(uscm == upp)
			return "ROUND OVER ON [place]: SERIES DRAWN [uscm] TO [upp]"
		return "ROUND OVER ON [place]: [uscm > upp ? "USCM" : "UPP"] TAKES THE SERIES [max(uscm, upp)] TO [min(uscm, upp)]"
	if(!length(match_results))
		return "ROUND OVER ON [place]"
	var/list/result = match_results[length(match_results)]
	if(!result["winner"])
		return "ROUND OVER ON [place]: DRAW [result["uscm"]] TO [result["upp"]]"
	return "ROUND OVER ON [place]: [clash_side_name(result["winner"])] WINS [max(result["uscm"], result["upp"])] TO [min(result["uscm"], result["upp"])]"

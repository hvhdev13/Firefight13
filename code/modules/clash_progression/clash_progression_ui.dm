/proc/clash_next_unlock_text(ckey, faction)
	if(!clash_progression_active() || !(faction in list(FACTION_MARINE, FACTION_UPP)))
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return null
	var/level = progress.faction_level(faction)
	var/list/entry = progress.factions[faction]
	var/xp = entry ? entry["xp"] : 0
	for(var/list/rung as anything in GLOB.clash_faction_ladders[faction])
		if(rung[1] > level && ispath(rung[2], /obj/item/weapon/gun))
			return "Next: [clash_item_name(faction, rung[2])], [clash_number_text(max(0, clash_faction_xp_for(rung[1]) - xp))] XP to go"
	return null

/proc/clash_scoreboard_level(ckey, faction)
	if(!ckey || !clash_progression_active())
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	return progress?.faction_level(faction)

/proc/clash_progress_report(ckey)
	if(!clash_progression_active())
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress?.side)
		return null
	var/list/sources = list()
	var/total = 0
	for(var/source in progress.ledger)
		sources += list(list("source" = source, "xp" = progress.ledger[source]))
		total += progress.ledger[source]
	var/side = progress.side
	var/faction_level = progress.faction_level(side)
	var/class = progress.class_id
	return list(
		"total" = total,
		"sources" = sources,
		"side" = clash_side_name(side),
		"faction_level" = faction_level,
		"faction_start" = progress.start_levels[side] || faction_level,
		"insignia" = clash_insignia_name(side, faction_level),
		"class" = class ? GLOB.clash_class_names[class] : null,
		"class_level" = class ? progress.class_level(class) : null,
		"class_start" = class ? (progress.start_levels[class] || progress.class_level(class)) : null,
		"unlocks" = progress.unlocked_round,
		"next" = clash_next_unlock_text(ckey, side),
	)

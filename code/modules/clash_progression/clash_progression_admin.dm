#define CLASH_PROGRESSION_MAX_MULTIPLIER 5

GLOBAL_DATUM_INIT(clash_progression_admin, /datum/clash_progression_admin, new)

/client/proc/clash_progression_panel()
	set name = "Progression Panel"
	set desc = "Look up and set player levels and XP, the XP multiplier, bot XP and the locks."
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return
	GLOB.clash_progression_admin.tgui_interact(mob)

/datum/clash_progression_admin
	var/list/lookups = list()

/datum/clash_progression_admin/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashProgressionAdmin", "Progression Panel")
		ui.open()

/datum/clash_progression_admin/ui_state(mob/user)
	return GLOB.admin_state

/datum/clash_progression_admin/ui_static_data(mob/user)
	return list("max_multiplier" = CLASH_PROGRESSION_MAX_MULTIPLIER, "level_cap" = CLASH_LEVEL_CAP)

/datum/clash_progression_admin/ui_data(mob/user)
	var/ckey = lookups[user.ckey]
	return list(
		"enabled" = GLOB.clash_progression_settings["enabled"],
		"multiplier" = GLOB.clash_progression_settings["xp_multiplier"],
		"bot_xp" = GLOB.clash_progression_settings["bot_xp"],
		"ckey" = ckey,
		"progress" = ckey ? clash_career_progress(ckey) : null,
	)

/datum/clash_progression_admin/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!CLIENT_HAS_RIGHTS(user.client, R_EVENT))
		return
	var/note
	switch(action)
		if("lookup")
			var/wanted = ckey(params["ckey"])
			lookups[user.ckey] = length(wanted) ? wanted : null
			return TRUE
		if("set_level")
			var/ckey = lookups[user.ckey]
			var/level = text2num(params["level"])
			if(!ckey || !clash_set_progress_level(ckey, params["track"], params["key"], level, user))
				to_chat(user, SPAN_WARNING("That level could not be set."))
			return TRUE
		if("set_xp")
			var/ckey = lookups[user.ckey]
			var/xp = text2num(params["xp"])
			if(!ckey || !clash_set_progress_xp(ckey, params["track"], params["key"], xp, user))
				to_chat(user, SPAN_WARNING("That XP could not be set."))
			return TRUE
		if("multiplier")
			var/value = text2num(params["value"])
			if(!isnum(value))
				return
			GLOB.clash_progression_settings["xp_multiplier"] = clamp(round(value, 0.25), 0, CLASH_PROGRESSION_MAX_MULTIPLIER)
			note = "set the progression XP multiplier to [GLOB.clash_progression_settings["xp_multiplier"]]"
		if("bot_xp")
			GLOB.clash_progression_settings["bot_xp"] = !GLOB.clash_progression_settings["bot_xp"]
			note = "turned bot XP [GLOB.clash_progression_settings["bot_xp"] ? "on" : "off"]"
		if("enabled")
			GLOB.clash_progression_settings["enabled"] = !GLOB.clash_progression_settings["enabled"]
			note = "turned progression locks [GLOB.clash_progression_settings["enabled"] ? "on" : "off"]"
	if(!note)
		return
	message_admins("[key_name_admin(user)] [note].")
	log_admin("[key_name(user)] [note].")
	return TRUE

#undef CLASH_PROGRESSION_MAX_MULTIPLIER

#define CLASH_XP_BOOST_FILE "data/clash_xp_boost.json"
#define CLASH_XP_BOOST_MAX 5
#define CLASH_XP_BOOST_MAX_HOURS 336
#define CLASH_XP_BOOST_MAX_ROUNDS 200

GLOBAL_DATUM_INIT(clash_xp_boost, /datum/clash_xp_boost, new)

/datum/clash_xp_boost
	var/multiplier = 1
	var/expires
	var/rounds_left
	var/started_by
	var/list/greeted = list()

/datum/clash_xp_boost/New()
	load()

/datum/clash_xp_boost/proc/load()
	if(!fexists(CLASH_XP_BOOST_FILE))
		return
	var/list/decoded
	try
		decoded = json_decode(file2text(CLASH_XP_BOOST_FILE))
	catch(var/exception/e)
		log_world("Clash XP boost: could not read [CLASH_XP_BOOST_FILE]: [e]")
		return
	if(!islist(decoded))
		return
	multiplier = text2num(decoded["multiplier"]) || 1
	expires = text2num(decoded["expires"])
	rounds_left = text2num(decoded["rounds_left"])
	started_by = decoded["started_by"]
	if(!active())
		clear()

/datum/clash_xp_boost/proc/save()
	fdel(CLASH_XP_BOOST_FILE)
	if(multiplier == 1)
		return
	text2file(json_encode(list(
		"multiplier" = num2text(multiplier),
		"expires" = isnull(expires) ? null : num2text(expires, 20),
		"rounds_left" = isnull(rounds_left) ? null : num2text(rounds_left),
		"started_by" = started_by,
	)), CLASH_XP_BOOST_FILE)

/datum/clash_xp_boost/proc/active()
	if(multiplier == 1)
		return FALSE
	if(!isnull(expires))
		return world.realtime < expires
	return rounds_left > 0

/datum/clash_xp_boost/proc/current()
	if(active())
		return multiplier
	if(multiplier != 1)
		clear()
	return 1

/datum/clash_xp_boost/proc/start(new_multiplier, amount, unit, ckey)
	multiplier = new_multiplier
	started_by = ckey
	if(unit == "rounds")
		rounds_left = amount
		expires = null
	else
		expires = world.realtime + amount HOURS
		rounds_left = null
	greeted = list()
	save()
	to_chat(world, SPAN_BOLDANNOUNCE("XP boost: [multiplier]x XP [describe_left()]."))

/datum/clash_xp_boost/proc/clear()
	multiplier = 1
	expires = null
	rounds_left = null
	started_by = null
	save()

/datum/clash_xp_boost/proc/describe_left()
	if(!isnull(expires))
		return "for the next [DisplayTimeText(max(expires - world.realtime, 0), 60)]"
	return "for the next [rounds_left] round\s"

/datum/clash_xp_boost/proc/greet(mob/user)
	if(!user.ckey || (user.ckey in greeted) || current() == 1)
		return
	greeted += user.ckey
	to_chat(user, SPAN_NOTICE("<b>XP boost active:</b> [multiplier]x XP [describe_left()]."))

/datum/clash_xp_boost/proc/round_ended()
	if(isnull(rounds_left) || current() == 1)
		return
	var/played = FALSE
	for(var/ckey in GLOB.clash_progress.players)
		var/datum/clash_progress/progress = GLOB.clash_progress.players[ckey]
		if(progress.side && GLOB.directory[ckey])
			played = TRUE
			break
	if(!played)
		return
	rounds_left--
	if(rounds_left > 0)
		save()
		to_chat(world, SPAN_NOTICE("XP boost: [multiplier]x XP for [rounds_left] more round\s."))
		return
	clear()
	to_chat(world, SPAN_NOTICE("The XP boost has ended."))

/datum/clash_xp_boost/proc/panel_data()
	return list(
		"active" = current() != 1,
		"multiplier" = multiplier,
		"left" = active() ? describe_left() : null,
		"started_by" = started_by,
		"max" = CLASH_XP_BOOST_MAX,
		"max_hours" = CLASH_XP_BOOST_MAX_HOURS,
		"max_rounds" = CLASH_XP_BOOST_MAX_ROUNDS,
	)

/datum/clash_xp_boost/proc/admin_act(action, list/params, mob/user)
	switch(action)
		if("boost_start")
			var/value = clamp(round(text2num(params["multiplier"]), 0.25), 1.25, CLASH_XP_BOOST_MAX)
			var/unit = params["unit"] == "rounds" ? "rounds" : "hours"
			var/amount = round(text2num(params["amount"]))
			amount = clamp(amount, 1, unit == "rounds" ? CLASH_XP_BOOST_MAX_ROUNDS : CLASH_XP_BOOST_MAX_HOURS)
			start(value, amount, unit, user.ckey)
			return "started a [value]x XP boost for [amount] [unit]"
		if("boost_end")
			if(current() == 1)
				return
			clear()
			to_chat(world, SPAN_NOTICE("The XP boost has ended."))
			return "ended the XP boost"

#undef CLASH_XP_BOOST_FILE
#undef CLASH_XP_BOOST_MAX
#undef CLASH_XP_BOOST_MAX_HOURS
#undef CLASH_XP_BOOST_MAX_ROUNDS

#define CLASH_STATUS_EVERYONE "everyone"
#define CLASH_STATUS_TEAM "team"
#define CLASH_STATUS_MEDIC "medic"
#define CLASH_STATUS_X 24
#define CLASH_STATUS_TOP_Y 8
#define CLASH_STATUS_STEP 8
#define CLASH_STATUS_FADE (2 DECISECONDS)
#define CLASH_CLASS_MARK_Y 24

GLOBAL_LIST_EMPTY(clash_status_holders)
GLOBAL_LIST_INIT(clash_statuses, build_clash_statuses())
GLOBAL_LIST_EMPTY(clash_class_marks)
GLOBAL_LIST_EMPTY(clash_class_mark_icons)
GLOBAL_LIST_INIT(clash_class_mark_patterns, list(
	CLASH_CLASS_MEDIC = list(
		"..ooo..",
		"..oGo..",
		"oooGooo",
		"oGGGGGo",
		"oooGooo",
		"..oGo..",
		"..ooo..",
	),
	CLASH_CLASS_ENGINEER = list(
		"oo...oo",
		"oGo.oGo",
		"oGGoGGo",
		".oGGGo.",
		"..oGo..",
		"..oGo..",
		"..ooo..",
	),
	CLASH_CLASS_HEAVY = list(
		"ooooooo",
		"oGoGoGo",
		"oGoGoGo",
		"oGoGoGo",
		"oGoGoGo",
		"oGoGoGo",
		"ooooooo",
	),
	CLASH_CLASS_LEADER = list(
		"...o...",
		"..oGo..",
		"ooGGGoo",
		"oGGGGGo",
		".oGGGo.",
		"oGGoGGo",
		"oo...oo",
	),
))

/datum/clash_status
	var/name
	var/priority = 1
	var/audience = CLASH_STATUS_EVERYONE
	var/list/pattern
	var/list/palette
	var/icon/badge

/datum/clash_status/proc/get_badge()
	if(!badge)
		badge = clash_pattern_icon(pattern, palette)
	return badge

/datum/clash_status/suppressed
	name = "Suppressed"
	priority = 1
	pattern = list(
		"oo...oo",
		"oRo.oRo",
		"oRRoRRo",
		".oRRRo.",
		"..oRo..",
		"...o...",
	)
	palette = list("o" = rgb(10, 12, 15, 230), "R" = rgb(225, 55, 45))

/datum/clash_status/internal_injuries
	name = "Needs Fix-all"
	priority = 2
	audience = CLASH_STATUS_MEDIC
	pattern = list(
		".oo.oo.",
		"oPPoPPo",
		"oPPPPPo",
		"oPPPPPo",
		".oPPPo.",
		"..oPo..",
		"...o...",
	)
	palette = list("o" = rgb(10, 12, 15, 230), "P" = rgb(235, 90, 160))

/proc/build_clash_statuses()
	. = list()
	for(var/status_type in subtypesof(/datum/clash_status))
		.[status_type] = new status_type

/datum/clash_status_holder
	var/mob/living/carbon/human/target
	var/list/active = list()
	var/list/images = list()
	var/list/shown = list()

/datum/clash_status_holder/New(mob/living/carbon/human/owner)
	target = owner
	RegisterSignal(target, COMSIG_PARENT_QDELETING, PROC_REF(on_target_deleted))
	GLOB.clash_status_holders[target] = src

/datum/clash_status_holder/Destroy(force)
	for(var/client/viewer as anything in shown)
		viewer?.images -= shown[viewer]
	shown = null
	images = null
	GLOB.clash_status_holders -= target
	target = null
	return ..()

/datum/clash_status_holder/proc/on_target_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/clash_status_holder/proc/get_image(view, status_type)
	var/key = "[view]|[status_type]"
	var/image/badge = images[key]
	if(!badge)
		var/datum/clash_status/status = GLOB.clash_statuses[status_type]
		badge = image(status.get_badge(), target, layer = ABOVE_FLY_LAYER)
		badge.appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM|KEEP_APART
		badge.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		badge.pixel_x = CLASH_STATUS_X
		badge.alpha = 0
		images[key] = badge
	return badge

/datum/clash_status_holder/proc/layout(view)
	. = list()
	var/list/visible = list()
	for(var/status_type in active)
		var/datum/clash_status/status = GLOB.clash_statuses[status_type]
		if(status.audience == CLASH_STATUS_EVERYONE || status.audience == view || (view == CLASH_STATUS_MEDIC && status.audience == CLASH_STATUS_TEAM))
			visible += status
	sortTim(visible, GLOBAL_PROC_REF(cmp_clash_status_priority))
	var/slot = 0
	for(var/datum/clash_status/status as anything in visible)
		var/image/badge = get_image(view, status.type)
		var/height = CLASH_STATUS_TOP_Y - slot * CLASH_STATUS_STEP
		if(!badge.alpha)
			badge.pixel_y = height
		animate(badge, alpha = 255, pixel_y = height, time = CLASH_STATUS_FADE)
		. += badge
		slot++

/datum/clash_status_holder/proc/refresh()
	var/list/layouts = list(CLASH_STATUS_MEDIC = layout(CLASH_STATUS_MEDIC), CLASH_STATUS_TEAM = layout(CLASH_STATUS_TEAM), CLASH_STATUS_EVERYONE = layout(CLASH_STATUS_EVERYONE))
	for(var/key in images)
		var/image/badge = images[key]
		if(!(badge in layouts[CLASH_STATUS_MEDIC]) && !(badge in layouts[CLASH_STATUS_TEAM]) && !(badge in layouts[CLASH_STATUS_EVERYONE]))
			badge.alpha = 0
	for(var/client/viewer as anything in GLOB.clients)
		show_to(viewer, layouts[clash_status_view(viewer, target)])
	if(!length(active))
		qdel(src)

/datum/clash_status_holder/proc/show_to(client/viewer, list/badges)
	var/list/old = shown[viewer]
	if(old)
		viewer.images -= old
	if(!length(badges))
		shown -= viewer
		return
	viewer.images += badges
	shown[viewer] = badges.Copy()

/proc/cmp_clash_status_priority(datum/clash_status/first, datum/clash_status/second)
	return first.priority - second.priority

/proc/clash_status_view(client/viewer, mob/living/carbon/human/target)
	if(isobserver(viewer.mob))
		return CLASH_STATUS_TEAM
	if(viewer.mob.faction == target.faction)
		return ishuman(viewer.mob) && clash_is_medic(viewer.mob) ? CLASH_STATUS_MEDIC : CLASH_STATUS_TEAM
	return CLASH_STATUS_EVERYONE

/proc/clash_status_has(mob/living/carbon/human/target, status_type)
	var/datum/clash_status_holder/holder = GLOB.clash_status_holders[target]
	return holder && (status_type in holder.active)

/proc/clash_status_add(mob/living/carbon/human/target, status_type)
	if(QDELETED(target) || clash_status_has(target, status_type))
		return
	var/datum/clash_status_holder/holder = GLOB.clash_status_holders[target] || new /datum/clash_status_holder(target)
	holder.active += status_type
	holder.refresh()

/proc/clash_status_remove(mob/living/carbon/human/target, status_type)
	var/datum/clash_status_holder/holder = GLOB.clash_status_holders[target]
	if(!holder || !(status_type in holder.active))
		return
	holder.active -= status_type
	holder.refresh()

/proc/clash_status_sync_viewer(client/viewer)
	for(var/mob/living/carbon/human/target as anything in GLOB.clash_status_holders)
		var/datum/clash_status_holder/holder = GLOB.clash_status_holders[target]
		var/view = clash_status_view(viewer, target)
		var/list/badges = list()
		for(var/key in holder.images)
			var/image/badge = holder.images[key]
			if(findtext(key, "[view]|") == 1 && badge.alpha)
				badges += badge
		holder.show_to(viewer, badges)

/proc/get_clash_class_mark_icon(class)
	if(!GLOB.clash_class_mark_icons[class])
		GLOB.clash_class_mark_icons[class] = clash_pattern_icon(GLOB.clash_class_mark_patterns[class], list("o" = rgb(10, 12, 15, 230), "G" = rgb(240, 190, 60)))
	return GLOB.clash_class_mark_icons[class]

/proc/clash_class_mark_sees(client/viewer, mob/living/carbon/human/target)
	return isobserver(viewer.mob) || viewer.mob.faction == target.faction

/proc/clash_class_mark_add(mob/living/carbon/human/target)
	clash_class_mark_remove(target)
	var/class = GLOB.clash_job_classes[target.job]
	if(!clash_fast_medicine() || !GLOB.clash_class_mark_patterns[class])
		return
	var/image/mark = image(get_clash_class_mark_icon(class), target, layer = ABOVE_FLY_LAYER)
	mark.appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM|KEEP_APART
	mark.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	mark.pixel_x = CLASH_STATUS_X
	mark.pixel_y = CLASH_CLASS_MARK_Y
	GLOB.clash_class_marks[target] = mark
	for(var/client/viewer as anything in GLOB.clients)
		if(clash_class_mark_sees(viewer, target))
			viewer.images += mark

/proc/clash_class_mark_remove(mob/living/carbon/human/target)
	var/image/mark = GLOB.clash_class_marks[target]
	if(!mark)
		return
	GLOB.clash_class_marks -= target
	for(var/client/viewer as anything in GLOB.clients)
		viewer.images -= mark

/proc/clash_class_mark_sync_viewer(client/viewer)
	for(var/mob/living/carbon/human/target as anything in GLOB.clash_class_marks)
		var/image/mark = GLOB.clash_class_marks[target]
		if(QDELETED(target))
			GLOB.clash_class_marks -= target
			viewer.images -= mark
		else if(clash_class_mark_sees(viewer, target))
			viewer.images |= mark
		else
			viewer.images -= mark

/proc/clash_hide_squad_icon(mob/living/carbon/human/target)
	if(!clash_fast_medicine() || !(target.faction in list(FACTION_MARINE, FACTION_UPP)))
		return
	var/datum/faction/side = get_faction(target.faction)
	var/image/holder = target.hud_list[side.hud_type]
	holder.icon_state = "hudblank"
	holder.overlays.Cut()

SUBSYSTEM_DEF(clash_status)
	name = "Clash Status"
	flags = SS_NO_FIRE

/datum/controller/subsystem/clash_status/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(on_mob_logged_in))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/clash_status/proc/on_mob_logged_in(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(new_mob.client)
		clash_status_sync_viewer(new_mob.client)
		clash_class_mark_sync_viewer(new_mob.client)

#undef CLASH_STATUS_EVERYONE
#undef CLASH_STATUS_TEAM
#undef CLASH_STATUS_MEDIC
#undef CLASH_STATUS_X
#undef CLASH_STATUS_TOP_Y
#undef CLASH_STATUS_STEP
#undef CLASH_STATUS_FADE
#undef CLASH_CLASS_MARK_Y

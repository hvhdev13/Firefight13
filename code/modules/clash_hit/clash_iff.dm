GLOBAL_LIST_EMPTY(clash_iff_markers)

/obj/effect/clash_iff
	name = ""
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_FLY_LAYER
	pixel_y = 8
	appearance_flags = RESET_COLOR|RESET_TRANSFORM|KEEP_APART

/proc/get_clash_iff_marker(faction, bot)
	var/key = "[faction][bot ? "bot" : ""]"
	if(GLOB.clash_iff_markers[key])
		return GLOB.clash_iff_markers[key]
	var/color = faction == FACTION_MARINE ? "#5a8fe6" : "#e61919"
	var/list/pixels = bot ? list(list(14, 31), list(18, 31), list(15, 30), list(17, 30), list(16, 29)) : list(list(16, 31), list(15, 30), list(17, 30), list(14, 29), list(18, 29), list(15, 28), list(17, 28), list(16, 27))
	var/icon/chevron = icon('icons/effects/effects.dmi', "nothing")
	for(var/list/pixel as anything in pixels)
		chevron.DrawBox(rgb(10, 12, 15), pixel[1], pixel[2] - 1)
	for(var/list/pixel as anything in pixels)
		chevron.DrawBox(color, pixel[1], pixel[2])
	var/obj/effect/clash_iff/marker = new
	marker.icon = chevron
	GLOB.clash_iff_markers[key] = marker
	return marker

/datum/element/clash_iff
	element_flags = ELEMENT_DETACH

/datum/element/clash_iff/Attach(datum/target)
	. = ..()
	var/mob/living/carbon/human/fighter = target
	if(!istype(fighter) || !(fighter.faction in list(FACTION_MARINE, FACTION_UPP)))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(fighter, COMSIG_MOB_DEATH, PROC_REF(hide))
	RegisterSignal(fighter, COMSIG_HUMAN_REVIVED, PROC_REF(show))
	if(fighter.stat != DEAD)
		show(fighter)

/datum/element/clash_iff/Detach(datum/source, force)
	. = ..()
	UnregisterSignal(source, list(COMSIG_MOB_DEATH, COMSIG_HUMAN_REVIVED))
	hide(source)

/datum/element/clash_iff/proc/show(mob/living/carbon/human/fighter)
	SIGNAL_HANDLER
	fighter.vis_contents |= get_clash_iff_marker(fighter.faction, clash_is_bot(fighter))
	clash_class_mark_add(fighter)

/datum/element/clash_iff/proc/hide(mob/living/carbon/human/fighter)
	SIGNAL_HANDLER
	for(var/obj/effect/clash_iff/marker in fighter.vis_contents)
		fighter.vis_contents -= marker
	clash_class_mark_remove(fighter)

GLOBAL_LIST_EMPTY(clash_iff_markers)

/obj/effect/clash_iff
	name = ""
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_FLY_LAYER
	pixel_y = 9
	appearance_flags = RESET_COLOR|RESET_TRANSFORM|KEEP_APART

/proc/get_clash_iff_marker(faction)
	if(GLOB.clash_iff_markers[faction])
		return GLOB.clash_iff_markers[faction]
	var/color = faction == FACTION_MARINE ? "#5a8fe6" : "#e61919"
	var/list/pixels = list(list(12, 31), list(13, 31), list(19, 31), list(20, 31), list(13, 30), list(14, 30), list(18, 30), list(19, 30), list(14, 29), list(15, 29), list(17, 29), list(18, 29), list(15, 28), list(16, 28), list(17, 28), list(16, 27))
	var/icon/chevron = icon('icons/effects/effects.dmi', "nothing")
	for(var/list/pixel as anything in pixels)
		chevron.DrawBox(rgb(10, 12, 15), pixel[1] - 1, pixel[2] - 1, pixel[1] + 1, min(pixel[2] + 1, 32))
	for(var/list/pixel as anything in pixels)
		chevron.DrawBox(color, pixel[1], pixel[2])
	var/obj/effect/clash_iff/marker = new
	marker.icon = chevron
	GLOB.clash_iff_markers[faction] = marker
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
	fighter.vis_contents |= get_clash_iff_marker(fighter.faction)

/datum/element/clash_iff/proc/hide(mob/living/carbon/human/fighter)
	SIGNAL_HANDLER
	for(var/obj/effect/clash_iff/marker in fighter.vis_contents)
		fighter.vis_contents -= marker

#define CLASH_FLAG_STAND_OFFSET 4

/obj/effect/landmark/clash_flag_stand
	name = "Clash flag stand"
	var/faction

/obj/effect/landmark/clash_flag_stand/uscm
	name = "Clash flag stand (USCM)"
	faction = FACTION_MARINE

/obj/effect/landmark/clash_flag_stand/upp
	name = "Clash flag stand (UPP)"
	faction = FACTION_UPP

/obj/item/clash_flag
	name = "flag"
	desc = "Take it back to your own flag to score. Your own side returns it by touching it where it lies."
	icon = 'icons/obj/structures/plantable_flag.dmi'
	w_class = SIZE_MASSIVE
	throw_range = 2
	force = 10
	hitsound = "swing_hit"
	unacidable = TRUE
	explo_proof = TRUE
	anchored = TRUE
	inhand_x_dimension = 64
	inhand_y_dimension = 64
	item_icons = list(
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/items/items_lefthand_64.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/items/items_righthand_64.dmi'
		)
	var/faction
	var/base_state
	var/turf/home
	var/state = CLASH_FLAG_HOME
	var/mob/living/carbon/human/carrier
	var/dropped_at

/obj/item/clash_flag/uscm
	name = "\improper USCM flag"
	faction = FACTION_MARINE
	base_state = "flag_ua"

/obj/item/clash_flag/upp
	name = "\improper UPP flag"
	faction = FACTION_UPP
	base_state = "flag_upp"

/obj/item/clash_flag/Initialize(mapload, ...)
	. = ..()
	home = get_turf(src)
	show_planted(TRUE)

/obj/item/clash_flag/Destroy(force)
	home = null
	carrier = null
	return ..()

/obj/item/clash_flag/proc/show_planted(planted)
	icon_state = planted ? "[base_state]_planted" : base_state
	item_state = base_state
	pixel_x = planted ? 9 : 0
	anchored = planted

/obj/item/clash_flag/attack_hand(mob/user)
	var/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/mode = SSticker.mode
	if(!istype(mode) || !ishuman(user))
		return ..()
	if(user.faction == faction)
		if(state == CLASH_FLAG_HOME)
			to_chat(user, SPAN_NOTICE("Your flag is home. Keep it that way."))
		else if(isturf(loc))
			mode.return_flag(src, user)
		return
	if(!(user.faction in list(FACTION_MARINE, FACTION_UPP)) || user.statistic_exempt || !user.client)
		return
	if(!mode.match_live)
		to_chat(user, SPAN_WARNING("The match is not on."))
		return
	anchored = FALSE
	. = ..()
	if(loc != user)
		show_planted(state == CLASH_FLAG_HOME)

/obj/item/clash_flag/equipped(mob/user, slot, silent)
	. = ..()
	queue_settle()

/obj/item/clash_flag/dropped(mob/user)
	. = ..()
	queue_settle()

/obj/item/clash_flag/proc/queue_settle()
	addtimer(CALLBACK(src, PROC_REF(settle)), 1)

/obj/item/clash_flag/proc/settle()
	var/datum/game_mode/extended/faction_clash/hvh/tdm/ctf/mode = SSticker.mode
	if(istype(mode))
		mode.settle_flag(src)

/proc/place_clash_flag_stand(turf/home, colour)
	. = list()
	for(var/turf/spot as anything in RANGE_TURFS(1, home))
		if(spot.density)
			continue
		var/obj/effect/clash_zone_tile/tile = new(spot)
		tile.color = colour
		. += tile

/proc/clash_carries_enemy_flag(atom/movable/mover)
	if(!ishuman(mover))
		return FALSE
	var/mob/living/carbon/human/runner = mover
	for(var/obj/item/clash_flag/flag in list(runner.l_hand, runner.r_hand))
		if(flag.faction != runner.faction)
			return TRUE
	return FALSE

/proc/get_clash_flag_spots()
	. = list()
	var/list/levels = SSmapping.levels_by_trait(ZTRAIT_GROUND)
	if(!length(levels))
		return
	var/z = levels[1]
	for(var/obj/effect/landmark/clash_flag_stand/mark as anything in GLOB.landmarks_list)
		if(istype(mark) && mark.z == z && mark.faction)
			.[mark.faction] = get_turf(mark)
	if(.[FACTION_MARINE] && .[FACTION_UPP])
		return
	. = list()
	var/list/centres = get_clash_base_centres(z)
	var/list/uscm = centres[FACTION_MARINE]
	var/list/upp = centres[FACTION_UPP]
	if(!uscm || !upp)
		log_debug("HVH: no base areas found, cannot place flag stands")
		return
	var/turf/middle = get_clash_open_turf_near((uscm[1] + upp[1]) / 2, (uscm[2] + upp[2]) / 2, z)
	if(!middle)
		return
	var/list/reachable = get_clash_reachable_turfs(middle, 200)
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		var/list/centre = centres[faction]
		var/span_x = middle.x - centre[1]
		var/span_y = middle.y - centre[2]
		var/span = max(1, sqrt(span_x ** 2 + span_y ** 2))
		var/step_x = span_x / span
		var/step_y = span_y / span
		var/target_x = middle.x
		var/target_y = middle.y
		for(var/distance in 0 to round(span))
			var/turf/along = locate(round(centre[1] + step_x * distance), round(centre[2] + step_y * distance), z)
			if(along && !clash_in_base(along))
				var/beyond = min(distance + CLASH_FLAG_STAND_OFFSET, span)
				target_x = centre[1] + step_x * beyond
				target_y = centre[2] + step_y * beyond
				break
		.[faction] = get_clash_nearest_turf(reachable, target_x, target_y) || middle

#undef CLASH_FLAG_STAND_OFFSET

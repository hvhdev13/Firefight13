#define CLASH_MEDIC_RANGE 40
#define CLASH_CALL_MEDIC_COOLDOWN (10 SECONDS)
#define CLASH_CALL_MEDIC_MARK (20 SECONDS)
#define CALL_MEDIC_WIDTH 144
#define CALL_MEDIC_HEIGHT 18
#define CLASH_MEDIC_NEARBY_RANGE 10

GLOBAL_LIST_EMPTY(clash_medic_marks)

/mob/living/carbon/human/var/clash_called_until = 0
/client/var/clash_medic_called_until = 0
/client/var/atom/movable/screen/clash_call_medic/clash_call_medic

GLOBAL_LIST_EMPTY(clash_call_medic_icons)

/proc/clash_medics_near(mob/living/carbon/human/body)
	. = list()
	for(var/mob/living/carbon/human/medic as anything in GLOB.alive_human_list)
		if(medic.client && medic.stat == CONSCIOUS && medic.faction == body.faction && medic.z == body.z && clash_is_medic(medic) && get_dist(medic, body) <= CLASH_MEDIC_RANGE)
			. += medic

/proc/clash_revive_status(mob/viewer)
	var/mob/living/carbon/human/body = clash_revivable_body(viewer)
	if(!body)
		return null
	if(!clash_fast_medicine())
		return "STATUS: REVIVABLE"
	var/closest
	for(var/mob/living/carbon/human/medic as anything in clash_medics_near(body))
		var/distance = get_dist(medic, body)
		if(isnull(closest) || distance < closest)
			closest = distance
	if(isnull(closest) || closest > CLASH_MEDIC_NEARBY_RANGE)
		return "STATUS: REVIVABLE"
	return "MEDIC NEARBY  ·  [closest] TILE\s"

/proc/clash_mark_medic_call(mob/living/carbon/human/patient, duration)
	var/list/mark = GLOB.clash_medic_marks[patient]
	if(!mark)
		var/image/cross = image(get_clash_radar_mark("downed"), patient, layer = ABOVE_FLY_LAYER)
		cross.pixel_x = 2
		cross.pixel_y = 30
		cross.transform = matrix(2, 0, 0, 0, 2, 0)
		cross.appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM|KEEP_APART|PIXEL_SCALE
		mark = list("image" = cross, "viewers" = list())
		GLOB.clash_medic_marks[patient] = mark
	mark["until"] = duration ? world.time + duration : 0
	clash_refresh_medic_marks()

/proc/clash_medic_shout(mob/living/carbon/human/patient)
	if(clash_fast_medicine())
		clash_mark_medic_call(patient, CLASH_MEDIC_SHOUT_MARK)

/proc/clash_refresh_medic_marks()
	for(var/mob/living/carbon/human/patient as anything in GLOB.clash_medic_marks.Copy())
		var/list/mark = GLOB.clash_medic_marks[patient]
		var/list/viewers = mark["viewers"]
		var/keep = !QDELETED(patient)
		if(keep)
			keep = mark["until"] ? (patient.stat != DEAD && world.time < mark["until"]) : (patient.stat == DEAD && patient.check_tod() && patient.is_revivable())
		if(!keep)
			for(var/client/viewer as anything in viewers)
				viewer?.images -= mark["image"]
			GLOB.clash_medic_marks -= patient
			continue
		for(var/mob/player as anything in GLOB.player_list)
			if(player.client && player.faction == patient.faction && !(player.client in viewers))
				player.client.images += mark["image"]
				viewers += player.client

/proc/get_clash_call_medic_icon(called)
	var/key = called ? "called" : "ready"
	if(GLOB.clash_call_medic_icons[key])
		return GLOB.clash_call_medic_icons[key]
	var/icon/button = icon('icons/effects/effects.dmi', "nothing")
	button.Scale(CALL_MEDIC_WIDTH, CALL_MEDIC_HEIGHT)
	button.DrawBox(rgb(10, 12, 15), 1, 1, CALL_MEDIC_WIDTH, CALL_MEDIC_HEIGHT)
	button.DrawBox(called ? rgb(34, 38, 43) : rgb(70, 30, 30), 2, 2, CALL_MEDIC_WIDTH - 1, CALL_MEDIC_HEIGHT - 1)
	button.DrawBox(called ? rgb(66, 73, 81) : rgb(200, 70, 70), 2, CALL_MEDIC_HEIGHT - 1, CALL_MEDIC_WIDTH - 1, CALL_MEDIC_HEIGHT - 1)
	button.DrawBox(called ? rgb(80, 87, 95) : rgb(224, 90, 90), 3, 3, 5, CALL_MEDIC_HEIGHT - 2)
	GLOB.clash_call_medic_icons[key] = button
	return button

/atom/movable/screen/clash_call_medic
	name = "Call Medic"
	desc = "Ping the medics near your body."
	icon = null
	screen_loc = "CENTER-2:8,CENTER-4:-12"
	maptext_width = CALL_MEDIC_WIDTH
	maptext_height = CALL_MEDIC_HEIGHT
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/shown_called

/atom/movable/screen/clash_call_medic/proc/update(client/player)
	var/called = world.time < player.clash_medic_called_until
	if(called == shown_called)
		return
	shown_called = called
	icon = get_clash_call_medic_icon(called)
	maptext = "<span style='text-align: center; vertical-align: middle; -dm-text-outline: 1px #0a0c0f; font-family: \"VCR OSD Mono\"; font-size: 8px; color: [called ? "#8a939c" : "#ffd9d9"]'>[called ? "MEDIC CALLED" : "CALL MEDIC"]</span>"

/atom/movable/screen/clash_call_medic/clicked(mob/user, list/mods)
	var/mob/living/carbon/human/body = clash_revivable_body(user)
	var/client/player = user.client
	if(!body || !player || world.time < player.clash_medic_called_until)
		return TRUE
	player.clash_medic_called_until = world.time + CLASH_CALL_MEDIC_COOLDOWN
	body.clash_called_until = world.time + CLASH_CALL_MEDIC_MARK
	clash_mark_medic_call(body, 0)
	var/list/medics = clash_medics_near(body)
	for(var/mob/living/carbon/human/medic as anything in medics)
		playsound_client(medic.client, 'sound/machines/twobeep.ogg', null, 50)
		var/distance = get_dist(medic, body)
		to_chat(medic, SPAN_BOLDNOTICE(distance ? "[body.real_name] needs a medic, [distance] tile\s [dir2text(get_dir(medic, body))]." : "[body.real_name] needs a medic, right here."))
	to_chat(user, SPAN_NOTICE(length(medics) ? "Medic called." : "No medic nearby."))
	update(player)
	return TRUE

/proc/clash_show_call_medic(mob/viewer)
	var/client/player = viewer.client
	if(!player)
		return
	var/atom/movable/screen/clash_call_medic/button = player.clash_call_medic
	if(!clash_fast_medicine() || !clash_revivable_body(viewer))
		if(button)
			player.remove_from_screen(button)
		return
	if(!button)
		button = new
		player.clash_call_medic = button
	if(!(button in player.screen))
		player.add_to_screen(button)
	button.update(player)

/mob/living/carbon/human/get_pull_multiplier()
	var/mob/living/carbon/human/body = pulling
	if(ishuman(body) && body.stat == DEAD && body.faction == faction && clash_fast_medicine() && clash_is_medic(src))
		return 0
	return ..()

/proc/clash_issue_medic_gear(mob/living/carbon/human/medic)
	if(!clash_fast_medicine() || !clash_is_medic(medic))
		return
	var/pouch_type = clash_medic_perk(medic, CLASH_PERK_LARGE_POUCH) ? /obj/item/storage/pouch/firstaid/clash/medic/large : /obj/item/storage/pouch/firstaid/clash/medic
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/worn = medic.get_item_by_slot(wear_slot)
		if(istype(worn, /obj/item/storage/pouch/medkit) || worn?.type == /obj/item/storage/pouch/medical)
			medic.temp_drop_inv_item(worn, TRUE)
			qdel(worn)
			var/obj/item/pouch = new pouch_type(medic)
			if(!medic.equip_to_slot_if_possible(pouch, wear_slot, TRUE, FALSE, TRUE))
				clash_give_medic_item(medic, pouch)
			return
	clash_give_medic_item(medic, new pouch_type(medic))

/proc/clash_give_medic_item(mob/living/carbon/human/medic, obj/item/item)
	if(!medic.equip_to_slot_if_possible(item, WEAR_IN_BACK, TRUE, FALSE, TRUE) && !medic.equip_to_appropriate_slot(item) && !medic.put_in_hands(item))
		item.forceMove(get_turf(medic))

#undef CLASH_MEDIC_RANGE
#undef CLASH_CALL_MEDIC_COOLDOWN
#undef CLASH_CALL_MEDIC_MARK
#undef CALL_MEDIC_WIDTH
#undef CALL_MEDIC_HEIGHT
#undef CLASH_MEDIC_NEARBY_RANGE

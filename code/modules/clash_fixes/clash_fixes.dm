/obj/item/clothing/glasses/welding/dropped(mob/living/carbon/human/user)
	. = ..()
	if(istype(user))
		user.update_tint()

/datum/game_decorator/halloween/pumpkins/is_active_decor()
	return FALSE

/datum/config_entry/string/servername
	default = "Firefight13"

/datum/config_entry/number/lobby_countdown
	config_entry_value = 20
	max_val = 20

/datum/config_entry/flag/respawn
	config_entry_value = TRUE
	protection = CONFIG_ENTRY_LOCKED

/datum/config_entry/flag/respawn/ValidateAndSet(str_val)
	config_entry_value = TRUE
	return TRUE

/datum/config_entry/flag/autooocmute/ValidateAndSet(str_val)
	config_entry_value = FALSE
	return TRUE

/datum/controller/subsystem/ticker
	tipped = TRUE

/obj/item/weapon/gun/shotgun/attackby(obj/item/attack_item, mob/user)
	if(istype(attack_item, /obj/item/ammo_magazine/handful) && loc == user && !(src in user.get_hands()) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		reload(user, attack_item)
		return
	return ..()

/datum/player_action/kill/anonymous

/datum/player_action/kill/anonymous/act(client/user, mob/target, list/params)
	if(tgui_alert(user, "Kill [target.real_name || target.name]?", "Kill", list("Kill", "Cancel")) != "Kill" || QDELETED(target))
		return TRUE
	target.death(create_cause_data("an admin"))
	message_admins("[key_name_admin(user)] killed [key_name_admin(target)].")
	return TRUE

/mob/living/say_dead(message)
	if(!istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		return ..()
	clash_say_dead(message)

/mob/dead/say_dead(message)
	if(!istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		return ..()
	clash_say_dead(message)

/mob/proc/clash_say_dead(message)
	if(!client)
		return
	if(!(client.admin_holder?.rights & R_MOD) && !GLOB.dsay_allowed)
		to_chat(src, SPAN_DANGER("Deadchat is globally muted."))
		return
	if(!(client.prefs?.toggles_chat & CHAT_DEAD))
		to_chat(src, SPAN_DANGER("You have deadchat muted."))
		return
	if(!client.attempt_talking(message))
		return
	log_say("DEAD/[key_name(src)] : [message]")
	var/turf/my_turf = get_turf(src)
	var/list/mob/langchat_listeners = list()
	for(var/mob/listener as anything in GLOB.player_list)
		if(isnewplayer(listener) || !(listener.client?.prefs?.toggles_chat & CHAT_DEAD))
			continue
		if(isobserver(listener) && !orbiting)
			var/mob/dead/observer/observer = listener
			var/turf/their_turf = get_turf(listener)
			if(alpha && observer.ghostvision && my_turf.z == their_turf.z && get_dist(my_turf, their_turf) <= observer.client.view)
				langchat_listeners += observer
		var/follow = listener.stat == DEAD ? " (<a href='byond://?src=\ref[listener];track=\ref[src]'>F</a>)" : ""
		to_chat(listener, "<span class='game deadsay'><span class='prefix'>DEAD:</span> <span class='name'>[real_name][follow]</span> says, <span class='message'>\"[message]\"</span></span>")
	if(length(langchat_listeners))
		langchat_speech(message, langchat_listeners, GLOB.all_languages, skip_language_check = TRUE)

/proc/clash_is_bot(mob/living/carbon/human/fighter)
	return fighter.statistic_exempt && !fighter.client && istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh)

/mob/living/carbon/human/visible_message(message, self_message, blind_message, max_distance, message_flags = CHAT_TYPE_OTHER)
	if(clash_is_bot(src))
		return
	return ..()

/mob/living/carbon/human/audible_message(message, deaf_message, max_distance, message_flags = CHAT_TYPE_OTHER)
	if(clash_is_bot(src))
		return
	return ..()

/obj/structure/barricade/update_health(damage, nomessage)
	return ..(damage, nomessage || istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))

/mob/living/say_verb(message as text)
	if(!clash_wants_all_chat(message))
		return ..()
	clash_all_chat(copytext(message, 2))

/mob/dead/say_verb(message as text)
	if(!clash_wants_all_chat(message))
		return ..()
	clash_all_chat(copytext(message, 2))

/proc/clash_wants_all_chat(message)
	return copytext(message, 1, 2) == ";" && istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh)

/mob/proc/clash_all_chat(message)
	message = trim(strip_html(message, MAX_MESSAGE_LEN))
	if(!length(message) || !client)
		return
	if(client.prefs.muted & MUTE_IC)
		to_chat(src, SPAN_DANGER("You cannot speak in IC (Muted)."))
		return
	if(isliving(src) && stat == UNCONSCIOUS)
		to_chat(src, SPAN_WARNING("You can't talk while unconscious."))
		return
	if(!client.attempt_talking(message) || !filter_message(client, message))
		return
	log_say("ALL/[key_name(src)] : [message]")
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	var/line = "<span class='game say'><b>\[ALL\]</b> <span style='color: [clash_mode.faction_color(faction)]'><b>[html_encode(real_name)]</b></span>: [message]</span>"
	for(var/client/listener as anything in GLOB.clients)
		to_chat(listener, line)

/obj/item/weapon/twohanded/offhand/unwield(mob/user)
	if(QDELETED(src))
		return
	return ..()

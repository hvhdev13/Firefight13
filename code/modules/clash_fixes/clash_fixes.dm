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

/datum/controller/subsystem/ticker/send_tip_of_the_round()
	return FALSE

/obj/item/weapon/gun/shotgun/attackby(obj/item/attack_item, mob/user)
	if(istype(attack_item, /obj/item/ammo_magazine/handful) && loc == user && !(src in user.get_hands()) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		reload(user, attack_item)
		return
	return ..()

/datum/player_action/kill/act(client/user, mob/target, list/params)
	if(tgui_alert(user, "Kill [target.real_name || target.name]?", "Kill", list("Kill", "Cancel")) != "Kill" || QDELETED(target))
		return TRUE
	target.death(create_cause_data("an admin"))
	message_admins("[key_name_admin(user)] killed [key_name_admin(target)].")
	return TRUE

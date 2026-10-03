/obj/item/clothing/glasses/welding/dropped(mob/living/carbon/human/user)
	. = ..()
	if(istype(user))
		user.update_tint()

/datum/game_decorator/halloween/pumpkins/is_active_decor()
	return FALSE

/datum/config_entry/string/servername
	default = "Firefight13"

/obj/item/weapon/gun/shotgun/attackby(obj/item/attack_item, mob/user)
	if(istype(attack_item, /obj/item/ammo_magazine/handful) && loc == user && !(src in user.get_hands()) && SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		reload(user, attack_item)
		return
	return ..()

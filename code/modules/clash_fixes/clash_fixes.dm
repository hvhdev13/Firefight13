/obj/item/clothing/glasses/welding/dropped(mob/living/carbon/human/user)
	. = ..()
	if(istype(user))
		user.update_tint()

/datum/game_decorator/halloween/pumpkins/is_active_decor()
	return FALSE

/datum/config_entry/string/servername
	default = "Firefight13"

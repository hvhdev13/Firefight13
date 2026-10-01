/obj/item/clothing/glasses/welding/dropped(mob/living/carbon/human/user)
	. = ..()
	if(istype(user))
		user.update_tint()

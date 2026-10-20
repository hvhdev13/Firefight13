#define CLASH_DRY_FIRE_ALERT_COOLDOWN (1 SECONDS)

/obj/item/weapon/gun/click_empty(mob/user)
	. = ..()
	if(user && clash_hvh_rules())
		balloon_alert(user, istype(src, /obj/item/weapon/gun/flamer) ? "*pshhhh*" : "*click*", delay = CLASH_DRY_FIRE_ALERT_COOLDOWN)

#undef CLASH_DRY_FIRE_ALERT_COOLDOWN

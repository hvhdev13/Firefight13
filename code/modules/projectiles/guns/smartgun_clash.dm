/obj/item/weapon/gun/smartgun/Initialize(mapload, ...)
	. = ..()
	if(!clash_hvh_rules())
		return
	can_change_ammo = FALSE
	for(var/datum/action/toggle as anything in actions?.Copy())
		if(istype(toggle, /datum/action/item_action/smartgun/toggle_frontline_mode) || istype(toggle, /datum/action/item_action/smartgun/toggle_lethal_mode) || istype(toggle, /datum/action/item_action/smartgun/toggle_ammo_type))
			qdel(toggle)

/obj/item/weapon/gun/smartgun/toggle_frontline_mode(mob/user, silent)
	if(clash_hvh_rules())
		return
	return ..()

/obj/item/weapon/gun/smartgun/toggle_lethal_mode(mob/user)
	if(clash_hvh_rules())
		return
	return ..()

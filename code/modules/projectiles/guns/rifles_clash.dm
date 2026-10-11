/obj/item/weapon/gun/rifle/m41a/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	burst_cooldown = 2
	fa_max_scatter = 4

/obj/item/weapon/gun/rifle/type71/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules() || istype(src, /obj/item/weapon/gun/rifle/type71/carbine))
		return
	set_fire_delay(FIRE_DELAY_TIER_9)
	burst_cooldown = 2.5
	scatter = 4.5

/obj/item/weapon/gun/rifle/type71/setup_firemodes()
	var/burst_rifle = clash_hvh_rules() && !istype(src, /obj/item/weapon/gun/rifle/type71/carbine)
	if(burst_rifle)
		start_automatic = FALSE
	. = ..()
	if(burst_rifle && (GUN_FIREMODE_BURSTFIRE in gun_firemode_list))
		gun_firemode_list -= GUN_FIREMODE_BURSTFIRE
		gun_firemode_list.Insert(1, GUN_FIREMODE_BURSTFIRE)

/obj/item/weapon/gun/rifle/type71/carbine/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	fa_max_scatter = 9
	recoil = RECOIL_AMOUNT_TIER_4

/obj/item/weapon/gun/rifle/type71/carbine/recalculate_attachment_bonuses()
	. = ..()
	if(clash_hvh_rules())
		recoil = max(recoil, RECOIL_AMOUNT_TIER_4)

/obj/item/weapon/gun/rifle/ak4047/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	set_fire_delay(FIRE_DELAY_TIER_8)
	damage_mult = BASE_BULLET_DAMAGE_MULT + BULLET_DAMAGE_MULT_TIER_5

/obj/item/weapon/gun/rifle/ak4047/recalculate_attachment_bonuses()
	. = ..()
	if(clash_hvh_rules())
		recoil = max(recoil, RECOIL_AMOUNT_TIER_4)

/obj/item/weapon/gun/rifle/m4ra/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	set_fire_delay(5.5)

/obj/item/weapon/gun/lever_action/xm88/set_gun_config_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	set_fire_delay(1.5 SECONDS)

/obj/item/weapon/gun/lever_action/xm88/apply_hit_buff()
	. = ..()
	if(clash_hvh_rules())
		modify_fire_delay(1.5 SECONDS - FIRE_DELAY_TIER_3)

/obj/item/weapon/gun/rifle/type71/carbine/reload(mob/user, obj/item/ammo_magazine/magazine)
	if(clash_hvh_rules() && istype(magazine, /obj/item/ammo_magazine/rifle/type71) && !istype(magazine, /obj/item/ammo_magazine/rifle/type71/carbine))
		to_chat(user, SPAN_WARNING("That magazine doesn't fit in there!"))
		return
	return ..()

/obj/item/attachable/bipod/m41ae2/activate_attachment(obj/item/weapon/gun/gun, mob/living/user, turn_off)
	. = ..()
	if(bipod_deployed && clash_hvh_rules())
		delay_mod = -0.5
		accuracy_mod = 0.4
		gun.recalculate_attachment_bonuses()

/obj/item/attachable/bipod/pkp/activate_attachment(obj/item/weapon/gun/gun, mob/living/user, turn_off)
	. = ..()
	if(bipod_deployed && clash_hvh_rules())
		accuracy_mod = 0.1
		gun.recalculate_attachment_bonuses()

/obj/item/weapon/gun/Initialize(mapload, spawn_empty)
	. = ..()
	if(clash_suppression_scale && clash_hvh_rules())
		add_bullet_traits(list(BULLET_TRAIT_ENTRY(/datum/element/bullet_trait_clash_suppression)))

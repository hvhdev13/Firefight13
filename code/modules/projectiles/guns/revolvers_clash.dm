/obj/item/weapon/gun/revolver/m44/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 0.8
		accuracy_mult = BASE_ACCURACY_MULT + HIT_ACCURACY_MULT_TIER_4

/obj/item/weapon/gun/revolver/upp/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 0.75
		accuracy_mult = BASE_ACCURACY_MULT + HIT_ACCURACY_MULT_TIER_4

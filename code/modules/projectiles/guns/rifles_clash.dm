/obj/item/weapon/gun/rifle/m4ra/set_gun_config_values()
	. = ..()
	if(!clash_fast_medicine())
		return
	set_fire_delay(5.5)
	damage_mult = BASE_BULLET_DAMAGE_MULT + BULLET_DAMAGE_MULT_TIER_4

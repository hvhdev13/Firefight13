/obj/item/weapon/gun/pistol/m1911/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 0.78

/obj/item/weapon/gun/pistol/vp78/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 0.69

/obj/item/weapon/gun/pistol/t73/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 0.78

/obj/item/weapon/gun/pistol/mod88/Initialize(mapload, spawn_empty)
	if(clash_hvh_rules() && current_mag == /obj/item/ammo_magazine/pistol/mod88)
		current_mag = /obj/item/ammo_magazine/pistol/mod88/normalpoint
	return ..()

/obj/item/weapon/gun/pistol/mod88/set_gun_config_values()
	. = ..()
	if(clash_hvh_rules())
		damage_mult = 1.25

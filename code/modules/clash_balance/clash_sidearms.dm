/datum/ammo/bullet/pistol/m10/setup_faction_clash_values()
	. = ..()
	if(!clash_hvh_rules())
		return
	damage = 30 * DAMAGE_MULT
	penetration = ARMOR_PENETRATION_TIER_4

/datum/ammo/bullet/pistol/setup_faction_clash_values()
	. = ..()
	if(type == /datum/ammo/bullet/pistol && clash_hvh_rules())
		penetration = ARMOR_PENETRATION_TIER_2

/datum/ammo/bullet/pistol/heavy/setup_faction_clash_values()
	. = ..()
	if(type == /datum/ammo/bullet/pistol/heavy && clash_hvh_rules())
		penetration = ARMOR_PENETRATION_TIER_2

/datum/ammo/bullet/pistol/squash/setup_faction_clash_values()
	. = ..()
	if(type == /datum/ammo/bullet/pistol/squash && clash_hvh_rules())
		penetration = ARMOR_PENETRATION_TIER_4

/datum/ammo/bullet/revolver/setup_faction_clash_values()
	. = ..()
	if(type == /datum/ammo/bullet/revolver && clash_hvh_rules())
		penetration = ARMOR_PENETRATION_TIER_3

/datum/ammo/bullet/revolver/upp/setup_faction_clash_values()
	. = ..()
	if(type == /datum/ammo/bullet/revolver/upp && clash_hvh_rules())
		penetration = ARMOR_PENETRATION_TIER_3

/obj/item/ammo_magazine/pistol/m1911/Initialize(mapload, spawn_empty)
	if(type == /obj/item/ammo_magazine/pistol/m1911 && clash_hvh_rules())
		max_rounds = 9
	return ..()

/obj/item/storage/belt/gun/type47/Initialize()
	if(clash_hvh_rules())
		can_hold += list(/obj/item/weapon/gun/pistol/mod88, /obj/item/ammo_magazine/pistol/mod88)
	return ..()

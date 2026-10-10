#define CLASH_ARMOR_LIGHT 1
#define CLASH_ARMOR_MEDIUM 2
#define CLASH_ARMOR_HEAVY 3
#define CLASH_ARMOR_LEADER 4
#define CLASH_ARMOR_HARNESS 5

#define CLASH_ARMOR_GEAR_BULLET 25
#define CLASH_ARMOR_GEAR_MELEE 20
#define CLASH_ARMOR_GEAR_BOMB 20
#define CLASH_ARMOR_GEAR_INTERNAL 30
#define CLASH_ARMOR_UPP_BONUS 1

GLOBAL_LIST_INIT(clash_armor_bullet, list(20, 25, 30, 25, 25))
GLOBAL_LIST_INIT(clash_armor_melee, list(15, 20, 25, 20, 20))
GLOBAL_LIST_INIT(clash_armor_bomb, list(15, 20, 35, 20, 20))
GLOBAL_LIST_INIT(clash_armor_internal, list(25, 30, 35, 30, 30))
GLOBAL_LIST_INIT(clash_armor_slowdown, list(
	FACTION_MARINE = list(0.25, 0.625, 0.85, 0.4, 0.25),
	FACTION_UPP = list(0.35, 0.75, 1, 0.5, 0.35),
))

GLOBAL_LIST_INIT(clash_armor_aim_slowdown, list(0.35, 0.55, 0.75, 0.35, 0.35))
GLOBAL_LIST_INIT(clash_armor_aim_compensation, list(0.35, 0.35, 0.55, 0.35, 0.35))

GLOBAL_LIST_INIT(clash_armor_leader_suits, list(
	/obj/item/clothing/suit/storage/marine/medium/leader,
	/obj/item/clothing/suit/storage/marine/faction/UPP/commando,
))

GLOBAL_LIST_INIT(clash_armor_light_suits, list(
	/obj/item/clothing/suit/storage/marine/light,
	/obj/item/clothing/suit/storage/marine/faction/UPP/support,
))

GLOBAL_LIST_INIT(clash_armor_heavy_suits, list(
	/obj/item/clothing/suit/storage/marine/heavy,
	/obj/item/clothing/suit/storage/marine/specialist,
	/obj/item/clothing/suit/storage/marine/faction/UPP/heavy,
))

GLOBAL_LIST_INIT(clash_armor_upp_gear, list(
	/obj/item/clothing/suit/storage/marine/faction/UPP,
	/obj/item/clothing/head/helmet/marine/veteran/UPP,
	/obj/item/clothing/head/uppcap,
	/obj/item/clothing/gloves/marine/veteran,
	/obj/item/clothing/shoes/marine/upp,
))

/proc/clash_armor_tier(obj/item/clothing/suit/suit)
	if(istype(suit, /obj/item/clothing/suit/storage/marine/smartgunner))
		return CLASH_ARMOR_HARNESS
	for(var/suit_type in GLOB.clash_armor_leader_suits)
		if(istype(suit, suit_type))
			return CLASH_ARMOR_LEADER
	for(var/suit_type in GLOB.clash_armor_light_suits)
		if(istype(suit, suit_type))
			return CLASH_ARMOR_LIGHT
	for(var/suit_type in GLOB.clash_armor_heavy_suits)
		if(istype(suit, suit_type))
			return CLASH_ARMOR_HEAVY
	return CLASH_ARMOR_MEDIUM

/proc/clash_armor_is_upp(obj/item/clothing/worn)
	for(var/gear_type in GLOB.clash_armor_upp_gear)
		if(istype(worn, gear_type))
			return TRUE
	return FALSE

/proc/clash_armor_standard(obj/item/clothing/worn)
	var/upp = clash_armor_is_upp(worn)
	var/bonus = upp ? CLASH_ARMOR_UPP_BONUS : 0
	if(!istype(worn, /obj/item/clothing/suit/storage/marine))
		worn.armor_bullet = CLASH_ARMOR_GEAR_BULLET + bonus
		worn.armor_melee = CLASH_ARMOR_GEAR_MELEE
		worn.armor_bomb = CLASH_ARMOR_GEAR_BOMB
		worn.armor_internaldamage = CLASH_ARMOR_GEAR_INTERNAL
		return
	var/obj/item/clothing/suit/storage/marine/suit = worn
	var/tier = clash_armor_tier(suit)
	suit.armor_bullet = GLOB.clash_armor_bullet[tier] + bonus
	suit.armor_melee = GLOB.clash_armor_melee[tier]
	suit.armor_bomb = GLOB.clash_armor_bomb[tier]
	suit.armor_internaldamage = GLOB.clash_armor_internal[tier]
	suit.slowdown = GLOB.clash_armor_slowdown[upp ? FACTION_UPP : FACTION_MARINE][tier]
	suit.flags_armor_protection = BODY_FLAG_CHEST|BODY_FLAG_GROIN|BODY_FLAG_ARMS|BODY_FLAG_LEGS

/datum/decorator/gamemode/decorate(atom/object)
	if(istype(SSticker.mode, /datum/game_mode/extended/faction_clash/hvh))
		return
	return ..()

/datum/decorator/gamemode/clash_armor
	gamemode = /datum/game_mode/extended/faction_clash/hvh

/datum/decorator/gamemode/clash_armor/get_decor_types()
	return typesof(/obj/item/clothing/suit/storage/marine, /obj/item/clothing/head/helmet/marine, /obj/item/clothing/head/uppcap, /obj/item/clothing/gloves/marine, /obj/item/clothing/shoes/marine)

/datum/decorator/gamemode/clash_armor/decorate(atom/object)
	clash_armor_standard(object)

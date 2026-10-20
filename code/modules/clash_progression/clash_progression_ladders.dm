GLOBAL_LIST_INIT(clash_starting_kits, list(
	FACTION_MARINE = list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/medium,
		KIT_SLOT_BACK = /obj/item/storage/backpack/marine,
		KIT_SLOT_BELT = /obj/item/storage/belt/marine,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/ert,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine,
		KIT_SLOT_WEBBING = /obj/item/clothing/accessory/storage/webbing/black,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/m41a,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/m4a3,
	),
	FACTION_UPP = list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine/veteran/UPP,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/faction/UPP,
		KIT_SLOT_BACK = /obj/item/storage/backpack/lightpack/upp,
		KIT_SLOT_BELT = /obj/item/storage/belt/marine/upp,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/ert,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine,
		KIT_SLOT_WEBBING = /obj/item/clothing/accessory/storage/webbing/black,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/type71,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/t73,
	),
))

GLOBAL_LIST_INIT(clash_faction_ladders, list(
	FACTION_MARINE = list(
		list(2, /obj/item/explosive/grenade/smokebomb),
		list(2, /obj/item/clothing/head/helmet/marine/jungle),
		list(3, /obj/item/weapon/gun/shotgun/pump/m37a),
//		list(5, /obj/item/weapon/gun/smg/m39),
		list(7, /obj/item/weapon/gun/pistol/mod88),
		list(9, /obj/item/clothing/head/helmet/marine/desert),
		list(12, /obj/item/clothing/head/helmet/marine/urban),
		list(13, /obj/item/weapon/gun/pistol/m10),
		list(15, /obj/item/weapon/gun/flamer/m240),
		list(16, /obj/item/weapon/gun/rifle/m4ra),
		list(17, /obj/item/weapon/gun/pistol/vp78),
		list(18, /obj/item/weapon/gun/lever_action/xm88),
		list(19, /obj/item/weapon/gun/pistol/m1911),
		list(20, /obj/item/weapon/gun/revolver/m44),
	),
	FACTION_UPP = list(
		list(2, /obj/item/explosive/grenade/smokebomb),
		list(2, /obj/item/clothing/head/helmet/marine/veteran/UPP/army),
		list(3, /obj/item/weapon/gun/shotgun/type23),
//		list(5, /obj/item/weapon/gun/smg/bizon),
		list(7, /obj/item/weapon/gun/pistol/np92),
		list(13, /obj/item/weapon/gun/revolver/upp),
		list(15, /obj/item/weapon/gun/flamer/m240),
		list(16, /obj/item/weapon/gun/rifle/type71/carbine),
		list(17, /obj/item/clothing/head/uppcap/beret),
		list(18, /obj/item/weapon/gun/rifle/ak4047),
		list(19, /obj/item/clothing/head/uppcap/ushanka),
		list(20, /obj/item/weapon/gun/rifle/sniper/svd),
	),
))

GLOBAL_LIST_INIT(clash_role_levels, list(
	JOB_SQUAD_MEDIC = 3,
	JOB_SQUAD_ENGI = 5,
	JOB_SQUAD_SMARTGUN = 7,
	JOB_SQUAD_TEAM_LEADER = 9,
	JOB_SQUAD_LEADER = 11,
	JOB_SQUAD_SPECIALIST = 13,
	JOB_UPP_MEDIC = 3,
	JOB_UPP_ENGI = 5,
	JOB_UPP_SPECIALIST = 7,
	JOB_UPP_LEADER = 11,
))

GLOBAL_LIST_INIT(clash_class_weapons, list(
	CLASH_CLASS_HEAVY = list(
		list(8, /obj/item/weapon/gun/smartgun),
		list(8, /obj/item/weapon/gun/minigun/upp),
	),
))

GLOBAL_LIST_INIT(clash_class_only_primaries, list(CLASH_CLASS_HEAVY))

GLOBAL_LIST_INIT(clash_class_primaries, list(
	FACTION_MARINE = list(
		CLASH_CLASS_RIFLEMAN = list("unlocks" = list(list(2, /obj/item/weapon/gun/rifle/m4ra))),
//		CLASH_CLASS_MEDIC = list("start" = /obj/item/weapon/gun/smg/m39, "unlocks" = list(list(2, /obj/item/weapon/gun/rifle/m41a))),
		CLASH_CLASS_MEDIC = list("start" = /obj/item/weapon/gun/rifle/m4ra, "blocked" = list(/obj/item/weapon/gun/lever_action/xm88)),
		CLASH_CLASS_ENGINEER = list("start" = /obj/item/weapon/gun/shotgun/pump/m37a, "unlocks" = list(list(2, /obj/item/weapon/gun/rifle/m4ra), list(3, /obj/item/weapon/gun/rifle/m41a))),
		CLASH_CLASS_LEADER = list("unlocks" = list(list(2, /obj/item/weapon/gun/rifle/m4ra))),
	),
	FACTION_UPP = list(
		CLASH_CLASS_RIFLEMAN = list("unlocks" = list(list(2, /obj/item/weapon/gun/rifle/type71/carbine), list(3, /obj/item/weapon/gun/rifle/ak4047))),
//		CLASH_CLASS_MEDIC = list("start" = /obj/item/weapon/gun/smg/bizon, "unlocks" = list(list(2, /obj/item/weapon/gun/rifle/type71))),
		CLASH_CLASS_MEDIC = list("start" = /obj/item/weapon/gun/rifle/ak4047),
//		CLASH_CLASS_ENGINEER = list("start" = /obj/item/weapon/gun/shotgun/type23, "unlocks" = list(list(2, /obj/item/weapon/gun/rifle/type71/carbine), list(3, /obj/item/weapon/gun/rifle/type71), list(4, /obj/item/weapon/gun/smg/bizon)), "blocked" = list(/obj/item/weapon/gun/rifle/ak4047)),
		CLASH_CLASS_ENGINEER = list("start" = /obj/item/weapon/gun/shotgun/type23, "unlocks" = list(list(2, /obj/item/weapon/gun/rifle/type71/carbine), list(3, /obj/item/weapon/gun/rifle/type71)), "blocked" = list(/obj/item/weapon/gun/rifle/ak4047)),
		CLASH_CLASS_LEADER = list("start" = /obj/item/weapon/gun/rifle/ak4047),
	),
))

GLOBAL_LIST_INIT(clash_role_names, list(
	JOB_SQUAD_SMARTGUN = "Machine Gunner",
	JOB_UPP = "Rifleman",
	JOB_UPP_MEDIC = "Hospital Corpsman",
	JOB_UPP_ENGI = "Combat Technician",
	JOB_UPP_SPECIALIST = "Machine Gunner",
	JOB_UPP_LEADER = "Squad Leader",
))

GLOBAL_LIST_INIT(clash_arena_roles, list(
	JOB_SQUAD_MARINE,
	JOB_SQUAD_MEDIC,
	JOB_SQUAD_ENGI,
	JOB_SQUAD_SMARTGUN,
	JOB_SQUAD_LEADER,
	JOB_UPP,
	JOB_UPP_MEDIC,
	JOB_UPP_ENGI,
	JOB_UPP_SPECIALIST,
	JOB_UPP_LEADER,
))

GLOBAL_LIST_INIT(clash_class_names, list(
	CLASH_CLASS_RIFLEMAN = "Rifleman",
	CLASH_CLASS_MEDIC = "Medic",
	CLASH_CLASS_ENGINEER = "Engineer",
	CLASH_CLASS_HEAVY = "Heavy",
	CLASH_CLASS_LEADER = "Leader",
	CLASH_CLASS_SUPPORT = "Support",
))

GLOBAL_LIST_INIT(clash_class_gear, list(
	CLASH_CLASS_RIFLEMAN = list("light_armor" = 2, "frag_grenade" = 3, "heavy_armor" = 6, "second_grenade" = 10, "extra_helmet" = 20),
	CLASH_CLASS_MEDIC = list("light_armor" = 3, "frag_grenade" = 6, "heavy_armor" = 15, "second_grenade" = 18, "extra_helmet" = 20),
	CLASH_CLASS_ENGINEER = list("extra_helmet" = 6, "heavy_armor" = 8, "light_armor" = 12, "frag_grenade" = 14, "second_grenade" = 17),
	CLASH_CLASS_HEAVY = list("heavy_armor" = 2, "extra_helmet" = 3, "second_grenade" = 5, "frag_grenade" = 11, "light_armor" = 12),
	CLASH_CLASS_LEADER = list("frag_grenade" = 2, "light_armor" = 5, "second_grenade" = 8, "heavy_armor" = 12, "extra_helmet" = 20),
	CLASH_CLASS_SUPPORT = list("light_armor" = 2, "frag_grenade" = 10, "heavy_armor" = 16, "second_grenade" = 18, "extra_helmet" = 20),
))

GLOBAL_LIST_INIT(clash_gear_types, list(
	"light_armor" = list(/obj/item/clothing/suit/storage/marine/light, /obj/item/clothing/suit/storage/marine/faction/UPP/support),
	"heavy_armor" = list(/obj/item/clothing/suit/storage/marine/heavy, /obj/item/clothing/suit/storage/marine/faction/UPP/heavy),
	"frag_grenade" = list(/obj/item/explosive/grenade/high_explosive, /obj/item/explosive/grenade/high_explosive/upp),
	"second_grenade" = list(/obj/item/explosive/grenade/high_explosive/m15, /obj/item/explosive/grenade/incendiary, /obj/item/explosive/grenade/phosphorus/upp),
	"extra_helmet" = list(/obj/item/clothing/head/helmet/marine/tech, /obj/item/clothing/head/helmet/marine/veteran/UPP/heavy),
))

GLOBAL_LIST_INIT(clash_gear_names, list(
	"light_armor" = "light armor",
	"heavy_armor" = "heavy armor",
	"frag_grenade" = "frag grenade",
	"second_grenade" = "second grenade",
	"extra_helmet" = "extra helmet",
))

GLOBAL_LIST_INIT(clash_shop_tiers, list(list(1, 5), list(4, 10), list(7, 15), list(10, 20), list(13, 25), list(16, INFINITY)))

GLOBAL_LIST_INIT(clash_role_free_gear, list(
	JOB_SQUAD_ENGI = list(/obj/item/clothing/head/helmet/marine/tech),
))

GLOBAL_LIST_EMPTY(clash_option_gates)

/proc/clash_gate_key(faction, item_type)
	return "[faction]|[item_type]"

/proc/build_clash_option_gates()
	if(length(GLOB.clash_option_gates))
		return
	var/list/gates = GLOB.clash_option_gates
	for(var/faction in list(FACTION_MARINE, FACTION_UPP))
		for(var/slot in GLOB.clash_starting_kits[faction])
			gates[clash_gate_key(faction, GLOB.clash_starting_kits[faction][slot])] = list("kind" = CLASH_GATE_FREE)
		for(var/gear in GLOB.clash_gear_types)
			for(var/item_type in GLOB.clash_gear_types[gear])
				gates[clash_gate_key(faction, item_type)] = list("kind" = CLASH_GATE_CLASS, "gear" = gear)
		for(var/class in GLOB.clash_class_weapons)
			for(var/list/rung as anything in GLOB.clash_class_weapons[class])
				gates[clash_gate_key(faction, rung[2])] = list("kind" = CLASH_GATE_CLASS_LEVEL, "class" = class, "level" = rung[1])
		for(var/list/rung as anything in GLOB.clash_faction_ladders[faction])
			gates[clash_gate_key(faction, rung[2])] = list("kind" = CLASH_GATE_FACTION, "level" = rung[1])

/proc/clash_class_start_primary(faction, class)
	var/list/entry = GLOB.clash_class_primaries[faction]?[class]
	return entry?["start"]

/proc/clash_class_primary_blocked(faction, class, item_type)
	var/list/entry = GLOB.clash_class_primaries[faction]?[class]
	return (item_type in entry?["blocked"])

/proc/clash_class_hidden_options(job)
	. = list()
	var/faction = clash_kit_faction_for_job(job)
	var/list/entry = GLOB.clash_class_primaries[faction]?[GLOB.clash_job_classes[job]]
	for(var/item_type in entry?["blocked"])
		. += clash_kit_option_id(faction, KIT_SLOT_PRIMARY, item_type)

/proc/clash_class_primary_level(faction, class, item_type)
	var/list/entry = GLOB.clash_class_primaries[faction]?[class]
	for(var/list/rung as anything in entry?["unlocks"])
		if(rung[2] == item_type)
			return rung[1]
	return null

/proc/clash_class_gear_level(class, gear)
	return GLOB.clash_class_gear[class]?[gear]

/proc/clash_shop_cost_limit(class_level)
	. = 0
	for(var/list/tier as anything in GLOB.clash_shop_tiers)
		if(class_level >= tier[1])
			. = tier[2]

/proc/clash_item_option(faction, item_type)
	build_clash_kit_catalog()
	for(var/slot in GLOB.clash_kit_menu[faction])
		var/datum/clash_kit_option/option = GLOB.clash_kit_options[clash_kit_option_id(faction, slot, item_type)]
		if(option)
			return option
	return null

/proc/clash_item_name(faction, item_type)
	var/datum/clash_kit_option/option = clash_item_option(faction, item_type)
	if(option)
		return option.name
	var/obj/item/sample = item_type
	return capitalize(initial(sample.name))

/proc/clash_gear_type_for(gear, faction)
	for(var/item_type in GLOB.clash_gear_types[gear])
		if(clash_item_option(faction, item_type))
			return item_type
	return null

/proc/clash_role_name(title)
	return GLOB.clash_role_names[title] || title

/proc/clash_veteran_class(ckey, job)
	var/class = GLOB.clash_job_classes[job]
	if(!class || !ckey || !clash_progression_active())
		return null
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	return progress?.class_level(class) >= CLASH_LEVEL_CAP ? class : null

/proc/clash_veteran_rank(ckey, job)
	var/class = clash_veteran_class(ckey, job)
	return class && "[GLOB.clash_class_names[class]] level [CLASH_LEVEL_CAP]"

/obj/item/clothing/accessory/medal/gold/clash_veteran
	name = "veteran medal"
	icon_state = "gold_star"
	overlay_state = "gold_star"

/proc/clash_pin_veteran_medal(mob/living/carbon/human/wearer, ckey, job)
	usr = null
	for(var/obj/item/clothing/clothes in list(wearer.wear_suit, wearer.w_uniform))
		for(var/obj/item/clothing/accessory/medal/gold/clash_veteran/old in clothes.accessories?.Copy())
			clothes.remove_accessory(null, old)
			qdel(old)
	var/class = clash_veteran_class(ckey, job)
	if(!class)
		return
	var/class_name = GLOB.clash_class_names[class]
	var/obj/item/clothing/accessory/medal/gold/clash_veteran/medal = new(wearer)
	medal.name = "veteran [lowertext(class_name)] medal"
	medal.desc = "A gold star medal awarded for reaching [class_name] level [CLASH_LEVEL_CAP]."
	medal.recipient_name = wearer.real_name
	medal.recipient_rank = clash_role_name(job)
	for(var/obj/item/clothing/clothes in list(wearer.wear_suit, wearer.w_uniform))
		if(clothes.can_attach_accessory(medal))
			clothes.attach_accessory(wearer, medal, TRUE)
			return
	qdel(medal)

/proc/clash_insignia_name(faction, level)
	var/list/names = GLOB.clash_insignia_names[faction]
	level = clamp(level, 1, CLASH_LEVEL_CAP)
	var/rank = CEILING(level / 2, 1)
	return "[names[rank]] [level % 2 ? "I" : "II"]"

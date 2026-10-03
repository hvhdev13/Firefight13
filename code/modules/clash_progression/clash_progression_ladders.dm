GLOBAL_LIST_INIT(clash_starting_kits, list(
	FACTION_MARINE = list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/medium,
		KIT_SLOT_BACK = /obj/item/storage/backpack/marine,
		KIT_SLOT_BELT = /obj/item/storage/belt/marine,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
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
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
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
		list(4, /obj/item/clothing/mask/rebreather),
		list(5, /obj/item/weapon/gun/smg/m39),
		list(5, /obj/item/storage/pouch/magazine/large),
		list(6, /obj/item/clothing/mask/rebreather/scarf),
		list(7, /obj/item/weapon/gun/pistol/mod88),
		list(8, /obj/item/clothing/accessory/storage/webbing),
		list(9, /obj/item/clothing/head/helmet/marine/desert),
		list(10, /obj/item/clothing/accessory/storage/black_vest, "webbing_vest"),
		list(11, /obj/item/weapon/gun/rifle/lmg),
		list(12, /obj/item/clothing/head/helmet/marine/urban),
		list(13, /obj/item/weapon/gun/revolver/m44),
		list(13, /obj/item/storage/belt/gun/m44),
		list(14, /obj/item/clothing/accessory/storage/droppouch/black, "drop_pouch"),
		list(15, /obj/item/weapon/gun/flamer/m240),
		list(15, /obj/item/storage/pouch/flamertank),
		list(16, /obj/item/weapon/gun/rifle/m4ra),
		list(17, /obj/item/weapon/gun/pistol/m10),
		list(17, /obj/item/clothing/accessory/storage/black_vest/black_leg_pouch, "leg_pouch"),
		list(18, /obj/item/weapon/gun/lever_action/xm88),
		list(19, /obj/item/weapon/gun/pistol/m1911),
		list(19, /obj/item/clothing/mask/gas),
		list(20, /obj/item/weapon/gun/pistol/vp78),
	),
	FACTION_UPP = list(
		list(2, /obj/item/explosive/grenade/smokebomb),
		list(2, /obj/item/clothing/head/helmet/marine/veteran/UPP/army),
		list(3, /obj/item/weapon/gun/shotgun/type23),
		list(4, /obj/item/clothing/mask/rebreather),
		list(5, /obj/item/weapon/gun/smg/bizon),
		list(5, /obj/item/storage/pouch/magazine/large),
		list(6, /obj/item/clothing/mask/rebreather/scarf/tacticalmask/green),
		list(7, /obj/item/weapon/gun/pistol/np92),
		list(8, /obj/item/clothing/accessory/storage/webbing),
		list(9, /obj/item/clothing/mask/rebreather/scarf/tacticalmask/black),
		list(10, /obj/item/clothing/accessory/storage/black_vest, "webbing_vest"),
		list(11, /obj/item/weapon/gun/pkp),
		list(12, /obj/item/clothing/mask/rebreather/scarf/tacticalmask/tan),
		list(13, /obj/item/weapon/gun/revolver/upp),
		list(13, /obj/item/storage/belt/gun/type47),
		list(14, /obj/item/clothing/accessory/storage/droppouch/black, "drop_pouch"),
		list(15, /obj/item/weapon/gun/flamer/m240),
		list(15, /obj/item/storage/pouch/flamertank),
		list(16, /obj/item/weapon/gun/rifle/type71/carbine),
		list(17, /obj/item/clothing/head/uppcap/beret),
		list(18, /obj/item/weapon/gun/rifle/ak4047),
		list(19, /obj/item/clothing/head/uppcap/ushanka),
		list(19, /obj/item/clothing/mask/gas),
		list(20, /obj/item/weapon/gun/rifle/sniper/svd),
	),
))

GLOBAL_LIST_INIT(clash_role_levels, list(
	JOB_CARGO_TECH = 3,
	JOB_SQUAD_MEDIC = 3,
	JOB_SQUAD_ENGI = 5,
	JOB_CHIEF_REQUISITION = 6,
	JOB_SQUAD_SMARTGUN = 7,
	JOB_SQUAD_TEAM_LEADER = 9,
	JOB_SQUAD_LEADER = 11,
	JOB_SQUAD_SPECIALIST = 13,
	JOB_UPP_SUPPLY = 3,
	JOB_UPP_MEDIC = 3,
	JOB_UPP_ENGI = 5,
	JOB_UPP_SPECIALIST = 7,
	JOB_UPP_LEADER = 11,
))

GLOBAL_LIST_INIT(clash_arena_roles, list(
	JOB_SQUAD_MARINE,
	JOB_CARGO_TECH,
	JOB_SQUAD_MEDIC,
	JOB_SQUAD_ENGI,
	JOB_SQUAD_SMARTGUN,
	JOB_SQUAD_TEAM_LEADER,
	JOB_SQUAD_LEADER,
	JOB_SQUAD_SPECIALIST,
	JOB_UPP,
	JOB_UPP_SUPPLY,
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

GLOBAL_LIST_INIT(clash_class_gear_levels, list(2, 3, 5, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20))

GLOBAL_LIST_INIT(clash_class_gear, list(
	CLASH_CLASS_RIFLEMAN = list("light_armor", "frag_grenade", "webbing_vest", "heavy_armor", "satchel", "drop_pouch", "second_grenade", "general_pouch", "flare_pouch", "leg_pouch", "utility_belt", "bayonet_sheath", "shoulder_holster", "pistol_pouch", "shotgun_scabbard", "extra_helmet"),
	CLASH_CLASS_MEDIC = list("general_pouch", "light_armor", "satchel", "frag_grenade", "utility_belt", "drop_pouch", "webbing_vest", "flare_pouch", "pistol_pouch", "leg_pouch", "heavy_armor", "shoulder_holster", "bayonet_sheath", "second_grenade", "shotgun_scabbard", "extra_helmet"),
	CLASH_CLASS_ENGINEER = list("utility_belt", "general_pouch", "satchel", "extra_helmet", "heavy_armor", "webbing_vest", "drop_pouch", "shotgun_scabbard", "light_armor", "frag_grenade", "flare_pouch", "leg_pouch", "second_grenade", "bayonet_sheath", "shoulder_holster", "pistol_pouch"),
	CLASH_CLASS_HEAVY = list("heavy_armor", "extra_helmet", "second_grenade", "webbing_vest", "drop_pouch", "satchel", "general_pouch", "frag_grenade", "light_armor", "leg_pouch", "flare_pouch", "utility_belt", "shoulder_holster", "pistol_pouch", "bayonet_sheath", "shotgun_scabbard"),
	CLASH_CLASS_LEADER = list("frag_grenade", "flare_pouch", "light_armor", "webbing_vest", "second_grenade", "drop_pouch", "satchel", "general_pouch", "heavy_armor", "leg_pouch", "utility_belt", "shoulder_holster", "pistol_pouch", "bayonet_sheath", "shotgun_scabbard", "extra_helmet"),
	CLASH_CLASS_SUPPORT = list("light_armor", "general_pouch", "satchel", "pistol_pouch", "flare_pouch", "utility_belt", "frag_grenade", "drop_pouch", "webbing_vest", "leg_pouch", "shoulder_holster", "heavy_armor", "bayonet_sheath", "second_grenade", "shotgun_scabbard", "extra_helmet"),
))

GLOBAL_LIST_INIT(clash_gear_types, list(
	"light_armor" = list(/obj/item/clothing/suit/storage/marine/light, /obj/item/clothing/suit/storage/marine/faction/UPP/support),
	"heavy_armor" = list(/obj/item/clothing/suit/storage/marine/heavy, /obj/item/clothing/suit/storage/marine/faction/UPP/heavy),
	"frag_grenade" = list(/obj/item/explosive/grenade/high_explosive, /obj/item/explosive/grenade/high_explosive/upp),
	"second_grenade" = list(/obj/item/explosive/grenade/high_explosive/m15, /obj/item/explosive/grenade/incendiary, /obj/item/explosive/grenade/phosphorus/upp),
	"webbing_vest" = list(/obj/item/clothing/accessory/storage/black_vest/brown_vest),
	"drop_pouch" = list(/obj/item/clothing/accessory/storage/droppouch),
	"leg_pouch" = list(/obj/item/clothing/accessory/storage/black_vest/leg_pouch),
	"shoulder_holster" = list(/obj/item/clothing/accessory/storage/holster),
	"satchel" = list(/obj/item/storage/backpack/marine/satchel),
	"shotgun_scabbard" = list(/obj/item/storage/large_holster/m37),
	"utility_belt" = list(/obj/item/storage/backpack/general_belt),
	"general_pouch" = list(/obj/item/storage/pouch/general/medium),
	"flare_pouch" = list(/obj/item/storage/pouch/flare/full),
	"pistol_pouch" = list(/obj/item/storage/pouch/pistol),
	"bayonet_sheath" = list(/obj/item/storage/pouch/bayonet, /obj/item/storage/pouch/bayonet/upp),
	"extra_helmet" = list(/obj/item/clothing/head/helmet/marine/tech, /obj/item/clothing/head/helmet/marine/veteran/UPP/heavy),
))

GLOBAL_LIST_INIT(clash_gear_names, list(
	"light_armor" = "light armor",
	"heavy_armor" = "heavy armor",
	"frag_grenade" = "frag grenade",
	"second_grenade" = "second grenade",
	"webbing_vest" = "webbing vest",
	"drop_pouch" = "drop pouch",
	"leg_pouch" = "leg pouch",
	"shoulder_holster" = "shoulder holster",
	"satchel" = "satchel",
	"shotgun_scabbard" = "shotgun scabbard",
	"utility_belt" = "G8-A utility belt",
	"general_pouch" = "medium general pouch",
	"flare_pouch" = "flare pouch",
	"pistol_pouch" = "pistol pouch",
	"bayonet_sheath" = "bayonet sheath",
	"extra_helmet" = "extra helmet",
))

GLOBAL_LIST_INIT(clash_shop_tiers, list(list(1, 5), list(4, 10), list(7, 15), list(10, 20), list(13, 25), list(16, INFINITY)))

GLOBAL_LIST_INIT(clash_carrier_tracks, list(
	CLASH_FAMILY_SHOTGUN = list(
		list(0, /obj/item/storage/pouch/shotgun),
		list(5000, /obj/item/storage/pouch/shotgun/large),
		list(10000, /obj/item/storage/belt/shotgun, /obj/item/storage/belt/shotgun/upp),
	),
	CLASH_FAMILY_MAGAZINE = list(
		list(0, /obj/item/storage/pouch/magazine),
		list(3000, /obj/item/storage/pouch/magazine/large),
	),
	CLASH_FAMILY_SIDEARM = list(
		list(0, /obj/item/storage/pouch/magazine/pistol),
		list(3000, /obj/item/storage/pouch/magazine/pistol/large),
		list(6000, /obj/item/storage/belt/gun/m4a3, /obj/item/storage/belt/gun/m44, /obj/item/storage/belt/gun/m10, /obj/item/storage/belt/gun/type47),
	),
	CLASH_FAMILY_GRENADE = list(
		list(0, /obj/item/storage/pouch/explosive),
		list(2000, /obj/item/storage/belt/grenade, /obj/item/storage/belt/grenade/upp),
		list(4000, /obj/item/storage/belt/grenade/large),
	),
	CLASH_FAMILY_FUEL = list(
		list(2000, /obj/item/storage/pouch/flamertank),
	),
	CLASH_FAMILY_LEVER = list(
		list(3000, /obj/item/storage/belt/shotgun/xm88),
	),
))

GLOBAL_LIST_INIT(clash_family_names, list(
	CLASH_FAMILY_SHOTGUN = "shotgun",
	CLASH_FAMILY_MAGAZINE = "magazine",
	CLASH_FAMILY_SIDEARM = "sidearm",
	CLASH_FAMILY_GRENADE = "grenade",
	CLASH_FAMILY_FUEL = "fuel",
	CLASH_FAMILY_LEVER = "lever-action",
))

GLOBAL_LIST_INIT(clash_free_role_gear, list(/obj/item/storage/backpack/marine/satchel/medic, /obj/item/storage/backpack/marine/satchel/tech))

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
		for(var/item_type in GLOB.clash_free_role_gear)
			gates[clash_gate_key(faction, item_type)] = list("kind" = CLASH_GATE_FREE)
		for(var/gear in GLOB.clash_gear_types)
			for(var/item_type in GLOB.clash_gear_types[gear])
				gates[clash_gate_key(faction, item_type)] = list("kind" = CLASH_GATE_CLASS, "gear" = gear)
		for(var/family in GLOB.clash_carrier_tracks)
			var/list/steps = GLOB.clash_carrier_tracks[family]
			for(var/step in 1 to length(steps))
				var/list/carrier_step = steps[step]
				for(var/index in 2 to length(carrier_step))
					gates[clash_gate_key(faction, carrier_step[index])] = list("kind" = CLASH_GATE_CARRIER, "family" = family, "step" = step, "xp" = carrier_step[1])
		for(var/list/rung as anything in GLOB.clash_faction_ladders[faction])
			var/key = clash_gate_key(faction, rung[2])
			if(length(rung) > 2)
				gates[key] = list("kind" = CLASH_GATE_TWIN, "level" = rung[1], "gear" = rung[3])
			else if(gates[key]?["kind"] == CLASH_GATE_CARRIER)
				gates[key]["level"] = rung[1]
			else
				gates[key] = list("kind" = CLASH_GATE_FACTION, "level" = rung[1])

/proc/clash_class_gear_level(class, gear)
	var/list/order = GLOB.clash_class_gear[class]
	var/index = order?.Find(gear)
	return index ? GLOB.clash_class_gear_levels[index] : null

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

/proc/clash_insignia_name(faction, level)
	var/list/names = GLOB.clash_insignia_names[faction]
	level = clamp(level, 1, CLASH_LEVEL_CAP)
	var/rank = CEILING(level / 2, 1)
	return "[names[rank]] [level % 2 ? "I" : "II"]"

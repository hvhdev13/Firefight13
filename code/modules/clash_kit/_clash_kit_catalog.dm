// Team Deathmatch kits: a curated menu per faction, one pick per slot, applied over the job's issue gear on spawn.
#define KIT_SLOT_HELMET "helmet"
#define KIT_SLOT_ARMOR "armor"
#define KIT_SLOT_MASK "mask"
#define KIT_SLOT_BACK "back"
#define KIT_SLOT_BELT "belt"
#define KIT_SLOT_POUCH_L "pouch_l"
#define KIT_SLOT_POUCH_R "pouch_r"
#define KIT_SLOT_PRIMARY "primary"
#define KIT_SLOT_SIDEARM "sidearm"
#define KIT_SLOT_GRENADE "grenade"
#define KIT_SLOT_RAIL "rail"
#define KIT_SLOT_MUZZLE "muzzle"
#define KIT_SLOT_UNDER "under"
#define KIT_SLOT_STOCK "stock"
/// Slots whose picks go on the primary weapon
GLOBAL_LIST_INIT(clash_kit_attachment_slots, list(KIT_SLOT_RAIL, KIT_SLOT_MUZZLE, KIT_SLOT_UNDER, KIT_SLOT_STOCK))
/// Kits a player may keep per role
#define CLASH_KIT_COUNT 5

/// Kit slots in display order
GLOBAL_LIST_INIT(clash_kit_slots, list(
	KIT_SLOT_HELMET = list("name" = "Helmet", "image" = "inventory-head.png", "wear" = WEAR_HEAD),
	KIT_SLOT_ARMOR = list("name" = "Armor", "image" = "inventory-suit.png", "wear" = WEAR_JACKET),
	KIT_SLOT_MASK = list("name" = "Mask", "image" = "inventory-mask.png", "wear" = WEAR_FACE),
	KIT_SLOT_BACK = list("name" = "Back", "image" = "inventory-back.png", "wear" = WEAR_BACK),
	KIT_SLOT_BELT = list("name" = "Belt", "image" = "inventory-belt.png", "wear" = WEAR_WAIST),
	KIT_SLOT_POUCH_L = list("name" = "Left pouch", "image" = "inventory-pocket.png", "wear" = WEAR_L_STORE),
	KIT_SLOT_POUCH_R = list("name" = "Right pouch", "image" = "inventory-pocket.png", "wear" = WEAR_R_STORE),
	KIT_SLOT_PRIMARY = list("name" = "Primary", "image" = "inventory-suit_storage.png", "wear" = WEAR_J_STORE),
	KIT_SLOT_SIDEARM = list("name" = "Sidearm", "image" = "inventory-hand_r.png", "wear" = null),
	KIT_SLOT_GRENADE = list("name" = "Grenades", "image" = "inventory-pocket.png", "wear" = null),
	KIT_SLOT_RAIL = list("name" = "Rail", "image" = null, "wear" = null),
	KIT_SLOT_MUZZLE = list("name" = "Muzzle", "image" = null, "wear" = null),
	KIT_SLOT_UNDER = list("name" = "Underbarrel", "image" = null, "wear" = null),
	KIT_SLOT_STOCK = list("name" = "Stock", "image" = null, "wear" = null),
))

/// Option id to option
GLOBAL_LIST_EMPTY(clash_kit_options)
/// Faction to slot to list of options, in menu order
GLOBAL_LIST_EMPTY(clash_kit_menu)
/// Gun type to the attachment types it takes, read off one instance each
GLOBAL_LIST_EMPTY(clash_kit_gun_attachables)

/// One thing a player can put in a kit slot
/datum/clash_kit_option
	var/id
	var/name
	/// One line under the name in the menu
	var/blurb
	var/item_type
	var/faction
	var/slot
	/// Guns: magazine type and how many come with it. Grenades: how many
	var/ammo_type
	var/ammo_count = 0
	/// Numbers shown under the name, list of list(label, value), read off an instance once
	var/list/stats = list()

/proc/add_clash_kit_option(faction, slot, name, item_type, blurb, ammo_type, ammo_count = 0)
	var/datum/clash_kit_option/option = new
	option.id = "[item_type]"
	option.name = name
	option.blurb = blurb
	option.item_type = item_type
	option.faction = faction
	option.slot = slot
	option.ammo_type = ammo_type
	option.ammo_count = ammo_count
	GLOB.clash_kit_options[option.id] = option
	var/list/slots = GLOB.clash_kit_menu[faction]
	if(!slots)
		slots = list()
		GLOB.clash_kit_menu[faction] = slots
	var/list/options = slots[slot]
	if(!options)
		options = list()
		slots[slot] = options
	options += option
	option.stats = read_clash_kit_stats(option)
	return option

/// The numbers worth comparing for an option, from one throwaway instance
/proc/read_clash_kit_stats(datum/clash_kit_option/option)
	. = list()
	var/obj/item/sample = new option.item_type
	if(istype(sample, /obj/item/clothing))
		var/obj/item/clothing/worn = sample
		if(worn.armor_bullet || worn.armor_melee || worn.armor_bomb)
			. += list(list("Bullet", worn.armor_bullet), list("Melee", worn.armor_melee), list("Blast", worn.armor_bomb))
		if(worn.slowdown)
			. += list(list("Slowdown", worn.slowdown))
	else if(istype(sample, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/gun = sample
		if(option.ammo_type)
			var/obj/item/ammo_magazine/magazine = option.ammo_type
			var/datum/ammo/round = GLOB.ammo_list[initial(magazine.default_ammo)]
			if(round)
				. += list(list("Damage", round.damage))
				if(round.penetration)
					. += list(list("AP", round.penetration))
			. += list(list("Rounds", initial(magazine.max_rounds)))
		var/delay = gun.get_fire_delay()
		if(delay > 0)
			. += list(list("RPM", round(600 / delay)))
	else if(isstorage(sample))
		var/obj/item/storage/holder = sample
		if(holder.storage_slots)
			. += list(list("Slots", holder.storage_slots))
	qdel(sample)

/proc/get_clash_kit_option(id)
	return id ? GLOB.clash_kit_options[id] : null

/// Attachment types a gun takes, cached off an instance since the list is only set at runtime
/proc/get_clash_gun_attachables(gun_type)
	if(!gun_type)
		return list()
	var/list/allowed = GLOB.clash_kit_gun_attachables[gun_type]
	if(isnull(allowed))
		var/obj/item/weapon/gun/gun = new gun_type
		allowed = gun.attachable_allowed?.Copy() || list()
		GLOB.clash_kit_gun_attachables[gun_type] = allowed
		qdel(gun)
	return allowed

/proc/clash_kit_attachment_fits(attachment_type, gun_type)
	return attachment_type in get_clash_gun_attachables(gun_type)

/// Builds both factions' menus once
/proc/build_clash_kit_catalog()
	if(length(GLOB.clash_kit_options))
		return
	build_clash_kit_shared(FACTION_MARINE)
	build_clash_kit_shared(FACTION_UPP)
	build_clash_kit_uscm()
	build_clash_kit_upp()

/// Pouches and attachments both sides field the same way
/proc/build_clash_kit_shared(faction)
	for(var/slot in list(KIT_SLOT_POUCH_L, KIT_SLOT_POUCH_R))
		add_clash_kit_option(faction, slot, "Magazine pouch", /obj/item/storage/pouch/magazine, "Three rifle magazines")
		add_clash_kit_option(faction, slot, "Large magazine pouch", /obj/item/storage/pouch/magazine/large, "More magazines, slower to draw from")
		add_clash_kit_option(faction, slot, "Pistol magazine pouch", /obj/item/storage/pouch/magazine/pistol/large, "Sidearm magazines")
		add_clash_kit_option(faction, slot, "Pistol pouch", /obj/item/storage/pouch/pistol, "Holsters a sidearm on the hip")
		add_clash_kit_option(faction, slot, "Shotgun shell pouch", /obj/item/storage/pouch/shotgun, "Shells and slugs")
		add_clash_kit_option(faction, slot, "First aid pouch", /obj/item/storage/pouch/firstaid/full, "Autoinjectors, refillable")
		add_clash_kit_option(faction, slot, "Flare pouch", /obj/item/storage/pouch/flare/full, "Light up a lane")
		add_clash_kit_option(faction, slot, "Medium general pouch", /obj/item/storage/pouch/general/medium, "Grenades, tools, whatever fits")
		add_clash_kit_option(faction, slot, "Bayonet sheath", faction == FACTION_UPP ? /obj/item/storage/pouch/bayonet/upp : /obj/item/storage/pouch/bayonet, "Spare blade on the hip")
	add_clash_kit_option(faction, KIT_SLOT_RAIL, "Red dot sight", /obj/item/attachable/reddot, "Accuracy up")
	add_clash_kit_option(faction, KIT_SLOT_RAIL, "Reflex sight", /obj/item/attachable/reflex, "Accuracy up, less than the red dot, no scatter penalty")
	add_clash_kit_option(faction, KIT_SLOT_RAIL, "Rail flashlight", /obj/item/attachable/flashlight, "Light")
	add_clash_kit_option(faction, KIT_SLOT_RAIL, "Magnetic harness", /obj/item/attachable/magnetic_harness, "The gun returns to you when dropped")
	add_clash_kit_option(faction, KIT_SLOT_RAIL, "S4 2x mini scope", /obj/item/attachable/scope/mini, "Short zoom on aim")
	add_clash_kit_option(faction, KIT_SLOT_MUZZLE, "Extended barrel", /obj/item/attachable/extended_barrel, "Damage and accuracy up, recoil up")
	add_clash_kit_option(faction, KIT_SLOT_MUZZLE, "Suppressor", /obj/item/attachable/suppressor, "Quiet, less recoil, less damage")
	add_clash_kit_option(faction, KIT_SLOT_MUZZLE, "Recoil compensator", /obj/item/attachable/compensator, "Recoil and scatter down")
	add_clash_kit_option(faction, KIT_SLOT_MUZZLE, faction == FACTION_UPP ? "Type 80 bayonet" : "M5 bayonet", faction == FACTION_UPP ? /obj/item/attachable/bayonet/upp : /obj/item/attachable/bayonet, "Melee with the gun")
	add_clash_kit_option(faction, KIT_SLOT_UNDER, "Vertical grip", /obj/item/attachable/verticalgrip, "Recoil and scatter down, wield slower")
	add_clash_kit_option(faction, KIT_SLOT_UNDER, "Angled grip", /obj/item/attachable/angledgrip, "Wield faster")
	add_clash_kit_option(faction, KIT_SLOT_UNDER, "Flashlight grip", /obj/item/attachable/flashlight/grip, "Light and a little stability")
	add_clash_kit_option(faction, KIT_SLOT_UNDER, "Laser sight", /obj/item/attachable/lasersight, "Hipfire accuracy up")
	add_clash_kit_option(faction, KIT_SLOT_UNDER, "Underslung grenade launcher", /obj/item/attachable/attached_gun/grenade, "Two 40mm grenades")
	add_clash_kit_option(faction, KIT_SLOT_STOCK, "Rifle stock", /obj/item/attachable/stock/rifle, "Recoil and scatter down, slower")
	add_clash_kit_option(faction, KIT_SLOT_STOCK, "Folding rifle stock", /obj/item/attachable/stock/rifle/collapsible, "Fold it for speed, extend it for control")
	add_clash_kit_option(faction, KIT_SLOT_STOCK, "Folding SMG stock", /obj/item/attachable/stock/smg/collapsible, "Same, for the SMG")

/proc/build_clash_kit_uscm()
	var/faction = FACTION_MARINE
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "M10 helmet", /obj/item/clothing/head/helmet/marine, "Standard issue")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "M10 helmet, jungle", /obj/item/clothing/head/helmet/marine/jungle, "Same helmet, jungle pattern")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "M10 helmet, desert", /obj/item/clothing/head/helmet/marine/desert, "Same helmet, desert pattern")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "M10 helmet, urban", /obj/item/clothing/head/helmet/marine/urban, "Same helmet, urban pattern")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "M10 technician helmet", /obj/item/clothing/head/helmet/marine/tech, "Standard helmet with a visor")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "M3 light armor", /obj/item/clothing/suit/storage/marine/light, "Fast. Thinner plates, fewer pockets")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "M3 medium armor", /obj/item/clothing/suit/storage/marine/medium, "The balance. Standard issue")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "M3-EOD heavy armor", /obj/item/clothing/suit/storage/marine/heavy, "Slow. Shrugs off bullets and blasts")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Gas mask", /obj/item/clothing/mask/gas, "Full face")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Rebreather", /obj/item/clothing/mask/rebreather, "Low profile")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Heat absorbent coif", /obj/item/clothing/mask/rebreather/scarf, "Scarf and rebreather")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Backpack", /obj/item/storage/backpack/marine, "Most room")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Satchel", /obj/item/storage/backpack/marine/satchel, "Less room, open it without taking it off")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Shotgun scabbard", /obj/item/storage/large_holster/m37, "Carries a shotgun on the back")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 ammo load rig", /obj/item/storage/belt/marine, "Rifle magazines")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 M4A3 holster rig", /obj/item/storage/belt/gun/m4a3, "Holsters the M4A3 or 88 Mod 4 with spare magazines")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 M44 holster rig", /obj/item/storage/belt/gun/m44, "Holsters the revolver with speedloaders")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 M10 holster rig", /obj/item/storage/belt/gun/m10, "Holsters the M10 with spare magazines")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 shotgun shell rig", /obj/item/storage/belt/shotgun, "Shells and slugs")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "M276 M40 grenade rig", /obj/item/storage/belt/grenade, "Grenades on the hip")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "G8-A general utility pouch", /obj/item/storage/backpack/general_belt, "Anything that fits")
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "M40 HEDP", /obj/item/explosive/grenade/high_explosive, "High explosive, dual purpose", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "M15 fragmentation", /obj/item/explosive/grenade/high_explosive/m15, "Old pattern, bigger bang, longer fuse", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "M40 HIDP incendiary", /obj/item/explosive/grenade/incendiary, "Sets the ground alight", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "M40 HSDP smoke", /obj/item/explosive/grenade/smokebomb, "Cover to cross", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "M41A pulse rifle", /obj/item/weapon/gun/rifle/m41a, "All rounder. Burst and full auto", /obj/item/ammo_magazine/rifle, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "M4RA battle rifle", /obj/item/weapon/gun/rifle/m4ra, "Hits hard at range. Semi auto", /obj/item/ammo_magazine/rifle/m4ra, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "M37A2 pump shotgun", /obj/item/weapon/gun/shotgun/pump/m37a, "Wins the doorway. Buckshot", /obj/item/ammo_magazine/shotgun/buckshot, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "M39 submachine gun", /obj/item/weapon/gun/smg/m39, "Fast handling, fast firing, short reach", /obj/item/ammo_magazine/smg/m39, 4)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "M4A3 service pistol", /obj/item/weapon/gun/pistol/m4a3, "Standard sidearm", /obj/item/ammo_magazine/pistol, 3)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "88 Mod 4 combat pistol", /obj/item/weapon/gun/pistol/mod88, "Armor piercing, full auto", /obj/item/ammo_magazine/pistol/mod88/normalpoint, 3)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "M44 combat revolver", /obj/item/weapon/gun/revolver/m44, "Six heavy rounds", /obj/item/ammo_magazine/revolver, 3)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "M10 auto pistol", /obj/item/weapon/gun/pistol/m10, "Small and quick", /obj/item/ammo_magazine/pistol/m10, 3)

/proc/build_clash_kit_upp()
	var/faction = FACTION_UPP
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "UM4 helmet", /obj/item/clothing/head/helmet/marine/veteran/UPP, "Standard issue, heavy on the neck")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "UM4 heavy helmet", /obj/item/clothing/head/helmet/marine/veteran/UPP/heavy, "More plate, more weight")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "UM4 helmet, army", /obj/item/clothing/head/helmet/marine/veteran/UPP/army, "Same helmet, army pattern")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "UL3 armored beret", /obj/item/clothing/head/uppcap/beret, "Light. Some plate under the cloth")
	add_clash_kit_option(faction, KIT_SLOT_HELMET, "UL8 armored ushanka", /obj/item/clothing/head/uppcap/ushanka, "Light. Warm, some plate")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "UL6 light armor", /obj/item/clothing/suit/storage/marine/faction/UPP/support, "Fast. No neck guard")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "UM5 medium armor", /obj/item/clothing/suit/storage/marine/faction/UPP, "The balance. Standard issue")
	add_clash_kit_option(faction, KIT_SLOT_ARMOR, "UH7 heavy armor", /obj/item/clothing/suit/storage/marine/faction/UPP/heavy, "Slow. Shrugs off bullets and blasts")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Tactical mask, green", /obj/item/clothing/mask/rebreather/scarf/tacticalmask/green, "Scarf and rebreather")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Tactical mask, black", /obj/item/clothing/mask/rebreather/scarf/tacticalmask/black, "Scarf and rebreather")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Tactical mask, tan", /obj/item/clothing/mask/rebreather/scarf/tacticalmask/tan, "Scarf and rebreather")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Gas mask", /obj/item/clothing/mask/gas, "Full face")
	add_clash_kit_option(faction, KIT_SLOT_MASK, "Rebreather", /obj/item/clothing/mask/rebreather, "Low profile")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Combat pack", /obj/item/storage/backpack/lightpack/upp, "Standard issue")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Satchel", /obj/item/storage/backpack/marine/satchel, "Less room, open it without taking it off")
	add_clash_kit_option(faction, KIT_SLOT_BACK, "Shotgun scabbard", /obj/item/storage/large_holster/m37, "Carries a shotgun on the back")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "Type 41 ammo load rig", /obj/item/storage/belt/marine/upp, "Rifle magazines")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "NPZ92 holster rig", /obj/item/storage/belt/gun/type47, "Holsters a pistol with spare magazines")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "Type 42 shotgun shell rig", /obj/item/storage/belt/shotgun/upp, "Shells and slugs")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "Type 46 grenade rig", /obj/item/storage/belt/grenade/upp, "Grenades on the hip")
	add_clash_kit_option(faction, KIT_SLOT_BELT, "G8-A general utility pouch", /obj/item/storage/backpack/general_belt, "Anything that fits")
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "Type 6 shrapnel", /obj/item/explosive/grenade/high_explosive/upp, "Union pattern, fragments wide", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "Type 8 WP", /obj/item/explosive/grenade/phosphorus/upp, "White phosphorus. Burns and blinds", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_GRENADE, "Smoke grenade", /obj/item/explosive/grenade/smokebomb, "Cover to cross", null, 2)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "Type 71 pulse rifle", /obj/item/weapon/gun/rifle/type71, "All rounder. Burst and full auto", /obj/item/ammo_magazine/rifle/type71, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "Type 71 carbine", /obj/item/weapon/gun/rifle/type71/carbine, "Lighter and quicker, less reach", /obj/item/ammo_magazine/rifle/type71/carbine, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "AK-4047", /obj/item/weapon/gun/rifle/ak4047, "Big magazine, big kick", /obj/item/ammo_magazine/rifle/ak4047, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "Type 64 submachine gun", /obj/item/weapon/gun/smg/bizon, "Fast handling, helical magazine", /obj/item/ammo_magazine/smg/bizon, 4)
	add_clash_kit_option(faction, KIT_SLOT_PRIMARY, "Type 23 shotgun", /obj/item/weapon/gun/shotgun/type23, "Wins the doorway. Heavy buckshot", /obj/item/ammo_magazine/shotgun/heavy/buckshot, 4)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "Type 73 pistol", /obj/item/weapon/gun/pistol/t73, "Standard sidearm", /obj/item/ammo_magazine/pistol/t73, 3)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "NP92 pistol", /obj/item/weapon/gun/pistol/np92, "Bigger magazine", /obj/item/ammo_magazine/pistol/np92, 3)
	add_clash_kit_option(faction, KIT_SLOT_SIDEARM, "Type 44 revolver", /obj/item/weapon/gun/revolver/upp, "Six heavy rounds", /obj/item/ammo_magazine/revolver/upp, 3)

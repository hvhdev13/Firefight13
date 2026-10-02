# Kit presets (archived)

Archived on 2026-10-02. The loadout screen used to fill tabs 2 to 4 of every role with
these presets. They were taken out because they unlocked nothing the player could not
build in a Custom tab. Every part is gated on its own (gun by faction level, attachments
by weapon level, carriers by ammo XP, gear by class level). Kept here to bring back once
they have a place in the progression system.

Now every role starts with one tab, Default (the role's issued gear), and the other tabs
are empty Custom tabs the player names and builds. See `get_clash_kits` in
`code/modules/clash_kit/clash_kit.dm`.

## How they were wired

- `add_clash_kit_preset()` and `build_clash_kit_presets()` in `_clash_kit_catalog.dm`
  added them per side, in this order, into `GLOB.clash_kit_presets`. The builder ran from
  `build_clash_kit_catalog()`, after the gun attachments and before the weapon tracks.
- `get_clash_kit_role_presets(job)` (below) built a role's starting tabs: Default, then
  presets 2 to 4 of its side. Rifleman and Ryadovoy got the whole preset. Other roles only
  got the weapon slots (`GLOB.clash_kit_weapon_slots`). Heavy roles (Smartgunner, Weapons
  Specialist, UPP Serzhant) got no presets.
- Unarmed roles were meant to have Default and the first preset swapped so they spawned
  armed, but `job in GLOB.clash_kit_unarmed_roles && length(classes) > 1` parses as
  `job in (list && TRUE)`, so the swap never ran. Wrap the `in` test in brackets if this
  comes back.
- The first preset (Rifleman) was never used as a tab.
- Progression unlock levels, by class level (`GLOB.clash_preset_levels` in
  `clash_progression_ladders.dm`), with a NEW PRESET pop-up (`CLASH_UNLOCK_PRESET`, grey
  #8A939C, order 7, `sound/machines/terminal_button01.ogg`): Rifleman 1, Assault and
  Carbineer 6, Breacher 14, Marksman and Gunner 24. The levels were never enforced; each
  part was filtered at spawn instead.

## The presets

```dm
/proc/add_clash_kit_preset(faction, name, list/types_by_slot)
	var/list/choices = list()
	var/primary_type = types_by_slot[KIT_SLOT_PRIMARY]
	for(var/slot in types_by_slot)
		var/datum/clash_kit_option/option = get_clash_kit_option(clash_kit_option_id(faction, slot, types_by_slot[slot]))
		if(!option)
			stack_trace("Clash kit preset [name] names [types_by_slot[slot]] for [slot], which the [faction] menu does not have")
			continue
		if((slot in GLOB.clash_kit_attachment_slots) && !clash_kit_attachment_fits(option.item_type, primary_type))
			continue
		choices[slot] = option.id
	var/list/presets = GLOB.clash_kit_presets[faction]
	if(!presets)
		presets = list()
		GLOB.clash_kit_presets[faction] = presets
	presets += list(list(name, choices))

/proc/build_clash_kit_presets()
	add_clash_kit_preset(FACTION_MARINE, "Rifleman", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/m41a, KIT_SLOT_RAIL = /obj/item/attachable/reddot,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/medium, KIT_SLOT_BELT = /obj/item/storage/belt/marine,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full, KIT_SLOT_POUCH_R = /obj/item/storage/pouch/explosive,
		KIT_SLOT_GRENADE = /obj/item/explosive/grenade/high_explosive,
	))
	add_clash_kit_preset(FACTION_MARINE, "Assault", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/m41a, KIT_SLOT_RAIL = /obj/item/attachable/reflex, KIT_SLOT_UNDER = /obj/item/attachable/verticalgrip,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/light, KIT_SLOT_BELT = /obj/item/storage/belt/gun/m4a3,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/m4a3, KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine, KIT_SLOT_GRENADE = /obj/item/explosive/grenade/smokebomb,
	))
	add_clash_kit_preset(FACTION_MARINE, "Breacher", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/m41a, KIT_SLOT_RAIL = /obj/item/attachable/flashlight,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/heavy, KIT_SLOT_BELT = /obj/item/storage/belt/shotgun,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/mod88, KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/shotgun, KIT_SLOT_GRENADE = /obj/item/explosive/grenade/high_explosive,
	))
	add_clash_kit_preset(FACTION_MARINE, "Marksman", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/m41a, KIT_SLOT_RAIL = /obj/item/attachable/scope/mini, KIT_SLOT_MUZZLE = /obj/item/attachable/extended_barrel,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/medium, KIT_SLOT_BELT = /obj/item/storage/belt/gun/m44,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/revolver/m44, KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine,
	))
	add_clash_kit_preset(FACTION_UPP, "Rifleman", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine/veteran/UPP,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/type71, KIT_SLOT_RAIL = /obj/item/attachable/reddot,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/faction/UPP, KIT_SLOT_BELT = /obj/item/storage/belt/marine/upp,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full, KIT_SLOT_POUCH_R = /obj/item/storage/pouch/explosive,
		KIT_SLOT_GRENADE = /obj/item/explosive/grenade/high_explosive/upp,
	))
	add_clash_kit_preset(FACTION_UPP, "Carbineer", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine/veteran/UPP,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/type71, KIT_SLOT_RAIL = /obj/item/attachable/reflex, KIT_SLOT_UNDER = /obj/item/attachable/verticalgrip,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/faction/UPP/support, KIT_SLOT_BELT = /obj/item/storage/belt/gun/type47,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/t73, KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine, KIT_SLOT_GRENADE = /obj/item/explosive/grenade/smokebomb,
	))
	add_clash_kit_preset(FACTION_UPP, "Breacher", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine/veteran/UPP/heavy,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/type71,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/faction/UPP/heavy, KIT_SLOT_BELT = /obj/item/storage/belt/shotgun/upp,
		KIT_SLOT_SIDEARM = /obj/item/weapon/gun/pistol/np92, KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full,
		KIT_SLOT_POUCH_R = /obj/item/storage/pouch/shotgun, KIT_SLOT_GRENADE = /obj/item/explosive/grenade/phosphorus/upp,
	))
	add_clash_kit_preset(FACTION_UPP, "Gunner", list(
		KIT_SLOT_HELMET = /obj/item/clothing/head/helmet/marine/veteran/UPP,
		KIT_SLOT_PRIMARY = /obj/item/weapon/gun/rifle/type71, KIT_SLOT_RAIL = /obj/item/attachable/reddot, KIT_SLOT_MUZZLE = /obj/item/attachable/compensator,
		KIT_SLOT_ARMOR = /obj/item/clothing/suit/storage/marine/faction/UPP, KIT_SLOT_BELT = /obj/item/storage/belt/marine/upp,
		KIT_SLOT_POUCH_L = /obj/item/storage/pouch/firstaid/full, KIT_SLOT_POUCH_R = /obj/item/storage/pouch/magazine/large,
		KIT_SLOT_GRENADE = /obj/item/explosive/grenade/high_explosive/upp,
	))
```

```dm
GLOBAL_LIST_INIT(clash_preset_levels, list(
	"Rifleman" = 1,
	"Assault" = 6,
	"Carbineer" = 6,
	"Breacher" = 14,
	"Marksman" = 24,
	"Gunner" = 24,
))
```

## The old tab builder

```dm
GLOBAL_LIST_INIT(clash_kit_rifleman_roles, list(JOB_SQUAD_MARINE, JOB_UPP))
GLOBAL_LIST_INIT(clash_kit_heavy_roles, list(JOB_SQUAD_SMARTGUN, JOB_SQUAD_SPECIALIST, JOB_UPP_SPECIALIST))
GLOBAL_LIST_INIT(clash_kit_unarmed_roles, list(JOB_SQUAD_TEAM_LEADER, JOB_DOCTOR, JOB_NURSE, JOB_FIELD_DOCTOR, JOB_CHIEF_REQUISITION, JOB_CARGO_TECH, JOB_UPP_LT_DOKTOR, JOB_UPP_SUPPLY))
GLOBAL_LIST_INIT(clash_kit_weapon_slots, list(KIT_SLOT_HELMET, KIT_SLOT_ARMOR, KIT_SLOT_PRIMARY, KIT_SLOT_SIDEARM, KIT_SLOT_RAIL, KIT_SLOT_MUZZLE, KIT_SLOT_UNDER, KIT_SLOT_STOCK, KIT_SLOT_GRENADE))
GLOBAL_LIST_EMPTY(clash_kit_presets)
GLOBAL_LIST_EMPTY(clash_kit_role_presets)

/proc/get_clash_kit_role_presets(job)
	if(GLOB.clash_kit_role_presets[job])
		return GLOB.clash_kit_role_presets[job]
	var/list/classes = list(list("Default", list()))
	GLOB.clash_kit_role_presets[job] = classes
	if(job in GLOB.clash_kit_heavy_roles)
		return classes
	var/list/side_classes = GLOB.clash_kit_presets[clash_kit_faction_for_job(job)]
	var/whole_kit = (job in GLOB.clash_kit_rifleman_roles)
	for(var/index in 2 to length(side_classes))
		var/list/side_class = side_classes[index]
		var/list/choices = side_class[2]
		var/list/kept = list()
		for(var/slot in choices)
			if(whole_kit || (slot in GLOB.clash_kit_weapon_slots))
				kept[slot] = choices[slot]
		classes += list(list(side_class[1], kept))
	if(job in GLOB.clash_kit_unarmed_roles && length(classes) > 1)
		classes.Swap(1, 2)
	return classes
```

The tab seeding in `get_clash_kits` (`clash_kit.dm`) used the list like this:

```dm
/proc/get_clash_kits(ckey, job)
	if(!ckey || !job)
		return null
	build_clash_kit_catalog()
	var/list/by_job = GLOB.clash_kits[ckey]
	if(!by_job)
		by_job = list()
		GLOB.clash_kits[ckey] = by_job
		GLOB.clash_active_kits[ckey] = list()
		load_clash_kits(ckey)
	var/list/kits = by_job[job]
	var/list/presets = kits ? list() : get_clash_kit_role_presets(job)
	if(!kits)
		kits = list()
		by_job[job] = kits
	while(length(kits) < CLASH_KIT_COUNT)
		var/datum/clash_kit/kit = new
		var/list/preset = length(presets) > length(kits) ? presets[length(kits) + 1] : null
		if(preset)
			var/list/preset_choices = preset[2]
			kit.name = preset[1]
			kit.choices = preset_choices.Copy()
		else
			var/customs = 1
			for(var/datum/clash_kit/other as anything in kits)
				if(findtext(other.name, "Custom") == 1)
					customs++
			kit.name = customs > 1 ? "Custom [customs]" : "Custom"
		kits += kit
	return kits
```

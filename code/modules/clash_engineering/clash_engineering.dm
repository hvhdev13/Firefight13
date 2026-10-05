#define CLASH_METAL_BARRICADE_TIME (1 SECONDS)
#define CLASH_PLASTEEL_BARRICADE_TIME (3 SECONDS)

GLOBAL_LIST_INIT(clash_arena_eng_removed, list(
	/obj/item/circuitboard,
	/obj/item/cell,
	/obj/item/engi_upgrade_kit,
	/obj/item/defenses/handheld,
	/obj/item/storage/belt/gun/brutepack,
	/obj/item/explosive/mine,
	/obj/item/storage/box/explosive_mines,
))

/proc/clash_arena_eng_removed(item_type)
	for(var/family in GLOB.clash_arena_eng_removed)
		if(ispath(item_type, family))
			return TRUE
	return FALSE

/proc/clash_arena_engineering_setup()
	for(var/datum/stack_recipe/recipe in GLOB.metal_recipes)
		if(recipe.result_type == /obj/structure/barricade/metal)
			recipe.time = CLASH_METAL_BARRICADE_TIME
			recipe.min_time = CLASH_METAL_BARRICADE_TIME
	for(var/datum/stack_recipe/recipe in GLOB.plasteel_recipes)
		if(recipe.result_type == /obj/structure/barricade/metal/plasteel)
			recipe.time = CLASH_PLASTEEL_BARRICADE_TIME
			recipe.min_time = CLASH_PLASTEEL_BARRICADE_TIME

/obj/item/storage/pouch/construction/clash
	name = "engineer pouch"
	desc = "Metal, plasteel and filled sandbags for building cover and reloading sentries."
	can_hold = list(
		/obj/item/stack/sheet,
		/obj/item/stack/sandbags,
		/obj/item/stack/sandbags_empty,
		/obj/item/stack/barbed_wire,
	)

/obj/item/storage/pouch/construction/clash/fill_preset_inventory()
	new /obj/item/stack/sheet/metal(src, 25)
	new /obj/item/stack/sheet/plasteel(src, 12)
	new /obj/item/stack/sandbags(src, 15)

/proc/clash_issue_engineer_gear(mob/living/carbon/human/engineer)
	if(!clash_fast_medicine() || !engineer.ckey)
		return
	var/ckey = engineer.ckey
	if(!clash_is_engineer(engineer))
		clash_remove_engineer_builds(ckey, TRUE)
		return
	for(var/obj/item/defenses/handheld/stray in engineer.get_contents())
		var/obj/structure/machinery/defenses/sentry/turret = stray.TR
		if(!istype(turret) || !turret.clash_tier)
			qdel(stray)
	for(var/wear_slot in list(WEAR_L_STORE, WEAR_R_STORE))
		var/obj/item/worn = engineer.get_item_by_slot(wear_slot)
		if(istype(worn, /obj/item/storage/pouch/construction) && !istype(worn, /obj/item/storage/pouch/construction/clash))
			QDEL_LIST(worn.contents)
			clash_kit_replace_worn(engineer, wear_slot, /obj/item/storage/pouch/construction/clash)
	var/list/carried = engineer.get_contents()
	if(!(locate(/obj/item/tool/wrench) in carried))
		clash_give_engineer_item(engineer, new /obj/item/tool/wrench(engineer))
	if(!(locate(/obj/item/tool/weldingtool) in carried))
		clash_give_engineer_item(engineer, new /obj/item/tool/weldingtool(engineer))
	clash_remove_engineer_builds(ckey, FALSE)
	var/list/sentries = GLOB.clash_engineer_sentries[ckey]
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in sentries?.Copy())
		if(turret.clash_faction == engineer.faction)
			turret.owner_mob = engineer
		else
			qdel(turret)
	var/list/crates = GLOB.clash_engineer_crates[ckey]
	for(var/obj/item/clash_ammo_crate/old_crate as anything in crates?.Copy())
		if(old_crate.deployed?.faction != engineer.faction)
			qdel(old_crate)
	clash_give_engineer_item(engineer, clash_new_sentry(engineer, clash_engineer_sentry_choice(engineer)))
	clash_give_engineer_item(engineer, clash_new_crate(engineer))

/proc/clash_new_sentry(mob/living/carbon/human/engineer, tier)
	var/kit_type = clash_sentry_kit_for(engineer.faction, tier)
	var/obj/item/defenses/handheld/packed = new kit_type(engineer)
	var/obj/structure/machinery/defenses/sentry/fresh = packed.TR
	fresh.clash_owner_ckey = engineer.ckey
	LAZYADDASSOCLIST(GLOB.clash_engineer_sentries, engineer.ckey, fresh)
	return packed

/proc/clash_new_crate(mob/living/carbon/human/engineer)
	var/crate_type = engineer.faction == FACTION_UPP ? /obj/item/clash_ammo_crate/upp : /obj/item/clash_ammo_crate
	var/obj/item/clash_ammo_crate/crate = new crate_type(engineer)
	crate.owner_ckey = engineer.ckey
	LAZYADDASSOCLIST(GLOB.clash_engineer_crates, engineer.ckey, crate)
	return crate

/proc/clash_engineer_vendor_entries(faction)
	. = list(list("ENGINEER BUILDS", 0, null, null, null))
	for(var/tier in GLOB.clash_sentry_tiers)
		. += list(list(GLOB.clash_sentry_tiers[tier]["name"], 0, clash_sentry_kit_for(faction, tier), null, VENDOR_ITEM_REGULAR))
	. += list(list("Ammo Crate", 0, faction == FACTION_UPP ? /obj/item/clash_ammo_crate/upp : /obj/item/clash_ammo_crate, null, VENDOR_ITEM_REGULAR))

/proc/clash_build_owned_text(mob/living/carbon/human/engineer, list/owned, label)
	for(var/atom/build as anything in owned)
		var/obj/structure/machinery/defenses/sentry/turret = build
		var/atom/spot = istype(turret) && !turret.placed ? turret.HD : build
		if(spot in engineer.get_contents())
			return "You are already carrying your [label]."
		var/turf/where = get_turf(spot)
		var/distance = get_dist(engineer, where)
		return "You already have \a [label] out, [distance] tile\s [dir2text(get_dir(engineer, where)) || "here"]. Get it back or let it be destroyed."

/proc/clash_build_refusal(mob/living/carbon/human/engineer, item_type)
	var/tier = clash_sentry_tier_of(item_type)
	var/crate = ispath(item_type, /obj/item/clash_ammo_crate)
	if(!tier && !crate)
		return null
	if(!clash_is_engineer(engineer))
		return "Only engineers can take this."
	if(crate)
		var/list/crates = GLOB.clash_engineer_crates[engineer.ckey]
		return length(crates) ? clash_build_owned_text(engineer, crates, "ammo crate") : null
	var/level = GLOB.clash_sentry_tiers[tier]["level"]
	if(clash_engineer_level(engineer.ckey) < level)
		return "Unlocks at Engineer level [level]."
	var/limit = clash_has_perk(engineer, /datum/clash_perk/twin_sentries) ? 2 : 1
	var/list/sentries = GLOB.clash_engineer_sentries[engineer.ckey]
	return length(sentries) >= limit ? clash_build_owned_text(engineer, sentries, "sentry") : null

/obj/structure/machinery/cm_vending/vendor_successful_vend(list/itemspec, mob/living/carbon/human/user, turf/override_turf)
	var/item_type = LAZYACCESS(itemspec, 3)
	var/tier = clash_sentry_tier_of(item_type)
	if(!tier && !ispath(item_type, /obj/item/clash_ammo_crate))
		return ..()
	if(clash_build_refusal(user, item_type))
		return
	var/obj/item/build = tier ? clash_new_sentry(user, tier) : clash_new_crate(user)
	if(!user.put_in_hands(build))
		build.forceMove(get_turf(user))
	playsound(loc, 'sound/machines/ping.ogg', 15, 1)

/proc/clash_remove_engineer_builds(ckey, include_deployed)
	var/list/sentries = GLOB.clash_engineer_sentries[ckey]
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in sentries?.Copy())
		if(!turret.placed)
			qdel(turret.HD)
		else if(include_deployed)
			qdel(turret)
	var/list/crates = GLOB.clash_engineer_crates[ckey]
	for(var/obj/item/clash_ammo_crate/crate as anything in crates?.Copy())
		if(include_deployed || !crate.deployed || crate.loc != crate.deployed)
			qdel(crate)

/proc/clash_engineer_sentry_choice(mob/living/carbon/human/engineer)
	var/datum/clash_kit/kit = get_clash_active_kit(engineer.ckey, engineer.job)
	var/datum/clash_kit_option/option = kit?.get_option(KIT_SLOT_SENTRY)
	var/tier = option ? clash_sentry_tier_of(option.item_type) : null
	if(!tier || clash_engineer_level(engineer.ckey) < GLOB.clash_sentry_tiers[tier]["level"])
		return CLASH_SENTRY_LIGHT
	return tier

/proc/clash_give_engineer_item(mob/living/carbon/human/engineer, obj/item/item)
	if(!engineer.equip_to_slot_if_possible(item, WEAR_IN_BACK, TRUE, FALSE, TRUE) && !engineer.put_in_hands(item))
		item.forceMove(get_turf(engineer))

/proc/clash_clear_engineer_builds()
	for(var/ckey in GLOB.clash_engineer_sentries | GLOB.clash_engineer_crates)
		clash_remove_engineer_builds(ckey, TRUE)

/proc/clash_forget_build(list/registry, ckey, build)
	var/list/owned = registry[ckey]
	if(!owned)
		return
	owned -= build
	if(!length(owned))
		registry -= ckey

/proc/clash_engineer_only(mob/user)
	if(!clash_fast_medicine() || !ishuman(user) || clash_is_engineer(user))
		return FALSE
	to_chat(user, SPAN_WARNING("Only engineers can build."))
	return TRUE

/obj/item/stack/check_one_per_turf(datum/stack_recipe/recipe, mob/user)
	if(ispath(recipe.result_type, /obj/structure/barricade) && clash_engineer_only(user))
		return TRUE
	return ..()

/obj/item/stack/sandbags/attack_self(mob/living/user)
	if(clash_engineer_only(user))
		return
	return ..()

/obj/structure/barricade/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/stack/barbed_wire) && clash_engineer_only(user))
		return
	return ..()

/obj/structure/barricade/try_weld_cade(obj/item/tool/weldingtool/welder, mob/user, repeat = TRUE, skip_check = FALSE)
	if(clash_engineer_only(user))
		return FALSE
	return ..()

/proc/add_clash_sentry_options(faction)
	var/list/kits = GLOB.clash_sentry_kits[faction]
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Light Sentry", kits[CLASH_SENTRY_LIGHT], "Covers every direction up close")
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Sentry Gun", kits[CLASH_SENTRY_GUN], "Guards the way it faces, longer reach")
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Flamer Sentry", kits[CLASH_SENTRY_FLAMER], "Sets anyone in front of it on fire")

/proc/clash_sentry_issue(list/issue, job)
	if(!clash_job_is_engineer(job))
		return issue
	var/obj/item/light = clash_sentry_kit_for(clash_kit_faction_for_job(job), CLASH_SENTRY_LIGHT)
	. = issue.Copy()
	.[KIT_SLOT_SENTRY] = list("name" = "Light Sentry", "type" = "[light]", "icon" = "[initial(light.icon)]", "icon_state" = initial(light.icon_state))

/datum/game_mode/extended/faction_clash/hvh/proc/score_sentry_kill(mob/killer)
	if(!match_live || !killer)
		return
	var/list/entry = get_score_entry(killer.real_name, killer.faction, killer.mind?.ckey || killer.ckey)
	entry["sentry_kills"] = (entry["sentry_kills"] || 0) + 1

#undef CLASH_METAL_BARRICADE_TIME
#undef CLASH_PLASTEEL_BARRICADE_TIME

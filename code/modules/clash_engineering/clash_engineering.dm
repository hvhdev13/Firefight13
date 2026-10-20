#define CLASH_METAL_BARRICADE_TIME (1 SECONDS)
#define CLASH_PLASTEEL_BARRICADE_TIME (3 SECONDS)
#define CLASH_MG_DEPLOY_TIME (1 SECONDS)
#define CLASH_MG_PACK_TIME (1.5 SECONDS)
#define CLASH_MG_REPAIR_TIME (2 SECONDS)
#define CLASH_MG_REPAIR_HP 75
#define CLASH_MG_BULLET_SHARE 0.5
#define CLASH_MG_BLAST_MULT 1.5
#define CLASH_T37_DAMAGE 33
#define CLASH_M56D_DAMAGE 18
#define CLASH_M56D_FULL_DAMAGE_RANGE 12
#define CLASH_MG_ACCURACY -10
#define CLASH_MG_ACCURATE_RANGE 9
#define CLASH_MG_RELOAD_TIME (1 SECONDS)
#define CLASH_REBUILD_TIME (45 SECONDS)
#define CLASH_REBUILD_TIME_FAST (20 SECONDS)
#define CLASH_REBUILD_WELD_TIME (8 SECONDS)
#define CLASH_REBUILD_METAL 10
#define CLASH_WRECK_HEALTH 100
#define CLASH_WRECK_BULLET_SHARE 0.5
#define CLASH_WRECK_COLOR "#6e6e6e"

GLOBAL_LIST_INIT(clash_arena_eng_removed, list(
	/obj/item/circuitboard,
	/obj/item/cell,
	/obj/item/engi_upgrade_kit,
	/obj/item/defenses/handheld,
	/obj/item/storage/belt/gun/brutepack,
	/obj/item/explosive/mine,
	/obj/item/storage/box/explosive_mines,
	/obj/item/storage/box/guncase/m56d,
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
	var/obj/item/clothing/glasses/welding/goggles = locate() in carried
	if(goggles)
		clash_goggles_up(goggles, engineer)
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
	var/list/guns = GLOB.clash_engineer_mgs[ckey]
	for(var/obj/structure/machinery/m56d_hmg/auto/clash/nest in guns?.Copy())
		if(nest.clash_faction != engineer.faction)
			qdel(nest)
	clash_cancel_rebuilds(ckey)
	var/sentry_tier = clash_engineer_sentry_choice(engineer)
	if(sentry_tier)
		clash_give_engineer_item(engineer, clash_new_build(engineer, sentry_tier))
		for(var/ammo_type in clash_build_ammo(engineer.faction, sentry_tier))
			clash_give_engineer_item(engineer, new ammo_type(engineer))
	clash_give_engineer_item(engineer, clash_new_crate(engineer))

/proc/clash_goggles_up(obj/item/clothing/glasses/welding/goggles, mob/living/carbon/human/wearer)
	if(!goggles.active)
		return
	goggles.active = FALSE
	goggles.vision_impair = goggles.vision_impair_off
	goggles.flags_inventory &= ~COVEREYES
	goggles.flags_inv_hide &= ~HIDEEYES
	goggles.flags_armor_protection &= ~BODY_FLAG_EYES
	goggles.eye_protection = EYE_PROTECTION_NONE
	goggles.update_icon()
	if(wearer.glasses == goggles)
		wearer.update_tint()
	goggles.update_clothing_icon()

/proc/clash_new_sentry(mob/living/carbon/human/engineer, tier)
	var/kit_type = clash_sentry_kit_for(engineer.faction, tier)
	var/obj/item/defenses/handheld/packed = new kit_type(engineer)
	var/obj/structure/machinery/defenses/sentry/fresh = packed.TR
	fresh.clash_owner_ckey = engineer.ckey
	fresh.clash_module = clash_engineer_module_choice(engineer, tier)
	fresh.clash_apply_upgrades()
	LAZYADDASSOCLIST(GLOB.clash_engineer_sentries, engineer.ckey, fresh)
	return packed

/proc/clash_new_build(mob/living/carbon/human/engineer, tier)
	return tier == CLASH_SENTRY_MG ? clash_new_mg(engineer) : clash_new_sentry(engineer, tier)

/proc/clash_build_ammo(faction, tier)
	if(tier == CLASH_SENTRY_FLAMER)
		return list(/obj/item/ammo_magazine/flamer_tank)
	if(tier == CLASH_SENTRY_MG && faction == FACTION_UPP)
		return list(/obj/item/ammo_magazine/m2c/t37/clash, /obj/item/ammo_magazine/m2c/t37/clash)
	return list()

/proc/clash_new_crate(mob/living/carbon/human/engineer)
	var/crate_type = engineer.faction == FACTION_UPP ? /obj/item/clash_ammo_crate/upp : /obj/item/clash_ammo_crate
	var/obj/item/clash_ammo_crate/crate = new crate_type(engineer)
	crate.owner_ckey = engineer.ckey
	LAZYADDASSOCLIST(GLOB.clash_engineer_crates, engineer.ckey, crate)
	return crate

/proc/clash_engineer_vendor_entries(mob/living/carbon/human/engineer)
	. = list(list("ENGINEER BUILDS", -1, null, null))
	for(var/tier in GLOB.clash_sentry_tiers)
		var/level = GLOB.clash_sentry_tiers[tier]["level"]
		var/name = GLOB.clash_sentry_tiers[tier]["name"]
		if(clash_engineer_level(engineer.ckey) < level)
			name = "[name] (Unlocks at Engineer level [level])"
		. += list(list(name, 1, clash_sentry_kit_for(engineer.faction, tier), VENDOR_ITEM_REGULAR))
	. += list(list("Ammo Crate", 1, engineer.faction == FACTION_UPP ? /obj/item/clash_ammo_crate/upp : /obj/item/clash_ammo_crate, VENDOR_ITEM_REGULAR))

/proc/clash_engineer_build_icons()
	. = list(list("Ammo Crate", 0, /obj/item/clash_ammo_crate), list("Ammo Crate", 0, /obj/item/clash_ammo_crate/upp))
	for(var/faction in GLOB.clash_sentry_kits)
		for(var/tier in GLOB.clash_sentry_kits[faction])
			. += list(list(GLOB.clash_sentry_tiers[tier]["name"], 0, GLOB.clash_sentry_kits[faction][tier]))

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
	var/list/sentries = GLOB.clash_engineer_sentries[engineer.ckey]
	var/list/guns = GLOB.clash_engineer_mgs[engineer.ckey]
	if(length(sentries) + length(guns) < clash_engineer_build_limit(engineer))
		return null
	return length(guns) ? clash_build_owned_text(engineer, guns, "machine gun") : clash_build_owned_text(engineer, sentries, "sentry")

/obj/structure/machinery/cm_vending/vendor_successful_vend(list/itemspec, mob/living/carbon/human/user, turf/override_turf)
	var/item_type = LAZYACCESS(itemspec, 3)
	var/tier = clash_sentry_tier_of(item_type)
	if(!tier && !ispath(item_type, /obj/item/clash_ammo_crate))
		return ..()
	if(clash_build_refusal(user, item_type))
		return
	var/obj/item/build = tier ? clash_new_build(user, tier) : clash_new_crate(user)
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
	var/list/guns = GLOB.clash_engineer_mgs[ckey]
	for(var/obj/build as anything in guns?.Copy())
		if(include_deployed || isitem(build))
			qdel(build)
	if(include_deployed)
		clash_cancel_rebuilds(ckey)

/proc/clash_engineer_sentry_choice(mob/living/carbon/human/engineer)
	var/datum/clash_kit/kit = get_clash_active_kit(engineer.ckey, engineer.job)
	if(kit?.wants_nothing(KIT_SLOT_SENTRY))
		return null
	return clash_kit_sentry_tier(kit, engineer.ckey)

/proc/clash_kit_sentry_tier(datum/clash_kit/kit, ckey)
	var/datum/clash_kit_option/option = kit?.get_option(KIT_SLOT_SENTRY)
	var/tier = option ? clash_sentry_tier_of(option.item_type) : null
	if(!tier || clash_engineer_level(ckey) < GLOB.clash_sentry_tiers[tier]["level"])
		return CLASH_SENTRY_MG
	return tier

/proc/clash_kit_sentry_type(datum/clash_kit/kit, ckey, job)
	if(!clash_job_is_engineer(job) || kit?.wants_nothing(KIT_SLOT_SENTRY))
		return null
	return clash_sentry_kit_for(clash_kit_faction_for_job(job), clash_kit_sentry_tier(kit, ckey))

/proc/clash_engineer_module_choice(mob/living/carbon/human/engineer, tier)
	var/datum/clash_kit/kit = get_clash_active_kit(engineer.ckey, engineer.job)
	var/datum/clash_kit_option/option = kit?.get_option(KIT_SLOT_SENTRY_MODULE)
	if(!option || clash_option_lock_text(engineer.ckey, option.id, engineer.job, clash_sentry_kit_for(engineer.faction, tier)))
		return null
	return option.item_type

/proc/clash_give_engineer_item(mob/living/carbon/human/engineer, obj/item/item)
	if(!engineer.equip_to_slot_if_possible(item, WEAR_IN_BACK, TRUE, FALSE, TRUE) && !engineer.put_in_hands(item))
		item.forceMove(get_turf(engineer))

/proc/clash_clear_engineer_builds()
	for(var/ckey in GLOB.clash_engineer_sentries | GLOB.clash_engineer_crates | GLOB.clash_engineer_mgs | GLOB.clash_engineer_rebuilds)
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

/obj/structure/barricade/sandbags/increment_build_stage()
	. = ..()
	if(clash_hardened)
		maxhealth = round(maxhealth * CLASH_HARDENED_MULT)
		health = maxhealth

/obj/structure/barricade/sandbags/update_damage_state()
	var/old_max = maxhealth
	. = ..()
	if(clash_hardened && maxhealth != old_max)
		maxhealth = round(maxhealth * CLASH_HARDENED_MULT)

/proc/add_clash_sentry_options(faction)
	var/list/kits = GLOB.clash_sentry_kits[faction]
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Sentry Gun", kits[CLASH_SENTRY_GUN], "Guards the way it faces, longer reach")
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Flamer Sentry", kits[CLASH_SENTRY_FLAMER], "Sets anyone in front of it on fire")
	var/obj/item/device/clash_mg/gun = kits[CLASH_SENTRY_MG]
	add_clash_kit_option(faction, KIT_SLOT_SENTRY, "Machine Gun", gun, initial(gun.kit_blurb))
	for(var/module_type in GLOB.clash_sentry_modules)
		var/datum/clash_sentry_module/module = GLOB.clash_sentry_modules[module_type]
		add_clash_kit_option(faction, KIT_SLOT_SENTRY_MODULE, module.name, module_type, module.desc)

/proc/clash_sentry_issue(list/issue, job)
	if(!clash_job_is_engineer(job))
		return issue
	var/obj/item/gun = clash_sentry_kit_for(clash_kit_faction_for_job(job), CLASH_SENTRY_MG)
	. = issue.Copy()
	.[KIT_SLOT_SENTRY] = list("name" = initial(gun.name), "type" = "[gun]", "icon" = "[initial(gun.icon)]", "icon_state" = initial(gun.icon_state))

/datum/game_mode/extended/faction_clash/hvh/proc/score_sentry_kill(mob/killer)
	if(!match_live || !killer)
		return
	var/list/entry = get_score_entry(killer.real_name, killer.faction, killer.mind?.ckey || killer.ckey)
	entry["sentry_kills"] = (entry["sentry_kills"] || 0) + 1

/proc/clash_engineer_build_limit(mob/living/carbon/human/engineer)
	return clash_has_perk(engineer, /datum/clash_perk/twin_sentries) ? 2 : 1

/proc/clash_engineer_make_room(mob/living/carbon/human/engineer, atom/movable/fresh)
	var/list/standing = list()
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in GLOB.clash_engineer_sentries[engineer.ckey])
		if(turret != fresh && turret.placed)
			standing[turret] = turret.clash_deployed_at
	for(var/obj/structure/machinery/m56d_hmg/auto/clash/nest in GLOB.clash_engineer_mgs[engineer.ckey])
		if(nest != fresh)
			standing[nest] = nest.clash_deployed_at
	while(length(standing) >= clash_engineer_build_limit(engineer))
		var/atom/movable/oldest = standing[1]
		for(var/atom/movable/build as anything in standing)
			if(standing[build] < standing[oldest])
				oldest = build
		standing -= oldest
		to_chat(engineer, SPAN_NOTICE("Your older [oldest.name] shuts down."))
		var/obj/structure/machinery/defenses/sentry/old_turret = oldest
		var/obj/structure/machinery/defenses/sentry/new_turret = fresh
		if(istype(old_turret) && istype(new_turret) && old_turret.clash_tier == new_turret.clash_tier && old_turret.clash_kills > new_turret.clash_kills)
			new_turret.clash_kills = old_turret.clash_kills
			old_turret.clash_kills = 0
			new_turret.clash_apply_rank()
		qdel(oldest)

GLOBAL_LIST_EMPTY(clash_engineer_mgs)
GLOBAL_LIST_EMPTY(clash_engineer_rebuilds)

/datum/clash_rebuild
	var/ckey
	var/faction
	var/tier
	var/obj/item/kit_type
	var/name
	var/kills = 0
	var/due
	var/timer
	var/datum/weakref/alerted
	var/obj/structure/clash_build_wreck/wreck

/proc/clash_start_rebuild(atom/movable/build, ckey, faction, tier, kit_type, kills = 0)
	if(!ckey || !clash_fast_medicine())
		return
	var/datum/clash_rebuild/rebuild = new
	rebuild.ckey = ckey
	rebuild.faction = faction
	rebuild.tier = tier
	rebuild.kit_type = kit_type
	rebuild.name = initial(build.name)
	rebuild.kills = kills
	rebuild.due = world.time + (clash_has_perk(rebuild.owner_mob(), /datum/clash_perk/field_fabricator) ? CLASH_REBUILD_TIME_FAST : CLASH_REBUILD_TIME)
	if(isturf(build.loc))
		rebuild.wreck = new(build.loc, build, rebuild)
	LAZYADDASSOCLIST(GLOB.clash_engineer_rebuilds, ckey, rebuild)
	rebuild.timer = addtimer(CALLBACK(rebuild, TYPE_PROC_REF(/datum/clash_rebuild, tick)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE|TIMER_DELETE_ME)
	rebuild.tick()

/proc/clash_cancel_rebuilds(ckey)
	var/list/pending = GLOB.clash_engineer_rebuilds[ckey]
	for(var/datum/clash_rebuild/rebuild as anything in pending?.Copy())
		qdel(rebuild)

/proc/clash_next_rebuild_data(ckey)
	var/datum/clash_rebuild/next
	for(var/datum/clash_rebuild/rebuild as anything in GLOB.clash_engineer_rebuilds[ckey])
		if(!next || rebuild.due < next.due)
			next = rebuild
	if(next)
		return list("name" = next.name, "seconds" = max(0, CEILING((next.due - world.time) / (1 SECONDS), 1)))
	return null

/datum/clash_rebuild/Destroy(force)
	deltimer(timer)
	var/mob/shown = alerted?.resolve()
	shown?.clear_alert("clash_rebuild_[REF(src)]")
	if(wreck)
		wreck.rebuild = null
		QDEL_NULL(wreck)
	clash_forget_build(GLOB.clash_engineer_rebuilds, ckey, src)
	return ..()

/datum/clash_rebuild/proc/owner_mob()
	var/client/player = GLOB.directory[ckey]
	var/mob/living/carbon/human/owner = player?.mob
	if(ishuman(owner) && owner.stat != DEAD && owner.faction == faction && clash_is_engineer(owner))
		return owner
	return null

/datum/clash_rebuild/proc/tick()
	var/seconds = CEILING((due - world.time) / (1 SECONDS), 1)
	if(seconds <= 0)
		arrive()
		return
	var/mob/living/carbon/human/owner = owner_mob()
	if(!owner)
		return
	var/category = "clash_rebuild_[REF(src)]"
	var/atom/movable/screen/alert/clash_rebuild/shown = owner.alerts[category] || owner.throw_alert(category, /atom/movable/screen/alert/clash_rebuild)
	alerted = WEAKREF(owner)
	shown?.clash_show(src, seconds)

/datum/clash_rebuild/proc/arrive()
	var/mob/living/carbon/human/owner = owner_mob()
	if(owner && length(GLOB.clash_engineer_sentries[ckey]) + length(GLOB.clash_engineer_mgs[ckey]) < clash_engineer_build_limit(owner))
		clash_give_engineer_item(owner, clash_new_build(owner, tier))
		to_chat(owner, SPAN_NOTICE("Your new [name] has arrived."))
		playsound_client(owner.client, 'sound/machines/ping.ogg', null, 40)
	qdel(src)

/datum/clash_rebuild/proc/rebuild_at(turf/spot, facing, mob/living/carbon/human/builder)
	var/mob/living/carbon/human/owner = owner_mob() || builder
	if(tier == CLASH_SENTRY_MG)
		var/obj/item/device/clash_mg/gun = clash_new_mg(owner)
		gun.clash_place(spot, facing, owner)
	else
		var/obj/item/defenses/handheld/kit = clash_new_sentry(owner, tier)
		var/obj/structure/machinery/defenses/sentry/turret = kit.TR
		turret.clash_kills = max(turret.clash_kills, kills)
		turret.clash_apply_rank()
		turret.forceMove(spot)
		turret.setDir(facing)
		turret.placed = 1
		kit.dropped = 0
		kit.forceMove(turret)
		turret.update_icon()
		turret.clash_activate(owner)
	qdel(src)

/atom/movable/screen/alert/clash_rebuild
	icon_state = "template"
	maptext_width = 30
	maptext_height = 10
	maptext_y = 1

/atom/movable/screen/alert/clash_rebuild/proc/clash_show(datum/clash_rebuild/rebuild, seconds)
	if(!length(overlays))
		var/obj/item/kit_type = rebuild.kit_type
		overlays += image(initial(kit_type.icon), initial(kit_type.icon_state))
	name = rebuild.name
	desc = "A new one arrives in your backpack in [seconds] second\s."
	maptext = "<span style='text-align: right; -dm-text-outline: 1px #0a0c0f; font-family: \"VCR OSD Mono\"; font-size: 8px; color: #ffffff'>[seconds]</span>"

/obj/structure/clash_build_wreck
	anchored = TRUE
	density = FALSE
	health = CLASH_WRECK_HEALTH
	var/datum/clash_rebuild/rebuild
	var/faction

/obj/structure/clash_build_wreck/Initialize(mapload, atom/movable/build, datum/clash_rebuild/rebuild)
	. = ..()
	src.rebuild = rebuild
	faction = rebuild.faction
	name = "wrecked [rebuild.name]"
	desc = "What is left of a [rebuild.name]."
	setDir(build.dir)
	var/obj/structure/machinery/defenses/sentry/turret = build
	if(istype(turret))
		icon = turret.icon
		icon_state = turret.composite_icon ? "defense_base_off" : null
		overlays += image(icon, "[turret.defense_type] [turret.sentry_type]_destroyed")
		return
	var/obj/structure/machinery/m56d_hmg/auto/clash/nest = build
	icon = nest.icon
	icon_state = nest.icon_empty
	color = CLASH_WRECK_COLOR

/obj/structure/clash_build_wreck/Destroy()
	if(rebuild)
		rebuild.wreck = null
		rebuild = null
	return ..()

/obj/structure/clash_build_wreck/get_examine_text(mob/user)
	. = ..()
	. += SPAN_HELPFUL("An engineer on its team can rebuild it with a welder and [CLASH_REBUILD_METAL] metal.")

/obj/structure/clash_build_wreck/attackby(obj/item/tool, mob/living/carbon/human/user)
	if(!iswelder(tool) || user.faction != faction)
		return ..()
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can rebuild it."))
		return
	var/obj/item/tool/weldingtool/welder = tool
	if(!welder.isOn())
		to_chat(user, SPAN_WARNING("Turn the welder on first."))
		return
	var/obj/item/stack/sheet/metal/sheets = clash_metal_on(user)
	if(!sheets)
		to_chat(user, SPAN_WARNING("You need [CLASH_REBUILD_METAL] metal to rebuild it."))
		return
	playsound(loc, 'sound/items/Welder2.ogg', 25, 1)
	if(!do_after(user, CLASH_REBUILD_WELD_TIME * clash_build_time_mult(user), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src) || !rebuild || QDELETED(sheets) || !sheets.use(CLASH_REBUILD_METAL))
		return
	playsound(loc, 'sound/items/Welder2.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You rebuild the [rebuild.name]."))
	rebuild.rebuild_at(get_turf(src), dir, user)

/obj/structure/clash_build_wreck/get_projectile_hit_boolean(obj/projectile/bullet)
	var/mob/shooter = bullet.firer
	if(ismob(shooter) && shooter.faction == faction)
		return FALSE
	return ..()

/obj/structure/clash_build_wreck/bullet_act(obj/projectile/bullet)
	bullet_ping(bullet)
	clash_wreck_damage(bullet.damage * CLASH_WRECK_BULLET_SHARE)
	return TRUE

/obj/structure/clash_build_wreck/ex_act(severity)
	clash_wreck_damage(severity)

/obj/structure/clash_build_wreck/proc/clash_wreck_damage(amount)
	health -= amount
	if(health > 0)
		return
	visible_message(SPAN_WARNING("[src] falls apart."))
	qdel(src)

/proc/clash_metal_on(mob/living/carbon/human/user)
	for(var/obj/item/stack/sheet/metal/sheets in user.get_contents())
		if(sheets.amount >= CLASH_REBUILD_METAL)
			return sheets
	return null

/proc/clash_new_mg(mob/living/carbon/human/engineer)
	var/gun_type = clash_sentry_kit_for(engineer.faction, CLASH_SENTRY_MG)
	var/obj/item/device/clash_mg/gun = new gun_type(engineer)
	gun.clash_owner_ckey = engineer.ckey
	gun.clash_faction = engineer.faction
	LAZYADDASSOCLIST(GLOB.clash_engineer_mgs, engineer.ckey, gun)
	return gun

/obj/item/device/clash_mg
	w_class = SIZE_MEDIUM
	flags_equip_slot = SLOT_BACK
	icon = 'icons/obj/items/weapons/guns/guns_by_faction/USCM/machineguns.dmi'
	item_icons = list(
		WEAR_BACK = 'icons/mob/humans/onmob/clothing/back/guns_by_type/machineguns.dmi',
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/weapons/guns/machineguns_lefthand.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/weapons/guns/machineguns_righthand.dmi'
	)
	pixel_x = -5
	hud_offset = -5
	var/obj/structure/machinery/m56d_hmg/auto/clash/nest_type
	var/kit_blurb
	var/rounds
	var/health_max
	var/overheat_value = 0
	var/clash_owner_ckey
	var/clash_faction

/obj/item/device/clash_mg/Initialize(mapload, ...)
	. = ..()
	rounds = initial(nest_type.rounds_max)
	health_max = initial(nest_type.health_max)
	health = health_max

/obj/item/device/clash_mg/Destroy()
	if(clash_owner_ckey)
		clash_forget_build(GLOB.clash_engineer_mgs, clash_owner_ckey, src)
	return ..()

/obj/item/device/clash_mg/get_examine_text(mob/user)
	. = ..()
	. += SPAN_INFO("It has [rounds] round\s and [health]/[health_max] health.")

/obj/item/device/clash_mg/attack_self(mob/living/carbon/human/user)
	..()
	var/problem = clash_setup_problem(user)
	if(!problem && !do_after(user, CLASH_MG_DEPLOY_TIME * clash_build_time_mult(user), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
		return
	problem = problem || clash_setup_problem(user)
	if(problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	var/obj/structure/machinery/m56d_hmg/auto/clash/nest = clash_place(get_turf(user), user.dir, user)
	to_chat(user, SPAN_NOTICE("You set up [nest]."))
	if(nest.rounds)
		nest.try_mount_gun(user)

/obj/item/device/clash_mg/proc/clash_place(turf/spot, facing, mob/living/carbon/human/user)
	var/obj/structure/machinery/m56d_hmg/auto/clash/nest = new nest_type(spot)
	nest.setDir(facing)
	nest.rounds = rounds
	nest.health_max = initial(nest.health_max) * (clash_has_perk(user, /datum/clash_perk/hardened) ? CLASH_HARDENED_MULT : 1)
	nest.health = round(nest.health_max * health / health_max)
	nest.overheat_value = overheat_value
	nest.clash_owner_ckey = clash_owner_ckey
	nest.clash_faction = clash_faction
	nest.clash_deployed_at = world.time
	nest.update_damage_state()
	nest.update_icon()
	if(clash_owner_ckey)
		LAZYADDASSOCLIST(GLOB.clash_engineer_mgs, clash_owner_ckey, nest)
	if(user.ckey == clash_owner_ckey)
		clash_engineer_make_room(user, nest)
	playsound(nest, 'sound/items/m56dauto_setup.ogg', 75, TRUE)
	qdel(src)
	return nest

/obj/item/device/clash_mg/proc/clash_setup_problem(mob/living/carbon/human/user)
	if(!clash_is_engineer(user) || user.faction != clash_faction)
		return "Only engineers on its team can set it up."
	var/turf/open/spot = get_turf(user)
	var/area/clash_arena/spot_area = get_area(spot)
	if(istype(spot_area) && spot_area.clash_faction)
		return "Machine guns can't be set up inside a base."
	if(clash_near_enemy_base(spot, user.faction))
		return "Too close to the enemy base."
	if(!istype(spot) || !spot.allow_construction || !spot_area.allow_construction)
		return "You can't set it up here."
	for(var/obj/thing in spot)
		if(thing == src)
			continue
		if((thing.density && !(thing.flags_atom & ON_BORDER)) || istype(thing, /obj/structure/machinery/defenses) || istype(thing, /obj/structure/machinery/m56d_hmg) || istype(thing, /obj/structure/machinery/door))
			return "Something is in the way."
	return null

/obj/item/device/clash_mg/m56d
	name = "M56D machine gun"
	desc = "Use it in hand to set it up where you stand. Its bullets pass through your teammates."
	icon_state = "m56d_tri"
	item_state = "M56D_gun"
	item_state_slots = list(WEAR_BACK = "M56D_gun_mount")
	nest_type = /obj/structure/machinery/m56d_hmg/auto/clash/m56d
	kit_blurb = "Accurate mounted machine gun. Bullets pass through teammates."

/obj/item/device/clash_mg/t37
	name = "T37 machine gun"
	desc = "Use it in hand to set it up where you stand. It hits hard, overheats and hits teammates."
	icon_state = "M2C_gun_mount"
	item_state = "M2C_gun_mount"
	nest_type = /obj/structure/machinery/m56d_hmg/auto/clash/t37
	kit_blurb = "Mounted machine gun, hits hard, overheats, hits teammates"

/obj/structure/machinery/m56d_hmg/auto/clash
	var/obj/item/device/clash_mg/carry_type
	var/clash_owner_ckey
	var/clash_faction
	var/clash_deployed_at = 0
	var/clash_enemy_damage = 0
	var/obj/item/ammo_magazine/clash_ammo_box

/obj/structure/machinery/m56d_hmg/auto/clash/Initialize()
	. = ..()
	QDEL_NULL_LIST(cadeblockers)

/obj/structure/machinery/m56d_hmg/auto/clash/Destroy()
	if(clash_owner_ckey)
		clash_forget_build(GLOB.clash_engineer_mgs, clash_owner_ckey, src)
	return ..()

/obj/structure/machinery/m56d_hmg/auto/clash/get_examine_text(mob/user)
	. = ..()
	. += SPAN_INFO("It has [SPAN_HELPFUL("[health]/[health_max]")] health.")
	. += SPAN_HELPFUL("Click it from behind with empty hands to man it, or with its ammo box to reload it. Engineers also reload it with metal, [clash_reload_metal(user)] sheets for a full load, repair it with a welder and drag it onto themselves to pack it up.")

/obj/structure/machinery/m56d_hmg/auto/clash/try_mount_gun(mob/living/carbon/user)
	if(user.faction != clash_faction)
		to_chat(user, SPAN_WARNING("That gun belongs to the other team."))
		return
	return ..()

/obj/structure/machinery/m56d_hmg/auto/clash/handle_ammo_out(mob/user)
	visible_message(SPAN_NOTICE("[icon2html(src, viewers(src))] [src] is out of ammo."))
	playsound(loc, empty_alarm, 70, 1)
	update_icon()

/obj/structure/machinery/m56d_hmg/auto/clash/fire_shot()
	. = ..()
	if(. == AUTOFIRE_CONTINUE)
		clash_mark_loud(operator)

// Mounted guns never copy the ammo's full damage range onto the bullet, so it falls off from the muzzle.
/obj/structure/machinery/m56d_hmg/auto/clash/load_into_chamber()
	. = ..()
	if(in_chamber)
		in_chamber.effective_range_max = in_chamber.ammo.effective_range_max

/obj/structure/machinery/m56d_hmg/auto/clash/update_health(amount)
	health = min(health - amount, health_max)
	if(health > 0)
		update_damage_state()
		update_icon()
		return
	visible_message(SPAN_WARNING("[src] breaks apart!"))
	playsound(loc, 'sound/mecha/critdestrsyndi.ogg', 25, 1)
	clash_start_rebuild(src, clash_owner_ckey, clash_faction, CLASH_SENTRY_MG, carry_type)
	var/client/owner = GLOB.directory[clash_owner_ckey]
	if(owner)
		to_chat(owner, SPAN_WARNING("Your [name] was destroyed."))
	qdel(src)

/obj/structure/machinery/m56d_hmg/auto/clash/get_projectile_hit_boolean(obj/projectile/bullet)
	var/mob/shooter = bullet.firer
	if(ismob(shooter) && shooter.faction == clash_faction)
		return FALSE
	return ..()

/obj/structure/machinery/m56d_hmg/auto/clash/bullet_act(obj/projectile/bullet)
	bullet_ping(bullet)
	if(istype(bullet.ammo, /datum/ammo/bullet/shrapnel))
		return TRUE
	var/damage = floor(bullet.damage * CLASH_MG_BULLET_SHARE)
	clash_enemy_damage += clash_enemy_share(bullet.firer, clash_faction, damage)
	update_health(damage)
	return TRUE

/obj/structure/machinery/m56d_hmg/auto/clash/ex_act(severity)
	update_health(severity * CLASH_MG_BLAST_MULT)

/obj/structure/machinery/m56d_hmg/auto/clash/attackby(obj/item/tool, mob/living/carbon/human/user)
	if(istype(tool, clash_ammo_box) && user.faction == clash_faction)
		clash_box_reload(user, tool)
		return
	var/metal = istype(tool, /obj/item/stack/sheet/metal)
	if((!metal && !iswelder(tool)) || user.faction != clash_faction)
		return
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can work on machine guns."))
		return
	if(metal)
		var/loaded = clash_metal_reload(user, tool, src, rounds_max - rounds, rounds_max, clash_reload_metal(user))
		if(!loaded)
			return
		rounds = min(rounds_max, rounds + loaded)
		update_icon()
		to_chat(user, SPAN_NOTICE("You reload [src]: [rounds]/[rounds_max] rounds."))
		return
	var/obj/item/tool/weldingtool/welder = tool
	if(health >= health_max)
		to_chat(user, SPAN_WARNING("[src] doesn't need repairs."))
		return
	if(!welder.isOn())
		to_chat(user, SPAN_WARNING("Turn the welder on first."))
		return
	if(!do_after(user, CLASH_MG_REPAIR_TIME * clash_repair_mult(user), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_FRIENDLY, src) || QDELETED(src) || !welder.remove_fuel(1, user))
		return
	var/repaired = min(CLASH_MG_REPAIR_HP, health_max - health)
	update_health(-repaired)
	playsound(loc, 'sound/items/Welder2.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You repair [src]: [health]/[health_max] health."))
	var/paid = min(repaired, clash_enemy_damage)
	if(paid <= 0)
		return
	clash_enemy_damage -= paid
	clash_progress_repair(user, paid)

/obj/structure/machinery/m56d_hmg/auto/clash/MouseDrop(over_object, src_location, over_location)
	var/mob/living/carbon/human/user = usr
	if(over_object != user || !ishuman(user) || user.stat || !in_range(src, user) || user.faction != clash_faction)
		return
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can pack it up."))
		return
	if(operator)
		to_chat(user, SPAN_WARNING("Someone is manning [src]."))
		return
	if(!do_after(user, CLASH_MG_PACK_TIME * clash_build_time_mult(user), INTERRUPT_ALL, BUSY_ICON_BUILD, src) || QDELETED(src) || operator)
		return
	var/obj/item/device/clash_mg/gun = new carry_type(loc)
	gun.rounds = rounds
	gun.health = health
	gun.health_max = health_max
	gun.overheat_value = overheat_value
	gun.clash_owner_ckey = clash_owner_ckey
	gun.clash_faction = clash_faction
	if(clash_owner_ckey)
		LAZYADDASSOCLIST(GLOB.clash_engineer_mgs, clash_owner_ckey, gun)
	playsound(loc, 'sound/items/m56dauto_setup.ogg', 75, 1)
	to_chat(user, SPAN_NOTICE("You pack up [src]."))
	qdel(src)
	if(!user.equip_to_slot_if_possible(gun, WEAR_BACK, disable_warning = TRUE))
		user.put_in_hands(gun)

/obj/structure/machinery/m56d_hmg/auto/clash/m56d
	name = "M56D machine gun"
	desc = "A machine gun on a tripod. Its bullets pass through your teammates."
	icon = 'icons/obj/items/weapons/guns/guns_by_map/desert/hmg.dmi'
	icon_state = "M56D"
	icon_full = "M56D"
	icon_empty = "M56D_e"
	gun_has_gamemode_skin = TRUE
	ammo = /datum/ammo/bullet/machinegun/clash
	clash_ammo_box = /obj/item/ammo_magazine/m56d
	rounds_max = 700
	health = 200
	health_max = 200
	fire_delay = 0.2 SECONDS
	passive_cooldown = INFINITY
	gun_noise = 'sound/weapons/gun_rifle.ogg'
	empty_alarm = 'sound/weapons/smg_empty_alarm.ogg'
	carry_type = /obj/item/device/clash_mg/m56d
	north_x_offset = 0
	north_y_offset = 12
	east_x_offset = -4
	east_y_offset = 12
	south_x_offset = 0
	south_y_offset = 8
	west_x_offset = 4
	west_y_offset = 12

/obj/structure/machinery/m56d_hmg/auto/clash/t37
	name = "T37 machine gun"
	desc = "A machine gun on a tripod. It hits hard, overheats and hits teammates."
	icon = 'icons/obj/items/weapons/guns/guns_by_faction/UPP/hmg.dmi'
	icon_state = "t37"
	icon_full = "t37"
	icon_empty = "t37_e"
	ammo = /datum/ammo/bullet/machinegun/medium/clash
	clash_ammo_box = /obj/item/ammo_magazine/m2c/t37
	rounds_max = 150
	fire_delay = 0.35 SECONDS
	overheat_threshold = 35
	passive_cooldown = 1
	carry_type = /obj/item/device/clash_mg/t37

/datum/ammo/bullet/machinegun/medium/clash/setup_faction_clash_values()
	. = ..()
	damage = CLASH_T37_DAMAGE
	accuracy = CLASH_MG_ACCURACY
	accurate_range = CLASH_MG_ACCURATE_RANGE
	shell_speed = AMMO_SPEED_TIER_6
	scatter = 0

/obj/item/ammo_magazine/m2c/t37/clash
	w_class = SIZE_MEDIUM

/datum/ammo/bullet/machinegun/clash/setup_faction_clash_values()
	. = ..()
	damage = CLASH_M56D_DAMAGE
	effective_range_max = CLASH_M56D_FULL_DAMAGE_RANGE
	accuracy = CLASH_MG_ACCURACY
	shell_speed = AMMO_SPEED_TIER_6
	scatter = 0

/obj/structure/machinery/m56d_hmg/auto/clash/proc/clash_box_reload(mob/living/carbon/human/user, obj/item/ammo_magazine/box)
	if(rounds >= rounds_max)
		to_chat(user, SPAN_WARNING("[src] is fully loaded."))
		return
	if(box.current_rounds <= 0)
		to_chat(user, SPAN_WARNING("[box] is empty."))
		return
	if(!do_after(user, CLASH_MG_RELOAD_TIME, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_FRIENDLY, src) || QDELETED(src) || QDELETED(box))
		return
	var/loaded = min(rounds_max - rounds, box.current_rounds)
	rounds += loaded
	box.current_rounds -= loaded
	if(box.current_rounds <= 0)
		qdel(box)
	else
		box.update_icon()
	update_icon()
	playsound(loc, 'sound/weapons/handling/gun_m16_reload.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You reload [src]: [rounds]/[rounds_max] rounds."))

#undef CLASH_METAL_BARRICADE_TIME
#undef CLASH_PLASTEEL_BARRICADE_TIME
#undef CLASH_MG_DEPLOY_TIME
#undef CLASH_MG_PACK_TIME
#undef CLASH_MG_REPAIR_TIME
#undef CLASH_MG_REPAIR_HP
#undef CLASH_MG_BULLET_SHARE
#undef CLASH_MG_BLAST_MULT
#undef CLASH_T37_DAMAGE
#undef CLASH_M56D_DAMAGE
#undef CLASH_M56D_FULL_DAMAGE_RANGE
#undef CLASH_MG_ACCURACY
#undef CLASH_MG_ACCURATE_RANGE
#undef CLASH_MG_RELOAD_TIME
#undef CLASH_REBUILD_TIME
#undef CLASH_REBUILD_TIME_FAST
#undef CLASH_REBUILD_WELD_TIME
#undef CLASH_REBUILD_METAL
#undef CLASH_WRECK_HEALTH
#undef CLASH_WRECK_BULLET_SHARE
#undef CLASH_WRECK_COLOR

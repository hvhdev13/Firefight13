#define CLASH_SENTRY_BULLET_SHARE 0.5
#define CLASH_SENTRY_BLAST_MULT 1.5
#define CLASH_GRENADE_SENTRY_DAMAGE 150
#define CLASH_GRENADE_SENTRY_FALLOFF 40
#define CLASH_GRENADE_SENTRY_RANGE 3
#define CLASH_SENTRY_PACK_TIME (1.5 SECONDS)
#define CLASH_SENTRY_REPAIR_TIME (2 SECONDS)
#define CLASH_SENTRY_REPAIR_HP 75
#define CLASH_SENTRY_RELOAD_TIME (1 SECONDS)
#define CLASH_SENTRY_RELOAD_METAL 10
#define CLASH_SENTRY_GATE_RANGE 7
#define CLASH_SENTRY_ALERT_GAP (15 SECONDS)
#define CLASH_SENTRY_ARC 135
#define CLASH_AMMO_BAR_STEPS 20
#define CLASH_AMMO_BAR_HEIGHT 12
#define CLASH_AMMO_BAR_ALPHA 160
#define CLASH_AMMO_BAR_X -14
#define CLASH_AMMO_BAR_Y -10
#define CLASH_AMMO_COLOR_FULL "#3FA9FF"
#define CLASH_AMMO_COLOR_HALF "#FFD23F"
#define CLASH_AMMO_COLOR_EMPTY "#FF3B30"
#define CLASH_LASER_ALPHA 190
#define CLASH_LASER_GLOW_ALPHA 70
#define CLASH_LASER_GLOW_WIDTH 3
#define CLASH_LASER_SWEEP_TIME 3
#define CLASH_LASER_FADE_TIME 1
#define CLASH_LASER_MUZZLE 10
#define CLASH_LASER_HEIGHT 6

GLOBAL_LIST_EMPTY(clash_engineer_sentries)
GLOBAL_LIST_EMPTY(clash_sentry_banked_kills)
GLOBAL_LIST_EMPTY(clash_sentry_previews)
GLOBAL_LIST_INIT(clash_sentry_modules, build_clash_sentry_modules())
GLOBAL_LIST_INIT(clash_sentry_turn_icons, list("[NORTH]" = "radial_up", "[SOUTH]" = "radial_down", "[EAST]" = "radial_right", "[WEST]" = "radial_left"))

/datum/clash_sentry_module
	var/name
	var/desc
	var/icon_type

/datum/clash_sentry_module/belt
	name = "Extended Belt"
	desc = "Holds 50% more ammo"
	icon_type = /obj/item/ammo_magazine/sentry

/datum/clash_sentry_module/blast_shield
	name = "Blast Shield"
	desc = "Takes half damage from explosions"
	icon_type = /obj/item/stack/sheet/plasteel

/datum/clash_sentry_module/auto_repair
	name = "Auto-Repair"
	desc = "Repairs 5 health a second after 5 seconds without a hit"
	icon_type = /obj/item/tool/weldingtool

/datum/clash_sentry_module/radar_link
	name = "Radar Link"
	desc = "Enemies it can see show on your team's radar"
	icon_type = /obj/item/device/motiondetector

/proc/build_clash_sentry_modules()
	. = list()
	for(var/module_type in list(/datum/clash_sentry_module/belt, /datum/clash_sentry_module/blast_shield, /datum/clash_sentry_module/auto_repair, /datum/clash_sentry_module/radar_link))
		.[module_type] = new module_type

/obj/effect/clash_sentry_rank
	icon = 'icons/obj/items/clothing/accessory/ranks.dmi'
	color = "#FFD25A"
	pixel_x = 11
	pixel_y = -10
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_PLANE|VIS_INHERIT_LAYER

GLOBAL_LIST_INIT(clash_sentry_kits, list(
	FACTION_MARINE = list(
		CLASH_SENTRY_GUN = /obj/item/defenses/handheld/sentry/clash,
		CLASH_SENTRY_FLAMER = /obj/item/defenses/handheld/sentry/flamer/clash,
		CLASH_SENTRY_MG = /obj/item/device/clash_mg/m56d,
	),
	FACTION_UPP = list(
		CLASH_SENTRY_GUN = /obj/item/defenses/handheld/sentry/upp/clash,
		CLASH_SENTRY_FLAMER = /obj/item/defenses/handheld/sentry/flamer/upp/clash,
		CLASH_SENTRY_MG = /obj/item/device/clash_mg/t37,
	),
))

/obj/structure/machinery/defenses/sentry/var/clash_tier
/obj/structure/machinery/defenses/sentry/var/clash_owner_ckey
/obj/structure/machinery/defenses/sentry/var/clash_faction
/obj/structure/machinery/defenses/sentry/var/clash_enemy_damage = 0
/obj/structure/machinery/defenses/sentry/var/clash_next_alert = 0
/obj/structure/machinery/defenses/sentry/var/clash_blast_guard = 0
/obj/structure/machinery/defenses/sentry/var/clash_deployed_at = 0
/obj/structure/machinery/defenses/sentry/var/clash_module
/obj/structure/machinery/defenses/sentry/var/clash_kills = 0
/obj/structure/machinery/defenses/sentry/var/clash_wrecked = FALSE
/obj/structure/machinery/defenses/sentry/var/clash_last_hit = 0
/obj/structure/machinery/defenses/sentry/var/clash_module_timer
/obj/structure/machinery/defenses/sentry/var/obj/effect/clash_sentry_rank/clash_rank_mark
/obj/structure/machinery/defenses/sentry/var/image/clash_ammo_bar
/obj/structure/machinery/defenses/sentry/var/clash_ammo_step = -1
/obj/structure/machinery/defenses/sentry/var/list/clash_ammo_viewers
/obj/structure/machinery/defenses/sentry/var/obj/effect/clash_sentry_laser/clash_laser
/obj/structure/machinery/defenses/sentry/var/mob/living/clash_laser_target

/obj/structure/machinery/defenses/sentry/clash
	name = "Sentry Gun"
	desc = "A sentry that guards the way it faces. Wrench to turn it or pack it up, metal to reload, welder to repair."
	clash_tier = CLASH_SENTRY_GUN
	handheld_type = /obj/item/defenses/handheld/sentry/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/upp/clash
	name = "Sentry Gun"
	desc = "A sentry that guards the way it faces. Wrench to turn it or pack it up, metal to reload, welder to repair."
	clash_tier = CLASH_SENTRY_GUN
	handheld_type = /obj/item/defenses/handheld/sentry/upp/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/flamer/clash
	name = "Flamer Sentry"
	desc = "A sentry that sets anyone in front of it on fire. Wrench to turn it or pack it up, a flamer fuel tank to refuel, welder to repair."
	clash_tier = CLASH_SENTRY_FLAMER
	handheld_type = /obj/item/defenses/handheld/sentry/flamer/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/flamer/upp/clash
	name = "Flamer Sentry"
	desc = "A sentry that sets anyone in front of it on fire. Wrench to turn it or pack it up, a flamer fuel tank to refuel, welder to repair."
	clash_tier = CLASH_SENTRY_FLAMER
	handheld_type = /obj/item/defenses/handheld/sentry/flamer/upp/clash
	choice_categories = list()
	selected_categories = list()

/obj/item/defenses/handheld/sentry/clash
	name = "packed Sentry Gun"
	defense_type = /obj/structure/machinery/defenses/sentry/clash

/obj/item/defenses/handheld/sentry/upp/clash
	name = "packed Sentry Gun"
	defense_type = /obj/structure/machinery/defenses/sentry/upp/clash

/obj/item/defenses/handheld/sentry/flamer/clash
	name = "packed Flamer Sentry"
	defense_type = /obj/structure/machinery/defenses/sentry/flamer/clash

/obj/item/defenses/handheld/sentry/flamer/upp/clash
	name = "packed Flamer Sentry"
	defense_type = /obj/structure/machinery/defenses/sentry/flamer/upp/clash

/obj/structure/machinery/defenses/sentry/Initialize()
	. = ..()
	if(!clash_tier)
		return
	var/list/stats = GLOB.clash_sentry_tiers[clash_tier]
	health_max = stats["health"]
	health = health_max
	sentry_range = stats["range"]
	fire_delay = stats["delay"]
	damage_mult = stats["damage"]
	encryptable = FALSE
	QDEL_NULL(ammo)
	var/ammo_type = stats["ammo"]
	ammo = new ammo_type
	ammo.max_rounds = stats["rounds"]
	ammo.current_rounds = ammo.max_rounds
	RegisterSignal(src, COMSIG_SENTRY_LOW_AMMO_ALERT, PROC_REF(clash_low_ammo))
	RegisterSignal(src, COMSIG_SENTRY_EMPTY_AMMO_ALERT, PROC_REF(clash_empty_ammo))
	RegisterSignal(src, COMSIG_SENTRY_DESTROYED_ALERT, PROC_REF(clash_destroyed))
	update_icon()

/obj/structure/machinery/defenses/sentry/Destroy()
	if(clash_owner_ckey)
		clash_forget_build(GLOB.clash_engineer_sentries, clash_owner_ckey, src)
		if(clash_wrecked)
			clash_start_rebuild(src, clash_owner_ckey, clash_faction, clash_tier, handheld_type, clash_kills)
		if(clash_kills && !clash_wrecked)
			LAZYINITLIST(GLOB.clash_sentry_banked_kills[clash_owner_ckey])
			var/list/banked = GLOB.clash_sentry_banked_kills[clash_owner_ckey]
			banked[clash_tier] = max(banked[clash_tier], clash_kills)
	deltimer(clash_module_timer)
	QDEL_NULL(clash_rank_mark)
	clash_drop_laser()
	clash_hide_ammo_bar()
	clash_ammo_bar = null
	return ..()

/obj/structure/machinery/defenses/sentry/get_examine_text(mob/user)
	. = ..()
	if(!clash_tier)
		return
	for(var/line in .)
		if(findtext(line, "multitool"))
			. -= line
	. += SPAN_INFO("It has [SPAN_HELPFUL("[health]/[health_max]")] health.")
	if(clash_tier == CLASH_SENTRY_FLAMER)
		. += SPAN_HELPFUL("Click it with a flamer fuel tank to refuel it. A welder repairs it and a wrench turns it or packs it up.")
	else
		. += SPAN_HELPFUL("Click it with metal to reload it, [clash_reload_metal(user)] sheets for a full load. A welder repairs it and a wrench turns it or packs it up.")
	var/datum/clash_sentry_module/module = GLOB.clash_sentry_modules[clash_module]
	if(module)
		. += SPAN_INFO("Module: [module.name]. [module.desc].")
	if(clash_kills)
		. += SPAN_INFO(clash_sentry_rank_text(clash_kills))

/obj/structure/machinery/defenses/sentry/proc/clash_activate(mob/living/carbon/human/engineer)
	var/list/groups = engineer.faction_group
	faction_group = LAZYCOPY(groups)
	clash_faction = engineer.faction
	clash_owner_ckey = engineer.ckey
	owner_mob = engineer
	clash_deployed_at = world.time
	clash_engineer_make_room(engineer, src)
	var/ratio = health / health_max
	health_max = GLOB.clash_sentry_tiers[clash_tier]["health"] * (clash_has_perk(engineer, /datum/clash_perk/hardened) ? CLASH_HARDENED_MULT : 1)
	health = round(health_max * ratio)
	name = clash_sentry_engraved(engineer.ckey, type) ? "[engineer.real_name]'s [initial(name)]" : initial(name)
	power_on()
	deltimer(clash_module_timer)
	if(clash_module == /datum/clash_sentry_module/auto_repair || clash_module == /datum/clash_sentry_module/radar_link)
		clash_module_timer = addtimer(CALLBACK(src, PROC_REF(clash_module_tick)), 1 SECONDS, TIMER_LOOP|TIMER_STOPPABLE|TIMER_DELETE_ME)
	clash_update_ammo_bar()
	clash_refresh_ammo_viewers()

/obj/structure/machinery/defenses/sentry/proc/clash_module_tick()
	if(!placed || (stat & DEFENSE_DESTROYED))
		return
	if(clash_module == /datum/clash_sentry_module/radar_link)
		for(var/mob/living/carbon/human/enemy in targets)
			if(enemy.faction != clash_faction && enemy.stat != DEAD)
				enemy.clash_spotted_until = world.time + CLASH_SENTRY_SPOT_TIME
				enemy.clash_spotted_faction = clash_faction
		return
	if(health >= health_max || world.time < clash_last_hit + CLASH_SENTRY_AUTO_REPAIR_DELAY)
		return
	var/repaired = min(CLASH_SENTRY_AUTO_REPAIR_HP, health_max - health)
	clash_enemy_damage = max(0, clash_enemy_damage - repaired)
	update_health(-repaired)

/obj/structure/machinery/defenses/sentry/proc/clash_apply_upgrades()
	var/list/stats = GLOB.clash_sentry_tiers[clash_tier]
	ammo.max_rounds = round(stats["rounds"] * (clash_module == /datum/clash_sentry_module/belt ? CLASH_SENTRY_BELT_MULT : 1))
	ammo.current_rounds = ammo.max_rounds
	var/list/banked = GLOB.clash_sentry_banked_kills[clash_owner_ckey]
	if(banked?[clash_tier])
		clash_kills = banked[clash_tier]
		banked -= clash_tier
	clash_apply_rank()

/obj/structure/machinery/defenses/sentry/proc/clash_apply_rank()
	var/rank = clash_sentry_rank(clash_kills)
	fire_delay = GLOB.clash_sentry_tiers[clash_tier]["delay"] * (1 - CLASH_SENTRY_RANK_SPEEDUP * rank)
	if(!rank)
		return
	if(!clash_rank_mark)
		clash_rank_mark = new
		vis_contents += clash_rank_mark
	clash_rank_mark.icon_state = GLOB.clash_sentry_rank_states[rank]

/obj/structure/machinery/defenses/sentry/proc/clash_blast_share()
	return clash_module == /datum/clash_sentry_module/blast_shield ? CLASH_SENTRY_SHIELD_MULT : 1

/proc/clash_sentry_rank(kills)
	. = 0
	for(var/needed in GLOB.clash_sentry_rank_kills)
		if(kills >= needed)
			.++

/proc/clash_sentry_rank_text(kills)
	var/rank = clash_sentry_rank(kills)
	. = "[kills] kill\s"
	if(rank)
		. += ", rank [GLOB.clash_sentry_rank_names[rank]], fires [rank * CLASH_SENTRY_RANK_SPEEDUP * 100]% faster"
	if(rank < length(GLOB.clash_sentry_rank_kills))
		. += ". Rank [GLOB.clash_sentry_rank_names[rank + 1]] at [GLOB.clash_sentry_rank_kills[rank + 1]] kills"
	. += "."

/proc/clash_sentry_scored(obj/structure/machinery/defenses/sentry/turret)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(!istype(turret) || !turret.clash_tier || QDELETED(turret) || !istype(clash_mode) || !clash_mode.match_live)
		return
	var/old_rank = clash_sentry_rank(turret.clash_kills)
	turret.clash_kills++
	var/rank = clash_sentry_rank(turret.clash_kills)
	if(rank == old_rank)
		return
	turret.clash_apply_rank()
	turret.clash_alert("reached rank [GLOB.clash_sentry_rank_names[rank]] and fires [rank * CLASH_SENTRY_RANK_SPEEDUP * 100]% faster", 'sound/machines/ping.ogg')

/proc/clash_sentry_engraved(ckey, sentry_type)
	if(!clash_progression_active())
		return FALSE
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	var/track_type = clash_sentry_track_key(sentry_type)
	var/list/unlocks = GLOB.clash_weapon_tracks[track_type]
	return progress && unlocks && progress.weapon_level(track_type) > length(unlocks)

/proc/clash_sentry_track_key(item_type)
	var/tier = clash_sentry_tier_of(item_type)
	if(!tier && ispath(item_type, /obj/structure/machinery/defenses/sentry))
		var/obj/structure/machinery/defenses/sentry/turret = item_type
		tier = initial(turret.clash_tier)
	return tier ? GLOB.clash_sentry_track_keys[tier] : null

/proc/build_clash_sentry_tracks()
	for(var/tier in GLOB.clash_sentry_track_keys)
		var/track_type = GLOB.clash_sentry_track_keys[tier]
		var/list/unlocks = list()
		var/list/levels = list()
		var/index = 0
		for(var/module_type in GLOB.clash_sentry_modules)
			index++
			unlocks += list(list("types" = list(module_type), "xp" = GLOB.clash_sentry_track_xp[index]))
			levels[module_type] = index + 1
		unlocks += list(list("types" = list(), "xp" = CLASH_SENTRY_MASTERY_XP))
		GLOB.clash_weapon_tracks[track_type] = unlocks
		GLOB.clash_weapon_unlock_levels[track_type] = levels

/proc/clash_sentry_preview(sentry_kit_type)
	if(!GLOB.clash_sentry_previews[sentry_kit_type])
		var/image/preview
		if(ispath(sentry_kit_type, /obj/item/device/clash_mg))
			var/obj/item/device/clash_mg/gun = sentry_kit_type
			var/obj/structure/machinery/m56d_hmg/auto/clash/nest = initial(gun.nest_type)
			preview = image(initial(nest.icon), initial(nest.icon_state))
		else
			var/obj/item/defenses/handheld/kit = sentry_kit_type
			var/obj/structure/machinery/defenses/sentry/turret = initial(kit.defense_type)
			preview = image(initial(turret.icon), initial(turret.composite_icon) ? "defense_base" : null)
			preview.overlays += image(initial(turret.icon), "[initial(turret.defense_type)] [initial(turret.sentry_type)]_on")
		GLOB.clash_sentry_previews[sentry_kit_type] = icon2base64(getFlatIcon(preview, EAST))
	return GLOB.clash_sentry_previews[sentry_kit_type]

/proc/clash_sentry_kills_now(ckey, tier)
	. = GLOB.clash_sentry_banked_kills[ckey]?[tier] || 0
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in GLOB.clash_engineer_sentries[ckey])
		if(turret.clash_tier == tier)
			. = max(., turret.clash_kills)

/obj/item/defenses/handheld/sentry/deploy_handheld(mob/living/carbon/human/user)
	var/obj/structure/machinery/defenses/sentry/turret = TR
	if(!istype(turret) || !turret.clash_tier)
		return ..()
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can set up sentries."))
		return
	if(turret.clash_owner_ckey && turret.clash_owner_ckey != user.ckey)
		to_chat(user, SPAN_WARNING("This is not your sentry."))
		return
	var/turf/spot = get_step(user, user.dir)
	var/area/clash_arena/spot_area = get_area(spot)
	if(istype(spot_area) && spot_area.clash_faction)
		to_chat(user, SPAN_WARNING("Sentries can't be set up inside a base."))
		return
	if(clash_near_enemy_base(spot, user.faction))
		to_chat(user, SPAN_WARNING("Too close to the enemy base."))
		return
	deployment_time = GLOB.clash_sentry_tiers[turret.clash_tier]["deploy"] * (clash_has_perk(user, /datum/clash_perk/quick_build) ? 0.5 : 1)
	..()
	if(turret.placed)
		turret.clash_activate(user)

/obj/item/defenses/handheld/sentry/attack_hand(mob/user)
	var/obj/structure/machinery/defenses/sentry/turret = TR
	if(istype(turret) && turret.clash_owner_ckey && user.ckey != turret.clash_owner_ckey)
		to_chat(user, SPAN_WARNING("That belongs to another engineer."))
		return
	return ..()

/proc/clash_near_enemy_base(turf/spot, faction)
	for(var/obj/structure/blocker/clash_gate/gate in range(CLASH_SENTRY_GATE_RANGE, spot))
		if(gate.faction != faction)
			return TRUE
	return FALSE

/obj/structure/machinery/defenses/sentry/attack_hand(mob/user)
	if(!clash_tier)
		return ..()
	if(user.faction != clash_faction)
		return
	to_chat(user, SPAN_NOTICE("[src]: [health]/[health_max] health, [ammo.current_rounds]/[ammo.max_rounds] ammo."))

/obj/structure/machinery/defenses/sentry/attackby(obj/item/tool, mob/living/carbon/human/user)
	if(!clash_tier || QDELETED(tool))
		return ..()
	if(HAS_TRAIT(tool, TRAIT_TOOL_MULTITOOL))
		to_chat(user, SPAN_WARNING("[src] can't be hacked."))
		return
	var/wrench = HAS_TRAIT(tool, TRAIT_TOOL_WRENCH)
	var/metal = istype(tool, /obj/item/stack/sheet/metal)
	var/fuel = istype(tool, /obj/item/ammo_magazine/flamer_tank)
	if(!wrench && !metal && !fuel && !iswelder(tool))
		return ..()
	if(user.faction != clash_faction)
		return
	if(!clash_is_engineer(user))
		to_chat(user, SPAN_WARNING("Only engineers can work on sentries."))
		return
	if(wrench)
		clash_wrench(user)
	else if(metal || fuel)
		if(fuel != (clash_tier == CLASH_SENTRY_FLAMER))
			to_chat(user, SPAN_WARNING(clash_tier == CLASH_SENTRY_FLAMER ? "Refuel it with a flamer fuel tank." : "Reload it with metal."))
			return
		if(fuel)
			clash_refuel(user, tool)
		else
			clash_reload(user, tool)
	else
		clash_repair(user, tool)

/obj/structure/machinery/defenses/sentry/proc/clash_wrench(mob/living/carbon/human/user)
	var/list/choices = list()
	var/list/facings = list()
	for(var/facing in GLOB.cardinals)
		if(facing == dir)
			continue
		var/label = "Face [dir2text(facing)]"
		choices[label] = image('icons/mob/radial.dmi', GLOB.clash_sentry_turn_icons["[facing]"])
		facings[label] = facing
	if(user.ckey == clash_owner_ckey)
		choices["Pack up"] = image(HD.icon, HD.icon_state)
	var/choice = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	var/obj/item/held = user.get_active_hand()
	if(!choice || QDELETED(src) || !placed || !held || !HAS_TRAIT(held, TRAIT_TOOL_WRENCH))
		return
	if(choice == "Pack up")
		clash_pack(user)
		return
	if(!do_after(user, CLASH_SENTRY_TURN_TIME, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src) || !placed)
		return
	setDir(facings[choice])
	unset_range()
	target = null
	clash_drop_laser()
	update_minimap_icon()
	playsound(loc, 'sound/items/Ratchet.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You turn [src] to face [dir2text(dir)]."))

/obj/structure/machinery/defenses/sentry/proc/clash_pack(mob/living/carbon/human/user)
	if(user.ckey != clash_owner_ckey)
		to_chat(user, SPAN_WARNING("Only the engineer who set it up can pack it up."))
		return
	if(health < health_max * 0.25)
		to_chat(user, SPAN_WARNING("[src] is too damaged to pack up. Repair it first."))
		return
	var/pack_time = CLASH_SENTRY_PACK_TIME * (clash_has_perk(user, /datum/clash_perk/quick_build) ? 0.5 : 1)
	if(!do_after(user, pack_time, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src) || !placed)
		return
	power_off()
	deltimer(clash_module_timer)
	clash_drop_laser()
	clash_hide_ammo_bar()
	HD.forceMove(get_turf(src))
	HD.dropped = 1
	placed = 0
	forceMove(HD)
	HD.update_icon()
	user.put_in_hands(HD)
	playsound(get_turf(user), 'sound/mecha/mechmove04.ogg', 30, 1)
	to_chat(user, SPAN_NOTICE("You pack up [src]."))

/obj/structure/machinery/defenses/sentry/proc/clash_reload(mob/living/carbon/human/user, obj/item/stack/sheet/metal/sheets)
	var/loaded = clash_metal_reload(user, sheets, src, ammo.max_rounds - ammo.current_rounds, ammo.max_rounds, clash_reload_metal(user))
	if(!loaded)
		return
	ammo.current_rounds = min(ammo.max_rounds, ammo.current_rounds + loaded)
	update_icon()
	to_chat(user, SPAN_NOTICE("You reload [src]: [ammo.current_rounds]/[ammo.max_rounds] ammo."))

/proc/clash_reload_metal(mob/living/carbon/human/engineer)
	return CLASH_SENTRY_RELOAD_METAL * (clash_has_perk(engineer, /datum/clash_perk/efficient_reload) ? 0.5 : 1)

/proc/clash_build_time_mult(mob/living/carbon/human/engineer)
	return clash_has_perk(engineer, /datum/clash_perk/quick_build) ? 0.5 : 1

/proc/clash_metal_reload(mob/living/carbon/human/user, obj/item/stack/sheet/metal/sheets, atom/target, missing, max_rounds, full_load)
	if(missing <= 0)
		to_chat(user, SPAN_WARNING("[target] is fully loaded."))
		return 0
	var/used = min(CEILING(missing * full_load / max_rounds, 1), sheets.amount)
	if(!do_after(user, CLASH_SENTRY_RELOAD_TIME, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, target) || QDELETED(target) || !sheets.use(used))
		return 0
	playsound(target.loc, 'sound/weapons/handling/gun_m16_reload.ogg', 25, 1)
	return CEILING(used * max_rounds / full_load, 1)

/obj/structure/machinery/defenses/sentry/proc/clash_refuel(mob/living/carbon/human/user, obj/item/ammo_magazine/flamer_tank/tank)
	var/missing = ammo.max_rounds - ammo.current_rounds
	if(missing <= 0)
		to_chat(user, SPAN_WARNING("[src] is full."))
		return
	if(tank.current_rounds <= 0)
		to_chat(user, SPAN_WARNING("That tank is empty."))
		return
	var/fuel_used = min(CEILING(missing * tank.max_rounds / ammo.max_rounds, 1), tank.current_rounds)
	if(!do_after(user, CLASH_SENTRY_RELOAD_TIME, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src) || tank.current_rounds < fuel_used)
		return
	tank.current_rounds -= fuel_used
	tank.update_icon()
	ammo.current_rounds = min(ammo.max_rounds, ammo.current_rounds + CEILING(fuel_used * ammo.max_rounds / tank.max_rounds, 1))
	update_icon()
	playsound(loc, 'sound/weapons/handling/flamer_reload.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You refuel [src]: [ammo.current_rounds]/[ammo.max_rounds] shots."))

/obj/structure/machinery/defenses/sentry/proc/clash_repair(mob/living/carbon/human/user, obj/item/tool/weldingtool/welder)
	if(health >= health_max)
		to_chat(user, SPAN_WARNING("[src] doesn't need repairs."))
		return
	if(!welder.isOn())
		to_chat(user, SPAN_WARNING("Turn the welder on first."))
		return
	if(!do_after(user, CLASH_SENTRY_REPAIR_TIME * clash_repair_mult(user), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_FRIENDLY, src) || QDELETED(src) || !welder.remove_fuel(1, user))
		return
	var/repaired = min(CLASH_SENTRY_REPAIR_HP, health_max - health)
	update_health(-repaired)
	playsound(loc, 'sound/items/Welder2.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You repair [src]: [health]/[health_max] health."))
	var/paid = min(repaired, clash_enemy_damage)
	if(paid <= 0)
		return
	clash_enemy_damage -= paid
	clash_progress_repair(user, paid)

/obj/structure/machinery/defenses/sentry/get_projectile_hit_boolean(obj/projectile/bullet)
	var/mob/shooter = bullet.firer
	if(clash_tier && ismob(shooter) && shooter.faction == clash_faction)
		return FALSE
	return ..()

/obj/structure/machinery/defenses/sentry/bullet_act(obj/projectile/bullet)
	if(!clash_tier)
		return ..()
	bullet_ping(bullet)
	if(istype(bullet.ammo, /datum/ammo/bullet/shrapnel))
		return TRUE
	var/damage = floor(bullet.damage * CLASH_SENTRY_BULLET_SHARE)
	clash_enemy_damage += clash_enemy_share(bullet.firer, clash_faction, damage)
	update_health(damage)
	return TRUE

/obj/structure/machinery/defenses/sentry/ex_act(severity)
	if(!clash_tier)
		return ..()
	if(health <= 0 || world.time < clash_blast_guard)
		return
	update_health(severity * CLASH_SENTRY_BLAST_MULT * clash_blast_share())

/obj/structure/machinery/defenses/sentry/damaged_action(damage)
	if(!clash_tier)
		return ..()
	clash_last_hit = world.time
	if(prob(10))
		spark_system.start()
	clash_alert("is under fire", 'sound/machines/twobeep.ogg', TRUE)

/obj/structure/machinery/defenses/sentry/flamer/clash/actual_fire(atom/target)
	. = ..()
	clash_flamer_check_ammo()
	clash_update_ammo_bar()

/obj/structure/machinery/defenses/sentry/flamer/upp/clash/actual_fire(atom/target)
	. = ..()
	clash_flamer_check_ammo()
	clash_update_ammo_bar()

/obj/structure/machinery/defenses/sentry/clash/actual_fire(atom/target)
	. = ..()
	clash_update_ammo_bar()

/obj/structure/machinery/defenses/sentry/upp/clash/actual_fire(atom/target)
	. = ..()
	clash_update_ammo_bar()

/obj/structure/machinery/defenses/sentry/clash/get_target(atom/movable/new_target)
	. = ..()
	clash_aim_laser()

/obj/structure/machinery/defenses/sentry/upp/clash/get_target(atom/movable/new_target)
	. = ..()
	clash_aim_laser()

/obj/structure/machinery/defenses/sentry/update_icon()
	. = ..()
	if(clash_tier)
		clash_update_ammo_bar()

/obj/structure/machinery/defenses/sentry/proc/clash_update_ammo_bar()
	if(!placed || !ammo?.max_rounds)
		clash_hide_ammo_bar()
		return
	var/fraction = clamp(ammo.current_rounds / ammo.max_rounds, 0, 1)
	var/step = CEILING(fraction * CLASH_AMMO_BAR_STEPS, 1)
	if(clash_ammo_bar && step == clash_ammo_step)
		return
	clash_ammo_step = step
	if(!clash_ammo_bar)
		clash_ammo_bar = image('icons/effects/effects.dmi', src, "white", ABOVE_MOB_LAYER)
		clash_ammo_bar.alpha = CLASH_AMMO_BAR_ALPHA
		clash_ammo_bar.appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM|KEEP_APART
	var/height = max(1, round(CLASH_AMMO_BAR_HEIGHT * step / CLASH_AMMO_BAR_STEPS))
	var/matrix/shape = matrix()
	shape.Scale(1 / world.icon_size, height / world.icon_size)
	shape.Translate(CLASH_AMMO_BAR_X, CLASH_AMMO_BAR_Y + height * 0.5)
	clash_ammo_bar.transform = shape
	clash_ammo_bar.color = gradient(list(0, CLASH_AMMO_COLOR_EMPTY, 0.5, CLASH_AMMO_COLOR_HALF, 1, CLASH_AMMO_COLOR_FULL), fraction)
	clash_refresh_ammo_viewers()

/obj/structure/machinery/defenses/sentry/proc/clash_refresh_ammo_viewers()
	if(!clash_ammo_bar)
		return
	LAZYINITLIST(clash_ammo_viewers)
	var/list/team = list()
	if(placed)
		for(var/client/viewer as anything in GLOB.clients)
			var/mob/body = viewer.mob
			if(body?.faction == clash_faction || (isobserver(body) && body.mind?.original?.faction == clash_faction))
				team += viewer
	for(var/client/viewer as anything in clash_ammo_viewers - team)
		viewer?.images -= clash_ammo_bar
	for(var/client/viewer as anything in team - clash_ammo_viewers)
		viewer.images += clash_ammo_bar
	clash_ammo_viewers = team

/obj/structure/machinery/defenses/sentry/proc/clash_hide_ammo_bar()
	clash_ammo_step = -1
	for(var/client/viewer as anything in clash_ammo_viewers)
		viewer?.images -= clash_ammo_bar
	clash_ammo_viewers = null

/proc/clash_refresh_all_ammo_bars()
	for(var/ckey in GLOB.clash_engineer_sentries)
		for(var/obj/structure/machinery/defenses/sentry/turret as anything in GLOB.clash_engineer_sentries[ckey])
			turret.clash_refresh_ammo_viewers()

/obj/structure/machinery/defenses/sentry/proc/clash_aim_laser()
	var/mob/living/victim = target
	if(!placed || !turned_on || !istype(victim) || !clash_can_track(victim))
		clash_drop_laser()
		return
	if(victim == clash_laser_target)
		return
	clash_drop_laser(TRUE)
	clash_laser_target = victim
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(clash_laser_target_moved))
	RegisterSignal(victim, list(COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETING), PROC_REF(clash_laser_target_lost))
	if(!clash_laser)
		clash_laser = new(get_turf(src))
		clash_laser.transform = clash_laser_shape(clash_laser_point(victim))
		return
	animate(clash_laser, transform = clash_laser_shape(clash_laser_point(victim)), time = CLASH_LASER_SWEEP_TIME, easing = SINE_EASING|EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)

/obj/structure/machinery/defenses/sentry/proc/clash_laser_target_moved(atom/movable/mover, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(!clash_can_track(clash_laser_target))
		clash_drop_laser()
		return
	var/glide_time = clash_laser_target.glide_size ? clamp(world.icon_size / clash_laser_target.glide_size * world.tick_lag, world.tick_lag, CLASH_LASER_SWEEP_TIME) : world.tick_lag
	animate(clash_laser, transform = clash_laser_shape(clash_laser_point(clash_laser_target)), time = glide_time, flags = ANIMATION_LINEAR_TRANSFORM)

/obj/structure/machinery/defenses/sentry/proc/clash_laser_target_lost()
	SIGNAL_HANDLER
	clash_drop_laser()

/obj/structure/machinery/defenses/sentry/proc/clash_drop_laser(keep_beam)
	if(clash_laser_target)
		UnregisterSignal(clash_laser_target, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETING))
		clash_laser_target = null
	if(keep_beam || !clash_laser)
		return
	var/obj/effect/clash_sentry_laser/beam = clash_laser
	clash_laser = null
	animate(beam, alpha = 0, time = CLASH_LASER_FADE_TIME)
	QDEL_IN(beam, CLASH_LASER_FADE_TIME)

/obj/structure/machinery/defenses/sentry/proc/clash_can_track(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD || victim.invisibility || victim.z != z || get_dist(src, victim) > sentry_range)
		return FALSE
	var/turf/spot = get_turf(victim)
	var/ahead = dir == NORTH ? spot.y - y : (dir == SOUTH ? y - spot.y : (dir == EAST ? spot.x - x : x - spot.x))
	var/side = (dir & (NORTH|SOUTH)) ? spot.x - x : spot.y - y
	if(ahead <= 0 || arctan(abs(side) / ahead) * 2 > CLASH_SENTRY_ARC)
		return FALSE
	for(var/turf/step in get_line(src, spot, include_start_atom = FALSE))
		if(step.density || step.opacity)
			return FALSE
		for(var/obj/structure/thing in step)
			if(thing.opacity)
				return FALSE
		for(var/obj/effect/particle_effect/smoke/smoke in step)
			if(smoke.obscuring)
				return FALSE
	return TRUE

/obj/structure/machinery/defenses/sentry/proc/clash_laser_point(atom/movable/victim)
	return list((victim.x - x) * world.icon_size + victim.pixel_x, (victim.y - y) * world.icon_size + victim.pixel_y)

/obj/structure/machinery/defenses/sentry/proc/clash_laser_shape(list/point)
	var/start_x = (dir & EAST ? CLASH_LASER_MUZZLE : (dir & WEST ? -CLASH_LASER_MUZZLE : 0))
	var/start_y = CLASH_LASER_HEIGHT + (dir & NORTH ? CLASH_LASER_MUZZLE : (dir & SOUTH ? -CLASH_LASER_MUZZLE : 0))
	var/dx = point[1] - start_x
	var/dy = point[2] - start_y
	var/length = max(1, sqrt(dx * dx + dy * dy))
	var/matrix/shape = matrix()
	shape.Scale(length / world.icon_size, 1 / world.icon_size)
	shape.Translate(length * 0.5, 0)
	shape.Turn(-arctan(dx, dy))
	shape.Translate(start_x, start_y)
	return shape

/obj/effect/clash_sentry_laser
	icon = 'icons/effects/effects.dmi'
	icon_state = "white"
	color = "#FF2B2B"
	alpha = CLASH_LASER_ALPHA
	blend_mode = BLEND_ADD
	layer = ABOVE_MOB_LAYER
	plane = ABOVE_LIGHTING_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE

/obj/effect/clash_sentry_laser/Initialize(mapload, ...)
	. = ..()
	var/image/glow = image(icon, icon_state)
	glow.alpha = CLASH_LASER_GLOW_ALPHA
	glow.transform = matrix(1, 0, 0, 0, CLASH_LASER_GLOW_WIDTH, 0)
	overlays += glow

/obj/structure/machinery/defenses/sentry/proc/clash_flamer_check_ammo()
	if(ammo.current_rounds <= 0)
		clash_alert("is out of ammo", 'sound/weapons/smg_empty_alarm.ogg')

/obj/structure/machinery/defenses/sentry/flamer/clash/destroyed_action()
	clash_burst_apart()

/obj/structure/machinery/defenses/sentry/flamer/upp/clash/destroyed_action()
	clash_burst_apart()

/obj/structure/machinery/defenses/sentry/proc/clash_burst_apart()
	visible_message("[icon2html(src, viewers(src))] [SPAN_WARNING("The [name] starts spitting out sparks and smoke!")]")
	playsound(loc, 'sound/mecha/critdestrsyndi.ogg', 25, 1)
	sleep(5)
	cell_explosion(loc, 10, 10, EXPLOSION_FALLOFF_SHAPE_LINEAR, null, create_cause_data("sentry explosion", owner_mob))
	if(!QDELETED(src))
		qdel(src)

/obj/structure/machinery/defenses/sentry/proc/clash_alert(text, alert_sound, throttled)
	var/client/owner = GLOB.directory[clash_owner_ckey]
	if(!owner || !placed)
		return
	if(throttled)
		if(world.time < clash_next_alert)
			return
		clash_next_alert = world.time + CLASH_SENTRY_ALERT_GAP
	to_chat(owner, SPAN_WARNING("Your [initial(name)] [text]."))
	playsound_client(owner, alert_sound, null, 40)

/obj/structure/machinery/defenses/sentry/proc/clash_low_ammo()
	SIGNAL_HANDLER
	clash_alert("is low on ammo", 'sound/machines/twobeep.ogg')

/obj/structure/machinery/defenses/sentry/proc/clash_empty_ammo()
	SIGNAL_HANDLER
	clash_alert("is out of ammo", 'sound/weapons/smg_empty_alarm.ogg')

/obj/structure/machinery/defenses/sentry/proc/clash_destroyed()
	SIGNAL_HANDLER
	clash_wrecked = TRUE
	clash_alert("was destroyed", 'sound/mecha/critdestrsyndi.ogg')

/obj/item/explosive/grenade/high_explosive/prime()
	if(!clash_fast_medicine())
		return ..()
	var/turf/blast = get_turf(src)
	var/mob/thrower = cause_data?.resolve_mob()
	var/list/hit = list()
	for(var/obj/structure/machinery/defenses/sentry/turret in view(CLASH_GRENADE_SENTRY_RANGE, blast))
		if(turret.clash_tier && turret.placed)
			turret.clash_blast_guard = world.time + 1 SECONDS
			hit[turret] = (CLASH_GRENADE_SENTRY_DAMAGE - CLASH_GRENADE_SENTRY_FALLOFF * get_dist(blast, turret)) * turret.clash_blast_share()
	. = ..()
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in hit)
		turret.clash_enemy_damage += clash_enemy_share(thrower, turret.clash_faction, hit[turret])
		INVOKE_ASYNC(turret, TYPE_PROC_REF(/obj/structure/machinery/defenses, update_health), hit[turret])

/proc/clash_sentry_kit_for(faction, tier)
	return GLOB.clash_sentry_kits[faction]?[tier]

/proc/clash_sentry_tier_of(item_type)
	for(var/faction in GLOB.clash_sentry_kits)
		for(var/tier in GLOB.clash_sentry_kits[faction])
			if(GLOB.clash_sentry_kits[faction][tier] == item_type)
				return tier
	return null

#undef CLASH_SENTRY_BULLET_SHARE
#undef CLASH_SENTRY_BLAST_MULT
#undef CLASH_GRENADE_SENTRY_DAMAGE
#undef CLASH_GRENADE_SENTRY_FALLOFF
#undef CLASH_GRENADE_SENTRY_RANGE
#undef CLASH_SENTRY_PACK_TIME
#undef CLASH_SENTRY_REPAIR_TIME
#undef CLASH_SENTRY_REPAIR_HP
#undef CLASH_SENTRY_RELOAD_TIME
#undef CLASH_SENTRY_RELOAD_METAL
#undef CLASH_SENTRY_GATE_RANGE
#undef CLASH_SENTRY_ALERT_GAP
#undef CLASH_SENTRY_ARC
#undef CLASH_AMMO_BAR_STEPS
#undef CLASH_AMMO_BAR_HEIGHT
#undef CLASH_AMMO_BAR_ALPHA
#undef CLASH_AMMO_BAR_X
#undef CLASH_AMMO_BAR_Y
#undef CLASH_AMMO_COLOR_FULL
#undef CLASH_AMMO_COLOR_HALF
#undef CLASH_AMMO_COLOR_EMPTY
#undef CLASH_LASER_ALPHA
#undef CLASH_LASER_GLOW_ALPHA
#undef CLASH_LASER_GLOW_WIDTH
#undef CLASH_LASER_SWEEP_TIME
#undef CLASH_LASER_FADE_TIME
#undef CLASH_LASER_MUZZLE
#undef CLASH_LASER_HEIGHT

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

GLOBAL_LIST_EMPTY(clash_engineer_sentries)

GLOBAL_LIST_INIT(clash_sentry_kits, list(
	FACTION_MARINE = list(
		CLASH_SENTRY_LIGHT = /obj/item/defenses/handheld/sentry/mini/clash,
		CLASH_SENTRY_GUN = /obj/item/defenses/handheld/sentry/clash,
		CLASH_SENTRY_FLAMER = /obj/item/defenses/handheld/sentry/flamer/clash,
	),
	FACTION_UPP = list(
		CLASH_SENTRY_LIGHT = /obj/item/defenses/handheld/sentry/upp/light/clash,
		CLASH_SENTRY_GUN = /obj/item/defenses/handheld/sentry/upp/clash,
		CLASH_SENTRY_FLAMER = /obj/item/defenses/handheld/sentry/flamer/upp/clash,
	),
))

/obj/structure/machinery/defenses/sentry/var/clash_tier
/obj/structure/machinery/defenses/sentry/var/clash_owner_ckey
/obj/structure/machinery/defenses/sentry/var/clash_faction
/obj/structure/machinery/defenses/sentry/var/clash_enemy_damage = 0
/obj/structure/machinery/defenses/sentry/var/clash_next_alert = 0
/obj/structure/machinery/defenses/sentry/var/clash_blast_guard = 0
/obj/structure/machinery/defenses/sentry/var/clash_deployed_at = 0

/obj/structure/machinery/defenses/sentry/mini/clash
	name = "Light Sentry"
	desc = "A small sentry that covers every direction at short range. Wrench to pack it up, metal to reload, welder to repair."
	clash_tier = CLASH_SENTRY_LIGHT
	handheld_type = /obj/item/defenses/handheld/sentry/mini/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/upp/light/clash
	name = "Light Sentry"
	desc = "A small sentry that covers every direction at short range. Wrench to pack it up, metal to reload, welder to repair."
	density = FALSE
	clash_tier = CLASH_SENTRY_LIGHT
	handheld_type = /obj/item/defenses/handheld/sentry/upp/light/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/clash
	name = "Sentry Gun"
	desc = "A sentry that guards the way it faces. Wrench to pack it up, metal to reload, welder to repair."
	clash_tier = CLASH_SENTRY_GUN
	handheld_type = /obj/item/defenses/handheld/sentry/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/upp/clash
	name = "Sentry Gun"
	desc = "A sentry that guards the way it faces. Wrench to pack it up, metal to reload, welder to repair."
	clash_tier = CLASH_SENTRY_GUN
	handheld_type = /obj/item/defenses/handheld/sentry/upp/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/flamer/clash
	name = "Flamer Sentry"
	desc = "A sentry that sets anyone in front of it on fire. Wrench to pack it up, a flamer fuel tank to refuel, welder to repair."
	clash_tier = CLASH_SENTRY_FLAMER
	handheld_type = /obj/item/defenses/handheld/sentry/flamer/clash
	choice_categories = list()
	selected_categories = list()

/obj/structure/machinery/defenses/sentry/flamer/upp/clash
	name = "Flamer Sentry"
	desc = "A sentry that sets anyone in front of it on fire. Wrench to pack it up, a flamer fuel tank to refuel, welder to repair."
	clash_tier = CLASH_SENTRY_FLAMER
	handheld_type = /obj/item/defenses/handheld/sentry/flamer/upp/clash
	choice_categories = list()
	selected_categories = list()

/obj/item/defenses/handheld/sentry/mini/clash
	name = "packed Light Sentry"
	defense_type = /obj/structure/machinery/defenses/sentry/mini/clash

/obj/item/defenses/handheld/sentry/upp/light/clash
	name = "packed Light Sentry"
	defense_type = /obj/structure/machinery/defenses/sentry/upp/light/clash

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
	omni_directional = stats["omni"]
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
		. += SPAN_HELPFUL("Click it with a flamer fuel tank to refuel it. A welder repairs it and a wrench packs it up.")
	else
		. += SPAN_HELPFUL("Click it with metal to reload it, [clash_has_perk(user, /datum/clash_perk/efficient_reload) ? 5 : 10] sheets for a full load. A welder repairs it and a wrench packs it up.")

/obj/structure/machinery/defenses/sentry/proc/clash_activate(mob/living/carbon/human/engineer)
	faction_group = LAZYCOPY(engineer.faction_group)
	clash_faction = engineer.faction
	clash_owner_ckey = engineer.ckey
	owner_mob = engineer
	clash_deployed_at = world.time
	var/limit = clash_has_perk(engineer, /datum/clash_perk/twin_sentries) ? 2 : 1
	var/list/standing = list()
	for(var/obj/structure/machinery/defenses/sentry/other as anything in GLOB.clash_engineer_sentries[engineer.ckey])
		if(other != src && other.placed)
			standing += other
	while(length(standing) >= limit)
		var/obj/structure/machinery/defenses/sentry/oldest = standing[1]
		for(var/obj/structure/machinery/defenses/sentry/other as anything in standing)
			if(other.clash_deployed_at < oldest.clash_deployed_at)
				oldest = other
		standing -= oldest
		to_chat(engineer, SPAN_NOTICE("Your older [oldest.name] shuts down."))
		qdel(oldest)
	var/ratio = health / health_max
	health_max = GLOB.clash_sentry_tiers[clash_tier]["health"] * (clash_has_perk(engineer, /datum/clash_perk/hardened) ? CLASH_HARDENED_MULT : 1)
	health = round(health_max * ratio)
	power_on()

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
		clash_pack(user)
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
	HD.forceMove(get_turf(src))
	HD.dropped = 1
	placed = 0
	forceMove(HD)
	HD.update_icon()
	user.put_in_hands(HD)
	playsound(get_turf(user), 'sound/mecha/mechmove04.ogg', 30, 1)
	to_chat(user, SPAN_NOTICE("You pack up [src]."))

/obj/structure/machinery/defenses/sentry/proc/clash_reload(mob/living/carbon/human/user, obj/item/stack/sheet/metal/sheets)
	var/missing = ammo.max_rounds - ammo.current_rounds
	if(missing <= 0)
		to_chat(user, SPAN_WARNING("[src] is fully loaded."))
		return
	var/full_load = CLASH_SENTRY_RELOAD_METAL * (clash_has_perk(user, /datum/clash_perk/efficient_reload) ? 0.5 : 1)
	var/used = min(CEILING(missing * full_load / ammo.max_rounds, 1), sheets.amount)
	if(!do_after(user, CLASH_SENTRY_RELOAD_TIME, INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD, src) || QDELETED(src) || !sheets.use(used))
		return
	ammo.current_rounds = min(ammo.max_rounds, ammo.current_rounds + CEILING(used * ammo.max_rounds / full_load, 1))
	update_icon()
	playsound(loc, 'sound/weapons/handling/gun_m16_reload.ogg', 25, 1)
	to_chat(user, SPAN_NOTICE("You reload [src]: [ammo.current_rounds]/[ammo.max_rounds] ammo."))

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
	update_health(severity * CLASH_SENTRY_BLAST_MULT)

/obj/structure/machinery/defenses/sentry/damaged_action(damage)
	if(!clash_tier)
		return ..()
	if(prob(10))
		spark_system.start()
	clash_alert("is under fire", 'sound/machines/twobeep.ogg', TRUE)

/obj/structure/machinery/defenses/sentry/flamer/clash/actual_fire(atom/target)
	. = ..()
	clash_flamer_check_ammo()

/obj/structure/machinery/defenses/sentry/flamer/upp/clash/actual_fire(atom/target)
	. = ..()
	clash_flamer_check_ammo()

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
	to_chat(owner, SPAN_WARNING("Your [name] [text]."))
	playsound_client(owner, alert_sound, null, 40)

/obj/structure/machinery/defenses/sentry/proc/clash_low_ammo()
	SIGNAL_HANDLER
	clash_alert("is low on ammo", 'sound/machines/twobeep.ogg')

/obj/structure/machinery/defenses/sentry/proc/clash_empty_ammo()
	SIGNAL_HANDLER
	clash_alert("is out of ammo", 'sound/weapons/smg_empty_alarm.ogg')

/obj/structure/machinery/defenses/sentry/proc/clash_destroyed()
	SIGNAL_HANDLER
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
			hit[turret] = CLASH_GRENADE_SENTRY_DAMAGE - CLASH_GRENADE_SENTRY_FALLOFF * get_dist(blast, turret)
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

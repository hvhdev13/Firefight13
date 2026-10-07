#define CLASH_WIDE_ORDERS_RANGE 10
#define CLASH_QUICK_ORDERS_COOLDOWN (50 SECONDS)
#define CLASH_LONG_ORDERS_MULT 1.5
#define CLASH_BANDOLIER_EVERY 5
#define CLASH_BANDOLIER_FUEL_BACK 0.2
#define CLASH_BANDOLIER_FUEL_CHECK (3 SECONDS)
#define CLASH_QUICK_DRAW_CUT 0.5
#define CLASH_LONG_THROW_RANGE 2
#define CLASH_ADRENALINE_TIME (5 SECONDS)
#define CLASH_ADRENALINE_SPEED 1.2
#define CLASH_FAST_COVER_MULT 0.5
#define CLASH_QUICK_FIX_MULT 0.5
#define CLASH_BIPOD_DEPLOY_TIME (1.5 SECONDS)
#define CLASH_QUICK_BRACE_TIME (1 SECONDS)

/datum/clash_perk
	var/name
	var/desc
	var/class
	var/level
	var/icon_type

/datum/clash_perk/proc/lock_text(ckey, job)
	if(class && class != GLOB.clash_job_classes[job])
		return "Not for this class"
	if(!clash_progression_gating())
		return null
	var/datum/clash_progress/progress = clash_gate_progress(ckey)
	if(class)
		return progress.class_level(class) < level ? "Unlocks at [GLOB.clash_class_names[class]] level [level]" : null
	var/faction = clash_kit_faction_for_job(job)
	return progress.faction_level(faction) < level ? "Unlocks at [clash_side_name(faction)] level [level]" : null

/datum/clash_perk/medic_sense
	name = "Medic Sense"
	desc = "Teammates under half health show as a small red cross on your radar"
	class = CLASH_CLASS_MEDIC
	level = 2
	icon_type = /obj/item/clothing/glasses/hud/health

/datum/clash_perk/triage
	name = "Triage"
	desc = "Revivable teammates show on your radar at any range"
	class = CLASH_CLASS_MEDIC
	level = 4
	icon_type = /obj/item/device/healthanalyzer

/datum/clash_perk/loud_call
	name = "Loud Call"
	desc = "Teammates who shout *medic ping you with their distance and direction"
	class = CLASH_CLASS_MEDIC
	level = 6
	icon_type = /obj/item/device/radio

/datum/clash_perk/quick_zap
	name = "Quick Zap"
	desc = "Your defibrillator zaps in 1 second instead of 1.5"
	class = CLASH_CLASS_MEDIC
	level = 8
	icon_type = /obj/item/device/defibrillator

/datum/clash_perk/large_pouch
	name = "Large Medic Pouch"
	desc = "Your first-aid pouch becomes a large medic pouch: 8 slots (from 4) with more supplies"
	class = CLASH_CLASS_MEDIC
	level = 10
	icon_type = /obj/item/storage/pouch/firstaid/clash/medic/large

/datum/clash_perk/adrenaline
	name = "Adrenaline"
	desc = "Teammates you revive move 20% faster for 5 seconds"
	class = CLASH_CLASS_MEDIC
	level = 12
	icon_type = /obj/item/reagent_container/hypospray/autoinjector/adrenaline

/datum/clash_perk/field_surgeon
	name = "Field Surgeon"
	desc = "Teammates you revive always get up with 50 health, even if revived again within a minute"
	class = CLASH_CLASS_MEDIC
	level = 14
	icon_type = /obj/item/tool/surgery/surgical_line

/datum/clash_perk/second_wind
	name = "Second Wind"
	desc = "Teammates you revive get up with 20 more health"
	class = CLASH_CLASS_MEDIC
	level = 16
	icon_type = /obj/item/stack/medical/advanced/bruise_pack

/datum/clash_perk/fast_cover
	name = "Fast Cover"
	desc = "Your barricades go up twice as fast"
	class = CLASH_CLASS_ENGINEER
	level = 2
	icon_type = /obj/item/stack/sandbags

/datum/clash_perk/quick_fix
	name = "Quick Fix"
	desc = "Welder repairs on sentries and barricades take half the time"
	class = CLASH_CLASS_ENGINEER
	level = 4
	icon_type = /obj/item/tool/weldingtool

/datum/clash_perk/efficient_reload
	name = "Efficient Reload"
	desc = "Your sentries reload with half the metal"
	class = CLASH_CLASS_ENGINEER
	level = 6
	icon_type = /obj/item/stack/sheet/metal

/datum/clash_perk/quick_build
	name = "Quick Build"
	desc = "Your sentries and ammo crate set up and pack up twice as fast"
	class = CLASH_CLASS_ENGINEER
	level = 8
	icon_type = /obj/item/tool/wrench

/datum/clash_perk/big_crate
	name = "Big Crate"
	desc = "Your ammo crate holds 15 and restocks every 10 seconds"
	class = CLASH_CLASS_ENGINEER
	level = 10
	icon_type = /obj/item/clash_ammo_crate

/datum/clash_perk/blast_crate
	name = "Blast Crate"
	desc = "Your ammo crate survives one explosion"
	class = CLASH_CLASS_ENGINEER
	level = 14
	icon_type = /obj/item/clash_ammo_crate/upp

/datum/clash_perk/hardened
	name = "Hardened"
	desc = "Your sentries and barricades have 25% more health"
	class = CLASH_CLASS_ENGINEER
	level = 16
	icon_type = /obj/item/stack/sheet/plasteel

/datum/clash_perk/twin_sentries
	name = "Twin Sentries"
	desc = "Keep two sentries up at once"
	class = CLASH_CLASS_ENGINEER
	level = 18
	icon_type = /obj/item/defenses/handheld/sentry/mini/clash

/datum/clash_perk/wide_orders
	name = "Wide Orders"
	desc = "Your orders reach 10 tiles instead of 7"
	class = CLASH_CLASS_LEADER
	level = 4
	icon_type = /obj/item/device/megaphone

/datum/clash_perk/long_orders
	name = "Long Orders"
	desc = "Your orders last 50% longer"
	class = CLASH_CLASS_LEADER
	level = 7
	icon_type = /obj/item/device/binoculars/range

/datum/clash_perk/quick_orders
	name = "Quick Orders"
	desc = "Your next order is ready after 50 seconds instead of 80"
	class = CLASH_CLASS_LEADER
	level = 10
	icon_type = /obj/item/clothing/accessory/device/whistle

/datum/clash_perk/extra_grenade
	name = "Extra Grenade"
	desc = "Spawn with one more of the grenades you carry"
	class = CLASH_CLASS_RIFLEMAN
	level = 4
	icon_type = /obj/item/explosive/grenade/high_explosive

/datum/clash_perk/quick_draw
	name = "Quick Draw"
	desc = "Draw and wield guns in half the time"
	class = CLASH_CLASS_RIFLEMAN
	level = 7
	icon_type = /obj/item/clothing/accessory/storage/holster

/datum/clash_perk/bandolier
	name = "Bandolier"
	desc = "Every fifth shot costs no ammo and flamers burn 20% less fuel, so your ammo lasts 25% longer"
	class = CLASH_CLASS_RIFLEMAN
	level = 10
	icon_type = /obj/item/ammo_magazine/rifle

/datum/clash_perk/heavy_fire
	name = "Heavy Fire"
	desc = "Your near misses suppress 27 (from 18)"
	class = CLASH_CLASS_HEAVY
	level = 2
	icon_type = /obj/item/ammo_magazine/rifle/lmg

/datum/clash_perk/spotter
	name = "Spotter"
	desc = "Enemies you suppress past half show as red dots on your team's radar within 14 tiles for 3 seconds"
	class = CLASH_CLASS_HEAVY
	level = 4
	icon_type = /obj/item/device/binoculars

/datum/clash_perk/braced
	name = "Braced"
	desc = "While your bipod is deployed, enemy suppression on you is halved"
	class = CLASH_CLASS_HEAVY
	level = 6
	icon_type = /obj/item/attachable/bipod

/datum/clash_perk/wide_fire
	name = "Wide Fire"
	desc = "Your bullets suppress enemies up to 2.5 tiles from their path (from 1.5)"
	class = CLASH_CLASS_HEAVY
	level = 10
	icon_type = /obj/item/ammo_magazine/pkp

/datum/clash_perk/long_hold
	name = "Long Hold"
	desc = "Suppression you cause holds for 3 seconds before it fades (from 1.5)"
	class = CLASH_CLASS_HEAVY
	level = 12
	icon_type = /obj/item/device/motiondetector

/datum/clash_perk/quick_brace
	name = "Quick Brace"
	desc = "Your bipod deploys on the ground in 1 second (from 1.5)"
	class = CLASH_CLASS_HEAVY
	level = 14
	icon_type = /obj/item/attachable/bipod/m41ae2

/datum/clash_perk/flak
	name = "Flak"
	desc = "Explosions never tear off your limbs"
	level = 2
	icon_type = /obj/item/clothing/suit/storage/marine/heavy

/datum/clash_perk/steady_nerves
	name = "Steady Nerves"
	desc = "Suppression darkens your screen and slows you half as much"
	level = 4
	icon_type = /obj/item/clothing/mask/cigarette

/datum/clash_perk/keen_ears
	name = "Keen Ears"
	desc = "Enemies within 14 tiles show red on your radar when they fire without a suppressor, or fire a flamer or underbarrel weapon"
	level = 6
	icon_type = /obj/item/device/radio/headset

/datum/clash_perk/long_throw
	name = "Long Throw"
	desc = "You throw grenades 2 tiles further"
	level = 8
	icon_type = /obj/item/explosive/grenade/high_explosive/m15

GLOBAL_LIST_INIT(clash_perks, build_clash_perks())

/proc/build_clash_perks()
	. = list()
	for(var/perk_type in subtypesof(/datum/clash_perk))
		.[perk_type] = new perk_type

/mob/living/carbon/human/var/list/clash_perks
/mob/living/carbon/human/var/clash_bandolier_shots = 0
/obj/item/ammo_magazine/flamer_tank/var/clash_fuel_mark

/proc/clash_has_perk(mob/living/carbon/human/fighter, perk_type)
	return ishuman(fighter) && (perk_type in fighter.clash_perks)

/proc/add_clash_perk_options(faction)
	for(var/perk_type in GLOB.clash_perks)
		var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
		add_clash_kit_option(faction, perk.class ? KIT_SLOT_CLASS_PERK : KIT_SLOT_GENERAL_PERK, perk.name, perk_type, perk.desc)

/proc/clash_kit_perks(datum/clash_kit/kit)
	. = list()
	for(var/slot in list(KIT_SLOT_CLASS_PERK, KIT_SLOT_GENERAL_PERK))
		var/datum/clash_kit_option/option = kit.get_option(slot)
		if(option)
			. += option.item_type

/proc/clash_perk_names(mob/living/carbon/human/fighter)
	. = list()
	for(var/perk_type in fighter.clash_perks)
		var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
		. += perk.name

/proc/clash_perk_spawn_text(mob/living/carbon/human/fighter)
	if(length(fighter.clash_perks))
		return "Perks: [english_list(clash_perk_names(fighter))]. "
	for(var/perk_type in GLOB.clash_perks)
		var/datum/clash_perk/perk = GLOB.clash_perks[perk_type]
		if(!perk.lock_text(fighter.ckey, fighter.job))
			return "You have perks unlocked, pick them in your loadout. "
	return ""

/proc/clash_give_extra_grenade(mob/living/carbon/human/wearer)
	for(var/obj/item/explosive/grenade/carried in wearer.get_contents())
		if(istype(carried.loc, /obj/item/attachable))
			continue
		clash_kit_spare_ammo(wearer, carried.type, 1)
		return

/proc/clash_bandolier_shot(mob/living/carbon/human/shooter, obj/item/weapon/gun/gun)
	if(gun.active_attachable || !clash_has_perk(shooter, /datum/clash_perk/bandolier))
		return
	shooter.clash_bandolier_shots++
	var/obj/item/ammo_magazine/magazine = gun.current_mag
	if(shooter.clash_bandolier_shots % CLASH_BANDOLIER_EVERY || !magazine)
		return
	var/obj/item/ammo_magazine/internal/tube = magazine
	if(istype(gun, /obj/item/weapon/gun/revolver))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_refund_chamber), shooter, gun, tube, tube.chamber_position, tube.chamber_contents[tube.chamber_position]), 1)
		return
	if(magazine.current_rounds >= magazine.max_rounds)
		return
	if(istype(tube) && length(tube.chamber_contents))
		tube.chamber_position++
		tube.chamber_contents[tube.chamber_position] = gun.ammo.type
	magazine.current_rounds++
	to_chat(shooter, SPAN_NOTICE("Bandolier: free round."))

/proc/clash_refund_chamber(mob/living/carbon/human/shooter, obj/item/weapon/gun/gun, obj/item/ammo_magazine/internal/magazine, position, ammo_path)
	if(QDELETED(gun) || gun.current_mag != magazine || magazine.chamber_contents[position] != "empty")
		return
	magazine.chamber_contents[position] = ammo_path
	magazine.current_rounds++
	to_chat(shooter, SPAN_NOTICE("Bandolier: free round."))

/mob/living/carbon/human/track_shot(weapon, amount = 1)
	. = ..()
	for(var/obj/item/weapon/gun/flamer/flamer in list(get_active_hand(), get_inactive_hand()))
		if(initial(flamer.name) != weapon)
			continue
		clash_mark_loud(src)
		var/obj/item/ammo_magazine/flamer_tank/tank = flamer.current_mag
		if(clash_has_perk(src, /datum/clash_perk/bandolier) && tank?.reagents && isnull(tank.clash_fuel_mark))
			tank.clash_fuel_mark = tank.reagents.total_volume
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_refund_fuel), src, tank), CLASH_BANDOLIER_FUEL_CHECK)
		return

/proc/clash_refund_fuel(mob/living/carbon/human/shooter, obj/item/ammo_magazine/flamer_tank/tank)
	if(QDELETED(tank))
		return
	var/used = tank.clash_fuel_mark - tank.reagents.total_volume
	tank.clash_fuel_mark = null
	if(used <= 0 || !length(tank.reagents.reagent_list))
		return
	var/datum/reagent/fuel = tank.reagents.reagent_list[1]
	var/saved = used * CLASH_BANDOLIER_FUEL_BACK
	tank.reagents.add_reagent(fuel.id, saved)
	to_chat(shooter, SPAN_NOTICE("Bandolier: saved [max(1, round(saved * 100 / tank.reagents.maximum_volume))]% of a tank."))

/obj/item/weapon/gun/equipped(mob/living/user, slot)
	. = ..()
	if(clash_has_perk(user, /datum/clash_perk/quick_draw))
		pull_time -= wield_delay * CLASH_QUICK_DRAW_CUT

/obj/item/weapon/gun/wield(mob/living/user)
	var/was_wielded = flags_item & WIELDED
	. = ..()
	if(!was_wielded && (flags_item & WIELDED) && clash_has_perk(user, /datum/clash_perk/quick_draw))
		wield_time -= wield_delay * CLASH_QUICK_DRAW_CUT

/obj/item/explosive/grenade/throw_atom(atom/target, range, speed = 0, atom/thrower, spin, launch_type = NORMAL_LAUNCH, pass_flags = NO_FLAGS, list/end_throw_callbacks, list/collision_callbacks, tracking = FALSE)
	if(spin && clash_has_perk(thrower, /datum/clash_perk/long_throw))
		range += CLASH_LONG_THROW_RANGE
	return ..()

/mob/living/carbon/human/proc/clash_adrenaline()
	RegisterSignal(src, COMSIG_HUMAN_POST_MOVE_DELAY, PROC_REF(clash_adrenaline_speed), override = TRUE)
	recalculate_move_delay = TRUE
	add_filter("clash_adrenaline", 3, outline_filter(1, "#7fd67fc0"))
	addtimer(CALLBACK(src, PROC_REF(clash_adrenaline_end)), CLASH_ADRENALINE_TIME, TIMER_UNIQUE|TIMER_OVERRIDE)

/mob/living/carbon/human/proc/clash_adrenaline_speed(mob/living/carbon/human/source, list/movedata)
	SIGNAL_HANDLER
	movedata["move_delay"] /= CLASH_ADRENALINE_SPEED

/mob/living/carbon/human/proc/clash_adrenaline_end()
	UnregisterSignal(src, COMSIG_HUMAN_POST_MOVE_DELAY)
	recalculate_move_delay = TRUE
	remove_filter("clash_adrenaline")

/proc/clash_bipod_deploy_time(mob/living/user)
	return clash_has_perk(user, /datum/clash_perk/quick_brace) ? CLASH_QUICK_BRACE_TIME : CLASH_BIPOD_DEPLOY_TIME

/proc/clash_cover_build_mult(mob/living/carbon/human/builder, result_type)
	return ispath(result_type, /obj/structure/barricade) && clash_has_perk(builder, /datum/clash_perk/fast_cover) ? CLASH_FAST_COVER_MULT : 1

/proc/clash_repair_mult(mob/living/carbon/human/repairer)
	return clash_has_perk(repairer, /datum/clash_perk/quick_fix) ? CLASH_QUICK_FIX_MULT : 1

/proc/clash_order_reaches(mob/living/carbon/human/leader, mob/living/carbon/human/listener)
	return !SSticker.mode || !MODE_HAS_FLAG(MODE_FACTION_CLASH) || listener.faction == leader.faction

/proc/clash_order_range(mob/living/carbon/human/leader, range)
	return clash_has_perk(leader, /datum/clash_perk/wide_orders) ? CLASH_WIDE_ORDERS_RANGE : range

/proc/clash_order_cooldown(mob/living/carbon/human/leader, cooldown)
	return clash_has_perk(leader, /datum/clash_perk/quick_orders) ? CLASH_QUICK_ORDERS_COOLDOWN : cooldown

/proc/clash_order_duration(mob/living/carbon/human/leader, duration)
	return clash_has_perk(leader, /datum/clash_perk/long_orders) ? duration * CLASH_LONG_ORDERS_MULT : duration

#undef CLASH_WIDE_ORDERS_RANGE
#undef CLASH_QUICK_ORDERS_COOLDOWN
#undef CLASH_LONG_ORDERS_MULT
#undef CLASH_BANDOLIER_EVERY
#undef CLASH_BANDOLIER_FUEL_BACK
#undef CLASH_BANDOLIER_FUEL_CHECK
#undef CLASH_QUICK_DRAW_CUT
#undef CLASH_LONG_THROW_RANGE
#undef CLASH_ADRENALINE_TIME
#undef CLASH_ADRENALINE_SPEED
#undef CLASH_FAST_COVER_MULT
#undef CLASH_QUICK_FIX_MULT
#undef CLASH_BIPOD_DEPLOY_TIME
#undef CLASH_QUICK_BRACE_TIME

#define CLASH_PACK_HEAL 10
#define CLASH_KIT_HEAL 20
#define CLASH_PACK_FUMBLE (0.5 SECONDS)
#define CLASH_KIT_FUMBLE (1 SECONDS)
#define CLASH_SPLINT_MEDIC (1 SECONDS)
#define CLASH_SPLINT_OTHER (3 SECONDS)
#define CLASH_SUTURE_TIME 0.5
#define CLASH_BURST_FRONT 0.4

#define CLASH_BURST_RATE 1
#define CLASH_BURST_BRUTE 2
#define CLASH_BURST_BURN 3
#define CLASH_BURST_TOX 4
#define CLASH_BURST_OXY 5
#define CLASH_OD_DAMAGE 8
#define CLASH_OD_CRITICAL_DAMAGE 16
#define CLASH_SHRAPNEL_SLOW 0.4
#define CLASH_SHRAPNEL_SLOW_MAX 1.6

GLOBAL_LIST_INIT(clash_med_bursts, list(
	"bicaridine" = list(5, 5, 0, 0, 0),
	"meralyne" = list(5, 7, 0, 0, 0),
	"kelotane" = list(5, 0, 5, 0, 0),
	"dermaline" = list(5, 0, 7, 0, 0),
	"tricordrazine" = list(5, 5, 5, 2.5, 2.5),
	"anti_toxin" = list(5, 0, 0, 5, 0),
	"anti_toxin_plus" = list(1, 0, 0, 1000, 0),
))

GLOBAL_LIST_INIT(clash_med_overdose, list(
	"oxycodone" = list(30, 50),
	"tramadol" = list(40, 60),
))

GLOBAL_LIST_INIT(clash_pouch_stock, list(
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 1,
	/obj/item/reagent_container/hypospray/autoinjector/clash_tramadol = 1,
	/obj/item/stack/medical/bruise_pack/field_dressing = 1,
	/obj/item/stack/medical/splint = 1,
))

GLOBAL_LIST_INIT(clash_medic_pouch_stock, list(
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 2,
	/obj/item/reagent_container/hypospray/autoinjector/oxycodone = 1,
	/obj/item/stack/medical/bruise_pack/field_dressing = 2,
	/obj/item/stack/medical/advanced/bruise_pack/healing_kit = 1,
))

GLOBAL_LIST_INIT(clash_large_medic_pouch_stock, list(
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 3,
	/obj/item/reagent_container/hypospray/autoinjector/oxycodone = 1,
	/obj/item/reagent_container/hypospray/autoinjector/clash_unga = 1,
	/obj/item/stack/medical/bruise_pack/field_dressing = 2,
	/obj/item/stack/medical/advanced/bruise_pack/healing_kit = 1,
))

GLOBAL_LIST_INIT(clash_medic_belt_stock, list(
	/obj/item/stack/medical/advanced/bruise_pack/healing_kit = 4,
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 2,
	/obj/item/reagent_container/hypospray/autoinjector/clash_unga = 2,
	/obj/item/stack/medical/bruise_pack/field_dressing = 2,
	/obj/item/stack/medical/splint = 2,
	/obj/item/reagent_container/hypospray/autoinjector/oxycodone = 2,
	/obj/item/reagent_container/hypospray/autoinjector/clash_tramadol = 1,
	/obj/item/reagent_container/hypospray/autoinjector/adrenaline = 1,
	/obj/item/reagent_container/hypospray/autoinjector/dexalinp = 1,
	/obj/item/reagent_container/hypospray/autoinjector/clash_antitox = 1,
	/obj/item/reagent_container/hypospray/autoinjector/inaprovaline = 1,
	/obj/item/reagent_container/hypospray/autoinjector/peridaxon = 1,
	/obj/item/device/defibrillator/compact = 1,
	/obj/item/device/healthanalyzer = 1,
))

GLOBAL_LIST_INIT(clash_firstaid_stock, list(
	/obj/item/device/healthanalyzer = 1,
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 2,
	/obj/item/reagent_container/hypospray/autoinjector/clash_tramadol = 1,
	/obj/item/stack/medical/bruise_pack/field_dressing = 2,
	/obj/item/stack/medical/splint = 1,
))

GLOBAL_LIST_INIT(clash_adv_firstaid_stock, list(
	/obj/item/stack/medical/advanced/bruise_pack/healing_kit = 3,
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal = 2,
	/obj/item/stack/medical/splint = 1,
))

/proc/clash_fast_medicine()
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	return istype(clash_mode) && clash_mode.arena_rules

/obj/item/dig_out_shrapnel(mob/living/carbon/human/embedded_human, mob/living/carbon/human/user = null)
	if(!clash_fast_medicine())
		return ..()
	user = user || embedded_human
	if(user.action_busy)
		return
	var/self = user == embedded_human
	if(!do_after(user, CLASH_SHRAPNEL_DIG_TIME, INTERRUPT_ALL, BUSY_ICON_FRIENDLY, self ? null : embedded_human, INTERRUPT_MOVED, self ? null : BUSY_ICON_MEDICAL))
		to_chat(user, SPAN_NOTICE("You were interrupted!"))
		return
	var/list/removed_limbs = list()
	for(var/obj/item/shard/shard in embedded_human.embedded_items)
		var/obj/limb/organ = shard.embedded_organ
		removed_limbs |= organ.display_name
		shard.forceMove(embedded_human.loc)
		organ.implants -= shard
		embedded_human.embedded_items -= shard
		for(var/count in 1 to shard.count)
			user.count_niche_stat(STATISTICS_NICHE_SURGERY_SHRAPNEL)
		QDEL_IN(shard, 30 SECONDS)
	if(!length(removed_limbs))
		to_chat(user, SPAN_NOTICE("You couldn't find any shrapnel."))
		return
	var/limbs = english_list(removed_limbs, final_comma_text = ",")
	user.affected_message(embedded_human,
		SPAN_NOTICE("You dig the shrapnel out of [self ? "your" : "[embedded_human]'s"] [limbs] with your [name]."),
		SPAN_NOTICE("[user] digs the shrapnel out of your [limbs] with \his [name]."),
		SPAN_NOTICE(self ? "[user] digs the shrapnel out of \his [limbs] with \his [name]." : "[user] digs the shrapnel out of [embedded_human]'s [limbs] with \his [name]."))
	if(!embedded_human.stat && embedded_human.pain.feels_pain && embedded_human.pain.reduction_pain < PAIN_REDUCTION_HEAVY)
		INVOKE_ASYNC(embedded_human, TYPE_PROC_REF(/mob, emote), "me", 1, pick("winces.", "grimaces.", "flinches."))
	embedded_human.recalculate_move_delay = TRUE
	SEND_SIGNAL(embedded_human, COMSIG_HUMAN_SHRAPNEL_REMOVED)

/mob/living/carbon/human/movement_delay()
	. = ..()
	if(!length(embedded_items) || !clash_fast_medicine())
		return
	var/pieces = 0
	for(var/obj/item/shard/shrapnel/shard in embedded_items)
		pieces += shard.count
	if(!pieces)
		return
	var/slow = min(pieces * CLASH_SHRAPNEL_SLOW, CLASH_SHRAPNEL_SLOW_MAX)
	. += slow
	move_delay += slow

GLOBAL_LIST_INIT(clash_medic_stripped_items, list(
	/obj/item/device/defibrillator,
	/obj/item/storage/firstaid/regular,
	/obj/item/storage/firstaid/adv,
	/obj/item/tool/surgery/surgical_line,
	/obj/item/tool/surgery/synthgraft,
))

/proc/clash_strip_medic_kit(mob/living/carbon/human/medic)
	for(var/obj/item/carried in medic.get_contents())
		if(carried.type in GLOB.clash_medic_stripped_items)
			qdel(carried)

/obj/item/stack/medical/splint/Initialize(mapload, amount)
	. = ..()
	if(indestructible_splints && !istype(src, /obj/item/stack/medical/splint/nano))
		icon_state = initial(icon_state)
		update_icon()

/proc/clash_stock(atom/holder, list/stock)
	for(var/item_type in stock)
		for(var/count in 1 to stock[item_type])
			new item_type(holder)

/mob/living/carbon/human/var/datum/weakref/clash_care_medic
/mob/living/carbon/human/var/clash_care_until = 0

/datum/reagent/medical/on_mob_life(mob/living/M, alien, delta_time)
	if(!holder || !clash_fast_medicine())
		return ..()
	var/list/limits = GLOB.clash_med_overdose[id]
	if(limits)
		overdose = limits[1]
		overdose_critical = limits[2]
	if(overdose && volume > overdose)
		M.apply_damage((overdose_critical && volume > overdose_critical ? CLASH_OD_CRITICAL_DAMAGE : CLASH_OD_DAMAGE) * delta_time, TOX)
	var/list/burst = GLOB.clash_med_bursts[id]
	if(!burst || !ishuman(M))
		return ..()
	var/used = min(volume, burst[CLASH_BURST_RATE] * delta_time)
	clash_burst_heal(M, used, burst, TRUE)
	holder.remove_reagent_by_reference(src, used)
	if(QDELETED(src))
		return
	return ..()

/proc/clash_burst_heal(mob/living/carbon/human/patient, units, list/burst, credit)
	var/before = patient.getBruteLoss() + patient.getFireLoss()
	if(burst[CLASH_BURST_BRUTE] || burst[CLASH_BURST_BURN])
		patient.heal_overall_damage(units * burst[CLASH_BURST_BRUTE], units * burst[CLASH_BURST_BURN], chemical = TRUE)
	if(burst[CLASH_BURST_TOX])
		patient.apply_damage(-units * burst[CLASH_BURST_TOX], TOX)
	if(burst[CLASH_BURST_OXY])
		patient.apply_damage(-units * burst[CLASH_BURST_OXY], OXY)
	var/mob/living/carbon/human/medic = patient.clash_care_medic?.resolve()
	if(credit && medic && world.time < patient.clash_care_until)
		clash_credit_heal(medic, patient, before - (patient.getBruteLoss() + patient.getFireLoss()))

/obj/item/reagent_container/hypospray/autoinjector/attack(mob/M, mob/user)
	if(!ishuman(M) || !clash_fast_medicine())
		return ..()
	var/mob/living/carbon/human/patient = M
	var/list/before = list()
	for(var/datum/reagent/existing as anything in patient.reagents.reagent_list)
		before[existing.id] = existing.volume
	. = ..()
	if(!.)
		return
	if(user == patient)
		patient.clash_care_until = 0
	var/damage = patient.getBruteLoss() + patient.getFireLoss()
	for(var/datum/reagent/medical/added in patient.reagents.reagent_list.Copy())
		var/list/burst = GLOB.clash_med_bursts[added.id]
		var/units = (added.volume - (before[added.id] || 0)) * CLASH_BURST_FRONT
		if(!burst || units <= 0)
			continue
		clash_burst_heal(patient, units, burst, FALSE)
		patient.reagents.remove_reagent_by_reference(added, units)
	clash_heal_feedback(patient, user, damage - (patient.getBruteLoss() + patient.getFireLoss()))

/proc/clash_heal_feedback(mob/living/carbon/human/patient, mob/living/carbon/human/medic, amount)
	if(amount < 1 || !ishuman(medic) || medic == patient || !clash_is_medic(medic))
		return
	var/text = "+[round(amount)] HP"
	patient.balloon_alert(patient, text, "#7fd67f")
	patient.balloon_alert(medic, text, "#7fd67f")
	if(patient.client)
		playsound_client(patient.client, 'sound/machines/ping.ogg', null, 25)
	patient.add_filter("clash_heal", 3, outline_filter(1, "#7fd67fc0"))
	addtimer(CALLBACK(patient, TYPE_PROC_REF(/atom, remove_filter), "clash_heal"), 1 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/obj/item/stack/medical/bruise_pack/attack(mob/living/carbon/M, mob/user)
	if(!clash_fast_medicine())
		return ..()
	return clash_treat(M, user, CLASH_PACK_HEAL, CLASH_PACK_FUMBLE, list("bandage", "bandages", "", "", "a bandage"), 'sound/handling/bandage.ogg')

/obj/item/stack/medical/ointment/attack(mob/living/carbon/M, mob/user)
	if(!clash_fast_medicine())
		return ..()
	return clash_treat(M, user, CLASH_PACK_HEAL, CLASH_PACK_FUMBLE, list("salve the burns", "salves the burns", " on", "", "an ointment"), 'sound/handling/ointment_spreading.ogg')

/obj/item/stack/medical/advanced/bruise_pack/attack(mob/living/carbon/M, mob/user)
	if(!clash_fast_medicine())
		return ..()
	return clash_treat(M, user, CLASH_KIT_HEAL, CLASH_KIT_FUMBLE, list("clean and seal", "cleans and seals", " the wounds on", " with bioglue", "a trauma kit"))

/obj/item/stack/medical/advanced/ointment/attack(mob/living/carbon/M, mob/user)
	if(!clash_fast_medicine())
		return ..()
	return clash_treat(M, user, CLASH_KIT_HEAL, CLASH_KIT_FUMBLE, list("cover the burns", "covers the burns", " on", " with regenerative membrane", "a burn kit"))

/proc/clash_limb_untreated(obj/limb/limb)
	for(var/datum/wound/wound as anything in limb.wounds)
		if(!wound.internal && !(wound.damage_type == BURN ? wound.salved : wound.bandaged))
			return TRUE
	return FALSE

/proc/clash_limb_needs_care(obj/limb/limb)
	return !(limb.status & (LIMB_ROBOT|LIMB_SYNTHSKIN|LIMB_DESTROYED)) && (limb.brute_dam + limb.burn_dam > 0 || clash_limb_untreated(limb))

/proc/clash_treat_target(mob/living/carbon/human/patient, obj/limb/selected)
	if(selected && clash_limb_needs_care(selected))
		return selected
	var/obj/limb/worst
	for(var/obj/limb/limb as anything in patient.limbs)
		if(limb.get_incision_depth() || !clash_limb_needs_care(limb))
			continue
		if(!worst || limb.brute_dam + limb.burn_dam > worst.brute_dam + worst.burn_dam)
			worst = limb
	return worst || selected

/proc/clash_splint_target(mob/living/carbon/human/patient, obj/limb/selected)
	if(selected && (selected.status & LIMB_BROKEN) && !(selected.status & (LIMB_SPLINTED|LIMB_DESTROYED)))
		return selected
	for(var/obj/limb/limb as anything in patient.limbs)
		if((limb.status & LIMB_BROKEN) && !(limb.status & (LIMB_SPLINTED|LIMB_DESTROYED)))
			return limb
	return selected

/obj/item/stack/medical/proc/clash_treat(mob/living/carbon/human/patient, mob/living/carbon/human/user, heal, fumble, list/text, treat_sound)
	if(!ishuman(patient))
		to_chat(user, SPAN_DANGER("\The [src] cannot be applied to [patient]!"))
		return TRUE
	if(!ishuman(user))
		to_chat(user, SPAN_WARNING("You don't have the dexterity to do this!"))
		return TRUE
	var/obj/limb/affecting = clash_treat_target(patient, patient.get_limb(user.zone_selected))
	if(!affecting)
		to_chat(user, SPAN_WARNING("[patient] has no [parse_zone(user.zone_selected)]!"))
		return TRUE
	if(affecting.status & (LIMB_ROBOT|LIMB_SYNTHSKIN))
		to_chat(user, SPAN_WARNING("This isn't useful at all on a robotic limb."))
		return TRUE
	if(user.skills && !skillcheck(user, SKILL_MEDICAL, SKILL_MEDICAL_MEDIC) && !do_after(user, fumble, INTERRUPT_NO_NEEDHAND, BUSY_ICON_FRIENDLY, patient, INTERRUPT_MOVED, BUSY_ICON_MEDICAL))
		return TRUE
	if(affecting.get_incision_depth())
		to_chat(user, SPAN_NOTICE("[patient]'s [affecting.display_name] is cut open, you'll need more than [text[5]]!"))
		return TRUE
	var/possessive = "[user == patient ? "your" : "\the [patient]'s"]"
	var/possessive_their = "[user == patient ? user.p_their() : "\the [patient]'s"]"
	if(!clash_limb_needs_care(affecting))
		to_chat(user, SPAN_WARNING("There are no wounds on [possessive] [affecting.display_name]."))
		return TRUE
	var/advanced = istype(src, /obj/item/stack/medical/advanced)
	affecting.bandage(advanced)
	affecting.salve(advanced)
	var/damage = affecting.brute_dam + affecting.burn_dam
	affecting.status &= ~LIMB_THIRD_DEGREE_BURNS
	var/brute = min(heal, affecting.brute_dam)
	affecting.heal_damage(brute, heal - brute)
	user.affected_message(patient,
		SPAN_HELPFUL("You <b>[text[1]]</b>[text[3]] [possessive] <b>[affecting.display_name]</b>[text[4]]."),
		SPAN_HELPFUL("[user] <b>[text[2]]</b>[text[3]] your <b>[affecting.display_name]</b>[text[4]]."),
		SPAN_NOTICE("[user] [text[2]][text[3]] [possessive_their] [affecting.display_name][text[4]]."))
	clash_heal_feedback(patient, user, damage - (affecting.brute_dam + affecting.burn_dam))
	use(1)
	if(treat_sound)
		playsound(user, treat_sound, 25, 1, 2)

/obj/item/stack/medical/splint/attack(mob/living/carbon/M, mob/user)
	if(!clash_fast_medicine())
		return ..()
	if(!ishuman(M) || !ishuman(user))
		to_chat(user, SPAN_DANGER("\The [src] cannot be applied to [M]!"))
		return TRUE
	if(user.action_busy)
		return
	var/mob/living/carbon/human/patient = M
	var/obj/limb/affecting = clash_splint_target(patient, patient.get_limb(user.zone_selected))
	if(!affecting)
		to_chat(user, SPAN_WARNING("[patient] has no [parse_zone(user.zone_selected)]!"))
		return TRUE
	if(!(affecting.name in list("l_arm", "r_arm", "l_leg", "r_leg", "r_hand", "l_hand", "r_foot", "l_foot", "chest", "groin", "head")))
		to_chat(user, SPAN_WARNING("You can't apply a splint there!"))
		return
	if(affecting.status & LIMB_DESTROYED)
		to_chat(user, SPAN_WARNING("[user == patient ? "You don't" : "[patient] doesn't"] have \a [affecting.display_name]!"))
		return
	if(affecting.status & LIMB_SPLINTED)
		to_chat(user, SPAN_WARNING("[user == patient ? "Your" : "[patient]'s"] [affecting.display_name] is already splinted!"))
		return
	if(!(affecting.status & LIMB_BROKEN))
		patient.balloon_alert(user, "no broken bones")
		return
	if(user == patient && ((!user.hand && (affecting.name in list("r_arm", "r_hand"))) || (user.hand && (affecting.name in list("l_arm", "l_hand")))))
		to_chat(user, SPAN_WARNING("You can't apply a splint to the [affecting.name == "r_hand" || affecting.name == "l_hand" ? "hand" : "arm"] you're using!"))
		return
	var/medic = !user.skills || skillcheck(user, SKILL_MEDICAL, SKILL_MEDICAL_MEDIC)
	if(!do_after(user, medic ? CLASH_SPLINT_MEDIC : CLASH_SPLINT_OTHER, INTERRUPT_NO_NEEDHAND, BUSY_ICON_FRIENDLY, patient, INTERRUPT_MOVED, BUSY_ICON_MEDICAL))
		return
	if(affecting.status & (LIMB_DESTROYED|LIMB_SPLINTED))
		return
	var/possessive = "[user == patient ? "your" : "\the [patient]'s"]"
	var/possessive_their = "[user == patient ? user.p_their() : "\the [patient]'s"]"
	user.affected_message(patient,
		SPAN_HELPFUL("You finish applying <b>[src]</b> to [possessive] [affecting.display_name]."),
		SPAN_HELPFUL("[user] finishes applying <b>[src]</b> to your [affecting.display_name]."),
		SPAN_NOTICE("[user] finishes applying [src] to [possessive_their] [affecting.display_name]."))
	affecting.status |= LIMB_SPLINTED
	SEND_SIGNAL(affecting, COMSIG_LIVING_LIMB_SPLINTED, user)
	if(indestructible_splints)
		affecting.status |= LIMB_SPLINTED_INDESTRUCTIBLE
	patient.pain.apply_pain(affecting.status & LIMB_BROKEN ? -PAIN_BONE_BREAK_SPLINTED : PAIN_BONE_BREAK_SPLINTED)
	patient.update_med_icon()
	use(1)
	playsound(user, 'sound/handling/splint1.ogg', 25, 1, 2)

/obj/item/stack/medical/bruise_pack/field_dressing
	name = "field dressing"
	singular_name = "field dressing"
	desc = "A pressure bandage and burn gel in one wrap. Seals the wounds and burns on one body part."
	amount = 3
	max_amount = 3
	stack_id = "field dressing"

/obj/item/stack/medical/advanced/bruise_pack/healing_kit
	name = "advanced healing kit"
	singular_name = "advanced healing kit"
	desc = "Bioglue and regenerative membrane in one kit. Heals heavy wounds and burns on one body part."
	stack_id = "advanced healing kit"

/obj/item/reagent_container/hypospray/autoinjector/clash_heal
	name = "healing injector"
	chemname = "tricordrazine"
	desc = "An EZ autoinjector loaded with 2 doses of 8u of Tricordrazine. Rapidly heals both wounds and burns. It does not require any training to use."
	icon_state = "emptyskill"
	amount_per_transfer_from_this = 8
	volume = 16
	uses_left = 2
	skilllock = SKILL_MEDICAL_DEFAULT
	display_maptext = TRUE
	maptext_label = "Hl"

/obj/item/reagent_container/hypospray/autoinjector/clash_tramadol
	name = "tramadol injector"
	chemname = "tramadol"
	desc = "A single-use EZ autoinjector loaded with 15u of Tramadol, a painkiller. It does not require any training to use."
	icon_state = "empty_oneuse"
	autoinjector_type = "autoinjector_oneuse"
	amount_per_transfer_from_this = 15
	volume = 15
	uses_left = 1
	skilllock = SKILL_MEDICAL_DEFAULT
	display_maptext = TRUE
	maptext_label = "Tr"

/obj/item/reagent_container/hypospray/autoinjector/clash_unga
	name = "UNGA injector"
	desc = "A single 20u dose of UNGA: Bicaridine, Kelotane, Tricordrazine, Meralyne, Dermaline and Oxycodone. Heals heavy wounds and burns and kills pain. Medics only."
	icon_state = "empty_emergency"
	autoinjector_type = "autoinjector_oneuse"
	amount_per_transfer_from_this = 20
	volume = 20
	uses_left = 1
	mixed_chem = TRUE
	skilllock = SKILL_MEDICAL_MEDIC
	injectSFX = 'sound/items/air_release.ogg'
	display_maptext = TRUE
	maptext_label = "UN"

/obj/item/reagent_container/hypospray/autoinjector/clash_unga/Initialize()
	. = ..()
	var/list/mix = GLOB.clash_chem_mixes["UNGA"]
	var/parts = 0
	for(var/id in mix)
		parts += mix[id]
	for(var/id in mix)
		reagents.add_reagent(id, volume * mix[id] / parts)
	update_icon()

/obj/item/storage/pouch/firstaid/clash
	desc = "A first-aid pouch with a healing injector, a tramadol injector, field dressings and splints."
	storage_slots = 4

/obj/item/storage/pouch/firstaid/clash/fill_preset_inventory()
	clash_stock(src, GLOB.clash_pouch_stock)

/obj/item/storage/pouch/firstaid/clash/medic
	name = "medic pouch"
	desc = "A medic's pouch with healing injectors, oxycodone, field dressings and an advanced healing kit."
	storage_slots = 6
	can_hold = list(
		/obj/item/stack/medical,
		/obj/item/reagent_container/hypospray/autoinjector,
		/obj/item/storage/pill_bottle/packet,
	)

/obj/item/storage/pouch/firstaid/clash/medic/fill_preset_inventory()
	clash_stock(src, GLOB.clash_medic_pouch_stock)

/obj/item/storage/pouch/firstaid/clash/medic/large
	name = "large medic pouch"
	desc = "A bigger medic's pouch with healing injectors, oxycodone, an UNGA injector, field dressings and an advanced healing kit."
	storage_slots = 8

/obj/item/storage/pouch/firstaid/clash/medic/large/fill_preset_inventory()
	clash_stock(src, GLOB.clash_large_medic_pouch_stock)

/obj/item/storage/belt/medical/lifesaver/proc/clash_fill_arena()
	storage_slots = initial(storage_slots) + 1
	max_storage_space = initial(max_storage_space) + 2
	clash_stock(src, GLOB.clash_medic_belt_stock)

/obj/item/storage/belt/medical/lifesaver/full/fill_preset_inventory()
	if(!clash_fast_medicine())
		return ..()
	clash_fill_arena()

/obj/item/storage/belt/medical/lifesaver/upp/full/fill_preset_inventory()
	if(!clash_fast_medicine())
		return ..()
	clash_fill_arena()

/obj/item/storage/belt/medical/lifesaver/arena/fill_preset_inventory()
	clash_fill_arena()

/obj/item/storage/belt/medical/lifesaver/upp/arena/fill_preset_inventory()
	clash_fill_arena()

/datum/reagent/medical/anti_toxin_plus
	name = "Dylovene Plus"
	id = "anti_toxin_plus"
	description = "A fast form of Dylovene. One unit immediately clears every toxin from the body."
	reagent_state = LIQUID
	color = "#8fe03a"
	overdose = LOWH_REAGENTS_OVERDOSE
	overdose_critical = LOWH_REAGENTS_OVERDOSE_CRITICAL
	chemclass = CHEM_CLASS_SPECIAL
	properties = list(PROPERTY_ANTITOXIC = 2)

/obj/item/storage/pouch/pressurized_reagent_canister/clash_unga
	name = "Pressurized Reagent Canister Pouch (UNGA)"
	desc = "A pressurized reagent canister pouch. It is used to refill custom injectors, and can also store one. May be refilled with a reagent tank or a Chemical Dispenser. This one came pre-filled with UNGA mix: bicaridine, kelotane, tricordrazine, meralyne, dermaline and oxycodone."

/obj/item/storage/pouch/pressurized_reagent_canister/clash_unga/Initialize()
	. = ..()
	var/list/mix = GLOB.clash_chem_mixes["UNGA"]
	var/parts = 0
	for(var/id in mix)
		parts += mix[id]
	var/obj/item/reagent_container/hypospray/autoinjector/empty/injector = locate() in contents
	for(var/id in mix)
		inner.reagents.add_reagent(id, inner.volume * mix[id] / parts)
		injector?.reagents.add_reagent(id, injector.volume * mix[id] / parts)
	injector?.update_uses_left()
	injector?.update_icon()
	update_icon()

/obj/item/reagent_container/hypospray/autoinjector/clash_antitox
	name = "dylovene plus autoinjector"
	chemname = "anti_toxin_plus"
	desc = "Three 1u doses of Dylovene Plus. Each one clears every toxin from the body at once."
	amount_per_transfer_from_this = 1
	volume = 3
	display_maptext = TRUE
	maptext_label = "Dy+"

/obj/item/storage/firstaid/regular/fill_preset_inventory()
	if(!clash_fast_medicine())
		return ..()
	clash_stock(src, GLOB.clash_firstaid_stock)

/obj/item/storage/firstaid/adv/fill_preset_inventory()
	if(!clash_fast_medicine())
		return ..()
	clash_stock(src, GLOB.clash_adv_firstaid_stock)

/obj/item/storage/firstaid/regular/arena/fill_preset_inventory()
	clash_stock(src, GLOB.clash_firstaid_stock)

/obj/item/storage/firstaid/adv/arena/fill_preset_inventory()
	clash_stock(src, GLOB.clash_adv_firstaid_stock)

/obj/item/tool/surgery/surgical_line/Initialize(mapload, ...)
	. = ..()
	if(!clash_fast_medicine())
		return
	RemoveElement(/datum/element/suturing, TRUE, FALSE, 2.5, "suture", "suturing", "being stabbed with needles", "wounds")
	AddElement(/datum/element/suturing, TRUE, FALSE, CLASH_SUTURE_TIME, "suture", "suturing", "being stabbed with needles", "wounds")

/obj/item/tool/surgery/synthgraft/Initialize(mapload, ...)
	. = ..()
	if(!clash_fast_medicine())
		return
	RemoveElement(/datum/element/suturing, FALSE, TRUE, 2.5, "graft", "grafting", "being burnt away all over again", "burns")
	AddElement(/datum/element/suturing, FALSE, TRUE, CLASH_SUTURE_TIME, "graft", "grafting", "being burnt away all over again", "burns")

#undef CLASH_PACK_HEAL
#undef CLASH_KIT_HEAL
#undef CLASH_PACK_FUMBLE
#undef CLASH_KIT_FUMBLE
#undef CLASH_SPLINT_MEDIC
#undef CLASH_SPLINT_OTHER
#undef CLASH_SUTURE_TIME
#undef CLASH_BURST_FRONT
#undef CLASH_BURST_RATE
#undef CLASH_BURST_BRUTE
#undef CLASH_BURST_BURN
#undef CLASH_BURST_TOX
#undef CLASH_BURST_OXY
#undef CLASH_SHRAPNEL_SLOW
#undef CLASH_SHRAPNEL_SLOW_MAX

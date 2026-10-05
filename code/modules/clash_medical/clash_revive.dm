#define CLASH_REVIVE_ZAP (1.5 SECONDS)
#define CLASH_REVIVE_ZAP_FAST (1 SECONDS)
#define CLASH_SECOND_WIND_HEALTH 20
#define CLASH_REVIVE_SICKNESS (60 SECONDS)

GLOBAL_LIST_INIT(clash_revive_health, list(50, 35, 20))

/mob/living/carbon/human/var/clash_revive_chain = 0
/mob/living/carbon/human/var/clash_last_revive = 0
/mob/living/carbon/human/var/datum/weakref/clash_revived_by
/mob/living/carbon/human/var/clash_revived_at = 0

/mob/living/carbon/human/is_revivable(ignore_heart = FALSE)
	if(!clash_fast_medicine())
		return ..()
	if(!client && !get_ghost())
		return FALSE
	return ..(TRUE)

/obj/item/device/defibrillator/check_revive(mob/living/carbon/human/H, mob/living/carbon/human/user)
	if(ready || !clash_fast_medicine() || istype(src, /obj/item/device/defibrillator/synthetic))
		return ..()
	ready = TRUE
	. = ..()
	ready = FALSE

/obj/item/device/defibrillator/can_defib(mob/living/carbon/human/target, mob/living/carbon/human/user)
	if(!clash_fast_medicine() || istype(src, /obj/item/device/defibrillator/synthetic))
		return ..()
	if(shock_cooldown > world.time || user.action_busy)
		return FALSE
	shock_cooldown = world.time + 20
	if(user.skills && !noskill && !skillcheck(user, skill_to_check, skill_level) && (!skill_to_check_alt || !skillcheck(user, skill_to_check_alt, skill_level_alt)))
		to_chat(user, SPAN_WARNING("You don't seem to know how to use [src]..."))
		return FALSE
	if(target.faction != user.faction)
		to_chat(user, SPAN_WARNING("You can only revive your own team."))
		return FALSE
	if(!check_revive(target, user))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts setting up the [fluff_tool] on [target]'s [fluff_target_part]"),
		SPAN_HELPFUL("You start <b>setting up</b> the [fluff_tool] on <b>[target]</b>'s [fluff_target_part]."))
	playsound(get_turf(src), 'sound/items/defib_ready.ogg', 25, 0)
	var/zap = clash_has_perk(user, /datum/clash_perk/quick_zap) ? CLASH_REVIVE_ZAP_FAST : CLASH_REVIVE_ZAP
	if(!do_after(user, zap, INTERRUPT_NO_NEEDHAND|BEHAVIOR_IMMOBILE, BUSY_ICON_FRIENDLY, target, INTERRUPT_MOVED, BUSY_ICON_MEDICAL))
		user.visible_message(SPAN_WARNING("[user] stops setting up the [fluff_tool] on [target]'s [fluff_target_part]."),
			SPAN_WARNING("You stop setting up the [fluff_tool] on [target]'s [fluff_target_part]."))
		return FALSE
	return check_revive(target, user)

/obj/item/device/defibrillator/attack(mob/living/carbon/human/target, mob/living/carbon/human/user)
	if(!clash_fast_medicine() || istype(src, /obj/item/device/defibrillator/synthetic))
		return ..()
	if(!can_defib(target, user))
		return FALSE
	sparks?.start(do_NOT_delete = TRUE)
	dcell.use(charge_cost)
	update_icon()
	playsound(get_turf(src), sound_release, 25, 1)
	user.visible_message(SPAN_NOTICE("[user] shocks [target] with the [fluff_tool]."),
		SPAN_HELPFUL("You shock <b>[target]</b> with the [fluff_tool]."))
	target.visible_message(SPAN_DANGER("[target]'s body convulses a bit."))
	shock_cooldown = world.time + 10
	if(isobserver(target.mind?.current) && !target.client)
		target.mind.transfer_to(target, TRUE)
	user.track_life_saved(user.job)
	if(!user.statistic_exempt)
		user.life_revives_total++
	target.clash_zap_revive(user)
	user.visible_message(SPAN_NOTICE("[icon2html(src, viewers(src))] \The [src] beeps: [fluff_revive_message]."))
	msg_admin_niche("[key_name_admin(user)] successfully revived [key_name_admin(target)] with [src].")
	playsound(get_turf(src), sound_success, 25, 0)
	to_chat(target, SPAN_NOTICE("You suddenly feel a spark and your consciousness returns, dragging you back to the mortal plane."))
	to_chat(target, SPAN_BOLDNOTICE("Revived by [user.real_name]."))
	if(target.client?.prefs.toggles_flashing & FLASH_CORPSEREVIVE)
		window_flash(target.client)
	clash_reward_revive(user, target)

/mob/living/carbon/human/proc/clash_zap_revive(mob/living/carbon/human/medic)
	clash_revive_chain = world.time < clash_last_revive + CLASH_REVIVE_SICKNESS ? clash_revive_chain + 1 : 1
	clash_last_revive = world.time
	var/revive_health = GLOB.clash_revive_health[clash_has_perk(medic, /datum/clash_perk/field_surgeon) ? 1 : min(clash_revive_chain, length(GLOB.clash_revive_health))]
	if(clash_has_perk(medic, /datum/clash_perk/second_wind))
		revive_health += CLASH_SECOND_WIND_HEALTH
	for(var/datum/internal_organ/organ as anything in internal_organs)
		organ.rejuvenate()
	for(var/obj/limb/limb as anything in limbs)
		limb.remove_all_bleeding(TRUE)
	setOxyLoss(0)
	setToxLoss(0)
	setCloneLoss(0)
	blood_volume = max(blood_volume, BLOOD_VOLUME_NORMAL)
	var/brute = getBruteLoss()
	var/burn = getFireLoss()
	var/missing = revive_health - (maxHealth - brute - burn)
	if(missing > 0)
		heal_overall_damage(missing * brute / (brute + burn), missing * burn / (brute + burn))
	handle_revive()
	set_effect(0, PARALYZE)
	set_effect(2, EYE_BLUR)
	handle_regular_status_updates(FALSE)
	hud_used?.clash_respawn?.update(src)
	hud_used?.clash_death_card?.update(src)
	clash_show_call_medic(src)
	if(clash_has_perk(medic, /datum/clash_perk/adrenaline))
		clash_adrenaline()

/proc/clash_reward_revive(mob/living/carbon/human/medic, mob/living/carbon/human/patient)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	clash_mode.score_revive(medic, patient)
	if(!patient.clash_enemy_death)
		return
	patient.clash_revived_by = WEAKREF(medic)
	patient.clash_revived_at = world.time
	for(var/mob/living/carbon/human/enemy in range(CLASH_CLUTCH_RANGE, patient))
		if(enemy.stat != DEAD && enemy.faction != patient.faction && (enemy.faction in list(FACTION_MARINE, FACTION_UPP)))
			clash_award_xp(medic, CLASH_XP_CLUTCH, CLASH_XP_SOURCE_CLUTCH)
			return

#undef CLASH_REVIVE_ZAP
#undef CLASH_REVIVE_ZAP_FAST
#undef CLASH_SECOND_WIND_HEALTH
#undef CLASH_REVIVE_SICKNESS

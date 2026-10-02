#define CLASH_HIT_SOUND 'sound/weapons/handling/gun_lever_action_hitsound.ogg'
#define CLASH_HIT_SOUND_GAP (1 DECISECONDS)

/mob/var/clash_next_hit_sound = 0
/mob/var/clash_revives_seen = 0

/datum/element/clash_combat_log

/datum/element/clash_combat_log/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(target, COMSIG_MOB_MELEE_ATTACK, PROC_REF(on_melee))
	RegisterSignal(target, COMSIG_HUMAN_REVIVED, PROC_REF(on_revived))

/datum/element/clash_combat_log/Detach(datum/source, force)
	. = ..()
	UnregisterSignal(source, list(COMSIG_HUMAN_BULLET_ACT, COMSIG_MOB_MELEE_ATTACK, COMSIG_HUMAN_REVIVED))

/datum/element/clash_combat_log/proc/on_shot(mob/living/carbon/human/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	var/mob/firer = bullet.firer
	if(damage_result <= 0 || !ismob(firer) || firer == source)
		return
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode))
		clash_mode.record_damage(source, firer, bullet.shot_from?.type)
	if(firer.client && firer.faction != source.faction && world.time >= firer.clash_next_hit_sound)
		firer.clash_next_hit_sound = world.time + CLASH_HIT_SOUND_GAP
		playsound_client(firer.client, CLASH_HIT_SOUND, null, 35)

/datum/element/clash_combat_log/proc/on_melee(mob/living/carbon/human/source, mob/living/target, obj/item/weapon)
	SIGNAL_HANDLER
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode) && ishuman(target) && target != source)
		clash_mode.record_damage(target, source, weapon?.type)

/datum/element/clash_combat_log/proc/on_revived(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	clash_progress_revive(source)

#undef CLASH_HIT_SOUND
#undef CLASH_HIT_SOUND_GAP

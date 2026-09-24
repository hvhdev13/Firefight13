/proc/clash_blast_delimb(mob/living/carbon/human/victim, obj/limb/focused, damage, mob/attack_source)
	if(victim.stat == DEAD || (victim.chem_effect_flags & CHEM_EFFECT_RESIST_FRACTURE) || attack_source?.faction == victim.faction)
		return
	if(!prob(damage * 3))
		return
	var/list/extremities = list()
	for(var/obj/limb/candidate as anything in victim.limbs)
		if(!(candidate.status & LIMB_DESTROYED) && !(candidate.body_part & (BODY_FLAG_HEAD|BODY_FLAG_CHEST|BODY_FLAG_GROIN)))
			extremities += candidate
	if(!length(extremities))
		return
	var/obj/limb/torn = (focused in extremities) ? focused : pick(extremities)
	torn.limb_delimb(victim.last_damage_data)

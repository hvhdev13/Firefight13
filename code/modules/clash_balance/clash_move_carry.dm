/mob/living/carbon/human/var/clash_move_credit = 0
/mob/living/carbon/human/var/clash_last_step = 0

/datum/element/clash_move_carry
	element_flags = ELEMENT_DETACH

/datum/element/clash_move_carry/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(target, COMSIG_HUMAN_POST_MOVE_DELAY, PROC_REF(on_move_delay))

/datum/element/clash_move_carry/Detach(datum/source, force)
	UnregisterSignal(source, list(COMSIG_MOVABLE_MOVED, COMSIG_HUMAN_POST_MOVE_DELAY))
	return ..()

/proc/clash_move_aiming(mob/living/carbon/human/mover)
	var/obj/item/weapon/gun/gun = mover.get_active_hand()
	return istype(gun) && (gun.flags_item & WIELDED)

/datum/element/clash_move_carry/proc/on_move_delay(mob/living/carbon/human/mover, list/movedata)
	SIGNAL_HANDLER
	var/obj/item/clothing/suit/storage/marine/suit = mover.wear_suit
	if(!istype(suit) || !clash_move_aiming(mover))
		return
	var/obj/item/weapon/gun/gun = mover.get_active_hand()
	var/tier = clash_armor_tier(suit)
	var/delay = movedata["move_delay"] - suit.slowdown - max(0, gun.slowdown - suit.movement_compensation)
	delay += GLOB.clash_armor_aim_slowdown[tier] + max(0, gun.slowdown - GLOB.clash_armor_aim_compensation[tier])
	delay = CEILING(delay / world.tick_lag - 0.001, 1) * world.tick_lag
	if(!clash_armor_is_upp(suit))
		delay *= (2 + GLOB.clash_armor_slowdown[FACTION_MARINE][tier]) / (2 + GLOB.clash_armor_slowdown[FACTION_UPP][tier])
	movedata["move_delay"] = delay

/datum/element/clash_move_carry/proc/on_moved(mob/living/carbon/human/mover)
	SIGNAL_HANDLER
	if(!mover.client?.moving)
		return
	var/delay = mover.move_delay
	if(world.time - mover.clash_last_step > delay + world.tick_lag)
		mover.clash_move_credit = 0
	mover.clash_last_step = world.time
	var/step = max(1, CEILING((delay - mover.clash_move_credit) / world.tick_lag - 0.001, 1)) * world.tick_lag
	mover.clash_move_credit += step - delay
	mover.next_move_slowdown += step - delay

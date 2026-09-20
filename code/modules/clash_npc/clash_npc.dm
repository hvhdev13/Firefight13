/obj/effect/landmark/clash_npc
	name = "Clash NPC spawner"
	icon_state = "late_join_misc"
	var/equipment_preset
	/// Deciseconds before a replacement is sent out, 0 to never respawn
	var/respawn_delay = 30 SECONDS
	var/datum/clash_bot/bot

/obj/effect/landmark/clash_npc/Initialize(mapload, ...)
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_POST_SETUP, PROC_REF(on_post_setup))

/obj/effect/landmark/clash_npc/Destroy()
	QDEL_NULL(bot)
	return ..()

/obj/effect/landmark/clash_npc/proc/on_post_setup()
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(spawn_npc))

/obj/effect/landmark/clash_npc/proc/spawn_npc()
	var/mob/living/carbon/human/npc = new(get_turf(src))
	arm_equipment(npc, equipment_preset, TRUE, FALSE)
	npc.statistic_exempt = TRUE
	npc.setDir(dir)
	bot = new(npc, src)

/obj/effect/landmark/clash_npc/proc/bot_died()
	bot = null
	if(respawn_delay)
		addtimer(CALLBACK(src, PROC_REF(spawn_npc)), respawn_delay)

/obj/effect/landmark/clash_npc/uscm
	name = "Clash NPC spawner (USCM Rifleman)"
	equipment_preset = /datum/equipment_preset/uscm/private_equipped

/obj/effect/landmark/clash_npc/upp
	name = "Clash NPC spawner (UPP Soldier)"
	equipment_preset = /datum/equipment_preset/upp/soldier/dressed

/obj/effect/landmark/clash_npc/clf
	name = "Clash NPC spawner (CLF Soldier)"
	equipment_preset = /datum/equipment_preset/clf/soldier

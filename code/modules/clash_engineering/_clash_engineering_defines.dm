#define KIT_SLOT_SENTRY "sentry"
#define KIT_SLOT_SENTRY_MODULE "sentry_module"

#define CLASH_SENTRY_GUN "gun"
#define CLASH_SENTRY_FLAMER "flamer"
#define CLASH_SENTRY_MG "mg"

#define CLASH_HARDENED_MULT 1.25

#define CLASH_SENTRY_MASTERY_XP 7500
#define CLASH_SENTRY_RANK_SPEEDUP 0.1
#define CLASH_SENTRY_BELT_MULT 1.5
#define CLASH_SENTRY_SHIELD_MULT 0.5
#define CLASH_SENTRY_AUTO_REPAIR_HP 5
#define CLASH_SENTRY_AUTO_REPAIR_DELAY (5 SECONDS)
#define CLASH_SENTRY_SPOT_TIME (2 SECONDS)
#define CLASH_SENTRY_TURN_TIME (0.5 SECONDS)

#define CLASH_XP_RESUPPLY 10
#define CLASH_XP_SOURCE_RESUPPLY "Resupply"
#define CLASH_RESUPPLY_PAY_GAP (30 SECONDS)

GLOBAL_LIST_INIT(clash_sentry_tiers, list(
	CLASH_SENTRY_GUN = list("name" = "Sentry Gun", "level" = 4, "health" = 250, "range" = 6, "delay" = 4, "damage" = 1, "rounds" = 200, "deploy" = 3 SECONDS, "ammo" = /obj/item/ammo_magazine/sentry),
	CLASH_SENTRY_FLAMER = list("name" = "Flamer Sentry", "level" = 8, "health" = 300, "range" = 4, "delay" = 15, "damage" = 1, "rounds" = 20, "deploy" = 3 SECONDS, "ammo" = /obj/item/ammo_magazine/sentry_flamer/mini),
	CLASH_SENTRY_MG = list("name" = "Machine Gun", "level" = 1),
))

GLOBAL_LIST_INIT(clash_sentry_track_keys, list(
	CLASH_SENTRY_GUN = /obj/structure/machinery/defenses/sentry/clash,
	CLASH_SENTRY_FLAMER = /obj/structure/machinery/defenses/sentry/flamer/clash,
))

GLOBAL_LIST_INIT(clash_sentry_track_xp, list(500, 1500, 3000, 5000))
GLOBAL_LIST_INIT(clash_sentry_rank_kills, list(2, 5, 10))
GLOBAL_LIST_INIT(clash_sentry_rank_names, list("I", "II", "III"))
GLOBAL_LIST_INIT(clash_sentry_rank_states, list("ranks_ae2", "ranks_ae4", "ranks_ae5"))

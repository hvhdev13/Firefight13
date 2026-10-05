#define KIT_SLOT_SENTRY "sentry"

#define CLASH_SENTRY_LIGHT "light"
#define CLASH_SENTRY_GUN "gun"
#define CLASH_SENTRY_FLAMER "flamer"

#define CLASH_HARDENED_MULT 1.25

#define CLASH_XP_RESUPPLY 10
#define CLASH_XP_SOURCE_RESUPPLY "Resupply"
#define CLASH_RESUPPLY_PAY_GAP (30 SECONDS)

GLOBAL_LIST_INIT(clash_sentry_tiers, list(
	CLASH_SENTRY_LIGHT = list("name" = "Light Sentry", "level" = 1, "health" = 120, "range" = 4, "delay" = 3, "damage" = 0.5, "rounds" = 150, "deploy" = 1.5 SECONDS, "omni" = TRUE, "ammo" = /obj/item/ammo_magazine/sentry),
	CLASH_SENTRY_GUN = list("name" = "Sentry Gun", "level" = 4, "health" = 250, "range" = 6, "delay" = 4, "damage" = 1, "rounds" = 200, "deploy" = 3 SECONDS, "omni" = FALSE, "ammo" = /obj/item/ammo_magazine/sentry),
	CLASH_SENTRY_FLAMER = list("name" = "Flamer Sentry", "level" = 12, "health" = 300, "range" = 4, "delay" = 15, "damage" = 1, "rounds" = 20, "deploy" = 3 SECONDS, "omni" = FALSE, "ammo" = /obj/item/ammo_magazine/sentry_flamer/mini),
))

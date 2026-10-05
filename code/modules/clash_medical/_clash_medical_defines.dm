#define CLASH_XP_CLUTCH 25
#define CLASH_XP_PAYBACK 50
#define CLASH_CLUTCH_RANGE 7
#define CLASH_PAYBACK_WINDOW (30 SECONDS)
#define CLASH_MEDIC_SHOUT_MARK (15 SECONDS)

#define CLASH_XP_SOURCE_CLUTCH "Clutch revive"
#define CLASH_XP_SOURCE_PAYBACK "Payback"

#define CLASH_PERK_QUICK_ZAP 8
#define CLASH_PERK_LARGE_POUCH 10
#define CLASH_PERK_SECOND_WIND 16

GLOBAL_LIST_INIT(clash_medic_perks, list(
	list(CLASH_PERK_QUICK_ZAP, "Quick Zap: 1 second defibrillator"),
	list(CLASH_PERK_LARGE_POUCH, "Large Medic Pouch: 8 slots"),
	list(CLASH_PERK_SECOND_WIND, "Second Wind: revived teammates get 20 more health"),
))

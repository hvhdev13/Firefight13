#define CLASH_PROGRESS_FILE "clash_progress.json"
#define CLASH_PROGRESS_VERSION 1

#define CLASH_LEVEL_CAP 20
#define CLASH_FACTION_XP_BASE 1500
#define CLASH_CLASS_XP_BASE 1200
#define CLASH_LEVEL_XP_STEP 75

#define CLASH_XP_KILL 100
#define CLASH_XP_ASSIST 50
#define CLASH_XP_REVIVE 100
#define CLASH_XP_CAPTURE 300
#define CLASH_XP_ZONE 5
#define CLASH_XP_ZONE_SECONDS 5
#define CLASH_XP_MATCH_WIN 500
#define CLASH_XP_ROUND 250
#define CLASH_XP_BOT_KILL 25
#define CLASH_SHORT_SIDE_BONUS 1.25

#define CLASH_BOT_DAMAGE_SHARE 0.25
#define CLASH_XP_HEAL_HP 5
#define CLASH_XP_INJECT 10
#define CLASH_XP_TREAT 10
#define CLASH_XP_SPLINT 25
#define CLASH_XP_SURGERY 50
#define CLASH_XP_SURGERY_PATIENT_CAP 100
#define CLASH_XP_MEDICAL_CAP 500
#define CLASH_XP_COVER_DAMAGE 10
#define CLASH_XP_REPAIR_HP 10
#define CLASH_XP_ENGINEERING_CAP 300
#define CLASH_XP_LEADER_ASSIST 10
#define CLASH_XP_LEADER_RANGE 7
#define CLASH_TRIAL_STOCK 2

#define CLASH_WEAPON_XP_FIRST 1000
#define CLASH_WEAPON_XP_SPAN 10000
#define CLASH_WEAPON_MASTERY_XP 11000
#define CLASH_GRIP_FLOOR_XP 4300
#define CLASH_XP_PER_KILL_ESTIMATE 110

#define CLASH_SHOP_BASE 20
#define CLASH_SHOP_LEVEL_STEP 1.5
#define CLASH_SHOP_CAP 50
#define CLASH_SHOP_SNOWFLAKE_BASE 60
#define CLASH_SHOP_SNOWFLAKE_STEP 2

#define CLASH_GATE_FREE "free"
#define CLASH_GATE_FACTION "faction"
#define CLASH_GATE_CLASS "class"
#define CLASH_GATE_TWIN "twin"
#define CLASH_GATE_CARRIER "carrier"

#define CLASH_UNLOCK_GUN "gun"
#define CLASH_UNLOCK_MASTERY "mastery"
#define CLASH_UNLOCK_ROLE "role"
#define CLASH_UNLOCK_ATTACHMENT "attachment"
#define CLASH_UNLOCK_CARRIER "carrier"
#define CLASH_UNLOCK_GEAR "gear"
#define CLASH_UNLOCK_SHOP "shop"
#define CLASH_UNLOCK_COSMETIC "cosmetic"
#define CLASH_UNLOCK_LEVEL "level"
#define CLASH_UNLOCK_MORE "more"

#define CLASH_XP_SOURCE_KILL "Kill"
#define CLASH_XP_SOURCE_ASSIST "Assist"
#define CLASH_XP_SOURCE_REVIVE "Revive"
#define CLASH_XP_SOURCE_CAPTURE "Capture"
#define CLASH_XP_SOURCE_ZONE "Zone"
#define CLASH_XP_SOURCE_MATCH_WIN "Match win"
#define CLASH_XP_SOURCE_ROUND "Round"
#define CLASH_XP_SOURCE_BOT_KILL "Bot kill"
#define CLASH_XP_SOURCE_HEALING "Healing"
#define CLASH_XP_SOURCE_SPLINT "Splint"
#define CLASH_XP_SOURCE_SURGERY "Surgery"
#define CLASH_XP_SOURCE_COVER "Cover"
#define CLASH_XP_SOURCE_REPAIR "Repair"
#define CLASH_XP_SOURCE_LEADER "Leader assist"

#define CLASH_CLASS_RIFLEMAN "rifleman"
#define CLASH_CLASS_MEDIC "medic"
#define CLASH_CLASS_ENGINEER "engineer"
#define CLASH_CLASS_HEAVY "heavy"
#define CLASH_CLASS_LEADER "leader"
#define CLASH_CLASS_SUPPORT "support"

#define CLASH_FAMILY_SHOTGUN "shotgun"
#define CLASH_FAMILY_MAGAZINE "magazine"
#define CLASH_FAMILY_SIDEARM "sidearm"
#define CLASH_FAMILY_GRENADE "grenade"
#define CLASH_FAMILY_FUEL "fuel"
#define CLASH_FAMILY_LEVER "lever"

GLOBAL_LIST_INIT(clash_job_classes, list(
	JOB_SQUAD_MARINE = CLASH_CLASS_RIFLEMAN,
	JOB_UPP = CLASH_CLASS_RIFLEMAN,
	JOB_SQUAD_MEDIC = CLASH_CLASS_MEDIC,
	JOB_UPP_MEDIC = CLASH_CLASS_MEDIC,
	JOB_SQUAD_ENGI = CLASH_CLASS_ENGINEER,
	JOB_UPP_ENGI = CLASH_CLASS_ENGINEER,
	JOB_SQUAD_SMARTGUN = CLASH_CLASS_HEAVY,
	JOB_SQUAD_SPECIALIST = CLASH_CLASS_HEAVY,
	JOB_UPP_SPECIALIST = CLASH_CLASS_HEAVY,
	JOB_SQUAD_TEAM_LEADER = CLASH_CLASS_LEADER,
	JOB_SQUAD_LEADER = CLASH_CLASS_LEADER,
	JOB_UPP_LEADER = CLASH_CLASS_LEADER,
	JOB_DOCTOR = CLASH_CLASS_SUPPORT,
	JOB_NURSE = CLASH_CLASS_SUPPORT,
	JOB_FIELD_DOCTOR = CLASH_CLASS_SUPPORT,
	JOB_CHIEF_REQUISITION = CLASH_CLASS_SUPPORT,
	JOB_CARGO_TECH = CLASH_CLASS_SUPPORT,
	JOB_UPP_LT_DOKTOR = CLASH_CLASS_SUPPORT,
	JOB_UPP_SUPPLY = CLASH_CLASS_SUPPORT,
))

GLOBAL_LIST_EMPTY(clash_grenade_names)

GLOBAL_LIST_INIT(clash_unlock_styles, list(
	CLASH_UNLOCK_GUN = list("order" = 1, "color" = "#E8B931", "header" = "NEW WEAPON", "sound" = 'sound/machines/chime.ogg', "banner" = TRUE),
	CLASH_UNLOCK_MASTERY = list("order" = 2, "color" = "#E8B931", "header" = "WEAPON MASTERED", "sound" = 'sound/effects/dingding.ogg', "banner" = TRUE, "border" = TRUE),
	CLASH_UNLOCK_ROLE = list("order" = 3, "color" = "#D9534F", "header" = "ROLE UNLOCKED", "sound" = 'sound/effects/dingding.ogg'),
	CLASH_UNLOCK_ATTACHMENT = list("order" = 4, "color" = "#4A90E2", "header" = "NEW ATTACHMENT", "sound" = 'sound/machines/ping.ogg'),
	CLASH_UNLOCK_CARRIER = list("order" = 5, "color" = "#2BB5A8", "header" = "NEW CARRIER", "sound" = 'sound/machines/ding_short.ogg'),
	CLASH_UNLOCK_GEAR = list("order" = 6, "color" = "#5CB85C", "header" = "NEW GEAR", "sound" = 'sound/machines/ding_short.ogg'),
	CLASH_UNLOCK_SHOP = list("order" = 7, "color" = "#8A939C", "header" = "SHOP UPGRADE", "sound" = 'sound/machines/terminal_button01.ogg'),
	CLASH_UNLOCK_COSMETIC = list("order" = 8, "color" = "#9B6BD6", "header" = "NEW COSMETIC", "sound" = 'sound/machines/pda_ping.ogg'),
	CLASH_UNLOCK_LEVEL = list("order" = 9, "color" = "#E6E6E6", "header" = "LEVEL UP", "sound" = 'sound/machines/ding.ogg', "strip" = TRUE),
	CLASH_UNLOCK_MORE = list("order" = 10, "color" = "#8A939C", "header" = "MORE UNLOCKS", "sound" = 'sound/machines/ding.ogg', "strip" = TRUE),
))

GLOBAL_LIST_INIT(clash_insignia_names, list(
	FACTION_MARINE = list("Private", "Private First Class", "Lance Corporal", "Corporal", "Sergeant", "Staff Sergeant", "Gunnery Sergeant", "Master Sergeant", "First Sergeant", "Sergeant Major"),
	FACTION_UPP = list("Ryadovoy", "Yefreytor", "Mladshiy Serzhant", "Serzhant", "Starshiy Serzhant", "Starshina", "Praporshchik", "Mladshiy Leytenant", "Leytenant", "Starshiy Leytenant"),
))

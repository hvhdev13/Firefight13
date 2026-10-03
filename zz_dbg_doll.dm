TEST_FOCUS(/datum/unit_test/zz_dbg_doll)

/datum/unit_test/zz_dbg_doll/Run()
	build_clash_kit_catalog()
	GLOB.clash_progression_settings["enabled"] = FALSE
	for(var/gun_type in list(/obj/item/weapon/gun/shotgun/type23, /obj/item/weapon/gun/rifle/type71))
		var/datum/clash_kit/kit = new
		kit.choices[KIT_SLOT_PRIMARY] = clash_kit_option_id(FACTION_UPP, KIT_SLOT_PRIMARY, gun_type)
		var/list/result = render_clash_kit_doll(kit, JOB_UPP, null)
		log_world("DBGDOLL [gun_type]: rendered=[!!result] gun=[length(result?["gun"])]")

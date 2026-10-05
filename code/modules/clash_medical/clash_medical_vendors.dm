GLOBAL_LIST_INIT(clash_arena_med_removed, list(
	/obj/item/storage/pouch/medkit,
	/obj/item/storage/pouch/medkit/full,
	/obj/item/storage/pouch/medkit/full_advanced,
	/obj/item/storage/pouch/medical,
	/obj/item/storage/pouch/medical/full,
	/obj/item/storage/pouch/medical/full/pills,
	/obj/item/storage/belt/medical,
	/obj/item/storage/belt/medical/full,
	/obj/item/storage/belt/medical/lifesaver,
	/obj/item/storage/belt/medical/lifesaver/upp,
))

GLOBAL_LIST_INIT(clash_arena_med_removed_families, list(
	/obj/item/storage/pill_bottle,
	/obj/item/storage/firstaid/fire,
	/obj/item/storage/firstaid/o2,
	/obj/item/storage/firstaid/toxin,
	/obj/item/storage/firstaid/rad,
))

GLOBAL_LIST_INIT(clash_arena_med_swaps, list(
	/obj/item/storage/pouch/firstaid/full = list("First-aid Pouch", /obj/item/storage/pouch/firstaid/clash),
	/obj/item/storage/pouch/firstaid/full/alternate = list("First-aid Pouch", /obj/item/storage/pouch/firstaid/clash),
	/obj/item/storage/pouch/firstaid/full/pills = list("First-aid Pouch", /obj/item/storage/pouch/firstaid/clash),
	/obj/item/storage/pouch/firstaid/ert = list("First-aid Pouch", /obj/item/storage/pouch/firstaid/clash),
	/obj/item/storage/pouch/autoinjector/full = list("First-aid Pouch", /obj/item/storage/pouch/firstaid/clash),
	/obj/item/stack/medical/bruise_pack = list("Field Dressing", /obj/item/stack/medical/bruise_pack/field_dressing),
	/obj/item/stack/medical/ointment = list("Field Dressing", /obj/item/stack/medical/bruise_pack/field_dressing),
	/obj/item/stack/medical/advanced/bruise_pack = list("Advanced Healing Kit", /obj/item/stack/medical/advanced/bruise_pack/healing_kit),
	/obj/item/stack/medical/advanced/ointment = list("Advanced Healing Kit", /obj/item/stack/medical/advanced/bruise_pack/healing_kit),
	/obj/item/reagent_container/hypospray/autoinjector/bicaridine = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/kelotane = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/tricord = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/skillless = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/meralyne = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/dermaline = list("Healing Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_heal),
	/obj/item/reagent_container/hypospray/autoinjector/tramadol = list("Tramadol Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_tramadol),
	/obj/item/reagent_container/hypospray/autoinjector/antitoxin = list("Dylovene+ Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_antitox),
	/obj/item/reagent_container/hypospray/autoinjector/tramadol/skillless = list("Tramadol Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_tramadol),
	/obj/item/reagent_container/hypospray/autoinjector/skillless/tramadol = list("Tramadol Injector", /obj/item/reagent_container/hypospray/autoinjector/clash_tramadol),
))

GLOBAL_LIST_INIT(clash_arena_medic_only, list(
	/obj/item/reagent_container/hypospray,
	/obj/item/stack/medical/advanced,
	/obj/item/storage/belt/medical,
	/obj/item/storage/pouch/firstaid/clash/medic,
	/obj/item/device/defibrillator,
))

GLOBAL_LIST_INIT(clash_arena_crate_swaps, list(
	/obj/item/storage/pill_bottle/bicaridine = /obj/item/reagent_container/hypospray/autoinjector/clash_heal,
	/obj/item/storage/pill_bottle/kelotane = /obj/item/reagent_container/hypospray/autoinjector/clash_heal,
	/obj/item/storage/pill_bottle/tramadol = /obj/item/reagent_container/hypospray/autoinjector/clash_tramadol,
	/obj/item/storage/pill_bottle/inaprovaline = /obj/item/reagent_container/hypospray/autoinjector/inaprovaline,
	/obj/item/storage/pill_bottle/antitox = /obj/item/reagent_container/hypospray/autoinjector/clash_antitox,
	/obj/item/storage/pill_bottle/dexalin = /obj/item/reagent_container/hypospray/autoinjector/dexalinp,
	/obj/item/storage/pill_bottle/peridaxon = /obj/item/reagent_container/hypospray/autoinjector/peridaxon,
	/obj/item/storage/firstaid/fire = /obj/item/storage/firstaid/regular,
	/obj/item/storage/firstaid/o2 = /obj/item/storage/firstaid/regular,
	/obj/item/storage/firstaid/toxin = /obj/item/storage/firstaid/regular,
))

GLOBAL_LIST_INIT(clash_arena_crate_removed, list(
	/obj/item/storage/box/pillbottles,
	/obj/item/storage/box/syringes,
	/obj/item/reagent_container/glass/bottle,
))

/proc/clash_arena_med_supply()
	for(var/pack_type in GLOB.supply_packs_datums)
		var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
		if(!islist(pack.contains))
			continue
		var/list/contents = list()
		for(var/item_type in pack.contains)
			var/removed = FALSE
			for(var/family in GLOB.clash_arena_crate_removed)
				if(ispath(item_type, family))
					removed = TRUE
					break
			if(!removed && !clash_arena_eng_removed(item_type))
				contents += GLOB.clash_arena_crate_swaps[item_type] || item_type
		pack.contains = contents

/proc/clash_arena_med_entry(list/entry, medic, sorted)
	var/item_type = length(entry) >= 3 ? entry[3] : null
	if(!ispath(item_type, /obj/item))
		return entry
	if(item_type in GLOB.clash_arena_med_removed)
		return null
	for(var/family in GLOB.clash_arena_med_removed_families)
		if(ispath(item_type, family))
			return null
	if(clash_arena_eng_removed(item_type) || clash_is_arena_removed(item_type))
		return null
	var/list/swap = GLOB.clash_arena_med_swaps[item_type]
	if(swap)
		if(sorted && ispath(swap[2], /obj/item/storage))
			return null
		entry[1] = swap[1]
		entry[3] = swap[2]
		item_type = swap[2]
	if(!medic)
		for(var/medic_type in GLOB.clash_arena_medic_only)
			if(ispath(item_type, medic_type))
				return null
	return entry

/proc/clash_arena_med_products(list/products, medic, sorted, limited)
	. = list()
	var/list/seen = list()
	for(var/list/entry in products)
		var/list/mapped = clash_arena_med_entry(entry, medic, sorted)
		if(!mapped)
			continue
		var/item_type = length(mapped) >= 3 ? mapped[3] : null
		if(ispath(item_type))
			var/list/first = seen[item_type]
			if(first)
				if(limited && mapped[2] > 0)
					first[2] += mapped[2]
					mapped[2] = 0
				continue
			seen[item_type] = mapped
		. += list(mapped)

/obj/structure/machinery/cm_vending/get_available_products(mob/user)
	. = ..()
	if(clash_fast_medicine())
		var/mob/living/carbon/human/shopper = user
		. = clash_arena_med_products(., istype(src, /obj/structure/machinery/cm_vending/sorted/medical) || (ishuman(shopper) && clash_is_medic(shopper)), istype(src, /obj/structure/machinery/cm_vending/sorted), vend_flags & VEND_LIMITED_INVENTORY)
		if(ishuman(shopper) && clash_is_engineer(shopper) && istype(src, /obj/structure/machinery/cm_vending/gear))
			. += clash_engineer_vendor_entries(shopper.faction)

/proc/clash_medic_vendor_access(obj/structure/machinery/cm_vending/vendor, mob/user, display)
	if(!ishuman(user) || skillcheck(user, SKILL_MEDICAL, SKILL_MEDICAL_MEDIC))
		return TRUE
	if(display)
		to_chat(user, SPAN_WARNING("Access denied."))
		vendor.vend_fail()
	return FALSE

/proc/clash_wey_med_products(scale)
	return list(
		list("MEDICAL KITS", -1, null, null),
		list("Advanced Healing Kit", floor(scale * 30), /obj/item/stack/medical/advanced/bruise_pack/healing_kit, VENDOR_ITEM_REGULAR),
		list("Field Dressing", floor(scale * 30), /obj/item/stack/medical/bruise_pack/field_dressing, VENDOR_ITEM_REGULAR),
		list("Splints", floor(scale * 30), /obj/item/stack/medical/splint, VENDOR_ITEM_REGULAR),

		list("AUTOINJECTORS", -1, null, null),
		list("Healing Injector", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/clash_heal, VENDOR_ITEM_REGULAR),
		list("UNGA Injector", floor(scale * 10), /obj/item/reagent_container/hypospray/autoinjector/clash_unga, VENDOR_ITEM_REGULAR),
		list("Tramadol Injector", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/clash_tramadol, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Oxycodone)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/oxycodone, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Epinephrine)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/adrenaline, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Dexalin+)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/dexalinp, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Dylovene+)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/clash_antitox, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Inaprovaline)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/inaprovaline, VENDOR_ITEM_REGULAR),
		list("Autoinjector (Peridaxon)", floor(scale * 15), /obj/item/reagent_container/hypospray/autoinjector/peridaxon, VENDOR_ITEM_REGULAR),

		list("MEDICAL UTILITIES", -1, null, null),
		list("Emergency Defibrillator", floor(scale * 9), /obj/item/device/defibrillator, VENDOR_ITEM_REGULAR),
		list("Surgical Line", floor(scale * 6), /obj/item/tool/surgery/surgical_line, VENDOR_ITEM_REGULAR),
		list("Synth-Graft", floor(scale * 6), /obj/item/tool/surgery/synthgraft, VENDOR_ITEM_REGULAR),
		list("Health Analyzer", floor(scale * 15), /obj/item/device/healthanalyzer, VENDOR_ITEM_REGULAR),
		list("Stasis Bag", floor(scale * 9), /obj/item/bodybag/cryobag, VENDOR_ITEM_REGULAR),
	)

GLOBAL_LIST_INIT(clash_wey_med_refills, list(
	/obj/item/reagent_container/hypospray/autoinjector/clash_heal,
	/obj/item/reagent_container/hypospray/autoinjector/clash_tramadol,
	/obj/item/reagent_container/hypospray/autoinjector/oxycodone,
	/obj/item/reagent_container/hypospray/autoinjector/adrenaline,
	/obj/item/reagent_container/hypospray/autoinjector/dexalinp,
	/obj/item/reagent_container/hypospray/autoinjector/clash_antitox,
	/obj/item/reagent_container/hypospray/autoinjector/inaprovaline,
	/obj/item/reagent_container/hypospray/autoinjector/peridaxon,
))

/obj/structure/machinery/cm_vending/sorted/medical/arena
	req_access = list()
	req_one_access = list()

/obj/structure/machinery/cm_vending/sorted/medical/arena/Initialize()
	. = ..()
	chem_refill = GLOB.clash_wey_med_refills

/obj/structure/machinery/cm_vending/sorted/medical/arena/populate_product_list(scale)
	listed_products = clash_wey_med_products(scale)

/obj/structure/machinery/cm_vending/sorted/medical/arena/can_access_to_vend(mob/user, display = TRUE, ignore_hack = FALSE)
	return clash_medic_vendor_access(src, user, display) && ..()

/obj/structure/machinery/cm_vending/sorted/medical/upp/arena
	req_access = list()
	req_one_access = list()

/obj/structure/machinery/cm_vending/sorted/medical/upp/arena/Initialize()
	. = ..()
	chem_refill = GLOB.clash_wey_med_refills

/obj/structure/machinery/cm_vending/sorted/medical/upp/arena/populate_product_list(scale)
	listed_products = clash_wey_med_products(scale)

/obj/structure/machinery/cm_vending/sorted/medical/upp/arena/can_access_to_vend(mob/user, display = TRUE, ignore_hack = FALSE)
	return clash_medic_vendor_access(src, user, display) && ..()

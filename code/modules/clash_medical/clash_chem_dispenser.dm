#define CLASH_CHEM_TEMPLATES 3
#define CLASH_CHEM_TEMPLATE_NAME 24

GLOBAL_LIST_INIT(clash_chem_mixes, list(
	"UNGA" = list("bicaridine" = 1, "kelotane" = 1, "tricordrazine" = 1, "meralyne" = 1, "dermaline" = 1, "oxycodone" = 1),
	"MB" = list("meralyne" = 1, "bicaridine" = 1),
	"KD" = list("kelotane" = 1, "dermaline" = 1),
))

GLOBAL_LIST_EMPTY(clash_chem_templates)

/proc/clash_chem_template_path(ckey)
	return clash_player_save_path(ckey, "clash_chem_templates.sav")

/proc/get_clash_chem_templates(ckey)
	if(GLOB.clash_chem_templates[ckey])
		return GLOB.clash_chem_templates[ckey]
	var/list/templates = new /list(CLASH_CHEM_TEMPLATES)
	var/path = clash_chem_template_path(ckey)
	if(fexists(path))
		var/savefile/save = new(path)
		var/list/stored
		save["templates"] >> stored
		if(islist(stored))
			for(var/index in 1 to min(length(stored), CLASH_CHEM_TEMPLATES))
				var/list/template = stored[index]
				if(islist(template) && istext(template["name"]) && islist(template["reagents"]))
					templates[index] = template
	GLOB.clash_chem_templates[ckey] = templates
	return templates

/proc/save_clash_chem_templates(ckey)
	if(!ckey || IsGuestKey(ckey))
		return
	var/savefile/save = new(clash_chem_template_path(ckey))
	save["templates"] << GLOB.clash_chem_templates[ckey]

/obj/structure/machinery/chem_dispenser/corpsman/arena
	dispensable_reagents = list(
		"bicaridine",
		"kelotane",
		"tricordrazine",
		"meralyne",
		"dermaline",
		"oxycodone",
		"tramadol",
		"adrenaline",
		"dexalinp",
		"anti_toxin",
		"inaprovaline",
		"peridaxon",
	)

/obj/structure/machinery/chem_dispenser/corpsman/arena/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClashChemDispenser", name)
		ui.open()

/obj/structure/machinery/chem_dispenser/corpsman/arena/ui_data(mob/user)
	. = ..()
	var/list/mixes = list()
	for(var/mix_name in GLOB.clash_chem_mixes)
		mixes += list(list("name" = mix_name, "contents" = clash_describe_recipe(GLOB.clash_chem_mixes[mix_name], FALSE)))
	.["mixes"] = mixes
	var/list/templates = list()
	var/list/saved = user.ckey ? get_clash_chem_templates(user.ckey) : list()
	for(var/index in 1 to CLASH_CHEM_TEMPLATES)
		var/list/template = LAZYACCESS(saved, index)
		templates += list(template ? list("name" = template["name"], "contents" = clash_describe_recipe(template["reagents"])) : null)
	.["templates"] = templates

/proc/clash_describe_recipe(list/recipe, units = TRUE)
	. = list()
	for(var/id in recipe)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[id]
		. += "[units ? "[recipe[id]]u " : ""][reagent ? reagent.name : id]"
	return jointext(., ", ")

/obj/structure/machinery/chem_dispenser/corpsman/arena/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	switch(action)
		if("mix")
			var/list/mix = GLOB.clash_chem_mixes[params["name"]]
			if(!mix)
				return
			var/parts = 0
			for(var/id in mix)
				parts += mix[id]
			var/list/recipe = list()
			for(var/id in mix)
				recipe[id] = amount * mix[id] / parts
			clash_dispense(recipe)
			return TRUE
		if("template_fill")
			var/list/template = clash_template_at(user, params["index"])
			if(template)
				clash_dispense(template["reagents"])
			return TRUE
		if("template_save")
			var/index = text2num(params["index"])
			if(!user.ckey || !(index in 1 to CLASH_CHEM_TEMPLATES) || !beaker?.reagents?.total_volume)
				return TRUE
			var/list/recipe = list()
			for(var/datum/reagent/reagent as anything in beaker.reagents.reagent_list)
				if(reagent.id in dispensable_reagents)
					recipe[reagent.id] = round(reagent.volume, 0.1)
			if(!length(recipe))
				return TRUE
			INVOKE_ASYNC(src, PROC_REF(clash_save_template), user, index, recipe)
			return TRUE
		if("template_clear")
			var/index = text2num(params["index"])
			if(!user.ckey || !(index in 1 to CLASH_CHEM_TEMPLATES))
				return TRUE
			var/list/templates = get_clash_chem_templates(user.ckey)
			templates[index] = null
			save_clash_chem_templates(user.ckey)
			return TRUE

/obj/structure/machinery/chem_dispenser/corpsman/arena/proc/clash_template_at(mob/user, index)
	index = text2num(index)
	if(!user.ckey || !(index in 1 to CLASH_CHEM_TEMPLATES))
		return null
	return get_clash_chem_templates(user.ckey)[index]

/obj/structure/machinery/chem_dispenser/corpsman/arena/proc/clash_save_template(mob/user, index, list/recipe)
	var/list/templates = get_clash_chem_templates(user.ckey)
	var/list/old = templates[index]
	var/entered = tgui_input_text(user, "Name this mix.", "Save mix", old ? old["name"] : "Mix [index]", CLASH_CHEM_TEMPLATE_NAME, encode = FALSE)
	var/new_name = trim(sanitize_simple(strip_html_simple("[entered]", CLASH_CHEM_TEMPLATE_NAME + 1)))
	if(!length(new_name))
		return
	templates[index] = list("name" = new_name, "reagents" = recipe)
	save_clash_chem_templates(user.ckey)
	SStgui.update_uis(src)

/obj/structure/machinery/chem_dispenser/corpsman/arena/proc/clash_dispense(list/recipe)
	if(inoperable() || QDELETED(beaker))
		return
	var/datum/reagents/holder = beaker.reagents
	var/total = 0
	for(var/id in recipe)
		if(id in dispensable_reagents)
			total += recipe[id]
	if(total <= 0)
		return
	var/scale = min(1, (holder.maximum_volume - holder.total_volume) / total, chem_storage.energy * 10 / total)
	if(scale <= 0)
		return
	for(var/id in recipe)
		if(id in dispensable_reagents)
			holder.add_reagent(id, recipe[id] * scale)
	chem_storage.energy = max(chem_storage.energy - total * scale / 10, 0)

#undef CLASH_CHEM_TEMPLATES
#undef CLASH_CHEM_TEMPLATE_NAME

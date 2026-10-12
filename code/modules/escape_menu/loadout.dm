/datum/escape_menu/proc/home_open_loadout()
	open_clash_kit_screen(client?.mob)
	qdel(src)

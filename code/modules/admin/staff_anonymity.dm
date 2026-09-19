/proc/should_hide_staff_key(client/staff, client/viewer)
	return staff?.admin_holder && !viewer?.admin_holder

#define CLASH_TOAST_QUEUE_MAX 3
#define CLASH_TOAST_IN (3 DECISECONDS)
#define CLASH_TOAST_OUT (5 DECISECONDS)
#define CLASH_TOAST_HOLD (4.2 SECONDS)
#define CLASH_FEED_LIFETIME (2 SECONDS)
#define CLASH_FEED_LINES 4

GLOBAL_LIST_EMPTY(clash_toast_icons)

/client/var/atom/movable/screen/clash_toast/clash_toast
/client/var/atom/movable/screen/clash_score_feed/clash_score_feed
/client/var/list/clash_toast_queue = list()
/client/var/clash_toast_overflow = 0
/client/var/clash_toast_busy = FALSE
/client/var/list/clash_feed_lines = list()

/proc/clash_toast_size(list/style)
	if(style["banner"])
		return list(224, 48)
	if(style["strip"])
		return list(160, 20)
	return list(160, 32)

/proc/get_clash_toast_icon(list/style)
	var/key = "[style["color"]]|[style["banner"]]|[style["strip"]]|[style["border"]]"
	if(GLOB.clash_toast_icons[key])
		return GLOB.clash_toast_icons[key]
	var/list/size = clash_toast_size(style)
	var/width = size[1]
	var/height = size[2]
	var/color = style["color"]
	var/icon/card = icon('icons/effects/effects.dmi', "nothing")
	card.Scale(width, height)
	card.DrawBox(rgb(8, 10, 13, 205), 2, 1, width - 1, height)
	card.DrawBox(rgb(8, 10, 13, 205), 1, 2, width, height - 1)
	card.DrawBox(clash_tint(color, 36), 2, 2, width - 1, height - 1)
	card.DrawBox(color, 2, 2, 4, height - 1)
	if(style["banner"])
		card.DrawBox(color, 2, height - 2, width - 1, height - 1)
		card.DrawBox(color, 2, 2, width - 1, 3)
	if(style["border"])
		card.DrawBox(rgb(255, 255, 255), 1, 2, 1, height - 1)
		card.DrawBox(rgb(255, 255, 255), width, 2, width, height - 1)
		card.DrawBox(rgb(255, 255, 255), 2, 1, width - 1, 1)
		card.DrawBox(rgb(255, 255, 255), 2, height, width - 1, height)
	if(!style["strip"])
		card.DrawBox(rgb(14, 17, 21, 250), 7, 4, 7 + height - 9, height - 4)
	GLOB.clash_toast_icons[key] = card
	return card

/atom/movable/screen/clash_toast
	name = "Unlock"
	icon = null
	alpha = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/clash_toast/proc/show(list/entry)
	var/list/style = GLOB.clash_unlock_styles[entry["kind"]]
	var/list/size = clash_toast_size(style)
	var/width = size[1]
	var/height = size[2]
	screen_loc = style["banner"] ? "CENTER-3,TOP-5" : "CENTER-2,TOP-3:12"
	icon = get_clash_toast_icon(style)
	overlays.Cut()
	var/outline = "-dm-text-outline: 1px black"
	var/text_x = style["strip"] ? 9 : height + 4
	var/list/lines = list()
	lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: [style["color"]]'>[style["header"]]</span>"
	if(style["banner"])
		lines += "<span style='font-family: \"VCR OSD Mono\"; font-size: 11px; color: #ffffff'>[html_encode(entry["name"])]</span>"
		lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #aab2b9'>[html_encode(entry["source"])]</span>"
	else if(style["strip"])
		lines[1] = "[lines[1]]  <span style='font-family: \"Small Fonts\"; font-size: 6px; color: #e8ecef'>[html_encode(entry["name"])], [html_encode(entry["source"])]</span>"
	else
		lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #e8ecef'>[html_encode(entry["name"])]</span>"
		lines += "<span style='font-family: \"Small Fonts\"; font-size: 6px; color: #aab2b9'>[html_encode(entry["source"])]</span>"
	var/mutable_appearance/text = clash_score_text("<span style='[outline]; text-align: left; vertical-align: middle'>[lines.Join("<br>")]</span>", text_x, 2, width - text_x - 4, height - 4)
	text.appearance_flags &= ~RESET_ALPHA
	overlays += text
	var/item_type = entry["icon"]
	if(!style["strip"] && ispath(item_type, /atom))
		var/atom/sprite_type = item_type
		var/mutable_appearance/sprite = mutable_appearance(initial(sprite_type.icon), initial(sprite_type.icon_state))
		var/mutable_appearance/picture = clash_death_card_picture(sprite, world.icon_size, world.icon_size, 7 + (height - 8) / 2, height / 2, style["banner"] ? 2 : 1, height - 8)
		picture.appearance_flags &= ~RESET_ALPHA
		overlays += picture
	animate(src)
	pixel_y = 16
	alpha = 0
	animate(src, alpha = 255, pixel_y = 0, time = CLASH_TOAST_IN, easing = CUBIC_EASING|EASE_OUT)

/proc/clash_notify_unlock(ckey, kind, name, source_text, icon_path)
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		return
	var/list/style = GLOB.clash_unlock_styles[kind]
	progress.unlocked_round += list(list("header" = style["header"], "name" = name, "source" = source_text, "color" = style["color"]))
	var/client/player = GLOB.directory[ckey]
	if(!player)
		return
	to_chat(player, "<span style='color: [style["color"]]'><b>[style["header"]]</b>: [html_encode(name)], [html_encode(source_text)]</span>")
	if(!progress.toasts)
		return
	var/list/entry = list("kind" = kind, "name" = name, "source" = source_text, "icon" = icon_path)
	var/list/queue = player.clash_toast_queue
	var/index = length(queue) + 1
	for(var/position in 1 to length(queue))
		var/list/queued = queue[position]
		if(GLOB.clash_unlock_styles[queued["kind"]]["order"] > style["order"])
			index = position
			break
	if(index > CLASH_TOAST_QUEUE_MAX)
		player.clash_toast_overflow++
	else
		queue.Insert(index, list(entry))
		if(length(queue) > CLASH_TOAST_QUEUE_MAX)
			queue.Cut(CLASH_TOAST_QUEUE_MAX + 1)
			player.clash_toast_overflow++
	if(!player.clash_toast_busy)
		clash_show_next_toast(ckey)

/proc/clash_show_next_toast(ckey)
	var/client/player = GLOB.directory[ckey]
	if(!player)
		return
	var/list/entry
	if(length(player.clash_toast_queue))
		entry = player.clash_toast_queue[1]
		player.clash_toast_queue.Cut(1, 2)
	else if(player.clash_toast_overflow)
		entry = list("kind" = CLASH_UNLOCK_MORE, "name" = "+[player.clash_toast_overflow] more unlock\s", "source" = "see the kit screen")
		player.clash_toast_overflow = 0
	else
		player.clash_toast_busy = FALSE
		return
	player.clash_toast_busy = TRUE
	if(!player.clash_toast)
		player.clash_toast = new
	if(!(player.clash_toast in player.screen))
		player.screen += player.clash_toast
	player.clash_toast.show(entry)
	playsound_client(player, GLOB.clash_unlock_styles[entry["kind"]]["sound"], null, 50)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_hide_toast), ckey), CLASH_TOAST_IN + CLASH_TOAST_HOLD)

/proc/clash_hide_toast(ckey)
	var/client/player = GLOB.directory[ckey]
	if(!player?.clash_toast)
		return
	animate(player.clash_toast, alpha = 0, time = CLASH_TOAST_OUT)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_show_next_toast), ckey), CLASH_TOAST_OUT)

/atom/movable/screen/clash_score_feed
	name = "XP"
	icon = null
	screen_loc = "CENTER-2,BOTTOM+2"
	maptext_width = 160
	maptext_height = 48
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/proc/clash_score_feed(ckey, amount, source)
	var/client/player = GLOB.directory[ckey]
	if(!player)
		return
	player.clash_feed_lines += list(list("text" = "+[amount] [source]", "expiry" = world.time + CLASH_FEED_LIFETIME))
	if(length(player.clash_feed_lines) > CLASH_FEED_LINES)
		player.clash_feed_lines.Cut(1, 2)
	clash_render_score_feed(player)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_prune_score_feed), ckey), CLASH_FEED_LIFETIME + 1)

/proc/clash_prune_score_feed(ckey)
	var/client/player = GLOB.directory[ckey]
	if(!player)
		return
	for(var/index = length(player.clash_feed_lines) to 1 step -1)
		var/list/line = player.clash_feed_lines[index]
		if(line["expiry"] <= world.time)
			player.clash_feed_lines.Cut(index, index + 1)
	clash_render_score_feed(player)

/proc/clash_render_score_feed(client/player)
	if(!player.clash_score_feed)
		player.clash_score_feed = new
	if(!(player.clash_score_feed in player.screen))
		player.screen += player.clash_score_feed
	var/list/texts = list()
	for(var/list/line as anything in player.clash_feed_lines)
		texts += line["text"]
	player.clash_score_feed.maptext = "<span style='font-family: \"Small Fonts\"; font-size: 7px; text-align: center; vertical-align: bottom; color: #f2d36b; -dm-text-outline: 1px black'>[texts.Join("<br>")]</span>"

/mob/verb/clash_toggle_unlock_popups()
	set name = "Toggle unlock pop-ups"
	set category = "OOC"
	var/datum/clash_progress/progress = clash_progress_of(ckey)
	if(!progress)
		to_chat(src, SPAN_WARNING("Progression is not saved for guest accounts."))
		return
	progress.toasts = !progress.toasts
	progress.save()
	to_chat(src, SPAN_NOTICE("Unlock pop-ups are now [progress.toasts ? "on" : "off"]. Unlocks are always listed in chat."))

#undef CLASH_TOAST_QUEUE_MAX
#undef CLASH_TOAST_IN
#undef CLASH_TOAST_OUT
#undef CLASH_TOAST_HOLD
#undef CLASH_FEED_LIFETIME
#undef CLASH_FEED_LINES

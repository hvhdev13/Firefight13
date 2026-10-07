#define CLASH_SUPPRESSION_MAX 100
#define CLASH_SUPPRESSION_NEAR_MISS 18
#define CLASH_SUPPRESSION_HIT 35
#define CLASH_SUPPRESSION_HOLD (1.5 SECONDS)
#define CLASH_SUPPRESSION_LONG_HOLD (3 SECONDS)
#define CLASH_SUPPRESSION_DECAY 15
#define CLASH_SUPPRESSION_DESATURATE 0.6
#define CLASH_SUPPRESSION_DARKEN 0.45
#define CLASH_SUPPRESSION_PULSE (4 DECISECONDS)
#define CLASH_SUPPRESSION_PULSE_LOW 0.55
#define CLASH_SUPPRESSION_RAMP (2 DECISECONDS)
#define CLASH_SUPPRESSION_MISS_RADIUS 1.5
#define CLASH_SUPPRESSION_OVERSHOOT 3
#define CLASH_SUPPRESSION_STEADY 0.5
#define CLASH_SUPPRESSION_SHAKE 0.1
#define CLASH_SUPPRESSION_SHAKE_HEAVY 0.15
#define CLASH_LOUD_TIME (3 SECONDS)
#define CLASH_SUPPRESSION_HEAVY_MISS 27
#define CLASH_SUPPRESSION_WIDE_RADIUS 2.5
#define CLASH_SUPPRESSION_BRACED 0.5
#define CLASH_SUPPRESSION_SLOW 0.25
#define CLASH_SPOTTER_THRESHOLD 50
#define CLASH_SPOTTER_TIME (3 SECONDS)
#define CLASH_COWER_SQUASH 0.05
#define CLASH_COWER_SQUASH_STEP 0.01
#define CLASH_SUPPRESSED_STATUS 50
#define CLASH_COWER_JITTER 50
#define CLASH_COWER_JITTER_PIXELS 2
#define CLASH_COWER_STEP (2 DECISECONDS)
#define CLASH_DIP_DEPTH 2
#define CLASH_DIP_COOLDOWN (4 DECISECONDS)
#define CLASH_DUST_COLOR "#9c8a66"

/mob/living/carbon/human/var/clash_suppression = 0
/mob/living/carbon/human/var/clash_suppression_hold = 0
/mob/living/carbon/human/var/turf/clash_aim_turf
/mob/living/carbon/human/var/clash_loud_until = 0
/mob/living/carbon/human/var/clash_spotted_until = 0
/mob/living/carbon/human/var/clash_spotted_faction
/mob/living/carbon/human/var/clash_cowering = FALSE
/mob/living/carbon/human/var/clash_cower_squash = 0
/mob/living/carbon/human/var/clash_cower_w = 0
/mob/living/carbon/human/var/clash_dip_ready = 0

/particles/clash_dust_kick
	icon = 'icons/effects/particles/generic_particles.dmi'
	icon_state = "pixel"
	width = 64
	height = 64
	count = 30
	spawning = 0
	lifespan = 6
	fade = 4
	friction = 0.25
	gravity = list(0, -0.25)
	position = generator("circle", 0, 3)
	scale = generator("num", 1, 2)

/atom/movable/screen/fullscreen/clash_suppression
	icon_state = "brutedamageoverlay"
	layer = FULLSCREEN_DAMAGE_LAYER
	color = COLOR_BLACK
	alpha = 0

/proc/clash_suppression_now(mob/living/carbon/human/target)
	var/faded = max(world.time - target.clash_suppression_hold, 0)
	return max(target.clash_suppression - CLASH_SUPPRESSION_DECAY * faded / (1 SECONDS), 0)

/proc/clash_suppression_alpha(value)
	return value > 0 ? min(min(value, 20) * 7 + value * 1.15, 255) : 0

/proc/clash_suppression_matrix(value)
	var/list/matrix = color_matrix_saturation(1 - CLASH_SUPPRESSION_DESATURATE * value / CLASH_SUPPRESSION_MAX)
	var/light = 1 - CLASH_SUPPRESSION_DARKEN * value / CLASH_SUPPRESSION_MAX
	for(var/index in list(1, 2, 3, 5, 6, 7, 9, 10, 11))
		matrix[index] *= light
	return matrix

/proc/clash_suppress(mob/living/carbon/human/target, amount, mob/living/carbon/human/shooter)
	if((!target.client && !target.statistic_exempt) || target.stat == DEAD || amount <= 0)
		return
	if(clash_has_perk(target, /datum/clash_perk/steady_nerves))
		amount *= CLASH_SUPPRESSION_STEADY
	if(clash_braced(target))
		amount *= CLASH_SUPPRESSION_BRACED
	var/previous = clash_suppression_now(target)
	var/value = min(previous + amount, CLASH_SUPPRESSION_MAX)
	var/fade = value / CLASH_SUPPRESSION_DECAY * (1 SECONDS)
	target.clash_suppression = value
	target.clash_suppression_hold = max(target.clash_suppression_hold, world.time + (clash_has_perk(shooter, /datum/clash_perk/long_hold) ? CLASH_SUPPRESSION_LONG_HOLD : CLASH_SUPPRESSION_HOLD))
	var/hold = target.clash_suppression_hold - world.time
	if(target.client)
		clash_suppression_screen(target, previous, value, hold, fade)
	addtimer(CALLBACK(target, TYPE_PROC_REF(/mob/living/carbon/human, clash_suppression_end)), hold + fade + 1, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_NO_HASH_WAIT)
	target.recalculate_move_delay = TRUE
	if(!target.clash_cowering)
		target.clash_cowering = TRUE
		target.clash_cower_tick()
	clash_note_suppression(target, shooter, value - previous, value)

/proc/clash_suppression_screen(mob/living/carbon/human/target, previous, value, hold, fade)
	var/atom/movable/screen/fullscreen/screen = target.overlay_fullscreen("clash_suppression", /atom/movable/screen/fullscreen/clash_suppression, clamp(CEILING(value / 34, 1), 1, 3))
	if(screen)
		screen.alpha = clash_suppression_alpha(previous)
		animate(screen, alpha = clash_suppression_alpha(value), time = CLASH_SUPPRESSION_RAMP)
		var/elapsed = CLASH_SUPPRESSION_RAMP
		var/low = TRUE
		while(elapsed < hold + fade)
			elapsed += CLASH_SUPPRESSION_PULSE
			var/level = value - CLASH_SUPPRESSION_DECAY * max(elapsed - hold, 0) / (1 SECONDS)
			if(level <= 0)
				break
			animate(alpha = clash_suppression_alpha(level) * (low ? CLASH_SUPPRESSION_PULSE_LOW : 1), time = CLASH_SUPPRESSION_PULSE, easing = SINE_EASING)
			low = !low
		animate(alpha = 0, time = CLASH_SUPPRESSION_PULSE)
	var/atom/movable/screen/plane_master/plate = target.hud_used?.plane_masters["[RENDER_PLANE_GAME]"]
	if(plate)
		plate.add_filter("clash_suppression", 10, color_matrix_filter(clash_suppression_matrix(previous)))
		animate(plate.get_filter("clash_suppression"), color = clash_suppression_matrix(value), time = CLASH_SUPPRESSION_RAMP)
		animate(time = hold - CLASH_SUPPRESSION_RAMP)
		animate(color = clash_suppression_matrix(0), time = fade)
	shake_camera(target, 2, value >= CLASH_SUPPRESSION_MAX / 2 ? CLASH_SUPPRESSION_SHAKE_HEAVY : CLASH_SUPPRESSION_SHAKE)

/mob/living/carbon/human/proc/clash_suppression_end()
	clash_suppression = 0
	recalculate_move_delay = TRUE
	clear_fullscreen("clash_suppression", FALSE)
	hud_used?.plane_masters["[RENDER_PLANE_GAME]"]?.remove_filter("clash_suppression")

/mob/living/carbon/human/proc/clash_cower_tick()
	var/level = clash_suppression_now(src)
	var/upright = stat == CONSCIOUS && body_position != LYING_DOWN
	var/squash = upright ? round(CLASH_COWER_SQUASH * level / CLASH_SUPPRESSION_MAX, CLASH_COWER_SQUASH_STEP) : 0
	var/jitter = upright && level >= CLASH_COWER_JITTER ? (clash_cower_w > 0 ? -CLASH_COWER_JITTER_PIXELS : CLASH_COWER_JITTER_PIXELS) : 0
	recalculate_move_delay = TRUE
	if(level >= CLASH_SUPPRESSED_STATUS && stat != DEAD)
		clash_status_add(src, /datum/clash_status/suppressed)
	else
		clash_status_remove(src, /datum/clash_status/suppressed)
	if(squash != clash_cower_squash)
		var/matrix/hunch = matrix()
		hunch.Scale(1, 1 - squash)
		hunch.Translate(0, -world.icon_size / 2 * squash)
		update_base_transform(hunch, CLASH_COWER_STEP)
		clash_cower_squash = squash
	if(jitter != clash_cower_w)
		animate(src, pixel_w = jitter - clash_cower_w, time = CLASH_COWER_STEP, flags = ANIMATION_PARALLEL|ANIMATION_RELATIVE)
		clash_cower_w = jitter
	if(level <= 0 && !squash && !jitter)
		clash_cowering = FALSE
		return
	addtimer(CALLBACK(src, PROC_REF(clash_cower_tick)), CLASH_COWER_STEP)

/mob/living/carbon/human/proc/clash_near_miss_cue()
	if(world.time < clash_dip_ready || stat != CONSCIOUS || body_position == LYING_DOWN)
		return
	clash_dip_ready = world.time + CLASH_DIP_COOLDOWN
	animate(src, pixel_z = -CLASH_DIP_DEPTH, time = 1, easing = CUBIC_EASING|EASE_OUT, flags = ANIMATION_PARALLEL|ANIMATION_RELATIVE)
	animate(pixel_z = CLASH_DIP_DEPTH, time = 2, easing = CUBIC_EASING|EASE_IN, flags = ANIMATION_RELATIVE)
	var/obj/effect/clash_hit/spray/dust = new(get_turf(src), /particles/clash_dust_kick, CLASH_DUST_COLOR, 0, 1, 10, 2, 1.5)
	dust.pixel_x = rand(-12, 12)
	dust.pixel_y = rand(-14, -8)

/proc/clash_suppression_slow(mob/living/carbon/human/target)
	return 1 + CLASH_SUPPRESSION_SLOW * clash_suppression_now(target) / CLASH_SUPPRESSION_MAX

/proc/clash_note_suppression(mob/living/carbon/human/target, mob/living/carbon/human/shooter, gained, value)
	var/datum/game_mode/extended/faction_clash/hvh/clash_mode = SSticker.mode
	if(istype(clash_mode) && !target.statistic_exempt)
		clash_mode.note_suppression(target, shooter)
	if(value >= CLASH_SPOTTER_THRESHOLD && clash_has_perk(shooter, /datum/clash_perk/spotter))
		target.clash_spotted_until = world.time + CLASH_SPOTTER_TIME
		target.clash_spotted_faction = shooter.faction
	if(gained > 0)
		clash_progress_suppression(shooter, gained, target)

/proc/clash_braced(mob/living/carbon/human/fighter)
	if(!clash_has_perk(fighter, /datum/clash_perk/braced))
		return FALSE
	for(var/obj/item/weapon/gun/held in list(fighter.l_hand, fighter.r_hand))
		if(HAS_TRAIT(held, TRAIT_GUN_BIPODDED))
			return TRUE
	return FALSE

/proc/clash_suppress_line(mob/shooter, turf/start, turf/aim)
	var/line_x = aim.x - start.x
	var/line_y = aim.y - start.y
	var/length = sqrt(line_x ** 2 + line_y ** 2)
	if(!length)
		return
	var/reach = length + CLASH_SUPPRESSION_OVERSHOOT
	var/radius = clash_has_perk(shooter, /datum/clash_perk/wide_fire) ? CLASH_SUPPRESSION_WIDE_RADIUS : CLASH_SUPPRESSION_MISS_RADIUS
	var/amount = clash_has_perk(shooter, /datum/clash_perk/heavy_fire) ? CLASH_SUPPRESSION_HEAVY_MISS : CLASH_SUPPRESSION_NEAR_MISS
	for(var/mob/living/carbon/human/target as anything in GLOB.alive_human_list)
		if(target.z != start.z || target.faction == shooter.faction)
			continue
		var/offset_x = target.x - start.x
		var/offset_y = target.y - start.y
		var/along = (offset_x * line_x + offset_y * line_y) / length
		if(along < 1 || along > reach)
			continue
		if(abs(offset_x * line_y - offset_y * line_x) / length <= radius)
			clash_suppress(target, amount, shooter)
			target.clash_near_miss_cue()

/datum/element/clash_suppression

/datum/element/clash_suppression/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(target, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired))
	RegisterSignal(target, COMSIG_MOB_FIRED_GUN_ATTACHMENT, PROC_REF(on_fired_attachment))
	RegisterSignal(target, COMSIG_MOB_MOUSEDOWN, PROC_REF(on_mouse_down))
	RegisterSignal(target, COMSIG_MOB_MOUSEDRAG, PROC_REF(on_mouse_drag))
	RegisterSignal(target, COMSIG_HUMAN_POST_MOVE_DELAY, PROC_REF(on_move_delay))

/datum/element/clash_suppression/Detach(datum/source, force)
	. = ..()
	UnregisterSignal(source, list(COMSIG_HUMAN_BULLET_ACT, COMSIG_MOB_FIRED_GUN, COMSIG_MOB_FIRED_GUN_ATTACHMENT, COMSIG_MOB_MOUSEDOWN, COMSIG_MOB_MOUSEDRAG, COMSIG_HUMAN_POST_MOVE_DELAY))

/datum/element/clash_suppression/proc/on_shot(mob/living/carbon/human/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/shooter = bullet.firer
	if(ishuman(shooter) && shooter.faction != source.faction && clash_is_heavy(shooter))
		clash_suppress(source, CLASH_SUPPRESSION_HIT, shooter)

/datum/element/clash_suppression/proc/on_move_delay(mob/living/carbon/human/source, list/movedata)
	SIGNAL_HANDLER
	if(source.clash_suppression)
		movedata["move_delay"] *= clash_suppression_slow(source)

/datum/element/clash_suppression/proc/on_mouse_down(mob/living/carbon/human/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	source.clash_aim_turf = get_turf(get_turf_on_clickcatcher(object, source, params))

/datum/element/clash_suppression/proc/on_mouse_drag(mob/living/carbon/human/source, atom/src_object, atom/over_object, turf/src_location, turf/over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	source.clash_aim_turf = get_turf(get_turf_on_clickcatcher(over_object, source, params))

/datum/element/clash_suppression/proc/on_fired(mob/living/carbon/human/source, obj/item/weapon/gun/gun)
	SIGNAL_HANDLER
	if(!(gun.flags_gun_features & GUN_SILENCED) || gun.active_attachable)
		clash_mark_loud(source)
	clash_bandolier_shot(source, gun)
	var/turf/start = get_turf(source)
	var/turf/aim = source.clash_aim_turf
	if(start && aim && aim.z == start.z && clash_is_heavy(source))
		clash_suppress_line(source, start, aim)

/datum/element/clash_suppression/proc/on_fired_attachment(mob/living/carbon/human/source, obj/item/attachable/attachment)
	SIGNAL_HANDLER
	clash_mark_loud(source)

/proc/clash_mark_loud(mob/living/carbon/human/shooter)
	if(ishuman(shooter))
		shooter.clash_loud_until = world.time + CLASH_LOUD_TIME

#undef CLASH_SUPPRESSION_MAX
#undef CLASH_SUPPRESSION_NEAR_MISS
#undef CLASH_SUPPRESSION_HIT
#undef CLASH_SUPPRESSION_HOLD
#undef CLASH_SUPPRESSION_LONG_HOLD
#undef CLASH_SUPPRESSION_DECAY
#undef CLASH_SUPPRESSION_DESATURATE
#undef CLASH_SUPPRESSION_DARKEN
#undef CLASH_SUPPRESSION_PULSE
#undef CLASH_SUPPRESSION_PULSE_LOW
#undef CLASH_SUPPRESSION_RAMP
#undef CLASH_SUPPRESSION_MISS_RADIUS
#undef CLASH_SUPPRESSION_OVERSHOOT
#undef CLASH_SUPPRESSION_STEADY
#undef CLASH_SUPPRESSION_SHAKE
#undef CLASH_SUPPRESSION_SHAKE_HEAVY
#undef CLASH_LOUD_TIME
#undef CLASH_SUPPRESSION_HEAVY_MISS
#undef CLASH_SUPPRESSION_WIDE_RADIUS
#undef CLASH_SUPPRESSION_BRACED
#undef CLASH_SUPPRESSION_SLOW
#undef CLASH_SPOTTER_THRESHOLD
#undef CLASH_SPOTTER_TIME
#undef CLASH_COWER_SQUASH
#undef CLASH_COWER_SQUASH_STEP
#undef CLASH_SUPPRESSED_STATUS
#undef CLASH_COWER_JITTER
#undef CLASH_COWER_JITTER_PIXELS
#undef CLASH_COWER_STEP
#undef CLASH_DIP_DEPTH
#undef CLASH_DIP_COOLDOWN
#undef CLASH_DUST_COLOR

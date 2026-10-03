#define CLASH_SUPPRESSION_MAX 100
#define CLASH_SUPPRESSION_NEAR_MISS 12
#define CLASH_SUPPRESSION_HIT 25
#define CLASH_SUPPRESSION_FIRE 20
#define CLASH_SUPPRESSION_BLAST_MAX 40
#define CLASH_SUPPRESSION_HOLD (1.5 SECONDS)
#define CLASH_SUPPRESSION_DECAY 15
#define CLASH_SUPPRESSION_DESATURATE 0.25
#define CLASH_SUPPRESSION_PULSE (4 DECISECONDS)
#define CLASH_SUPPRESSION_PULSE_LOW 0.55
#define CLASH_SUPPRESSION_RAMP (2 DECISECONDS)
#define CLASH_SUPPRESSION_MISS_RADIUS 1.5
#define CLASH_SUPPRESSION_OVERSHOOT 3

/mob/living/carbon/human/var/clash_suppression = 0
/mob/living/carbon/human/var/clash_suppression_hold = 0

/atom/movable/screen/fullscreen/clash_suppression
	icon_state = "brutedamageoverlay"
	layer = FULLSCREEN_DAMAGE_LAYER
	color = COLOR_BLACK
	alpha = 0

/proc/clash_suppression_now(mob/living/carbon/human/target)
	var/faded = max(world.time - target.clash_suppression_hold, 0)
	return max(target.clash_suppression - CLASH_SUPPRESSION_DECAY * faded / (1 SECONDS), 0)

/proc/clash_suppression_alpha(value)
	return value > 0 ? min(value, 20) * 4.5 + value * 1.65 : 0

/proc/clash_suppress(mob/living/carbon/human/target, amount)
	if(!target.client || target.stat == DEAD || amount <= 0)
		return
	var/previous = clash_suppression_now(target)
	var/value = min(previous + amount, CLASH_SUPPRESSION_MAX)
	var/fade = value / CLASH_SUPPRESSION_DECAY * (1 SECONDS)
	target.clash_suppression = value
	target.clash_suppression_hold = world.time + CLASH_SUPPRESSION_HOLD
	var/atom/movable/screen/fullscreen/screen = target.overlay_fullscreen("clash_suppression", /atom/movable/screen/fullscreen/clash_suppression, clamp(CEILING(value / 34, 1), 1, 3))
	if(screen)
		screen.alpha = clash_suppression_alpha(previous)
		animate(screen, alpha = clash_suppression_alpha(value), time = CLASH_SUPPRESSION_RAMP)
		var/elapsed = CLASH_SUPPRESSION_RAMP
		var/low = TRUE
		while(elapsed < CLASH_SUPPRESSION_HOLD + fade)
			elapsed += CLASH_SUPPRESSION_PULSE
			var/level = value - CLASH_SUPPRESSION_DECAY * max(elapsed - CLASH_SUPPRESSION_HOLD, 0) / (1 SECONDS)
			if(level <= 0)
				break
			animate(alpha = clash_suppression_alpha(level) * (low ? CLASH_SUPPRESSION_PULSE_LOW : 1), time = CLASH_SUPPRESSION_PULSE, easing = SINE_EASING)
			low = !low
		animate(alpha = 0, time = CLASH_SUPPRESSION_PULSE)
	var/atom/movable/screen/plane_master/plate = target.hud_used?.plane_masters["[RENDER_PLANE_GAME]"]
	if(plate)
		plate.add_filter("clash_suppression", 10, color_matrix_filter(color_matrix_saturation(1 - CLASH_SUPPRESSION_DESATURATE * previous / CLASH_SUPPRESSION_MAX)))
		animate(plate.get_filter("clash_suppression"), color = color_matrix_saturation(1 - CLASH_SUPPRESSION_DESATURATE * value / CLASH_SUPPRESSION_MAX), time = CLASH_SUPPRESSION_RAMP)
		animate(time = CLASH_SUPPRESSION_HOLD - CLASH_SUPPRESSION_RAMP)
		animate(color = color_matrix_saturation(1), time = fade)
	addtimer(CALLBACK(target, TYPE_PROC_REF(/mob/living/carbon/human, clash_suppression_end)), CLASH_SUPPRESSION_HOLD + fade + 1, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_NO_HASH_WAIT)

/mob/living/carbon/human/proc/clash_suppression_end()
	clash_suppression = 0
	clear_fullscreen("clash_suppression", FALSE)
	hud_used?.plane_masters["[RENDER_PLANE_GAME]"]?.remove_filter("clash_suppression")

/proc/clash_suppress_blast(mob/living/carbon/human/target, damage)
	clash_suppress(target, min(damage, CLASH_SUPPRESSION_BLAST_MAX))

/proc/clash_suppress_line(mob/shooter, turf/start, turf/aim)
	var/line_x = aim.x - start.x
	var/line_y = aim.y - start.y
	var/length = sqrt(line_x ** 2 + line_y ** 2)
	if(!length)
		return
	var/reach = length + CLASH_SUPPRESSION_OVERSHOOT
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/target = player.mob
		if(!istype(target) || target.z != start.z || target.faction == shooter.faction || target.stat == DEAD)
			continue
		var/offset_x = target.x - start.x
		var/offset_y = target.y - start.y
		var/along = (offset_x * line_x + offset_y * line_y) / length
		if(along < 1 || along > reach)
			continue
		if(abs(offset_x * line_y - offset_y * line_x) / length <= CLASH_SUPPRESSION_MISS_RADIUS)
			clash_suppress(target, CLASH_SUPPRESSION_NEAR_MISS)

/datum/element/clash_suppression

/datum/element/clash_suppression/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(target, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired))
	RegisterSignal(target, list(COMSIG_LIVING_FLAMER_CROSSED, COMSIG_LIVING_FLAMER_FLAMED), PROC_REF(on_flamed))

/datum/element/clash_suppression/Detach(datum/source, force)
	. = ..()
	UnregisterSignal(source, list(COMSIG_HUMAN_BULLET_ACT, COMSIG_MOB_FIRED_GUN, COMSIG_LIVING_FLAMER_CROSSED, COMSIG_LIVING_FLAMER_FLAMED))

/datum/element/clash_suppression/proc/on_shot(mob/living/carbon/human/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	var/mob/shooter = bullet.firer
	if(ismob(shooter) && shooter.faction != source.faction)
		clash_suppress(source, CLASH_SUPPRESSION_HIT)

/datum/element/clash_suppression/proc/on_fired(mob/living/carbon/human/source, obj/item/weapon/gun/gun)
	SIGNAL_HANDLER
	var/turf/start = get_turf(source)
	var/turf/aim = get_turf(gun.target)
	if(start && aim && aim.z == start.z)
		clash_suppress_line(source, start, aim)

/datum/element/clash_suppression/proc/on_flamed(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	clash_suppress(source, CLASH_SUPPRESSION_FIRE)

#undef CLASH_SUPPRESSION_MAX
#undef CLASH_SUPPRESSION_NEAR_MISS
#undef CLASH_SUPPRESSION_HIT
#undef CLASH_SUPPRESSION_FIRE
#undef CLASH_SUPPRESSION_BLAST_MAX
#undef CLASH_SUPPRESSION_HOLD
#undef CLASH_SUPPRESSION_DECAY
#undef CLASH_SUPPRESSION_DESATURATE
#undef CLASH_SUPPRESSION_PULSE
#undef CLASH_SUPPRESSION_PULSE_LOW
#undef CLASH_SUPPRESSION_RAMP
#undef CLASH_SUPPRESSION_MISS_RADIUS
#undef CLASH_SUPPRESSION_OVERSHOOT

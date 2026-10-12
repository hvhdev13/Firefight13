GLOBAL_DATUM(clash_hit_ring_icon, /icon)
GLOBAL_LIST_INIT(clash_hit_zone_heights, list(
	"head" = 10,
	"eyes" = 10,
	"mouth" = 8,
	"chest" = 4,
	"l_arm" = 3,
	"r_arm" = 3,
	"groin" = -1,
	"l_hand" = -2,
	"r_hand" = -2,
	"l_leg" = -7,
	"r_leg" = -7,
	"l_foot" = -12,
	"r_foot" = -12,
))

/proc/get_clash_hit_ring_icon()
	if(GLOB.clash_hit_ring_icon)
		return GLOB.clash_hit_ring_icon
	var/icon/ring = icon('icons/effects/effects.dmi', "nothing")
	ring.Scale(32, 32)
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			var/distance = sqrt((x - 16.5) ** 2 + (y - 16.5) ** 2)
			var/strength = max(1 - abs(distance - 7) / 2, distance < 3 ? 1 - distance / 3 : 0)
			if(strength > 0)
				ring.DrawBox(rgb(255, 255, 255, round(255 * strength)), x, y)
	GLOB.clash_hit_ring_icon = ring
	return ring

/particles/clash_blood_spray
	icon = 'icons/effects/particles/generic_particles.dmi'
	icon_state = "drip"
	width = 96
	height = 96
	count = 60
	spawning = 0
	lifespan = 7
	fade = 3
	friction = 0.2
	gravity = list(0, -0.8)
	position = generator("circle", 0, 2)
	scale = generator("num", 0.45, 1)
	rotation = generator("num", 0, 359)

/particles/clash_blood_mist
	icon = 'icons/effects/particles/generic_particles.dmi'
	icon_state = "pixel"
	width = 96
	height = 96
	count = 80
	spawning = 0
	lifespan = 4
	fade = 3
	friction = 0.3
	gravity = list(0, -0.3)
	position = generator("circle", 0, 3)
	scale = generator("num", 1, 2)

/obj/effect/clash_hit
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_MOB_LAYER
	appearance_flags = PIXEL_SCALE|TILE_BOUND

/obj/effect/clash_hit/spray/Initialize(mapload, particle_type, blood_color, push_x, push_y, amount, speed, spread)
	. = ..()
	particles = new particle_type
	particles.color = blood_color
	particles.velocity = generator("box", list(push_x * speed - spread, push_y * speed - spread), list(push_x * speed + spread, push_y * speed + spread))
	particles.spawning = amount
	addtimer(CALLBACK(src, PROC_REF(stop_spawning)), 1)
	QDEL_IN(src, 1 SECONDS)

/obj/effect/clash_hit/spray/proc/stop_spawning()
	particles.spawning = 0

/obj/effect/clash_hit/ring/Initialize(mapload, blood_color, size)
	. = ..()
	icon = get_clash_hit_ring_icon()
	transform = matrix(0.3, 0.3, MATRIX_SCALE)
	animate(src, transform = matrix(size, size, MATRIX_SCALE), color = blood_color, alpha = 0, time = 3, easing = CUBIC_EASING|EASE_OUT)
	QDEL_IN(src, 4)

/proc/play_clash_hit_effect(mob/living/carbon/human/victim, obj/projectile/bullet, damage_result, push_x, push_y)
	var/turf/spot = get_turf(victim)
	if(!spot)
		return
	var/headshot = bullet.def_zone == "head" || bullet.def_zone == "eyes" || bullet.def_zone == "mouth"
	var/blood_color = victim.species.blood_color
	var/height = GLOB.clash_hit_zone_heights[bullet.def_zone] || 0
	if(victim.body_position == LYING_DOWN)
		height = -8
	var/jitter = rand(-3, 3)
	var/amount = clamp(round(damage_result * 0.8), 6, 28)
	if(headshot)
		amount = round(amount * 1.6)

	var/obj/effect/clash_hit/ring/ring = new(spot, blood_color, headshot ? 1.8 : 1.1)
	ring.pixel_x = jitter - push_x * 5
	ring.pixel_y = height - push_y * 5

	var/obj/effect/clash_hit/spray/droplets = new(spot, /particles/clash_blood_spray, blood_color, push_x, push_y, amount, headshot ? 6 : 4.5, 1.5)
	droplets.pixel_x = jitter + push_x * 3
	droplets.pixel_y = height + push_y * 3

	var/obj/effect/clash_hit/spray/mist = new(spot, /particles/clash_blood_mist, blood_color, push_x, push_y, amount * 2, 2.5, 2.5)
	mist.pixel_x = droplets.pixel_x
	mist.pixel_y = droplets.pixel_y

	var/obj/effect/clash_hit/spray/backspray = new(spot, /particles/clash_blood_mist, blood_color, -push_x, -push_y, round(amount * 0.5), 1.5, 1.5)
	backspray.pixel_x = ring.pixel_x
	backspray.pixel_y = ring.pixel_y

#define CLASH_HIT_MARKER_FRAMES 3
#define CLASH_HIT_MARKER_SIZE 64
#define CLASH_HIT_MARKER_MEDIUM 25
#define CLASH_HIT_MARKER_HEAVY 50
#define CLASH_MARKER_FRIENDLY 1
#define CLASH_MARKER_HIT 2
#define CLASH_MARKER_DOWN 3
#define CLASH_MARKER_KILL 4
#define CLASH_THREAT_MARKS 3
#define CLASH_THREAT_HOLD (2 DECISECONDS)
#define CLASH_THREAT_FADE (3 DECISECONDS)
#define CLASH_THREAT_GAP (1 DECISECONDS)

GLOBAL_LIST_EMPTY(clash_hit_marker_cursors)
GLOBAL_LIST_INIT(clash_hit_marker_states, list("ff", "hit", "down", "kill"))
GLOBAL_LIST_INIT(clash_hit_marker_times, list(5 DECISECONDS, 5 DECISECONDS, 7 DECISECONDS, 9 DECISECONDS))
GLOBAL_LIST_INIT(clash_hit_marker_sounds, list(null, null, 'sound/weapons/gun_xm88_directhit_high.ogg', 'sound/weapons/gun_xm88_directhit_low.ogg'))
GLOBAL_DATUM(clash_threat_icon, /icon)

/client/var/clash_marker_base
/client/var/clash_marker_shown
/client/var/clash_marker_kind = 0
/client/var/clash_marker_until = 0
/client/var/clash_marker_tick = 0
/client/var/clash_marker_shape
/client/var/clash_marker_seq = 0
/client/var/clash_marker_damage = 0
/client/var/clash_marker_tier = 1
/client/var/clash_down_sound_at = 0
/client/var/list/clash_threat_marks
/client/var/list/clash_threat_sources
/client/var/list/clash_threat_until

/proc/get_clash_hit_marker_cursor(shape, kind, frame, tier)
	var/state = "[GLOB.clash_hit_marker_states[kind]][frame]_[tier]"
	var/key = "[shape][state]"
	if(GLOB.clash_hit_marker_cursors[key])
		return GLOB.clash_hit_marker_cursors[key]
	var/icon/marker = icon(shape)
	var/pad_x = (CLASH_HIT_MARKER_SIZE - marker.Width()) * 0.5
	var/pad_y = (CLASH_HIT_MARKER_SIZE - marker.Height()) * 0.5
	marker.Crop(1 - pad_x, 1 - pad_y, marker.Width() + pad_x, marker.Height() + pad_y)
	marker.Blend(icon('icons/mob/hud/clash_hitmarker.dmi', state), ICON_OVERLAY)
	GLOB.clash_hit_marker_cursors[key] = fcopy_rsc(marker)
	return GLOB.clash_hit_marker_cursors[key]

/proc/clash_hit_marker_tier(damage)
	if(damage >= CLASH_HIT_MARKER_HEAVY)
		return 3
	if(damage >= CLASH_HIT_MARKER_MEDIUM)
		return 2
	return 1

/proc/clash_on_marker_hit(client/player, mob/living/carbon/human/victim, obj/item/weapon/gun/gun, damage, friendly)
	if(victim.stat == DEAD)
		return
	var/gun_pointer = istype(gun) ? gun.mouse_pointer : null
	if(friendly)
		clash_hit_marker(player, gun_pointer, CLASH_MARKER_FRIENDLY, damage)
		return
	clash_hit_marker(player, gun_pointer, CLASH_MARKER_HIT, damage)
	INVOKE_NEXT_TICK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_check_down_marker), player, victim, victim.health, gun_pointer)

/proc/clash_hit_marker(client/player, gun_pointer, kind, damage)
	if(!player?.prefs.custom_cursors)
		return
	var/active = world.time < player.clash_marker_until ? player.clash_marker_kind : 0
	if(world.time == player.clash_marker_tick && kind <= active)
		player.clash_marker_damage += damage
		var/tier = clash_hit_marker_tier(player.clash_marker_damage)
		if(tier > player.clash_marker_tier)
			player.clash_marker_tier = tier
			clash_hit_marker_frame(player, player.clash_marker_seq, 1)
		return
	var/current = player.mouse_pointer_icon
	if(!player.clash_marker_shown || current != player.clash_marker_shown)
		player.clash_marker_base = current
	var/shape = gun_pointer
	if(isfile(player.clash_marker_base) && length("[player.clash_marker_base]") && player.clash_marker_base != player.prefs.chosen_pointer)
		shape = player.clash_marker_base
	if(!shape)
		return
	var/duration = GLOB.clash_hit_marker_times[kind]
	if(active > kind)
		duration = max(player.clash_marker_until - world.time, duration)
		kind = active
	player.clash_marker_shape = shape
	player.clash_marker_damage = damage
	player.clash_marker_tier = clash_hit_marker_tier(damage)
	player.clash_marker_kind = kind
	player.clash_marker_tick = world.time
	player.clash_marker_until = world.time + duration
	player.clash_marker_seq++
	clash_hit_marker_frame(player, player.clash_marker_seq, 1)
	for(var/frame in 2 to CLASH_HIT_MARKER_FRAMES)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_hit_marker_frame), player, player.clash_marker_seq, frame), frame - 1)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_clear_hit_marker), player), duration)

/proc/clash_hit_marker_frame(client/player, seq, frame)
	if(player?.clash_marker_seq != seq || (frame > 1 && player.mouse_pointer_icon != player.clash_marker_shown))
		return
	player.clash_marker_shown = get_clash_hit_marker_cursor(player.clash_marker_shape, player.clash_marker_kind, frame, player.clash_marker_tier)
	player.mouse_pointer_icon = player.clash_marker_shown

/proc/clash_check_down_marker(client/player, mob/living/carbon/human/victim, health_before, gun_pointer)
	if(!player)
		return
	var/kind
	if(health_before > victim.health_threshold_dead && victim.stat == DEAD)
		kind = CLASH_MARKER_KILL
	else if(health_before >= victim.health_threshold_crit && victim.health < victim.health_threshold_crit)
		kind = CLASH_MARKER_DOWN
	else
		return
	if(world.time != player.clash_down_sound_at)
		player.clash_down_sound_at = world.time
		playsound_client(player, GLOB.clash_hit_marker_sounds[kind], null, 50)
	clash_hit_marker(player, gun_pointer, kind, health_before - victim.health)

/proc/clash_clear_hit_marker(client/player)
	if(!player?.clash_marker_shown || world.time < player.clash_marker_until)
		return
	if(player.mouse_pointer_icon == player.clash_marker_shown)
		player.mouse_pointer_icon = player.clash_marker_base
	player.clash_marker_shown = null
	player.clash_marker_kind = 0

/proc/clash_show_threat(mob/living/carbon/human/victim, source_ref, turf/origin)
	var/client/player = victim.client
	var/turf/victim_turf = get_turf(victim)
	if(!player || !origin || !victim_turf || origin.z != victim_turf.z || origin == victim_turf)
		return
	if(!player.clash_threat_marks)
		player.clash_threat_marks = list()
		player.clash_threat_sources = list()
		player.clash_threat_until = list()
	var/slot = player.clash_threat_sources.Find(source_ref)
	var/image/mark
	if(slot)
		if(world.time < player.clash_threat_until[slot] - CLASH_THREAT_HOLD - CLASH_THREAT_FADE + CLASH_THREAT_GAP)
			return
		mark = player.clash_threat_marks[slot]
	else if(length(player.clash_threat_marks) < CLASH_THREAT_MARKS)
		if(!GLOB.clash_threat_icon)
			GLOB.clash_threat_icon = icon('icons/effects/Targeted.dmi', "sniper_lockon_direction", NORTH)
		mark = image(GLOB.clash_threat_icon)
		mark.plane = ABOVE_LIGHTING_PLANE
		mark.appearance_flags = RESET_COLOR|RESET_TRANSFORM|RESET_ALPHA|KEEP_APART
	else
		slot = CLASH_THREAT_MARKS
		mark = player.clash_threat_marks[slot]
	if(slot)
		player.clash_threat_marks.Cut(slot, slot + 1)
		player.clash_threat_sources.Cut(slot, slot + 1)
		player.clash_threat_until.Cut(slot, slot + 1)
	player.clash_threat_marks.Insert(1, mark)
	player.clash_threat_sources.Insert(1, source_ref)
	player.clash_threat_until.Insert(1, world.time + CLASH_THREAT_HOLD + CLASH_THREAT_FADE)
	mark.loc = victim
	if(!(mark in player.images))
		player.images += mark
	var/matrix/placement = matrix()
	placement.Translate(0, 8)
	placement.Turn(get_clash_turn_sign() * Get_Angle(victim_turf, origin))
	animate(mark)
	mark.transform = placement
	mark.alpha = 255
	animate(mark, alpha = 255, time = CLASH_THREAT_HOLD)
	animate(alpha = 0, time = CLASH_THREAT_FADE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clash_drop_threat), player, mark), CLASH_THREAT_HOLD + CLASH_THREAT_FADE)

/proc/clash_drop_threat(client/player, image/mark)
	if(!player)
		return
	var/slot = player.clash_threat_marks.Find(mark)
	if(slot && world.time >= player.clash_threat_until[slot])
		mark.loc = null

#undef CLASH_HIT_MARKER_FRAMES
#undef CLASH_HIT_MARKER_SIZE
#undef CLASH_HIT_MARKER_MEDIUM
#undef CLASH_HIT_MARKER_HEAVY
#undef CLASH_MARKER_FRIENDLY
#undef CLASH_MARKER_HIT
#undef CLASH_MARKER_DOWN
#undef CLASH_MARKER_KILL
#undef CLASH_THREAT_MARKS
#undef CLASH_THREAT_HOLD
#undef CLASH_THREAT_FADE
#undef CLASH_THREAT_GAP

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

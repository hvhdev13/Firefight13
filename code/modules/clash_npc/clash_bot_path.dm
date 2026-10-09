#define CLASH_BOT_PATH_BUDGET 1200

/proc/clash_heap_push(list/heap, score, turf/item)
	heap += list(list(score, item))
	var/index = length(heap)
	while(index > 1)
		var/parent = floor(index / 2)
		var/list/parent_entry = heap[parent]
		var/list/entry = heap[index]
		if(parent_entry[1] <= entry[1])
			return
		heap.Swap(parent, index)
		index = parent

/proc/clash_heap_pop(list/heap)
	var/list/top = heap[1]
	heap[1] = heap[length(heap)]
	heap.len--
	var/size = length(heap)
	if(!size)
		return top[2]
	var/index = 1
	while(TRUE)
		var/smallest = index
		var/list/smallest_entry = heap[smallest]
		var/left = index * 2
		if(left <= size)
			var/list/left_entry = heap[left]
			if(left_entry[1] < smallest_entry[1])
				smallest = left
				smallest_entry = left_entry
		if(left + 1 <= size)
			var/list/right_entry = heap[left + 1]
			if(right_entry[1] < smallest_entry[1])
				smallest = left + 1
		if(smallest == index)
			return top[2]
		heap.Swap(index, smallest)
		index = smallest

/datum/clash_bot/proc/can_enter(turf/spot)
	if(istype(spot, /turf/open/clash_void))
		return FALSE
	var/area/clash_arena/zone = get_area(spot)
	if(!istype(zone) || !zone.clash_faction)
		return TRUE
	return zone.clash_faction == body.faction && !carrying()

/datum/clash_bot/proc/border_blocked(turf/from, turf/into, direction)
	for(var/obj/structure/thing in from)
		if((thing.flags_atom & ON_BORDER) && !istype(thing, /obj/structure/machinery/door) && thing.BlockedExitDirs(body, direction))
			return TRUE
	for(var/obj/structure/thing in into)
		if((thing.flags_atom & ON_BORDER) && !istype(thing, /obj/structure/machinery/door) && thing.BlockedPassDirs(body, direction))
			return TRUE
	return FALSE

/datum/clash_bot/var/obj/item/card/id/path_card

/datum/clash_bot/proc/step_open(turf/from, turf/into, direction)
	if(!into || into.density || !can_enter(into))
		return FALSE
	if(LinkBlockedWithAccess(from, into, path_card) || border_blocked(from, into, direction))
		return FALSE
	return !(locate(/obj/flamer_fire) in into)

/datum/clash_bot/proc/find_path(turf/goal)
	var/turf/start = get_turf(body)
	if(!start || !goal || start == goal)
		return list()
	path_card = body.get_idcard()
	var/list/heap = list()
	var/list/cost = list()
	var/list/came_from = list()
	var/list/closed = list()
	var/turf/closest = start
	var/closest_distance = get_dist(start, goal)
	cost[start] = 0
	clash_heap_push(heap, closest_distance, start)
	var/expanded = 0
	while(length(heap) && expanded < CLASH_BOT_PATH_BUDGET)
		var/turf/current = clash_heap_pop(heap)
		if(closed[current])
			continue
		if(current == goal)
			closest = goal
			break
		closed[current] = TRUE
		expanded++
		var/remaining = get_dist(current, goal)
		if(remaining < closest_distance)
			closest = current
			closest_distance = remaining
		for(var/direction in GLOB.alldirs)
			var/turf/next = get_step(current, direction)
			if(!next || closed[next])
				continue
			var/step_cost = 1
			if(direction in GLOB.cardinals)
				if(!step_open(current, next, direction))
					continue
			else
				var/vertical = direction & (NORTH|SOUTH)
				var/horizontal = direction & (EAST|WEST)
				var/turf/side_one = get_step(current, vertical)
				var/turf/side_two = get_step(current, horizontal)
				if(!step_open(current, side_one, vertical) || !step_open(side_one, next, horizontal) || !step_open(current, side_two, horizontal) || !step_open(side_two, next, vertical))
					continue
				step_cost = 1.4
			var/next_cost = cost[current] + step_cost + danger_cost(next)
			if(!isnull(cost[next]) && next_cost >= cost[next])
				continue
			cost[next] = next_cost
			came_from[next] = current
			clash_heap_push(heap, next_cost + get_dist(next, goal), next)
	var/list/path = list()
	var/turf/backtrack = closest
	while(backtrack && backtrack != start)
		path.Insert(1, backtrack)
		backtrack = came_from[backtrack]
	return path

#undef CLASH_BOT_PATH_BUDGET

/// Tiles a single path search may expand before settling for the closest point it reached
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
	var/area/clash_arena/zone = get_area(spot)
	return !(istype(zone) && zone.clash_faction && zone.clash_faction != body.faction)

/// Returns the steps toward goal, or toward the closest reachable tile when the search runs out of budget
/datum/clash_bot/proc/find_path(turf/goal)
	var/turf/start = get_turf(body)
	if(!start || !goal || start == goal)
		return list()
	var/obj/item/card/id/id_card = body.get_idcard()
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
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || next.density || closed[next] || !can_enter(next))
				continue
			if(LinkBlockedWithAccess(current, next, id_card))
				continue
			if(locate(/obj/flamer_fire) in next)
				continue
			var/next_cost = cost[current] + 1
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

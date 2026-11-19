class_name ScheduleEngine
extends RefCounted

## Schedule parsing and timeline point resolution for ReSDV NPCs.
## Parses authentic Stardew Valley schedule strings into structured navigation waypoints.

const SCHEDULE_DATA_DIR: String = "user://vanilla_data/Characters/schedules/"

# SDV direction integer to Vector2i map: 0 = UP, 1 = RIGHT, 2 = DOWN, 3 = LEFT
const DIRECTION_MAP: Dictionary[int, Vector2i] = {
	0: Vector2i.UP,
	1: Vector2i.RIGHT,
	2: Vector2i.DOWN,
	3: Vector2i.LEFT,
}

var _schedule_cache: Dictionary[StringName, Dictionary] = {}


func load_npc_schedule(npc_name: StringName) -> Dictionary:
	if _schedule_cache.has(npc_name):
		return _schedule_cache[npc_name]

	var file_path: String = SCHEDULE_DATA_DIR.path_join("%s.json" % String(npc_name))
	if not FileAccess.file_exists(file_path):
		push_warning("[ScheduleEngine] Schedule file not found: %s" % file_path)
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.ModeFlags.READ)
	if file == null:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK or not (json.data is Dictionary):
		push_error("[ScheduleEngine] Failed to parse JSON in %s" % file_path)
		return {}

	var dict: Dictionary = json.data as Dictionary
	_schedule_cache[npc_name] = dict
	return dict


func parse_schedule_string(schedule_str: String) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	if schedule_str.is_empty():
		return points

	# Handle GOTO statements (e.g. "GOTO 6" or "GOTO spring")
	var entries: PackedStringArray = schedule_str.split("/", false)
	for entry: String in entries:
		var tokens: PackedStringArray = entry.strip_edges().split(" ", false)
		if tokens.size() < 4:
			continue

		var time_val: int = tokens[0].to_int()
		var loc_name: StringName = StringName(tokens[1])
		var cell_x: int = tokens[2].to_int()
		var cell_y: int = tokens[3].to_int()
		var dir_val: int = 2
		var anim_name: String = ""

		if tokens.size() >= 5:
			if tokens[4].is_valid_int():
				dir_val = tokens[4].to_int()
			else:
				anim_name = tokens[4]

		if tokens.size() >= 6:
			anim_name = tokens[5].replace('"', '')

		points.append({
			"time": time_val,
			"location": loc_name,
			"cell": Vector2i(cell_x, cell_y),
			"direction": dir_val,
			"facing": DIRECTION_MAP.get(dir_val, Vector2i.DOWN),
			"animation": anim_name,
		})

	# Sort by time ascending
	points.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["time"] < b["time"]
	)

	return points


func get_active_schedule_point(npc_name: StringName, current_time: int, day_of_week: String = "Mon", season: String = "spring", is_raining: bool = false) -> Dictionary:
	var dict: Dictionary = load_npc_schedule(npc_name)
	if dict.is_empty():
		return {}

	var sched_str: String = ""

	# Check priorities: rain -> day of week -> season -> default
	if is_raining and dict.has("rain"):
		sched_str = String(dict["rain"])
	elif dict.has(day_of_week):
		sched_str = String(dict[day_of_week])
	elif dict.has(season):
		sched_str = String(dict[season])
	elif dict.has("spring"):
		sched_str = String(dict["spring"])
	else:
		for k in dict.keys():
			var val: String = String(dict[k])
			if not val.begins_with("GOTO") and val.contains("/"):
				sched_str = val
				break

	if sched_str.is_empty():
		return {}

	var points: Array[Dictionary] = parse_schedule_string(sched_str)
	if points.is_empty():
		return {}

	# Find latest point where time <= current_time
	var active_pt: Dictionary = points[0]
	for pt: Dictionary in points:
		if pt["time"] <= current_time:
			active_pt = pt
		else:
			break

	return active_pt

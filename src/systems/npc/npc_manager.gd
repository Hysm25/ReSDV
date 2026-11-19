class_name NPCManager
extends Node2D

## Central NPC coordinator for ReSDV.
## Manages NPC lifecycle, schedule evaluations on time ticks, cross-location visibility,
## and player conversations.

@export var current_location_id: StringName = &"Farm"
@export var dialogue_ui: DialogueBoxUI = null

var dialogue_engine: DialogueEngine = null
var schedule_engine: ScheduleEngine = null

# Registered NPCs keyed by npc_name
var _npcs: Dictionary[StringName, NPC] = {}


func _ready() -> void:
	dialogue_engine = DialogueEngine.new()
	schedule_engine = ScheduleEngine.new()

	_connect_event_bus()
	_adopt_existing_npcs()


func _connect_event_bus() -> void:
	if not is_instance_valid(EventBus):
		return

	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_started.connect(_on_day_started)
	EventBus.location_changed.connect(_on_location_changed)


func _adopt_existing_npcs() -> void:
	for child in get_children():
		if child is NPC:
			register_npc(child as NPC)


func register_npc(npc: NPC) -> void:
	if npc == null:
		return
	_npcs[npc.npc_name] = npc
	if npc.get_parent() != self:
		add_child(npc)
	_update_npc_visibility(npc)


func spawn_npc(npc_name: StringName, start_cell: Vector2i, location_id: StringName = &"Farm") -> NPC:
	if _npcs.has(npc_name):
		return _npcs[npc_name]

	var npc: NPC = NPC.new(npc_name, start_cell, location_id)
	register_npc(npc)
	print("[NPCManager] Spawned NPC '%s' at %s in %s" % [String(npc_name), str(start_cell), location_id])
	return npc


func get_npc(npc_name: StringName) -> NPC:
	return _npcs.get(npc_name, null)


func has_npc_at(loc: StringName, cell: Vector2i) -> bool:
	return get_npc_at(loc, cell) != null


func get_npc_at(loc: StringName, cell: Vector2i) -> NPC:
	for npc: NPC in _npcs.values():
		if is_instance_valid(npc) and npc.current_location_id == loc and npc.cell == cell:
			return npc
	return null


func interact_with_npc_at(loc: StringName, cell: Vector2i, player: Player) -> bool:
	var npc: NPC = get_npc_at(loc, cell)
	if npc == null:
		return false

	if dialogue_ui != null and dialogue_engine != null:
		npc.interact_with_player(player, dialogue_ui, dialogue_engine)
		return true
	return false


func _on_time_ticked(time_of_day: int) -> void:
	if schedule_engine == null:
		return

	for npc: NPC in _npcs.values():
		if not is_instance_valid(npc):
			continue

		var point: Dictionary = schedule_engine.get_active_schedule_point(npc.npc_name, time_of_day)
		if point.is_empty():
			continue

		var target_loc: StringName = point.get("location", npc.current_location_id)
		var target_cell: Vector2i = point.get("cell", npc.cell)
		var target_dir: Vector2i = point.get("facing", Vector2i.DOWN)

		# If destination is in the same location, walk there
		if target_loc == npc.current_location_id:
			if target_cell != npc.cell and not npc.is_moving:
				npc.walk_to_cell(target_cell)
			elif not npc.is_moving:
				npc.set_facing_direction(target_dir)
		else:
			# Location change for NPC
			npc.current_location_id = target_loc
			npc.cell = target_cell
			npc.position = Vector2(target_cell.x * NPC.TILE_SIZE.x + 8, target_cell.y * NPC.TILE_SIZE.y + 8)
			npc.set_facing_direction(target_dir)
			_update_npc_visibility(npc)

		if is_instance_valid(EventBus):
			EventBus.npc_moved.emit(npc.npc_name, npc.current_location_id, npc.cell)


func _on_day_started(_day: int, _season: String, _year: int) -> void:
	for npc: NPC in _npcs.values():
		if is_instance_valid(npc):
			npc.has_talked_today = false


func _on_location_changed(_from_map: StringName, to_map: StringName, _target_cell: Vector2i) -> void:
	current_location_id = to_map
	for npc: NPC in _npcs.values():
		if is_instance_valid(npc):
			_update_npc_visibility(npc)


func _update_npc_visibility(npc: NPC) -> void:
	var is_active: bool = (npc.current_location_id == current_location_id)
	npc.visible = is_active
	npc.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

class_name Player
extends CharacterBody2D

## Playable farmer entity for ReSDV.
## Handles 8-directional movement, grid targeting, tool usage, and basic inventory.

enum ToolType {
	HOE = 0,
	WATERING_CAN = 1,
	PARSNIP_SEEDS = 2,
	HAND = 3,
}

const MOVE_SPEED: float = 110.0

@export var farm_grid: FarmGrid = null
@export var crop_manager: CropManager = null
@export var map_loader: MapLoader = null
@export var location_manager: LocationManager = null
@export var default_spawn_cell: Vector2i = Vector2i(64, 15)

var active_tool: ToolType = ToolType.HOE
var facing_direction: Vector2i = Vector2i.DOWN
var target_cell: Vector2i = Vector2i.ZERO

# Basic Inventory
var parsnip_seeds_count: int = 15
var harvest_bag: Dictionary[StringName, int] = {}

func _ready() -> void:
	if location_manager != null:
		location_manager.player = self
		# If location_manager already initialized, align with it
		var cur_loader: MapLoader = location_manager.get_current_map_loader()
		if cur_loader != null:
			map_loader = cur_loader
			_apply_map_setup()
	elif map_loader != null:
		if map_loader.map_size != Vector2i.ZERO:
			_apply_map_setup()
		else:
			map_loader.map_loaded.connect(func(_id: String) -> void: _apply_map_setup())
	elif farm_grid != null:
		global_position = farm_grid.cell_to_center_world(Vector2i(farm_grid.grid_width / 2, farm_grid.grid_height / 2))
	queue_redraw()

func _apply_map_setup() -> void:
	var active_loader: MapLoader = location_manager.get_current_map_loader() if location_manager != null else map_loader
	if active_loader == null:
		return
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		for child: Node in get_children():
			if child is Camera2D:
				cam = child as Camera2D
				break
	if cam != null and active_loader.map_size != Vector2i.ZERO:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = active_loader.map_size.x * active_loader.tile_size.x
		cam.limit_bottom = active_loader.map_size.y * active_loader.tile_size.y

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_update_target_cell()
	_check_warps()

func _check_warps() -> void:
	if location_manager == null:
		return
	var active_loader: MapLoader = location_manager.get_current_map_loader()
	if active_loader == null:
		return
	var cur_cell: Vector2i = active_loader.world_to_cell(global_position)
	var is_moving: bool = velocity.length_squared() > 1.0
	location_manager.check_and_trigger_warp(cur_cell, facing_direction if is_moving else Vector2i.ZERO)

func _update_target_cell() -> void:
	var active_loader: MapLoader = location_manager.get_current_map_loader() if location_manager != null else map_loader
	var current_cell: Vector2i = Vector2i.ZERO
	if active_loader != null:
		current_cell = active_loader.world_to_cell(global_position)
	elif farm_grid != null:
		current_cell = farm_grid.world_to_cell(global_position)

	target_cell = current_cell + facing_direction
	if farm_grid != null and farm_grid.visible:
		farm_grid.set_highlight_cell(target_cell)

func _unhandled_input(event: InputEvent) -> void:
	# Tool selection via 1-4 keys
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				_set_tool(ToolType.HOE)
			KEY_2:
				_set_tool(ToolType.WATERING_CAN)
			KEY_3:
				_set_tool(ToolType.PARSNIP_SEEDS)
			KEY_4:
				_set_tool(ToolType.HAND)

	# Action trigger via Space, Enter, or Mouse Click
	if event.is_action_pressed(&"ui_accept") or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_SPACE):
		use_active_tool()
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		use_active_tool()

func _handle_movement() -> void:
	var input_vec: Vector2 = Vector2.ZERO

	# Support both standard actions and direct key fallbacks
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0

	if input_vec != Vector2.ZERO:
		input_vec = input_vec.normalized()
		velocity = input_vec * MOVE_SPEED

		# Update cardinal facing direction
		if absf(input_vec.x) > absf(input_vec.y):
			facing_direction = Vector2i.RIGHT if input_vec.x > 0 else Vector2i.LEFT
		else:
			facing_direction = Vector2i.DOWN if input_vec.y > 0 else Vector2i.UP
		queue_redraw()
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _set_tool(tool_type: ToolType) -> void:
	active_tool = tool_type
	var tool_name: String = get_active_tool_name()
	print("[Player] Selected Tool: %s" % tool_name)
	EventBus.item_selected.emit(int(active_tool), StringName(tool_name))
	queue_redraw()

func get_active_tool_name() -> String:
	match active_tool:
		ToolType.HOE:
			return "Hoe"
		ToolType.WATERING_CAN:
			return "Watering Can"
		ToolType.PARSNIP_SEEDS:
			return "Parsnip Seeds (%d)" % parsnip_seeds_count
		ToolType.HAND:
			return "Hand / Harvest"
	return "None"

func use_active_tool() -> bool:
	if farm_grid == null or not farm_grid.visible:
		return false
	if location_manager != null and location_manager.current_location_id != &"Farm":
		return false

	var cell: Vector2i = target_cell

	# Check for mature harvest first
	if crop_manager != null and crop_manager.is_mature(cell):
		var harvest_res: Dictionary = crop_manager.harvest_crop(cell)
		if harvest_res.get("success", false):
			var item_id: StringName = harvest_res["yield_item_id"]
			var count: int = harvest_res["count"]
			harvest_bag[item_id] = harvest_bag.get(item_id, 0) + count
			print("[Player] Harvested: %s x%d! Total in bag: %d" % [item_id, count, harvest_bag[item_id]])
			return true

	match active_tool:
		ToolType.HOE:
			if farm_grid.till_soil(cell):
				print("[Player] Tilled soil at %s" % str(cell))
				return true
		ToolType.WATERING_CAN:
			if farm_grid.water_soil(cell):
				print("[Player] Watered soil at %s" % str(cell))
				return true
		ToolType.PARSNIP_SEEDS:
			if parsnip_seeds_count <= 0:
				print("[Player] Out of Parsnip Seeds!")
				return false
			if crop_manager != null and crop_manager.plant_seed(cell, &"472"):
				parsnip_seeds_count -= 1
				print("[Player] Planted Parsnip Seed at %s (Remaining: %d)" % [str(cell), parsnip_seeds_count])
				return true
		ToolType.HAND:
			# If not mature, nothing to harvest
			pass

	return false

func _draw() -> void:
	# Draw player avatar (procedural clean farmer body)
	# Body
	draw_circle(Vector2(0, 0), 7.0, Color(0.2, 0.4, 0.8)) # Blue shirt
	# Head
	draw_circle(Vector2(0, -7), 5.0, Color(0.95, 0.8, 0.65)) # Skin
	# Hat
	draw_circle(Vector2(0, -9), 5.5, Color(0.85, 0.7, 0.2)) # Straw hat

	# Facing pointer
	var pointer_offset: Vector2 = Vector2(facing_direction.x * 9.0, facing_direction.y * 9.0)
	draw_circle(pointer_offset, 2.0, Color(1.0, 0.9, 0.3))

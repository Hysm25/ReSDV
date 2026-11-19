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
const EXHAUSTED_SPEED: float = 55.0
const TOOL_ANIM_DURATION: float = 0.22

@export var farm_grid: FarmGrid = null
@export var crop_manager: CropManager = null
@export var map_loader: MapLoader = null
@export var location_manager: LocationManager = null
@export var inventory_manager: InventoryManager = null
@export var energy_manager: EnergyManager = null
@export var default_spawn_cell: Vector2i = Vector2i(64, 15)

var active_tool: ToolType = ToolType.HOE
var facing_direction: Vector2i = Vector2i.DOWN
var target_cell: Vector2i = Vector2i.ZERO

# Tool animation state
var is_using_tool: bool = false
var tool_anim_timer: float = 0.0
var animated_tool_id: StringName = &""

# Basic Inventory
var parsnip_seeds_count: int = 15
var harvest_bag: Dictionary[StringName, int] = {}

func _ready() -> void:
	if energy_manager == null:
		# Auto-discover EnergyManager sibling or child
		var parent_node: Node = get_parent()
		if parent_node != null:
			energy_manager = parent_node.get_node_or_null("EnergyManager") as EnergyManager
		if energy_manager == null:
			energy_manager = get_node_or_null("EnergyManager") as EnergyManager
	
	if energy_manager != null:
		energy_manager.exhaustion_changed.connect(func(_ex: bool) -> void: queue_redraw())

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

func _physics_process(delta: float) -> void:
	if is_using_tool:
		tool_anim_timer += delta
		velocity = Vector2.ZERO
		queue_redraw()
		if tool_anim_timer >= TOOL_ANIM_DURATION:
			is_using_tool = false
			tool_anim_timer = 0.0
			queue_redraw()
		return

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
	# Inventory slot selection
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if inventory_manager != null:
			match event.keycode:
				KEY_1: inventory_manager.select_slot(0)
				KEY_2: inventory_manager.select_slot(1)
				KEY_3: inventory_manager.select_slot(2)
				KEY_4: inventory_manager.select_slot(3)
				KEY_5: inventory_manager.select_slot(4)
				KEY_6: inventory_manager.select_slot(5)
				KEY_7: inventory_manager.select_slot(6)
				KEY_8: inventory_manager.select_slot(7)
				KEY_9: inventory_manager.select_slot(8)
				KEY_0: inventory_manager.select_slot(9)
				KEY_MINUS: inventory_manager.select_slot(10)
				KEY_EQUAL: inventory_manager.select_slot(11)
		else:
			match event.keycode:
				KEY_1: _set_tool(ToolType.HOE)
				KEY_2: _set_tool(ToolType.WATERING_CAN)
				KEY_3: _set_tool(ToolType.PARSNIP_SEEDS)
				KEY_4: _set_tool(ToolType.HAND)

	# Action trigger via Space, Enter, or Mouse Click
	if event.is_action_pressed(&"ui_accept") or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_SPACE):
		use_active_tool()
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		use_active_tool()
	# Eat food trigger via E or Right Click
	elif (event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_E) \
		or (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT):
		try_eat_selected_item()

func get_effective_move_speed() -> float:
	if energy_manager != null and energy_manager.is_exhausted:
		return EXHAUSTED_SPEED
	return MOVE_SPEED

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
		velocity = input_vec * get_effective_move_speed()

		# Update cardinal facing direction
		if absf(input_vec.x) > absf(input_vec.y):
			facing_direction = Vector2i.RIGHT if input_vec.x > 0 else Vector2i.LEFT
		else:
			facing_direction = Vector2i.DOWN if input_vec.y > 0 else Vector2i.UP
		queue_redraw()
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _start_tool_animation(tool_id: StringName) -> void:
	is_using_tool = true
	tool_anim_timer = 0.0
	animated_tool_id = tool_id
	queue_redraw()

func try_eat_selected_item() -> bool:
	if inventory_manager == null:
		return false
	var slot: InventorySlot = inventory_manager.get_selected_slot()
	if slot == null or slot.is_empty():
		return false
	var item_id: StringName = slot.item_id
	var item_data: ItemData = ContentRegistry.get_item(item_id)
	if item_data != null and item_data.is_edible():
		if energy_manager != null and energy_manager.eat_item(item_id):
			inventory_manager.remove_item_at(inventory_manager.selected_slot_index, 1)
			print("[Player] Ate %s! Energy restored." % item_data.name)
			return true
	return false

func _set_tool(tool_type: ToolType) -> void:
	active_tool = tool_type
	var tool_name: String = get_active_tool_name()
	print("[Player] Selected Tool: %s" % tool_name)
	EventBus.item_selected.emit(int(active_tool), StringName(tool_name))
	queue_redraw()

func get_active_tool_name() -> String:
	if inventory_manager != null:
		var slot: InventorySlot = inventory_manager.get_selected_slot()
		if slot == null or slot.is_empty():
			return "Empty Hand"
		var item_data: ItemData = slot.get_item_data()
		var item_name: String = item_data.name if item_data != null else String(slot.item_id)
		if slot.count > 1:
			return "%s (%d)" % [item_name, slot.count]
		return item_name

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
	if energy_manager != null and not energy_manager.can_use_tool():
		print("[Player] Cannot use tool: completely exhausted / passed out!")
		return false

	var cell: Vector2i = target_cell

	# 1. Check for mature harvest first
	if crop_manager != null and crop_manager.is_mature(cell):
		var harvest_res: Dictionary = crop_manager.harvest_crop(cell)
		if harvest_res.get("success", false):
			var item_id: StringName = harvest_res["yield_item_id"]
			var count: int = harvest_res["count"]
			harvest_bag[item_id] = harvest_bag.get(item_id, 0) + count
			print("[Player] Harvested: %s x%d! Total in bag: %d" % [item_id, count, harvest_bag[item_id]])
			return true

	# 2. Use item from inventory if available
	if inventory_manager != null:
		var slot: InventorySlot = inventory_manager.get_selected_slot()
		if slot == null or slot.is_empty():
			return false

		var item_id: StringName = slot.item_id
		if item_id == &"vanilla:hoe":
			if farm_grid.till_soil(cell):
				if energy_manager != null:
					energy_manager.consume_tool_energy(item_id)
				_start_tool_animation(item_id)
				print("[Player] Tilled soil at %s" % str(cell))
				return true
		elif item_id == &"vanilla:watering_can":
			if farm_grid.water_soil(cell):
				if energy_manager != null:
					energy_manager.consume_tool_energy(item_id)
				_start_tool_animation(item_id)
				print("[Player] Watered soil at %s" % str(cell))
				return true
		elif item_id == &"vanilla:axe" or item_id == &"vanilla:pickaxe" or item_id == &"vanilla:scythe":
			if energy_manager != null:
				energy_manager.consume_tool_energy(item_id)
			_start_tool_animation(item_id)
			print("[Player] Swung %s at %s" % [item_id, str(cell)])
			return true
		else:
			# Check if selected item is a plantable crop seed
			var seed_key: StringName = item_id
			if String(seed_key).begins_with("vanilla:"):
				seed_key = StringName(String(seed_key).substr(8))
			if ContentRegistry.has_crop(seed_key) or ContentRegistry.has_crop(item_id):
				if crop_manager != null and crop_manager.plant_seed(cell, seed_key):
					inventory_manager.remove_item_at(inventory_manager.selected_slot_index, 1)
					print("[Player] Planted %s at %s" % [item_id, str(cell)])
					return true
		return false

	# 3. Fallback to legacy active_tool enum
	match active_tool:
		ToolType.HOE:
			if farm_grid.till_soil(cell):
				if energy_manager != null:
					energy_manager.consume_tool_energy(&"vanilla:hoe")
				_start_tool_animation(&"vanilla:hoe")
				print("[Player] Tilled soil at %s" % str(cell))
				return true
		ToolType.WATERING_CAN:
			if farm_grid.water_soil(cell):
				if energy_manager != null:
					energy_manager.consume_tool_energy(&"vanilla:watering_can")
				_start_tool_animation(&"vanilla:watering_can")
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
			pass

	return false

func _draw() -> void:
	var progress: float = clampf(tool_anim_timer / TOOL_ANIM_DURATION, 0.0, 1.0) if is_using_tool else 0.0
	var lean_offset: Vector2 = Vector2.ZERO
	if is_using_tool:
		var swing_progress: float = sin(progress * PI)
		lean_offset = Vector2(facing_direction.x, facing_direction.y) * (swing_progress * 3.5)

	# Draw player avatar (procedural clean farmer body)
	# Body
	draw_circle(lean_offset + Vector2(0, 0), 7.0, Color(0.2, 0.4, 0.8)) # Blue shirt
	# Head
	draw_circle(lean_offset + Vector2(0, -7), 5.0, Color(0.95, 0.8, 0.65)) # Skin
	# Hat
	draw_circle(lean_offset + Vector2(0, -9), 5.5, Color(0.85, 0.7, 0.2)) # Straw hat

	# Facing pointer
	var pointer_offset: Vector2 = lean_offset + Vector2(facing_direction.x * 9.0, facing_direction.y * 9.0)
	draw_circle(pointer_offset, 2.0, Color(1.0, 0.9, 0.3))

	# Exhaustion sweat drops
	if energy_manager != null and energy_manager.is_exhausted:
		var sweat_color: Color = Color(0.35, 0.7, 1.0, 0.85)
		draw_circle(lean_offset + Vector2(7, -10), 1.8, sweat_color)
		draw_circle(lean_offset + Vector2(-7, -9), 1.5, sweat_color)

	# Tool swing animation
	if is_using_tool:
		_draw_tool_swing(progress, lean_offset)

func _draw_tool_swing(progress: float, lean_offset: Vector2) -> void:
	var swing_intensity: float = sin(progress * PI)
	var reach: float = 8.0 + swing_intensity * 8.0
	var tool_pos: Vector2 = lean_offset + Vector2(facing_direction.x * reach, facing_direction.y * reach)

	# Draw swing swoosh arc
	var arc_color: Color = Color(1.0, 1.0, 1.0, 0.4 * (1.0 - progress))
	draw_arc(lean_offset + Vector2(facing_direction.x * (reach * 0.5), facing_direction.y * (reach * 0.5)), 7.0, 0.0, TAU, 10, arc_color, 1.5)

	# Tool icon or procedural tool
	var icon: AtlasTexture = ContentRegistry.get_item_icon(animated_tool_id)
	if icon != null:
		draw_texture(icon, tool_pos - Vector2(8, 8))
	else:
		var handle_color: Color = Color(0.55, 0.35, 0.15)
		var head_color: Color = Color(0.75, 0.75, 0.8)
		if animated_tool_id.contains("water"):
			head_color = Color(0.2, 0.6, 0.9)
		draw_line(lean_offset, tool_pos, handle_color, 2.0)
		draw_circle(tool_pos, 3.0, head_color)

	# Action particle: water drop or dirt particle
	if animated_tool_id.contains("water"):
		var drop_pos: Vector2 = tool_pos + Vector2(0, 4.0 * swing_intensity)
		draw_circle(drop_pos, 2.0, Color(0.2, 0.5, 0.9, 0.8))
	elif animated_tool_id.contains("hoe"):
		var dirt_pos: Vector2 = tool_pos + Vector2(2.0 * swing_intensity, 2.0)
		draw_circle(dirt_pos, 2.0, Color(0.45, 0.3, 0.15, 0.8))

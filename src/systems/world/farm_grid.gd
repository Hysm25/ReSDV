class_name FarmGrid
extends Node2D

## Manages farm terrain grid and soil states (untilled, tilled, watered).
## Works at standard Stardew Valley 16x16 pixel tile resolution.

enum SoilState {
	UNTILLED = 0,
	TILLED = 1,
	WATERED = 2,
}

const TILE_SIZE: int = 16

@export var grid_width: int = 32
@export var grid_height: int = 24
@export var map_loader: MapLoader = null
@export var debris_manager: DebrisManager = null
@export var draw_procedural_background: bool = true

# Colors for procedural soil representation
const COLOR_GRASS: Color = Color(0.32, 0.58, 0.28)
const COLOR_GRASS_ALT: Color = Color(0.29, 0.54, 0.25)
const COLOR_TILLED_DRY: Color = Color(0.52, 0.36, 0.22)
const COLOR_TILLED_BORDER: Color = Color(0.42, 0.28, 0.16)
const COLOR_WATERED_WET: Color = Color(0.34, 0.22, 0.13)
const COLOR_WATERED_BORDER: Color = Color(0.25, 0.15, 0.08)

var _soil_states: Dictionary[Vector2i, SoilState] = {}
var highlight_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	if map_loader != null:
		_sync_with_map_loader()
		if not map_loader.map_loaded.is_connected(_on_map_loaded):
			map_loader.map_loaded.connect(_on_map_loaded)
	queue_redraw()

func _sync_with_map_loader() -> void:
	if map_loader == null:
		return
	if map_loader.map_size != Vector2i.ZERO:
		grid_width = map_loader.map_size.x
		grid_height = map_loader.map_size.y
		draw_procedural_background = false
		queue_redraw()

func _on_map_loaded(_loaded_map_id: String) -> void:
	_sync_with_map_loader()

func _draw() -> void:
	# 1. Draw base farm grass terrain (only when no map loader is active)
	if draw_procedural_background:
		for y: int in range(grid_height):
			for x: int in range(grid_width):
				var rect: Rect2 = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				var base_color: Color = COLOR_GRASS if ((x + y) % 2 == 0) else COLOR_GRASS_ALT
				draw_rect(rect, base_color)

	# 2. Draw tilled and watered soil tiles
	for cell: Vector2i in _soil_states.keys():
		var state: SoilState = _soil_states[cell]
		if state == SoilState.UNTILLED:
			continue

		var rect: Rect2 = Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		if state == SoilState.TILLED:
			draw_rect(rect, COLOR_TILLED_DRY)
			draw_rect(rect, COLOR_TILLED_BORDER, false, 1.0)
		elif state == SoilState.WATERED:
			draw_rect(rect, COLOR_WATERED_WET)
			draw_rect(rect, COLOR_WATERED_BORDER, false, 1.0)

	# 3. Draw targeted cell highlight box
	if is_in_bounds(highlight_cell):
		var target_rect: Rect2 = Rect2(highlight_cell.x * TILE_SIZE, highlight_cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(target_rect, Color(1.0, 1.0, 1.0, 0.4), false, 2.0)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(TILE_SIZE))), int(floor(world_pos.y / float(TILE_SIZE))))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)

func cell_to_center_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + (TILE_SIZE / 2.0), cell.y * TILE_SIZE + (TILE_SIZE / 2.0))

func is_in_bounds(cell: Vector2i) -> bool:
	if map_loader != null and map_loader.map_size != Vector2i.ZERO:
		return map_loader.is_tile_in_bounds(cell)
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_diggable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if map_loader != null:
		return map_loader.is_tile_diggable(cell)
	return true

func get_soil_state(cell: Vector2i) -> SoilState:
	return _soil_states.get(cell, SoilState.UNTILLED)

func is_tilled(cell: Vector2i) -> bool:
	var state: SoilState = get_soil_state(cell)
	return state == SoilState.TILLED or state == SoilState.WATERED

func is_watered(cell: Vector2i) -> bool:
	return get_soil_state(cell) == SoilState.WATERED

func till_soil(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if not is_diggable(cell):
		return false
	if debris_manager != null and debris_manager.has_debris_at(&"Farm", cell):
		return false
	var current: SoilState = get_soil_state(cell)
	if current != SoilState.UNTILLED:
		return false

	_soil_states[cell] = SoilState.TILLED
	EventBus.soil_tilled.emit(cell)
	queue_redraw()
	return true

func water_soil(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var current: SoilState = get_soil_state(cell)
	if current == SoilState.UNTILLED:
		return false
	if current == SoilState.WATERED:
		return false

	_soil_states[cell] = SoilState.WATERED
	EventBus.crop_watered.emit(cell)
	queue_redraw()
	return true

func set_highlight_cell(cell: Vector2i) -> void:
	if highlight_cell != cell:
		highlight_cell = cell
		queue_redraw()

func _on_day_started(_day: int, _season: String, _year: int) -> void:
	# Overnight: watered soil dries out
	for cell: Vector2i in _soil_states.keys():
		if _soil_states[cell] == SoilState.WATERED:
			_soil_states[cell] = SoilState.TILLED
	queue_redraw()

class_name Chest
extends StaticBody2D

## Placeable Wooden Chest world entity in ReSDV.
## Holds an ItemContainer (36 slots), provides collision, renders authentic Craftables.png frames,
## and handles opening/closing states and tool interactions.

signal opened()
signal closed()

const FRAME_CLOSED_IDX: int = 130
const FRAME_OPEN_IDX: int = 135
const CRAFTABLE_COLS: int = 8
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const SPRITE_SIZE: Vector2i = Vector2i(16, 32)

@export var cell: Vector2i = Vector2i.ZERO
@export var location_id: StringName = &"Farm"

var container: ItemContainer = null
var is_open: bool = false
var shake_timer: float = 0.0

var _collision_shape: CollisionShape2D = null


func _init(p_cell: Vector2i = Vector2i.ZERO, p_location: StringName = &"Farm") -> void:
	cell = p_cell
	location_id = p_location
	container = ItemContainer.new(ItemContainer.DEFAULT_CHEST_CAPACITY, "Chest")


func _ready() -> void:
	position = Vector2(cell.x * TILE_SIZE.x, cell.y * TILE_SIZE.y)
	_setup_collision()
	queue_redraw()


func _setup_collision() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(16, 16)
		_collision_shape.shape = box
		_collision_shape.position = Vector2(8, 8)
		add_child(_collision_shape)


func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		if shake_timer <= 0.0:
			shake_timer = 0.0
		queue_redraw()


func open() -> void:
	is_open = true
	opened.emit()
	queue_redraw()


func close() -> void:
	is_open = false
	closed.emit()
	queue_redraw()


func shake() -> void:
	shake_timer = 0.35
	queue_redraw()


func is_empty() -> bool:
	return container == null or container.is_empty()


func _draw() -> void:
	var shake_offset: Vector2 = Vector2.ZERO
	if shake_timer > 0.0:
		shake_offset = Vector2(sin(shake_timer * 40.0) * 2.5, 0.0)

	var tex: Texture2D = ContentRegistry.get_craftables_texture() if is_instance_valid(ContentRegistry) else null
	if tex != null:
		var frame_idx: int = FRAME_OPEN_IDX if is_open else FRAME_CLOSED_IDX
		var src_x: int = (frame_idx % CRAFTABLE_COLS) * SPRITE_SIZE.x
		var src_y: int = (frame_idx / CRAFTABLE_COLS) * SPRITE_SIZE.y
		var src_rect: Rect2 = Rect2(src_x, src_y, SPRITE_SIZE.x, SPRITE_SIZE.y)
		var dest_rect: Rect2 = Rect2(shake_offset.x, -16.0 + shake_offset.y, SPRITE_SIZE.x, SPRITE_SIZE.y)
		draw_texture_rect_region(tex, dest_rect, src_rect)
	else:
		# Procedural fallback
		var base_rect: Rect2 = Rect2(shake_offset.x, shake_offset.y, 16, 16)
		draw_rect(base_rect, Color(0.55, 0.35, 0.18), true)
		draw_rect(base_rect, Color(0.35, 0.20, 0.08), false, 1.5)
		# Clasp
		draw_rect(Rect2(shake_offset.x + 6, shake_offset.y + 6, 4, 4), Color(0.95, 0.80, 0.25), true)
		if is_open:
			# Open lid indicator
			draw_rect(Rect2(shake_offset.x + 1, -8 + shake_offset.y, 14, 8), Color(0.40, 0.25, 0.12), true)

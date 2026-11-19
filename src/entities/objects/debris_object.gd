class_name DebrisObject
extends StaticBody2D

## World debris and wild seasonal forageable object for ReSDV.
## Represents Twigs, Stones, Weeds, Wild Grass, and Seasonal Forageables.
## Strictly typed GDScript.

enum DebrisType {
	WEED = 0,
	TWIG = 1,
	STONE = 2,
	GRASS = 3,
	FORAGE = 4,
}

const TILE_SIZE: Vector2i = Vector2i(16, 16)
const SPRINGOBJECTS_COLS: int = 24

@export var cell: Vector2i = Vector2i.ZERO:
	set(value):
		cell = value
		update_position()

@export var location_id: StringName = &"Farm"
@export var debris_type: DebrisType = DebrisType.WEED
@export var sprite_index: int = 0
@export var item_id: StringName = &""
@export var yield_item_id: StringName = &""
@export var yield_count: int = 1
@export var is_obstacle: bool = false
@export var health: int = 1

var shake_timer: float = 0.0
var _collision_shape: CollisionShape2D = null
var sprite: Sprite2D = null


func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_location: StringName = &"Farm",
	p_type: DebrisType = DebrisType.WEED,
	p_sprite_idx: int = -1,
	p_item_id: StringName = &"",
	p_yield_id: StringName = &"",
	p_yield_count: int = 1
) -> void:
	cell = p_cell
	location_id = p_location
	debris_type = p_type
	yield_count = p_yield_count
	position = Vector2(cell.x * TILE_SIZE.x, cell.y * TILE_SIZE.y)
	z_index = 2

	match debris_type:
		DebrisType.WEED:
			# Authentic spring weed indices: 0, 313, 314, 315
			sprite_index = p_sprite_idx if p_sprite_idx >= 0 else 0
			item_id = p_item_id if not p_item_id.is_empty() else &"vanilla:0"
			yield_item_id = p_yield_id if not p_yield_id.is_empty() else &"vanilla:771" # Fiber
			is_obstacle = false
			health = 1
		DebrisType.TWIG:
			# Authentic twigs: 294, 295
			sprite_index = p_sprite_idx if p_sprite_idx >= 0 else 294
			item_id = p_item_id if not p_item_id.is_empty() else &"vanilla:294"
			yield_item_id = p_yield_id if not p_yield_id.is_empty() else &"vanilla:388" # Wood
			is_obstacle = true
			health = 1
		DebrisType.STONE:
			# Authentic small stones: 32, 34, 343
			sprite_index = p_sprite_idx if p_sprite_idx >= 0 else 32
			item_id = p_item_id if not p_item_id.is_empty() else &"vanilla:32"
			yield_item_id = p_yield_id if not p_yield_id.is_empty() else &"vanilla:390" # Stone
			is_obstacle = true
			health = 1
		DebrisType.GRASS:
			sprite_index = p_sprite_idx if p_sprite_idx >= 0 else 0
			item_id = &""
			yield_item_id = p_yield_id if not p_yield_id.is_empty() else &"vanilla:178" # Hay
			is_obstacle = false
			health = 1
		DebrisType.FORAGE:
			sprite_index = p_sprite_idx if p_sprite_idx >= 0 else 18 # Daffodil default
			item_id = p_item_id if not p_item_id.is_empty() else &"vanilla:18"
			yield_item_id = item_id
			is_obstacle = false
			health = 1

	_setup_sprite()
	if is_obstacle:
		_setup_collision()


func _ready() -> void:
	update_position()
	z_index = 2
	if sprite == null:
		_setup_sprite()
	else:
		_update_sprite_texture()
	if is_obstacle:
		_setup_collision()
	queue_redraw()


func update_position() -> void:
	position = Vector2(cell.x * TILE_SIZE.x, cell.y * TILE_SIZE.y)


func get_global_visual_rect() -> Rect2:
	return Rect2(global_position, Vector2(TILE_SIZE))


func get_visual_center() -> Vector2:
	return global_position + Vector2(TILE_SIZE) / 2.0


func _setup_sprite() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2(8.0, 8.0)
	sprite.z_index = 2
	_update_sprite_texture()


func _update_sprite_texture() -> void:
	if sprite == null:
		return

	if debris_type == DebrisType.GRASS:
		var grass_tex: Texture2D = ContentRegistry.get_grass_texture() if is_instance_valid(ContentRegistry) else null
		if grass_tex != null:
			sprite.texture = grass_tex
			sprite.region_enabled = true
			var var_idx: int = abs(sprite_index) % 4
			sprite.region_rect = Rect2(var_idx * 15, 0, 15, 16)
			sprite.visible = true
		else:
			sprite.texture = null
			sprite.visible = false
		return

	var tex: Texture2D = ContentRegistry.get_springobjects_texture() if is_instance_valid(ContentRegistry) else null
	if tex != null and sprite_index >= 0:
		sprite.texture = tex
		sprite.region_enabled = true
		var col: int = sprite_index % SPRINGOBJECTS_COLS
		var row: int = sprite_index / SPRINGOBJECTS_COLS
		sprite.region_rect = Rect2(col * 16, row * 16, 16, 16)
		sprite.visible = true
	else:
		sprite.texture = null
		sprite.visible = false


func _setup_collision() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(16, 16)
		_collision_shape.shape = box
		_collision_shape.position = Vector2(8.0, 8.0)
		add_child(_collision_shape)


func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		var shake_offset: Vector2 = Vector2.ZERO
		if shake_timer <= 0.0:
			shake_timer = 0.0
		else:
			shake_offset = Vector2(sin(shake_timer * 40.0) * 2.0, 0.0)
		if sprite != null:
			sprite.position = Vector2(8.0, 8.0) + shake_offset
		queue_redraw()


func shake() -> void:
	shake_timer = 0.25
	queue_redraw()


func can_be_hit_by(tool_id: StringName) -> bool:
	match debris_type:
		DebrisType.WEED:
			return tool_id == &"vanilla:scythe" or tool_id == &"vanilla:axe" or tool_id == &"vanilla:pickaxe" or tool_id == &"vanilla:hoe"
		DebrisType.TWIG:
			return tool_id == &"vanilla:axe"
		DebrisType.STONE:
			return tool_id == &"vanilla:pickaxe"
		DebrisType.GRASS:
			return tool_id == &"vanilla:scythe"
		DebrisType.FORAGE:
			return false
	return false


func is_forage() -> bool:
	return debris_type == DebrisType.FORAGE


func _draw() -> void:
	if sprite != null and sprite.texture != null:
		return

	var shake_offset: Vector2 = Vector2.ZERO
	if shake_timer > 0.0:
		shake_offset = Vector2(sin(shake_timer * 40.0) * 2.0, 0.0)
	var center: Vector2 = Vector2(8.0, 8.0) + shake_offset

	match debris_type:
		DebrisType.WEED:
			draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color(0.3, 0.6, 0.2))
		DebrisType.TWIG:
			draw_rect(Rect2(center - Vector2(6, 2), Vector2(12, 4)), Color(0.5, 0.35, 0.2))
		DebrisType.STONE:
			draw_circle(center, 5.0, Color(0.5, 0.5, 0.5))
		DebrisType.GRASS:
			draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 0.7, 0.2, 0.8))
		DebrisType.FORAGE:
			draw_circle(center, 6.0, Color(0.9, 0.8, 0.2))
		_:
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color.WHITE)


func to_dict() -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y,
		"type": int(debris_type),
		"sprite_index": sprite_index,
		"item_id": String(item_id),
		"yield_id": String(yield_item_id),
		"yield_count": yield_count,
		"health": health,
	}


static func from_dict(data: Dictionary, loc: StringName = &"Farm") -> DebrisObject:
	var c: Vector2i = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	var t: DebrisType = data.get("type", DebrisType.WEED) as DebrisType
	var s_idx: int = int(data.get("sprite_index", -1))
	var i_id: StringName = StringName(data.get("item_id", ""))
	var y_id: StringName = StringName(data.get("yield_id", ""))
	var y_cnt: int = int(data.get("yield_count", 1))
	var obj: DebrisObject = DebrisObject.new(c, loc, t, s_idx, i_id, y_id, y_cnt)
	obj.health = int(data.get("health", 1))
	return obj

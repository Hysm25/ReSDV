class_name NPC
extends CharacterBody2D

## Autonomous Villager/NPC entity for ReSDV.
## Handles directional movement, schedule navigation, walking animations,
## authentic portrait rendering, and interactive dialogues.

signal schedule_destination_reached(target_cell: Vector2i)
signal dialogue_triggered(npc_name: StringName)

const TILE_SIZE: Vector2i = Vector2i(16, 16)
const SPRITE_FRAME_SIZE: Vector2i = Vector2i(16, 32)
const ANIM_FRAME_TIME: float = 0.16
const DEFAULT_WALK_SPEED: float = 55.0

@export var npc_name: StringName = &"Robin"
@export var display_name: String = "Robin"
@export var current_location_id: StringName = &"Farm"
@export var cell: Vector2i = Vector2i.ZERO
@export var facing_direction: Vector2i = Vector2i.DOWN

var is_moving: bool = false
var is_talking: bool = false
var walk_speed: float = DEFAULT_WALK_SPEED

var waypoints: Array[Vector2i] = []
var _target_world_pos: Vector2 = Vector2.ZERO

var character_texture: Texture2D = null
var portrait_texture: Texture2D = null

var current_frame: int = 0
var anim_timer: float = 0.0
var has_talked_today: bool = false

var _collision_shape: CollisionShape2D = null


func _init(p_name: StringName = &"Robin", p_cell: Vector2i = Vector2i.ZERO, p_location: StringName = &"Farm") -> void:
	npc_name = p_name
	display_name = String(p_name)
	cell = p_cell
	current_location_id = p_location


func _ready() -> void:
	position = Vector2(cell.x * TILE_SIZE.x + 8, cell.y * TILE_SIZE.y + 8)
	_setup_collision()
	_load_textures()
	_update_idle_frame()
	queue_redraw()


func _setup_collision() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(14, 14)
		_collision_shape.shape = box
		_collision_shape.position = Vector2.ZERO
		add_child(_collision_shape)


func _load_textures() -> void:
	var char_path: String = "user://vanilla_data/Characters/%s.png" % String(npc_name)
	if FileAccess.file_exists(char_path):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(char_path))
		if img != null and not img.is_empty():
			character_texture = ImageTexture.create_from_image(img)

	var port_path: String = "user://vanilla_data/Portraits/%s.png" % String(npc_name)
	if FileAccess.file_exists(port_path):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(port_path))
		if img != null and not img.is_empty():
			portrait_texture = ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	if is_talking:
		velocity = Vector2.ZERO
		return

	if is_moving:
		_process_movement(delta)
	else:
		velocity = Vector2.ZERO


func _process_movement(delta: float) -> void:
	anim_timer += delta
	if anim_timer >= ANIM_FRAME_TIME:
		anim_timer = 0.0
		_advance_walk_frame()
		queue_redraw()

	var to_target: Vector2 = _target_world_pos - position
	var dist: float = to_target.length()
	var step: float = walk_speed * delta

	if dist <= step:
		position = _target_world_pos
		cell = Vector2i(int(position.x / TILE_SIZE.x), int(position.y / TILE_SIZE.y))
		_advance_to_next_waypoint()
	else:
		velocity = to_target.normalized() * walk_speed
		move_and_slide()


func walk_to_cell(target_cell: Vector2i) -> void:
	if target_cell == cell:
		return

	waypoints.clear()
	# Generate simple cardinal path: X axis first, then Y axis
	var curr: Vector2i = cell
	var step_x: int = 1 if target_cell.x > curr.x else -1
	while curr.x != target_cell.x:
		curr.x += step_x
		waypoints.append(curr)

	var step_y: int = 1 if target_cell.y > curr.y else -1
	while curr.y != target_cell.y:
		curr.y += step_y
		waypoints.append(curr)

	_start_following_waypoints()


func set_waypoints(new_waypoints: Array[Vector2i]) -> void:
	waypoints = new_waypoints.duplicate()
	_start_following_waypoints()


func _start_following_waypoints() -> void:
	if waypoints.is_empty():
		is_moving = false
		_update_idle_frame()
		return

	is_moving = true
	var next_cell: Vector2i = waypoints.pop_front()
	_set_movement_target(next_cell)


func _advance_to_next_waypoint() -> void:
	if waypoints.is_empty():
		is_moving = false
		_update_idle_frame()
		queue_redraw()
		schedule_destination_reached.emit(cell)
		return

	var next_cell: Vector2i = waypoints.pop_front()
	_set_movement_target(next_cell)


func _set_movement_target(target_cell: Vector2i) -> void:
	_target_world_pos = Vector2(target_cell.x * TILE_SIZE.x + 8, target_cell.y * TILE_SIZE.y + 8)
	var diff: Vector2i = target_cell - cell
	if abs(diff.x) > abs(diff.y):
		facing_direction = Vector2i.RIGHT if diff.x > 0 else Vector2i.LEFT
	else:
		facing_direction = Vector2i.DOWN if diff.y > 0 else Vector2i.UP


func _advance_walk_frame() -> void:
	var base_row: int = _get_row_for_direction(facing_direction)
	var frame_in_row: int = (current_frame % 4 + 1) % 4
	current_frame = base_row * 4 + frame_in_row


func _update_idle_frame() -> void:
	var base_row: int = _get_row_for_direction(facing_direction)
	current_frame = base_row * 4


func _get_row_for_direction(dir: Vector2i) -> int:
	if dir == Vector2i.RIGHT:
		return 1
	elif dir == Vector2i.UP:
		return 2
	elif dir == Vector2i.LEFT:
		return 3
	return 0 # DOWN


func set_facing_direction(dir: Vector2i) -> void:
	facing_direction = dir
	_update_idle_frame()
	queue_redraw()


func interact_with_player(player: Player, dialogue_ui: DialogueBoxUI, dialogue_engine: DialogueEngine) -> void:
	if player == null or dialogue_ui == null or dialogue_engine == null:
		return

	is_talking = true
	# Turn toward player
	facing_direction = -player.facing_direction if player.facing_direction != Vector2i.ZERO else Vector2i.DOWN
	_update_idle_frame()
	queue_redraw()

	var raw_text: String = dialogue_engine.get_best_dialogue(npc_name, "Mon", not has_talked_today)
	var pages: Array[Dictionary] = dialogue_engine.parse_dialogue(raw_text)
	has_talked_today = true

	dialogue_triggered.emit(npc_name)
	dialogue_ui.show_dialogue(display_name, pages, portrait_texture)

	if not dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_ui.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished() -> void:
	is_talking = false
	_update_idle_frame()
	queue_redraw()


func _draw() -> void:
	if character_texture != null:
		var cols: int = 4
		var src_x: int = (current_frame % cols) * SPRITE_FRAME_SIZE.x
		var src_y: int = (current_frame / cols) * SPRITE_FRAME_SIZE.y
		var src_rect: Rect2 = Rect2(src_x, src_y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
		# Position offset so 16x32 sprite stands properly on the 16x16 tile
		draw_texture_rect_region(character_texture, Rect2(-8, -24, 16, 32), src_rect)
	else:
		# Procedural villager avatar
		draw_circle(Vector2(0, -6), 6.0, Color(0.85, 0.45, 0.25)) # Shirt / body
		draw_circle(Vector2(0, -14), 5.0, Color(0.95, 0.82, 0.70)) # Head / face
		draw_circle(Vector2(0, -17), 5.5, Color(0.40, 0.25, 0.15)) # Hair
		# Facing pointer
		var pointer: Vector2 = Vector2(facing_direction.x * 6.0, facing_direction.y * 6.0 - 10.0)
		draw_circle(pointer, 2.0, Color(1.0, 0.9, 0.4))

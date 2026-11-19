class_name ContainerSlotUI
extends Control

## UI slot component for Chest Container and Player Inventory modals.
## Displays item icon, count, tooltip, and handles left/right click transfer signals.

signal slot_clicked(index: int, is_right_click: bool)

const SLOT_SIZE: Vector2 = Vector2(38, 38)
const COLOR_BG: Color = Color(0.20, 0.14, 0.09, 0.90)
const COLOR_BG_HOVER: Color = Color(0.32, 0.22, 0.14, 0.95)
const COLOR_BORDER_NORMAL: Color = Color(0.40, 0.28, 0.18, 1.0)
const COLOR_BORDER_HOVER: Color = Color(0.95, 0.85, 0.35, 1.0)

var slot_index: int = 0
var item_slot: InventorySlot = null
var is_hovered: bool = false

var icon_rect: TextureRect = null
var count_label: Label = null


func _init(p_index: int = 0) -> void:
	slot_index = p_index
	custom_minimum_size = SLOT_SIZE


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	_setup_children()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_display(item_slot)


func _setup_children() -> void:
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(24, 24)
		icon_rect.position = Vector2(7, 7)
		icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(icon_rect)

	if count_label == null:
		count_label = Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override(&"font_size", 10)
		count_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		count_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		count_label.add_theme_constant_override(&"shadow_offset_x", 1)
		count_label.add_theme_constant_override(&"shadow_offset_y", 1)
		count_label.size = Vector2(20, 14)
		count_label.position = Vector2(16, 22)
		count_label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(count_label)


func update_display(slot: InventorySlot) -> void:
	item_slot = slot
	queue_redraw()

	if icon_rect == null or count_label == null:
		return

	if slot == null or slot.is_empty():
		icon_rect.texture = null
		count_label.text = ""
		tooltip_text = ""
	else:
		icon_rect.texture = slot.get_icon()
		count_label.text = str(slot.count) if slot.count > 1 else ""
		var data: ItemData = slot.get_item_data()
		if data != null:
			tooltip_text = "%s\n%s" % [data.name, data.description]
		else:
			tooltip_text = String(slot.item_id)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SLOT_SIZE)
	var bg_col: Color = COLOR_BG_HOVER if is_hovered else COLOR_BG
	var border_col: Color = COLOR_BORDER_HOVER if is_hovered else COLOR_BORDER_NORMAL
	var border_width: float = 2.0 if is_hovered else 1.5

	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, border_width)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot_index, false)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			slot_clicked.emit(slot_index, true)
			accept_event()


func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

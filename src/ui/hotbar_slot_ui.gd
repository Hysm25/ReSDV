class_name HotbarSlotUI
extends Control

## Individual UI view for an inventory slot on the Hotbar.
## Displays item icon from tools.png or springobjects.png, stack count, and selection highlight.

signal slot_clicked(index: int)

const SLOT_SIZE: Vector2 = Vector2(44, 44)
const COLOR_BG: Color = Color(0.22, 0.15, 0.10, 0.88)
const COLOR_BG_SELECTED: Color = Color(0.35, 0.24, 0.14, 0.95)
const COLOR_BORDER_NORMAL: Color = Color(0.45, 0.32, 0.20, 1.0)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 0.88, 0.25, 1.0)

@export var slot_index: int = 0
var is_selected: bool = false
var item_slot: InventorySlot = null

var icon_rect: TextureRect = null
var count_label: Label = null
var num_label: Label = null

func _init(p_index: int = 0) -> void:
	slot_index = p_index
	custom_minimum_size = SLOT_SIZE

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	_setup_children()
	update_display(item_slot, is_selected)

func _setup_children() -> void:
	mouse_filter = MOUSE_FILTER_STOP

	# Number indicator (Top-Left)
	if num_label == null:
		num_label = Label.new()
		num_label.text = _get_key_label_text(slot_index)
		num_label.add_theme_font_size_override(&"font_size", 10)
		num_label.add_theme_color_override(&"font_color", Color(0.85, 0.80, 0.70, 0.75))
		num_label.position = Vector2(3, 1)
		num_label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(num_label)

	# Centered item icon
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(28, 28)
		icon_rect.position = Vector2(8, 8)
		icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(icon_rect)

	# Stack count label (Bottom-Right)
	if count_label == null:
		count_label = Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override(&"font_size", 11)
		count_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		count_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		count_label.add_theme_constant_override(&"shadow_offset_x", 1)
		count_label.add_theme_constant_override(&"shadow_offset_y", 1)
		count_label.size = Vector2(24, 16)
		count_label.position = Vector2(17, 26)
		count_label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(count_label)

func update_display(slot: InventorySlot, selected: bool) -> void:
	item_slot = slot
	is_selected = selected
	queue_redraw()

	if icon_rect == null or count_label == null:
		return

	if slot == null or slot.is_empty():
		icon_rect.texture = null
		count_label.text = ""
	else:
		icon_rect.texture = slot.get_icon()
		if slot.count > 1:
			count_label.text = str(slot.count)
		else:
			count_label.text = ""

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SLOT_SIZE)
	var bg_col: Color = COLOR_BG_SELECTED if is_selected else COLOR_BG
	draw_rect(rect, bg_col, true)

	if is_selected:
		draw_rect(rect, COLOR_BORDER_SELECTED, false, 3.0)
		var inner_rect: Rect2 = Rect2(Vector2(2, 2), SLOT_SIZE - Vector2(4, 4))
		draw_rect(inner_rect, Color(1.0, 1.0, 0.4, 0.35), false, 1.0)
	else:
		draw_rect(rect, COLOR_BORDER_NORMAL, false, 1.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)
		accept_event()

func _get_key_label_text(idx: int) -> String:
	match idx:
		0, 1, 2, 3, 4, 5, 6, 7, 8:
			return str(idx + 1)
		9:
			return "0"
		10:
			return "-"
		11:
			return "="
	return ""

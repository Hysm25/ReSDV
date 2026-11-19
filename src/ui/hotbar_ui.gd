class_name HotbarUI
extends Control

## Displays the 12-slot inventory hotbar at the bottom of the screen.
## Connects to InventoryManager to render real extracted tool and item icons,
## stack counts, and slot selection highlights.

@export var inventory_manager: InventoryManager = null

var slot_views: Array[HotbarSlotUI] = []
var hbox: HBoxContainer = null

func _ready() -> void:
	_setup_ui()
	if inventory_manager != null:
		bind_inventory(inventory_manager)
	else:
		# Search parent/scene tree for InventoryManager if not set
		var found_mgr: InventoryManager = _find_inventory_manager()
		if found_mgr != null:
			bind_inventory(found_mgr)
		else:
			EventBus.inventory_changed.connect(_on_event_bus_inventory_changed)
			EventBus.item_selected.connect(_on_event_bus_item_selected)

func _setup_ui() -> void:
	# Bottom center positioning
	set_anchors_preset(PRESET_BOTTOM_WIDE)
	offset_top = -60.0
	offset_bottom = -12.0
	mouse_filter = MOUSE_FILTER_IGNORE

	if hbox == null:
		hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override(&"separation", 6)
		hbox.set_anchors_preset(PRESET_FULL_RECT)
		hbox.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(hbox)

	slot_views.clear()
	for i: int in range(12):
		var slot_view: HotbarSlotUI = HotbarSlotUI.new(i)
		slot_view.slot_clicked.connect(_on_slot_clicked)
		hbox.add_child(slot_view)
		slot_views.append(slot_view)

func bind_inventory(mgr: InventoryManager) -> void:
	if inventory_manager != null:
		if inventory_manager.slot_changed.is_connected(_on_slot_changed):
			inventory_manager.slot_changed.disconnect(_on_slot_changed)
		if inventory_manager.active_slot_changed.is_connected(_on_active_slot_changed):
			inventory_manager.active_slot_changed.disconnect(_on_active_slot_changed)

	inventory_manager = mgr
	if inventory_manager != null:
		if not inventory_manager.slot_changed.is_connected(_on_slot_changed):
			inventory_manager.slot_changed.connect(_on_slot_changed)
		if not inventory_manager.active_slot_changed.is_connected(_on_active_slot_changed):
			inventory_manager.active_slot_changed.connect(_on_active_slot_changed)
		refresh_all()

func refresh_all() -> void:
	if inventory_manager == null:
		return
	for i: int in range(slot_views.size()):
		var slot: InventorySlot = inventory_manager.get_slot(i)
		var is_sel: bool = (i == inventory_manager.selected_slot_index)
		slot_views[i].update_display(slot, is_sel)

func _on_slot_clicked(idx: int) -> void:
	if inventory_manager != null:
		inventory_manager.select_slot(idx)

func _on_slot_changed(idx: int, slot: InventorySlot) -> void:
	if idx >= 0 and idx < slot_views.size():
		var is_sel: bool = (inventory_manager != null and idx == inventory_manager.selected_slot_index)
		slot_views[idx].update_display(slot, is_sel)

func _on_active_slot_changed(idx: int, _slot: InventorySlot) -> void:
	for i: int in range(slot_views.size()):
		var is_sel: bool = (i == idx)
		var s: InventorySlot = inventory_manager.get_slot(i) if inventory_manager != null else null
		slot_views[i].update_display(s, is_sel)

func _unhandled_input(event: InputEvent) -> void:
	if inventory_manager == null:
		return

	# Number keys 1-9, 0, -, =
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
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

	# Mouse wheel slot scrolling
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory_manager.select_previous_slot()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory_manager.select_next_slot()

func _find_inventory_manager() -> InventoryManager:
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		var node: Node = tree.current_scene.find_child("InventoryManager", true, false)
		if node is InventoryManager:
			return node as InventoryManager
	return null

func _on_event_bus_inventory_changed(slot_idx: int, item_id: StringName, count: int) -> void:
	if inventory_manager == null and slot_idx >= 0 and slot_idx < slot_views.size():
		var dummy_slot: InventorySlot = InventorySlot.new(item_id, count)
		slot_views[slot_idx].update_display(dummy_slot, slot_views[slot_idx].is_selected)

func _on_event_bus_item_selected(slot_idx: int, _item_id: StringName) -> void:
	if inventory_manager == null and slot_idx >= 0 and slot_idx < slot_views.size():
		for i: int in range(slot_views.size()):
			slot_views[i].update_display(slot_views[i].item_slot, i == slot_idx)

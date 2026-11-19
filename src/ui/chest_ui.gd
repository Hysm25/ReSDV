class_name ChestUI
extends CanvasLayer

## Full-featured Chest Container and Player Inventory transfer UI modal in ReSDV.
## Renders 36 container slots (3x12) alongside Player inventory (12, 24, or 36 slots),
## and handles click-to-transfer, right-click single transfers, and inventory organizing.

signal opened()
signal closed()

@onready var backdrop: ColorRect = $Backdrop
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var chest_grid: GridContainer = $CenterContainer/MainPanel/VBox/ChestSection/ChestGrid
@onready var player_grid: GridContainer = $CenterContainer/MainPanel/VBox/PlayerSection/PlayerGrid
@onready var chest_title: Label = $CenterContainer/MainPanel/VBox/ChestSection/Header/TitleLabel
@onready var close_btn: Button = $CenterContainer/MainPanel/VBox/ChestSection/Header/CloseButton
@onready var organize_btn: Button = $CenterContainer/MainPanel/VBox/ChestSection/Header/OrganizeButton

var _active_chest: Chest = null
var _active_inv: InventoryManager = null

var _chest_slot_views: Array[ContainerSlotUI] = []
var _player_slot_views: Array[ContainerSlotUI] = []


func _ready() -> void:
	visible = false
	if close_btn != null:
		close_btn.pressed.connect(close_chest)
	if organize_btn != null:
		organize_btn.pressed.connect(_on_organize_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_chest()
			get_viewport().set_input_as_handled()


func open_chest(chest: Chest, inv: InventoryManager) -> void:
	if chest == null or inv == null:
		return

	_active_chest = chest
	_active_inv = inv

	_active_chest.open()
	if is_instance_valid(EventBus):
		EventBus.chest_opened.emit(_active_chest)

	if chest_title != null and chest.container != null:
		chest_title.text = chest.container.container_name

	_build_chest_slots()
	_build_player_slots()

	if not _active_chest.container.container_changed.is_connected(_refresh_all):
		_active_chest.container.container_changed.connect(_refresh_all)
	if not _active_inv.slot_changed.is_connected(_on_inv_slot_changed):
		_active_inv.slot_changed.connect(_on_inv_slot_changed)

	visible = true
	opened.emit()


func close_chest() -> void:
	if not visible:
		return

	if _active_chest != null:
		if _active_chest.container != null and _active_chest.container.container_changed.is_connected(_refresh_all):
			_active_chest.container.container_changed.disconnect(_refresh_all)
		_active_chest.close()
		if is_instance_valid(EventBus):
			EventBus.chest_closed.emit(_active_chest)
		_active_chest = null

	if _active_inv != null:
		if _active_inv.slot_changed.is_connected(_on_inv_slot_changed):
			_active_inv.slot_changed.disconnect(_on_inv_slot_changed)
		_active_inv = null

	visible = false
	closed.emit()


func _build_chest_slots() -> void:
	if chest_grid == null or _active_chest == null or _active_chest.container == null:
		return

	for child in chest_grid.get_children():
		child.queue_free()
	_chest_slot_views.clear()

	var container: ItemContainer = _active_chest.container
	for i in range(container.capacity):
		var slot_view: ContainerSlotUI = ContainerSlotUI.new(i)
		slot_view.slot_clicked.connect(_on_chest_slot_clicked)
		chest_grid.add_child(slot_view)
		_chest_slot_views.append(slot_view)
		slot_view.update_display(container.get_slot(i))


func _build_player_slots() -> void:
	if player_grid == null or _active_inv == null:
		return

	for child in player_grid.get_children():
		child.queue_free()
	_player_slot_views.clear()

	for i in range(_active_inv.total_slots):
		var slot_view: ContainerSlotUI = ContainerSlotUI.new(i)
		slot_view.slot_clicked.connect(_on_player_slot_clicked)
		player_grid.add_child(slot_view)
		_player_slot_views.append(slot_view)
		slot_view.update_display(_active_inv.get_slot(i))


func _on_chest_slot_clicked(index: int, is_right_click: bool) -> void:
	if _active_chest == null or _active_inv == null or _active_chest.container == null:
		return
	var count_to_withdraw: int = 1 if is_right_click else -1
	_active_chest.container.withdraw_to_inventory(_active_inv, index, count_to_withdraw)
	_refresh_all()


func _on_player_slot_clicked(index: int, is_right_click: bool) -> void:
	if _active_chest == null or _active_inv == null or _active_chest.container == null:
		return
	var count_to_deposit: int = 1 if is_right_click else -1
	_active_chest.container.deposit_from_inventory(_active_inv, index, count_to_deposit)
	_refresh_all()


func _on_organize_pressed() -> void:
	if _active_chest != null and _active_chest.container != null:
		_active_chest.container.organize()
		_refresh_all()


func _on_inv_slot_changed(_slot_idx: int, _slot: InventorySlot) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _active_chest != null and _active_chest.container != null:
		for i in range(mini(_chest_slot_views.size(), _active_chest.container.slots.size())):
			_chest_slot_views[i].update_display(_active_chest.container.get_slot(i))

	if _active_inv != null:
		for i in range(mini(_player_slot_views.size(), _active_inv.slots.size())):
			_player_slot_views[i].update_display(_active_inv.get_slot(i))

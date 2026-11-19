class_name InventoryManager
extends Node

## Manages player inventory slots, stacking, addition/removal,
## and active hotbar slot selection. Decoupled from Player via EventBus.

signal slot_changed(slot_index: int, slot: InventorySlot)
signal active_slot_changed(slot_index: int, slot: InventorySlot)
signal capacity_changed(new_capacity: int)

const DEFAULT_HOTBAR_SIZE: int = 12
const MAX_BACKPACK_CAPACITY: int = 36

@export var total_slots: int = DEFAULT_HOTBAR_SIZE
@export var selected_slot_index: int = 0
@export var auto_starter_inventory: bool = true

var slots: Array[InventorySlot] = []

func _ready() -> void:
	_init_slots()
	if auto_starter_inventory and is_all_empty():
		initialize_starter_inventory()
	if not EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.connect(_on_crop_harvested)

func _exit_tree() -> void:
	if EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.disconnect(_on_crop_harvested)

func _init_slots() -> void:
	while slots.size() < total_slots:
		slots.append(InventorySlot.new())

func can_expand() -> bool:
	return total_slots < MAX_BACKPACK_CAPACITY

func upgrade_capacity(new_capacity: int) -> bool:
	if new_capacity <= total_slots:
		return false
	var target_cap: int = mini(new_capacity, MAX_BACKPACK_CAPACITY)
	total_slots = target_cap
	_init_slots()
	capacity_changed.emit(total_slots)
	if is_instance_valid(EventBus):
		EventBus.inventory_capacity_changed.emit(total_slots)
	print("[InventoryManager] Inventory capacity upgraded to %d slots!" % total_slots)
	return true

func cycle_hotbar_row() -> void:
	if total_slots <= DEFAULT_HOTBAR_SIZE:
		return
	# Rotate rows of 12 cyclically (e.g. Row 1 -> Row 2 -> Row 3 -> Row 1)
	var first_row: Array[InventorySlot] = slots.slice(0, DEFAULT_HOTBAR_SIZE)
	var remaining: Array[InventorySlot] = slots.slice(DEFAULT_HOTBAR_SIZE)
	slots = remaining + first_row
	for i: int in range(slots.size()):
		slot_changed.emit(i, slots[i])
		if is_instance_valid(EventBus):
			EventBus.inventory_changed.emit(i, slots[i].item_id, slots[i].count)
	active_slot_changed.emit(selected_slot_index, get_selected_slot())
	if is_instance_valid(EventBus):
		EventBus.item_selected.emit(selected_slot_index, get_selected_item_id())

func is_all_empty() -> bool:
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			return false
	return true

func clear_all() -> void:
	for i: int in range(slots.size()):
		slots[i].clear()
		slot_changed.emit(i, slots[i])
		EventBus.inventory_changed.emit(i, &"", 0)
	select_slot(0)

func initialize_starter_inventory() -> void:
	_init_slots()
	set_slot(0, &"vanilla:hoe", 1)
	set_slot(1, &"vanilla:watering_can", 1)
	set_slot(2, &"vanilla:axe", 1)
	set_slot(3, &"vanilla:pickaxe", 1)
	set_slot(4, &"vanilla:472", 15) # 15 Parsnip Seeds
	select_slot(0)

func set_slot(slot_index: int, item_id: StringName, count: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id) if not item_id.is_empty() else &""
	slots[slot_index].item_id = namespaced_id
	slots[slot_index].count = count
	slot_changed.emit(slot_index, slots[slot_index])
	EventBus.inventory_changed.emit(slot_index, namespaced_id, count)
	if slot_index == selected_slot_index:
		active_slot_changed.emit(slot_index, slots[slot_index])
		EventBus.item_selected.emit(slot_index, namespaced_id)
	return true

func add_item(item_id: StringName, count: int = 1) -> int:
	if count <= 0 or item_id.is_empty():
		return count
	_init_slots()

	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id)
	var data: ItemData = ContentRegistry.get_item(namespaced_id)
	var max_stack: int = data.max_stack if data != null else 999
	var remaining: int = count

	# 1. First pass: stack onto existing slots of the same item
	if max_stack > 1:
		for i: int in range(slots.size()):
			if slots[i].item_id == namespaced_id and slots[i].count < max_stack:
				var available: int = max_stack - slots[i].count
				var to_add: int = mini(remaining, available)
				slots[i].count += to_add
				remaining -= to_add
				slot_changed.emit(i, slots[i])
				EventBus.inventory_changed.emit(i, namespaced_id, slots[i].count)
				if i == selected_slot_index:
					active_slot_changed.emit(i, slots[i])
					EventBus.item_selected.emit(i, namespaced_id)
				if remaining <= 0:
					return 0

	# 2. Second pass: place into first available empty slot
	while remaining > 0:
		var empty_idx: int = find_first_empty_slot()
		if empty_idx == -1:
			# Inventory full
			break
		var to_add: int = mini(remaining, max_stack)
		slots[empty_idx].item_id = namespaced_id
		slots[empty_idx].count = to_add
		remaining -= to_add
		slot_changed.emit(empty_idx, slots[empty_idx])
		EventBus.inventory_changed.emit(empty_idx, namespaced_id, slots[empty_idx].count)
		if empty_idx == selected_slot_index:
			active_slot_changed.emit(empty_idx, slots[empty_idx])
			EventBus.item_selected.emit(empty_idx, namespaced_id)

	return remaining

func remove_item_at(slot_index: int, count: int = 1) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if slots[slot_index].is_empty() or count <= 0:
		return false

	var current: int = slots[slot_index].count
	if count >= current:
		slots[slot_index].clear()
	else:
		slots[slot_index].count -= count

	slot_changed.emit(slot_index, slots[slot_index])
	EventBus.inventory_changed.emit(slot_index, slots[slot_index].item_id, slots[slot_index].count)
	if slot_index == selected_slot_index:
		active_slot_changed.emit(slot_index, slots[slot_index])
		EventBus.item_selected.emit(slot_index, slots[slot_index].item_id)
	return true

func remove_item(item_id: StringName, count: int = 1) -> bool:
	if not has_item(item_id, count):
		return false
	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id)
	var remaining_to_remove: int = count

	# Remove starting from last slots
	for i: int in range(slots.size() - 1, -1, -1):
		if slots[i].item_id == namespaced_id:
			var take: int = mini(remaining_to_remove, slots[i].count)
			slots[i].count -= take
			remaining_to_remove -= take
			if slots[i].count <= 0:
				slots[i].clear()
			slot_changed.emit(i, slots[i])
			EventBus.inventory_changed.emit(i, slots[i].item_id, slots[i].count)
			if i == selected_slot_index:
				active_slot_changed.emit(i, slots[i])
				EventBus.item_selected.emit(i, slots[i].item_id)
			if remaining_to_remove <= 0:
				break

	return true

func select_slot(slot_index: int) -> void:
	_init_slots()
	var hotbar_max: int = mini(slots.size(), DEFAULT_HOTBAR_SIZE) - 1
	var new_index: int = clampi(slot_index, 0, max(hotbar_max, 0))
	selected_slot_index = new_index
	var current_slot: InventorySlot = get_selected_slot()
	active_slot_changed.emit(new_index, current_slot)
	EventBus.item_selected.emit(new_index, get_selected_item_id())

func select_next_slot() -> void:
	var hotbar_len: int = mini(slots.size(), DEFAULT_HOTBAR_SIZE)
	if hotbar_len <= 0:
		return
	var next_idx: int = (selected_slot_index + 1) % hotbar_len
	select_slot(next_idx)

func select_previous_slot() -> void:
	var hotbar_len: int = mini(slots.size(), DEFAULT_HOTBAR_SIZE)
	if hotbar_len <= 0:
		return
	var prev_idx: int = (selected_slot_index - 1 + hotbar_len) % hotbar_len
	select_slot(prev_idx)

func swap_slots(index_a: int, index_b: int) -> bool:
	if index_a < 0 or index_a >= slots.size() or index_b < 0 or index_b >= slots.size():
		return false
	if index_a == index_b:
		return true

	var temp_id: StringName = slots[index_a].item_id
	var temp_count: int = slots[index_a].count

	slots[index_a].item_id = slots[index_b].item_id
	slots[index_a].count = slots[index_b].count

	slots[index_b].item_id = temp_id
	slots[index_b].count = temp_count

	slot_changed.emit(index_a, slots[index_a])
	slot_changed.emit(index_b, slots[index_b])
	EventBus.inventory_changed.emit(index_a, slots[index_a].item_id, slots[index_a].count)
	EventBus.inventory_changed.emit(index_b, slots[index_b].item_id, slots[index_b].count)

	if index_a == selected_slot_index or index_b == selected_slot_index:
		active_slot_changed.emit(selected_slot_index, get_selected_slot())
		EventBus.item_selected.emit(selected_slot_index, get_selected_item_id())

	return true

func get_slot(index: int) -> InventorySlot:
	_init_slots()
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func get_selected_slot() -> InventorySlot:
	return get_slot(selected_slot_index)

func get_selected_item_id() -> StringName:
	var slot: InventorySlot = get_selected_slot()
	return slot.item_id if slot != null else &""

func get_selected_item_data() -> ItemData:
	var slot: InventorySlot = get_selected_slot()
	return slot.get_item_data() if slot != null else null

func has_item(item_id: StringName, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

func get_item_count(item_id: StringName) -> int:
	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id)
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == namespaced_id:
			total += slot.count
	return total

func find_first_empty_slot() -> int:
	_init_slots()
	for i: int in range(slots.size()):
		if slots[i].is_empty():
			return i
	return -1

func is_full() -> bool:
	return find_first_empty_slot() == -1

func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		result.append(slot.to_dict())
	return result

func from_array(data: Array) -> void:
	slots.clear()
	for d: Variant in data:
		if d is Dictionary:
			slots.append(InventorySlot.from_dict(d as Dictionary))
		else:
			slots.append(InventorySlot.new())
	while slots.size() < total_slots:
		slots.append(InventorySlot.new())
	select_slot(selected_slot_index)

func _on_crop_harvested(_cell: Vector2i, _crop_id: StringName, yield_id: StringName, count: int) -> void:
	var remaining: int = add_item(yield_id, count)
	if remaining > 0:
		print("[InventoryManager] Inventory full! Could not fit %d of %s" % [remaining, yield_id])
	else:
		print("[InventoryManager] Harvest received: %s (+%d). Total in inventory: %d" % [yield_id, count, get_item_count(yield_id)])

class_name ItemContainer
extends RefCounted

## Generic container data model for chests, dressers, and storage boxes in ReSDV.
## Strictly typed, serializable, and supports seamless stack transfers with InventoryManager.

signal slot_changed(index: int, slot: InventorySlot)
signal container_changed()

const DEFAULT_CHEST_CAPACITY: int = 36

var capacity: int = DEFAULT_CHEST_CAPACITY
var container_name: String = "Chest"
var slots: Array[InventorySlot] = []


func _init(cap: int = DEFAULT_CHEST_CAPACITY, name_str: String = "Chest") -> void:
	capacity = cap
	container_name = name_str
	_init_slots()


func _init_slots() -> void:
	while slots.size() < capacity:
		slots.append(InventorySlot.new())


func is_empty() -> bool:
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			return false
	return true


func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


func set_slot(index: int, item_id: StringName, count: int) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id) if not item_id.is_empty() else &""
	slots[index].item_id = namespaced_id
	slots[index].count = count
	slot_changed.emit(index, slots[index])
	container_changed.emit()
	return true


func add_item(item_id: StringName, count: int = 1) -> int:
	if count <= 0 or item_id.is_empty():
		return count
	_init_slots()

	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(item_id)
	var data: ItemData = ContentRegistry.get_item(namespaced_id)
	var max_stack: int = data.max_stack if data != null else 999
	var remaining: int = count

	# 1. Stack onto existing matching items
	if max_stack > 1:
		for i: int in range(slots.size()):
			if slots[i].item_id == namespaced_id and slots[i].count < max_stack:
				var space: int = max_stack - slots[i].count
				var to_add: int = mini(remaining, space)
				slots[i].count += to_add
				remaining -= to_add
				slot_changed.emit(i, slots[i])
				if remaining <= 0:
					container_changed.emit()
					return 0

	# 2. Add to first empty slot
	while remaining > 0:
		var empty_idx: int = find_first_empty_slot()
		if empty_idx == -1:
			break
		var to_add: int = mini(remaining, max_stack)
		slots[empty_idx].item_id = namespaced_id
		slots[empty_idx].count = to_add
		remaining -= to_add
		slot_changed.emit(empty_idx, slots[empty_idx])

	container_changed.emit()
	return remaining


func remove_item_at(index: int, count: int = 1) -> bool:
	if index < 0 or index >= slots.size() or count <= 0:
		return false
	if slots[index].is_empty():
		return false
	if count >= slots[index].count:
		slots[index].clear()
	else:
		slots[index].count -= count
	slot_changed.emit(index, slots[index])
	container_changed.emit()
	return true


func find_first_empty_slot() -> int:
	_init_slots()
	for i: int in range(slots.size()):
		if slots[i].is_empty():
			return i
	return -1


func swap_slots(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= slots.size() or idx_b < 0 or idx_b >= slots.size():
		return false
	if idx_a == idx_b:
		return true
	var temp_id: StringName = slots[idx_a].item_id
	var temp_count: int = slots[idx_a].count
	slots[idx_a].item_id = slots[idx_b].item_id
	slots[idx_a].count = slots[idx_b].count
	slots[idx_b].item_id = temp_id
	slots[idx_b].count = temp_count
	slot_changed.emit(idx_a, slots[idx_a])
	slot_changed.emit(idx_b, slots[idx_b])
	container_changed.emit()
	return true


func organize() -> void:
	# Collect all non-empty items
	var items: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			items.append({"item_id": slot.item_id, "count": slot.count})
		slot.clear()

	# Sort by ID
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["item_id"]) < String(b["item_id"])
	)

	# Re-add items
	for it: Dictionary in items:
		add_item(it["item_id"], it["count"])

	for i: int in range(slots.size()):
		slot_changed.emit(i, slots[i])
	container_changed.emit()


func deposit_from_inventory(inv: InventoryManager, inv_slot_idx: int, count: int = -1) -> bool:
	if inv == null:
		return false
	var p_slot: InventorySlot = inv.get_slot(inv_slot_idx)
	if p_slot == null or p_slot.is_empty():
		return false

	var to_transfer: int = p_slot.count if (count <= 0 or count > p_slot.count) else count
	var item_id: StringName = p_slot.item_id

	var unadded: int = add_item(item_id, to_transfer)
	var actually_transferred: int = to_transfer - unadded
	if actually_transferred > 0:
		inv.remove_item_at(inv_slot_idx, actually_transferred)
		return true
	return false


func withdraw_to_inventory(inv: InventoryManager, container_slot_idx: int, count: int = -1) -> bool:
	if inv == null:
		return false
	var c_slot: InventorySlot = get_slot(container_slot_idx)
	if c_slot == null or c_slot.is_empty():
		return false

	var to_transfer: int = c_slot.count if (count <= 0 or count > c_slot.count) else count
	var item_id: StringName = c_slot.item_id

	var unadded: int = inv.add_item(item_id, to_transfer)
	var actually_transferred: int = to_transfer - unadded
	if actually_transferred > 0:
		remove_item_at(container_slot_idx, actually_transferred)
		return true
	return false


func to_dict() -> Dictionary:
	var slots_arr: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		slots_arr.append(slot.to_dict())
	return {
		"capacity": capacity,
		"name": container_name,
		"slots": slots_arr,
	}


static func from_dict(dict: Dictionary) -> ItemContainer:
	var cap: int = dict.get("capacity", DEFAULT_CHEST_CAPACITY)
	var cname: String = dict.get("name", "Chest")
	var container: ItemContainer = ItemContainer.new(cap, cname)
	var raw_slots: Array = dict.get("slots", [])
	container.slots.clear()
	for d: Variant in raw_slots:
		if d is Dictionary:
			container.slots.append(InventorySlot.from_dict(d as Dictionary))
		else:
			container.slots.append(InventorySlot.new())
	container._init_slots()
	return container

class_name InventorySlot
extends Resource

## Data representation of an individual inventory slot.
## Strictly typed for ReSDV.

@export var item_id: StringName = &""
@export var count: int = 0

func _init(p_item_id: StringName = &"", p_count: int = 0) -> void:
	item_id = p_item_id
	count = p_count

func is_empty() -> bool:
	return item_id.is_empty() or count <= 0

func clear() -> void:
	item_id = &""
	count = 0

func get_item_data() -> ItemData:
	if is_empty():
		return null
	return ContentRegistry.get_item(item_id)

func get_icon() -> AtlasTexture:
	if is_empty():
		return null
	return ContentRegistry.get_item_icon(item_id)

func get_item_name() -> String:
	var data: ItemData = get_item_data()
	return data.name if data != null else ""

func to_dict() -> Dictionary:
	return {
		"item_id": String(item_id),
		"count": count,
	}

static func from_dict(dict: Dictionary) -> InventorySlot:
	var slot: InventorySlot = InventorySlot.new()
	slot.item_id = StringName(dict.get("item_id", ""))
	slot.count = int(dict.get("count", 0))
	return slot

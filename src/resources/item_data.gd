class_name ItemData
extends Resource

## Base data representation for all inventory items and objects.
## Adheres to strict static typing standards for ReSDV.

enum Category {
	GENERAL = 0,
	TOOL = 1,
	SEED = 2,
	CROP = 3,
	MINERAL = 4,
	FISH = 5,
	FORAGE = 6,
	COOKING = 7,
	CRAFTING = 8,
	FERTILIZER = 9,
	RING = 10,
	WEAPON = 11,
	BOOTS = 12,
}

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var category: Category = Category.GENERAL
@export var texture_path: String = ""
@export var sprite_index: int = -1
@export var texture: Texture2D = null
@export var max_stack: int = 999
@export var price: int = 0
@export var edibility: int = -300
@export var can_be_given_as_gift: bool = true
@export var can_be_trashed: bool = true

func is_edible() -> bool:
	return edibility > -300

static func from_dict(data: Dictionary) -> ItemData:
	var item: ItemData = ItemData.new()
	if data.has("id"):
		item.id = StringName(str(data["id"]))
	if data.has("name"):
		item.name = str(data["name"])
	if data.has("description"):
		item.description = str(data["description"])
	if data.has("category"):
		item.category = int(data["category"]) as Category
	if data.has("max_stack"):
		item.max_stack = int(data["max_stack"])
	if data.has("price"):
		item.price = int(data["price"])
	if data.has("edibility"):
		item.edibility = int(data["edibility"])
	if data.has("can_be_given_as_gift"):
		item.can_be_given_as_gift = bool(data["can_be_given_as_gift"])
	if data.has("can_be_trashed"):
		item.can_be_trashed = bool(data["can_be_trashed"])
	if data.has("texture"):
		item.texture_path = str(data["texture"])
	elif data.has("texture_path"):
		item.texture_path = str(data["texture_path"])
	if data.has("sprite_index"):
		item.sprite_index = int(data["sprite_index"])
	return item

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"description": description,
		"category": int(category),
		"max_stack": max_stack,
		"price": price,
		"edibility": edibility,
		"can_be_given_as_gift": can_be_given_as_gift,
		"can_be_trashed": can_be_trashed,
		"texture_path": texture_path,
		"sprite_index": sprite_index,
	}

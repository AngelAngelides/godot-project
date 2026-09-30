extends Node

# Item definitions loaded from res://data/items/items.json
# Each entry maps item_id -> { display_name, consumable, max_uses }
#   max_uses: -1 means unlimited uses, >0 is a consumable charge count

const ITEMS_PATH := "res://data/items/items.json"

var items: Dictionary = {}

func _ready() -> void:
	_load_items()

func _load_items() -> void:
	items = {}
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_error("ItemDatabase: Could not open item database: %s" % ITEMS_PATH)
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("ItemDatabase: JSON parse error in %s at line %d: %s" % [ITEMS_PATH, json.get_error_line(), json.get_error_message()])
		return

	items = json.data
	print("ItemDatabase: Loaded %d items" % items.size())

func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}

func has_item(item_id: String) -> bool:
	return items.has(item_id)

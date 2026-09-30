extends Node

# Player identity
var player_name: String = "Unknown"

# Core stats — start at 1, player distributes bonus points during creation
var stats: Dictionary = {
	"Strength": 1,
	"Perception": 1,
	"Intelligence": 1,
	"Agility": 1,
	"Endurance": 1,
}

# Inventory — maps item_id -> { "uses": int }
# "uses" is -1 for unlimited items, or a count for consumables (e.g. bullets)
var inventory: Dictionary = {}

# Total bonus points the player can distribute
const BONUS_POINTS: int = 10

func get_stat(stat_name: String) -> int:
	if stats.has(stat_name):
		return stats[stat_name]
	return 0

func set_stat(stat_name: String, value: int) -> void:
	if stats.has(stat_name):
		stats[stat_name] = value

func check_stat(stat_name: String, threshold: int) -> bool:
	return get_stat(stat_name) >= threshold

func get_total_assigned() -> int:
	var total: int = 0
	for stat_name in stats:
		total += stats[stat_name]
	return total

func get_points_remaining() -> int:
	# Each stat starts at 1 (5 stats = 5 base), plus BONUS_POINTS to distribute
	var base_total: int = stats.size()
	return BONUS_POINTS - (get_total_assigned() - base_total)

func reset_stats() -> void:
	for stat_name in stats:
		stats[stat_name] = 1

func add_item(item_id: String) -> void:
	if has_item(item_id):
		return
	var item_def: Dictionary = ItemDatabase.get_item(item_id)
	if item_def.is_empty():
		# Unknown item — still add it so gameplay isn't blocked
		inventory[item_id] = {"uses": -1}
		return
	inventory[item_id] = {"uses": item_def.get("max_uses", -1)}

func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

func use_item(item_id: String) -> bool:
	if not has_item(item_id):
		return false
	var state: Dictionary = inventory[item_id]
	if state["uses"] == -1:
		return true  # unlimited use item
	if state["uses"] <= 0:
		return false
	state["uses"] -= 1
	if state["uses"] == 0:
		inventory.erase(item_id)  # consumed — remove from inventory
	return true

func get_item_uses(item_id: String) -> int:
	if not has_item(item_id):
		return 0
	return inventory[item_id]["uses"]

func remove_item(item_id: String) -> void:
	inventory.erase(item_id)

func clear_inventory() -> void:
	inventory.clear()

func get_inventory_text() -> String:
	if inventory.is_empty():
		return "Empty"
	var parts: Array[String] = []
	for item_id in inventory:
		var item_def: Dictionary = ItemDatabase.get_item(item_id)
		var display: String = item_def.get("display_name", item_id)
		var uses: int = inventory[item_id]["uses"]
		if uses >= 0:
			display += " (%d)" % uses
		parts.append(display)
	return ", ".join(parts)

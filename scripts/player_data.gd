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

# Inventory — stores item names the player has picked up
var inventory: Array[String] = []

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

func add_item(item_name: String) -> void:
	if not has_item(item_name):
		inventory.append(item_name)

func has_item(item_name: String) -> bool:
	return inventory.has(item_name)

func remove_item(item_name: String) -> void:
	inventory.erase(item_name)

func clear_inventory() -> void:
	inventory.clear()

func get_inventory_text() -> String:
	if inventory.is_empty():
		return "Empty"
	return ", ".join(inventory)

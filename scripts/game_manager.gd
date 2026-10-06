extends Control

const ChoiceButtonScene := preload("res://scenes/ChoiceButton.tscn")

@onready var story_data: Node = $StoryData
@onready var story_label: RichTextLabel = $MarginContainer/VBoxContainer/StoryPanel/MarginContainer/ScrollContainer/StoryLabel
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/StoryPanel/MarginContainer/ScrollContainer
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoicesPanel/MarginContainer/ChoicesContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleBar/TitleLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsBar/StatsLabel
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryBar/InventoryLabel

var current_node: String = "start"

func _ready() -> void:
	title_label.text = PlayerData.player_name.to_upper()
	_update_stats_display()
	_update_inventory_display()
	_display_node(current_node)

func _update_stats_display() -> void:
	var parts: Array[String] = []
	for stat_name in PlayerData.stats:
		# Use first 3 letters as abbreviation
		var abbr: String = stat_name.left(3).to_upper()
		parts.append("%s:%d" % [abbr, PlayerData.get_stat(stat_name)])
	stats_label.text = "  ".join(parts)

func _update_inventory_display() -> void:
	inventory_label.text = "Inv: %s" % PlayerData.get_inventory_text()

func _display_node(node_key: String) -> void:
	current_node = node_key
	var data: Dictionary = story_data.get_node_data(node_key)

	# Pick up items granted by this node
	if data.has("gives_item"):
		PlayerData.add_item(data["gives_item"])
		_update_inventory_display()

	# Consume items used by this node (e.g. firing the gun costs a bullet)
	if data.has("uses_item"):
		PlayerData.use_item(data["uses_item"])
		_update_inventory_display()

	# Update story text — replace {player_name} placeholder
	var story_text: String = data["text"]
	story_text = story_text.replace("{player_name}", PlayerData.player_name)
	story_label.text = ""
	story_label.append_text(story_text)

	# Scroll to top after setting text
	await get_tree().process_frame
	scroll_container.scroll_vertical = 0

	# Clear old choices
	for child in choices_container.get_children():
		child.queue_free()

	# Wait a frame so old buttons are freed
	await get_tree().process_frame

	# Create choice buttons — filter by stat and item requirements
	var choices: Array = data["choices"]
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]

		# Check stat requirement
		if choice.has("require_stat") and choice.has("require_value"):
			if not PlayerData.check_stat(choice["require_stat"], choice["require_value"]):
				var button := _make_disabled_button(
					"%s [Requires %s %d]" % [choice["text"], choice["require_stat"], choice["require_value"]]
				)
				choices_container.add_child(button)
				continue

		# Check item requirement
		if choice.has("require_item"):
			if not PlayerData.has_item(choice["require_item"]):
				var button := _make_disabled_button(
					"%s [Requires: %s]" % [choice["text"], choice["require_item"]]
				)
				choices_container.add_child(button)
				continue

		# Resolve the destination — stat_check routes to pass/fail at click time
		var next_key: String = choice.get("next", "")
		var has_stat_check: bool = choice.has("stat_check")

		var button := ChoiceButtonScene.instantiate()
		button.text = choice["text"]
		if has_stat_check:
			button.pressed.connect(_on_stat_check_choice.bind(choice["stat_check"]))
		else:
			button.pressed.connect(_on_choice_pressed.bind(next_key))
		choices_container.add_child(button)

func _make_disabled_button(text: String) -> Button:
	var button := ChoiceButtonScene.instantiate()
	button.text = text
	button.disabled = true
	return button

func _on_stat_check_choice(stat_check: Dictionary) -> void:
	var stat_name: String = stat_check["stat"]
	var value: int = int(stat_check["value"])
	var next_node: String
	if PlayerData.check_stat(stat_name, value):
		next_node = stat_check["pass"]
	else:
		next_node = stat_check["fail"]
	_on_choice_pressed(next_node)

func _on_choice_pressed(next_node: String) -> void:
	# Reset inventory when restarting the game
	if next_node == "start":
		PlayerData.clear_inventory()
		_update_inventory_display()
	_display_node(next_node)

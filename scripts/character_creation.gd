extends Control

const StatRowScene := preload("res://scenes/StatRow.tscn")

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/NameSection/NameInput
@onready var points_label: Label = $MarginContainer/VBoxContainer/PointsLabel
@onready var stats_container: VBoxContainer = $MarginContainer/VBoxContainer/StatsScrollContainer/StatsContainer
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var error_label: Label = $MarginContainer/VBoxContainer/ErrorLabel

var stat_rows: Dictionary = {}

func _ready() -> void:
	PlayerData.reset_stats()
	_build_stat_rows()
	_update_points_display()
	start_button.pressed.connect(_on_start_pressed)
	name_input.text_changed.connect(_on_name_changed)
	error_label.text = ""

func _build_stat_rows() -> void:
	for stat_name in PlayerData.stats:
		var row: HBoxContainer = StatRowScene.instantiate()
		stats_container.add_child(row)
		row.set_stat_name(stat_name)
		row.set_value(PlayerData.get_stat(stat_name))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.minus_pressed.connect(_on_minus_pressed.bind(stat_name))
		row.plus_pressed.connect(_on_plus_pressed.bind(stat_name))
		stat_rows[stat_name] = row

func _on_plus_pressed(stat_name: String) -> void:
	if PlayerData.get_points_remaining() <= 0:
		return
	if PlayerData.get_stat(stat_name) >= 10:
		return
	PlayerData.set_stat(stat_name, PlayerData.get_stat(stat_name) + 1)
	_update_stat_display(stat_name)
	_update_points_display()

func _on_minus_pressed(stat_name: String) -> void:
	if PlayerData.get_stat(stat_name) <= 1:
		return
	PlayerData.set_stat(stat_name, PlayerData.get_stat(stat_name) - 1)
	_update_stat_display(stat_name)
	_update_points_display()

func _update_stat_display(stat_name: String) -> void:
	if stat_rows.has(stat_name):
		stat_rows[stat_name].set_value(PlayerData.get_stat(stat_name))

func _update_points_display() -> void:
	points_label.text = "Points remaining: %d" % PlayerData.get_points_remaining()

func _on_name_changed(_new_text: String) -> void:
	error_label.text = ""

func _on_start_pressed() -> void:
	var trimmed_name := name_input.text.strip_edges()
	if trimmed_name.length() == 0:
		error_label.text = "Please enter a name."
		return
	if PlayerData.get_points_remaining() > 0:
		error_label.text = "You still have %d points to spend!" % PlayerData.get_points_remaining()
		return
	PlayerData.player_name = trimmed_name
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

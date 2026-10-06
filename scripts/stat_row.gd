extends HBoxContainer

signal minus_pressed
signal plus_pressed

@onready var stat_name_label: Label = $StatNameLabel
@onready var value_label: Label = $ValueLabel

func _ready() -> void:
	$MinusButton.pressed.connect(func(): minus_pressed.emit())
	$PlusButton.pressed.connect(func(): plus_pressed.emit())

func set_stat_name(stat_name: String) -> void:
	stat_name_label.text = stat_name

func set_value(value: int) -> void:
	value_label.text = str(value)

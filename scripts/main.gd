extends Control
## Точка входа MVP. Пока только проверяет, что автолоады поднялись.

@onready var _status: Label = $StatusLabel


func _ready() -> void:
	_status.text = "\n".join([
		"Godot merge MVP",
		"Config energy_max = %s" % Config.get_value("energy_max"),
		"Save coins = %s" % SaveManager.get_value("coins"),
	])
	Analytics.log_event("main_ready")

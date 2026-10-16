extends Node
## Локальное сохранение (JSON в user://).
## Облако добавим позже через REST/HTTPRequest.

signal saved
signal loaded(data: Dictionary)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		loaded.emit(data)
		return data

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveManager: не удалось открыть %s" % SAVE_PATH)
		data = _default_data()
		loaded.emit(data)
		return data

	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	data = _migrate(parsed) if parsed is Dictionary else _default_data()
	loaded.emit(data)
	return data


func save_game() -> void:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: не удалось записать %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	saved.emit()


func get_value(key: String, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)


func set_value(key: String, value: Variant) -> void:
	data[key] = value


func reset() -> void:
	data = _default_data()
	save_game()


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"energy": 100,
		"coins": 0,
		"board": [],
		"orders_done": 0,
	}


func _migrate(raw: Dictionary) -> Dictionary:
	# Заготовка миграций по версиям.
	if int(raw.get("version", 0)) < SAVE_VERSION:
		var base := _default_data()
		base.merge(raw, true)
		base["version"] = SAVE_VERSION
		return base
	return raw

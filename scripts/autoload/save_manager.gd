extends Node
## Локальное сохранение (JSON в user://).
## Облако добавим позже через REST/HTTPRequest.

signal saved
signal loaded(data: Dictionary)

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const BACKUP_PATH := "user://save.bak"
const SAVE_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func load_game() -> Dictionary:
	var parsed = _read_json(SAVE_PATH)
	if not (parsed is Dictionary):
		# Основной файл повреждён или отсутствует — пробуем резервную копию.
		parsed = _read_json(BACKUP_PATH)
		if parsed is Dictionary:
			push_warning("SaveManager: основной сейв повреждён, загружена резервная копия")
			_restore_backup_to_main()
		else:
			# Последний шанс: недописанный tmp от прерванной записи.
			parsed = _read_json(TMP_PATH)
			if parsed is Dictionary:
				push_warning("SaveManager: остался незавершённый save.tmp, читаю его")
	data = _migrate(parsed) if parsed is Dictionary else _default_data()
	loaded.emit(data)
	return data


func save_game() -> void:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()

	var text := JSON.stringify(data, "  ")
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: не удалось записать %s" % TMP_PATH)
		return
	f.store_string(text)
	f.flush()
	f.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: не удалось открыть user:// для атомарной записи")
		return

	# Старый сейв не удаляем сразу: он станет резервной копией.
	if dir.file_exists("save.json"):
		if dir.file_exists("save.bak"):
			dir.remove("save.bak")
		if dir.rename("save.json", "save.bak") != OK:
			push_warning("SaveManager: не удалось создать резервную копию")

	if dir.rename("save.tmp", "save.json") != OK:
		push_error("SaveManager: не удалось заменить сейв; пробую восстановить резерв")
		if dir.file_exists("save.bak"):
			dir.rename("save.bak", "save.json")
		return
	saved.emit()


## Восстановить основной сейв из backup, чтобы следующий save_game не затёр
## хорошую копию испорченным файлом.
func _restore_backup_to_main() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("save.json"):
		dir.remove("save.json")
	if dir.copy("save.bak", "save.json") != OK:
		push_warning("SaveManager: не удалось восстановить save.json из backup")


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


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _migrate(raw: Dictionary) -> Dictionary:
	# Всегда добиваем недостающие ключи дефолтами: сейв мог быть записан
	# более старой версией игры, где части полей ещё не существовало.
	var base := _default_data()
	base.merge(raw, true)
	base["version"] = SAVE_VERSION
	return base

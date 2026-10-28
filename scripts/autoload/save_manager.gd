extends Node
## Локальное сохранение (JSON в user://).
## Облако добавим позже через REST/HTTPRequest.
##
## Запись отложенная и единая для всей игры: set_value() и request_save()
## заводят таймер SAVE_DELAY — серия действий (тап-тап-слияние) пишет файл один
## раз. На сворачивании/закрытии пишем сразу (flush, см. _notification).
## Состояние, которое живёт не в `data`, а в узлах сцены (поле, заказы), сцена
## отдаёт через провайдер: register_provider(callable → Dictionary ключ → значение),
## провайдеры опрашиваются перед каждой записью.

signal saved
signal loaded(data: Dictionary)
## Данные сейва заменены целиком (сброс прогресса из настроек или откат после
## самопроверки): автолоады перечитывают своё состояние.
signal reset_done

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const BACKUP_PATH := "user://save.bak"
const SAVE_VERSION := 1
## Задержка отложенной записи, с.
const SAVE_DELAY := 1.5

var data: Dictionary = {}

var _loaded := false
var _timer: Timer
## Провайдеры состояния сцены: Callable() -> Dictionary.
var _providers: Array[Callable] = []
## > 0 — запись запрещена (самопроверка гоняет настоящие данные).
var _suspended := 0


func _ready() -> void:
	ensure_loaded()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SAVE_DELAY
	_timer.timeout.connect(flush)
	add_child(_timer)


func _notification(what: int) -> void:
	# Сворачивание, потеря фокуса и закрытие — пишем немедленно: отложенный
	# таймер может уже не успеть. Уведомления окна доходят до всех узлов дерева.
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, \
				NOTIFICATION_APPLICATION_FOCUS_OUT:
			flush()


## Сейв читается с диска один раз: автолоады и game.gd зовут это в своём
## _ready() — порядок автолоадов не важен, а повторный разбор JSON и затирание
## уже изменённых в памяти данных (оффлайн-реген энергии) исключены.
func ensure_loaded() -> void:
	if not _loaded:
		load_game()


func load_game() -> Dictionary:
	_loaded = true
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


# --- Отложенная запись ---------------------------------------------------------

## Запросить сохранение: файл запишется через SAVE_DELAY (один раз на серию).
func request_save() -> void:
	if _suspended > 0 or _timer == null or not _timer.is_inside_tree():
		return
	if _timer.is_stopped():
		_timer.start()


## Записать сейв прямо сейчас (таймер, сворачивание, покупки за деньги):
## опросить провайдеров сцены и сохранить.
func flush() -> void:
	if _timer != null:
		_timer.stop()
	if _suspended > 0:
		return
	for provider in _providers.duplicate():
		if not provider.is_valid():
			_providers.erase(provider)
			continue
		var state = provider.call()
		if state is Dictionary:
			data.merge(state, true)
	save_game()


## Сцена отдаёт своё состояние (поле, заказы) перед каждой записью.
func register_provider(provider: Callable) -> void:
	if not _providers.has(provider):
		_providers.append(provider)


func unregister_provider(provider: Callable) -> void:
	_providers.erase(provider)


## Запретить/разрешить запись (вложенные вызовы считаются). Самопроверка
## и сброс прогресса не должны записать промежуточное состояние.
func suspend(value: bool) -> void:
	_suspended = maxi(0, _suspended + (1 if value else -1))
	if _suspended > 0 and _timer != null:
		_timer.stop()


## Глубокая копия данных (откат после самопроверки).
func snapshot() -> Dictionary:
	return data.duplicate(true)


## Вернуть данные из snapshot(): автолоады перечитают их по reset_done.
## Файл не пишется — на диске и так состояние до самопроверки.
func restore_snapshot(copy: Dictionary) -> void:
	data = copy.duplicate(true)
	reset_done.emit()


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


## Любое изменение данных заводит отложенную запись.
func set_value(key: String, value: Variant) -> void:
	data[key] = value
	request_save()


## Удалить ключ (миграция убранных фич); запись — отложенная, если ключ был.
func erase_value(key: String) -> void:
	if data.erase(key):
		request_save()


## Сброс прогресса: провайдеров сцены не опрашиваем — старое поле не должно
## попасть в свежий сейв (сцена перезагружается следом).
func reset() -> void:
	if _timer != null:
		_timer.stop()
	_providers.clear()
	data = _default_data()
	save_game()
	reset_done.emit()


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

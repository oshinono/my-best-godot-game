extends Node

## Прогресс игрока (фаза 1): XP и уровень кофейни.
##
## Уровень — единственная шкала прогресса: он гейтит генераторы и слоты заказов
## (см. docs/GDD.md §9, docs/economy.md). Формула: xp_next(n) = round(base * n^1.5).
## Данные живут в SaveManager под ключами `cafe_level` и `xp`.

signal xp_changed(xp: int, xp_next: int)
signal level_changed(level: int, previous: int)

var level: int = 1
var xp: int = 0

var _base: float = 50.0
var _max_level: int = 20


func _ready() -> void:
	_base = _cfg_float("xp_per_level_base", 50.0)
	_max_level = maxi(1, _cfg_int("cafe_level_max", 20))
	## Загрузку зовём явно: порядок автолоадов не должен влиять на результат.
	SaveManager.load_game()
	level = clampi(int(SaveManager.get_value("cafe_level", 1)), 1, _max_level)
	xp = maxi(0, int(SaveManager.get_value("xp", 0)))


## Сколько XP нужно на следующий уровень (по умолчанию — от текущего уровня).
func xp_next(for_level: int = -1) -> int:
	var source := level if for_level < 0 else for_level
	return int(round(_base * pow(float(source), 1.5)))


func is_max_level() -> bool:
	return level >= _max_level


## Начисляет XP, поднимает уровни и сохраняет. Возвращает число взятых уровней.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var previous := level
	while not is_max_level() and xp >= xp_next():
		xp -= xp_next()
		level += 1
	if is_max_level():
		xp = mini(xp, xp_next())
	_persist()
	xp_changed.emit(xp, xp_next())
	if level != previous:
		level_changed.emit(level, previous)
	return level - previous


func progress_ratio() -> float:
	var need := xp_next()
	if need <= 0:
		return 0.0
	return clampf(float(xp) / float(need), 0.0, 1.0)


## Сколько слотов заказов доступно на текущем уровне.
func order_slots() -> int:
	var slots := _cfg_int("order_slots_start", 2)
	if level >= _cfg_int("order_slots_level3", 6):
		slots += 1
	if level >= _cfg_int("order_slots_level4", 12):
		slots += 1
	return slots


func generator_unlock_level(chain: StringName) -> int:
	match String(chain):
		"coffee":
			return 1
		"pastry":
			return _cfg_int("generator_unlock_pastry", 4)
		"flowers":
			return _cfg_int("generator_unlock_flowers", 8)
	return 1


func is_generator_unlocked(chain: StringName) -> bool:
	return level >= generator_unlock_level(chain)


## Текст следующей разблокировки для статуса при level up (или пусто).
func unlock_note(previous_level: int) -> String:
	var notes := PackedStringArray()
	for chain in Chains.all_chains():
		var need := generator_unlock_level(chain)
		if need > previous_level and need <= level:
			notes.append("генератор «%s»" % Chains.title(chain))
	if order_slots() > _slots_at(previous_level):
		notes.append("слот заказа")
	if notes.is_empty():
		return ""
	return "Открыто: " + ", ".join(notes)


func _slots_at(for_level: int) -> int:
	var slots := _cfg_int("order_slots_start", 2)
	if for_level >= _cfg_int("order_slots_level3", 6):
		slots += 1
	if for_level >= _cfg_int("order_slots_level4", 12):
		slots += 1
	return slots


func reset() -> void:
	level = 1
	xp = 0
	_persist()
	xp_changed.emit(xp, xp_next())


func _persist() -> void:
	SaveManager.set_value("cafe_level", level)
	SaveManager.set_value("xp", xp)


func _cfg_int(key: String, fallback: int) -> int:
	var value = Config.get_value(key)
	return int(value) if value != null else fallback


func _cfg_float(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

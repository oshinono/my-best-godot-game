extends Node

## Энергия: реген по таймеру, оффлайн-догрузка, списание.
## Настройки — в Config (energy_max / energy_regen_seconds / energy_regen_amount),
## состояние — в SaveManager (ключи "energy" и "energy_next_ts").
## "energy_ts" пишется для обратной совместимости со старыми сейвами.
## Автолоад: Energy.

signal energy_changed(value: int, maximum: int)
signal energy_spent(amount: int, left: int)
signal energy_not_enough(required: int, left: int)
signal energy_full

const TICK := 1.0

var maximum: int = 100

var _value: int = 100
var _regen_seconds: float = 60.0
var _regen_amount: int = 1
var _seconds_left: float = 60.0
var _next_ts: float = 0.0
var _timer: Timer


func _ready() -> void:
	maximum = maxi(1, _cfg_int("energy_max", 100))
	_regen_seconds = maxf(1.0, _cfg_float("energy_regen_seconds", 60.0))
	_regen_amount = maxi(1, _cfg_int("energy_regen_amount", 1))

	# Энергия читает своё состояние из сейва — грузим его явно,
	# чтобы порядок автолоадов не влиял на результат.
	SaveManager.load_game()
	_value = clampi(int(SaveManager.get_value("energy", maximum)), 0, maximum)
	_next_ts = _load_next_ts()

	_apply_offline()

	_timer = Timer.new()
	_timer.wait_time = TICK
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)

	energy_changed.emit(_value, maximum)


# --- Публичное API -----------------------------------------------------------

func current() -> int:
	return _value


func seconds_to_next() -> int:
	if is_full():
		return 0
	return int(ceil(_seconds_left))


func is_full() -> bool:
	return _value >= maximum


func can_spend(amount: int) -> bool:
	return _value >= amount


func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if _value < amount:
		energy_not_enough.emit(amount, _value)
		return false
	var was_full := is_full()
	_value -= amount
	# Если тратим из полного бака — новый отсчёт начинается сейчас.
	# Если реген уже идёт, его оставшийся прогресс сохраняется.
	if was_full:
		_next_ts = Time.get_unix_time_from_system() + _regen_seconds
	_seconds_left = maxf(0.0, _next_ts - Time.get_unix_time_from_system())
	_persist()
	energy_changed.emit(_value, maximum)
	energy_spent.emit(amount, _value)
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	_value = mini(maximum, _value + amount)
	if is_full():
		_next_ts = Time.get_unix_time_from_system() + _regen_seconds
	_seconds_left = maxf(0.0, _next_ts - Time.get_unix_time_from_system())
	_persist()
	energy_changed.emit(_value, maximum)


# --- Внутреннее --------------------------------------------------------------

## Абсолютное время следующего тика. Новый ключ энергия-независим:
## при трате/перезапуске прогресс регена не сбрасывается.
func _load_next_ts() -> float:
	var stored = SaveManager.get_value("energy_next_ts")
	if stored != null:
		return float(stored)
	# Миграция со старого формата: energy_ts — момент последней записи.
	var legacy := float(SaveManager.get_value("energy_ts", 0.0))
	var now := Time.get_unix_time_from_system()
	if legacy > 0.0:
		return legacy + _regen_seconds
	return now + _regen_seconds


## Догрузка за время, пока игра была закрыта.
func _apply_offline() -> void:
	var now := Time.get_unix_time_from_system()

	if is_full():
		_next_ts = now + _regen_seconds
	else:
		if _next_ts <= 0.0:
			_next_ts = now + _regen_seconds
		if now >= _next_ts:
			var ticks := int((now - _next_ts) / _regen_seconds) + 1
			_value = mini(maximum, _value + ticks * _regen_amount)
			_next_ts += float(ticks) * _regen_seconds
		if is_full():
			_next_ts = now + _regen_seconds

	_seconds_left = maxf(0.0, _next_ts - now)
	_persist()


func _tick() -> void:
	var now := Time.get_unix_time_from_system()

	if is_full():
		_next_ts = now + _regen_seconds
		_seconds_left = _regen_seconds
		return

	if now < _next_ts:
		_seconds_left = _next_ts - now
		return

	var ticks := int((now - _next_ts) / _regen_seconds) + 1
	_value = mini(maximum, _value + ticks * _regen_amount)
	_next_ts += float(ticks) * _regen_seconds
	if is_full():
		_next_ts = now + _regen_seconds
	_seconds_left = maxf(0.0, _next_ts - now)
	_persist()
	energy_changed.emit(_value, maximum)
	if is_full():
		energy_full.emit()


func _persist() -> void:
	SaveManager.set_value("energy", _value)
	SaveManager.set_value("energy_next_ts", _next_ts)
	# Совместимость: старые версии читают energy_ts как момент последней записи.
	SaveManager.set_value("energy_ts", maxf(0.0, _next_ts - _regen_seconds))


func _cfg_int(key: String, fallback: int) -> int:
	var value = Config.get_value(key)
	return int(value) if value != null else fallback


func _cfg_float(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

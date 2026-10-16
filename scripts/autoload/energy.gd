extends Node

## Энергия: реген по таймеру, оффлайн-догрузка, списание.
## Настройки — в Config (energy_max / energy_regen_seconds / energy_regen_amount),
## состояние — в SaveManager (ключи "energy" и "energy_ts").
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
var _timer: Timer


func _ready() -> void:
	maximum = maxi(1, _cfg_int("energy_max", 100))
	_regen_seconds = maxf(1.0, _cfg_float("energy_regen_seconds", 60.0))
	_regen_amount = maxi(1, _cfg_int("energy_regen_amount", 1))

	# Энергия читает своё состояние из сейва — грузим его явно,
	# чтобы порядок автолоадов не влиял на результат.
	SaveManager.load_game()
	_value = clampi(int(SaveManager.get_value("energy", maximum)), 0, maximum)

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
	_value -= amount
	_persist()
	energy_changed.emit(_value, maximum)
	energy_spent.emit(amount, _value)
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	_value = mini(maximum, _value + amount)
	_persist()
	energy_changed.emit(_value, maximum)


# --- Внутреннее --------------------------------------------------------------

## Догрузка за время, пока игра была закрыта.
func _apply_offline() -> void:
	var now := Time.get_unix_time_from_system()
	var last_ts := float(SaveManager.get_value("energy_ts", 0.0))

	if last_ts > 0.0 and _value < maximum:
		var elapsed := maxf(0.0, now - last_ts)
		var ticks := int(elapsed / _regen_seconds)
		_value = mini(maximum, _value + ticks * _regen_amount)
		_seconds_left = _regen_seconds - fmod(elapsed, _regen_seconds)
	else:
		_seconds_left = _regen_seconds

	_persist()


func _tick() -> void:
	if is_full():
		_seconds_left = _regen_seconds
		return

	_seconds_left -= TICK
	if _seconds_left > 0.0:
		return

	_seconds_left = _regen_seconds
	_value = mini(maximum, _value + _regen_amount)
	_persist()
	energy_changed.emit(_value, maximum)
	if is_full():
		energy_full.emit()


func _persist() -> void:
	SaveManager.set_value("energy", _value)
	SaveManager.set_value("energy_ts", Time.get_unix_time_from_system())


func _cfg_int(key: String, fallback: int) -> int:
	var value = Config.get_value(key)
	return int(value) if value != null else fallback


func _cfg_float(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

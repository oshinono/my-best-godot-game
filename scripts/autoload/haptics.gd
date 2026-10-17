extends Node
## Тактильная отдача (GDD §15). Автолоад: Haptics.
##
## Звука и музыки в прототипе нет: вся «сочность» — вибрация. Сила и рисунок
## каждого события лежат в scripts/data/haptics.gd, вызов один:
## `Haptics.haptic("<id>")` (id — из профелей таблицы).
##
## Правила:
## - работает только на мобилке и только если вибро включено (флаг сейва
##   `haptics_enabled`, тумблер 📳 в настройках);
## - во время rewarded-рекламы молчим: game.gd зовёт `mute_for_ads(true/false)`
##   (требование GDD §15 распространяется и на вибрацию);
## - одинаковые события чаще, чем раз в THROTTLE_MS, гасятся, чтобы тапы по
##   кнопкам не превращались в сплошное дрожание;
## - одновременно играет один рисунок: если предыдущий ещё не доиграл, новый
##   запрос отбрасывается.
##
## Ограничение платформы: `amplitude` из `Input.vibrate_handheld` учитывается на
## Android; на iOS система даёт свой фиксированный отклик, поэтому рисунок там
## звучит как серия коротких вибраций.

const DATA := preload("res://scripts/data/haptics.gd")
## Минимум между двумя одинаковыми событиями (мс).
const THROTTLE_MS := 40

var enabled := true

var _muted_for_ads := false
var _busy := false
var _last_id := ""
var _last_ms := 0
var _warned: Dictionary = {}


func _ready() -> void:
	SaveManager.load_game()
	# haptics_enabled — текущий ключ; audio_haptics — старый, для сейвов игроков.
	enabled = _saved_bool("haptics_enabled", _saved_bool("audio_haptics", true))


# --- Публичное API -----------------------------------------------------------

## Вибрация по имени события (профили — scripts/data/haptics.gd).
func haptic(event_id: String) -> void:
	var profile := DATA.profile(event_id)
	if profile.is_empty():
		if not _warned.has(event_id):
			_warned[event_id] = true
			push_warning("[Haptics] нет профиля %s" % event_id)
		return
	_play(profile)


## Одиночная вибрация: миллисекунды и сила 0.0..1.0 (для отладки и разовых мест).
func buzz(ms: int, amplitude := 0.5) -> void:
	_play({"pattern": [ms], "amplitude": amplitude})


## Заглушить вибрацию на время рекламы (GDD §15).
func mute_for_ads(muted: bool) -> void:
	_muted_for_ads = muted
	if muted:
		_busy = false


func set_enabled(value: bool) -> void:
	enabled = value
	SaveManager.set_value("haptics_enabled", value)


## Есть ли профиль с таким именем (для проверок и селфтеста).
func has(event_id: String) -> bool:
	return not DATA.profile(event_id).is_empty()


# --- Внутреннее --------------------------------------------------------------

func _play(profile: Dictionary) -> void:
	if not enabled or _muted_for_ads or not OS.has_feature("mobile"):
		return
	var event_id := String(profile.get("id", ""))
	var now := Time.get_ticks_msec()
	if event_id != "" and event_id == _last_id and now - _last_ms < THROTTLE_MS:
		return
	_last_id = event_id
	_last_ms = now
	if _busy:
		return

	var parts: Array = profile.get("pattern", [])
	var amplitude := float(profile.get("amplitude", 0.5))
	_busy = true
	for index in parts.size():
		if not enabled or _muted_for_ads or not is_inside_tree():
			break
		var ms := int(parts[index])
		# Чётные индексы жужжат, нечётные — пауза; вызов вибрации не блокирует,
		# поэтому после него всегда ждём длительность шага.
		if index % 2 == 0:
			Input.vibrate_handheld(ms, amplitude)
		await get_tree().create_timer(maxf(0.001, float(ms) / 1000.0)).timeout
	_busy = false


func _saved_bool(key: String, fallback: bool) -> bool:
	var value = SaveManager.get_value(key)
	return fallback if value == null else bool(value)

extends Node
## Тактильная отдача (GDD §15, docs/haptics.md). Автолоад: Haptics.
##
## Звука в прототипе нет: вся «сочность» — вибрация. Отклик один:
## `selection(strength)` — тик выбора, как системный щелчок пикера iOS
## (UISelectionFeedbackGenerator.selectionChanged). «Сила» — это длина серии:
## LIGHT = 1 тик, MEDIUM = 2, HEAVY = 3 с паузой TICK_GAP. У самого
## UISelectionFeedbackGenerator силы нет (она есть только у impact-генератора),
## поэтому градация сделана количеством тиков.
##
## На iOS работает нативный плагин res://ios/plugins/haptics (сборка — в
## docs/haptics.md): он регистрирует синглтон `HapticsIOS`. Пока плагин не
## собран, а также на Android и десктопе автолоад молча падает на
## `Input.vibrate_handheld` — игра остаётся рабочей.
##
## Правила:
## - только на мобилке и только если вибро включено (флаг сейва
##   `haptics_enabled`, тумблер 📳 в настройках);
## - во время rewarded-рекламы молчим: game.gd зовёт `mute_for_ads(true/false)`
##   (требование GDD §15 распространяется и на вибрацию);
## - частые серии гасятся троттлингом THROTTLE_MS на входе: внутри серии тики
##   идут без гейта, иначе 2–3 тика схлопывались бы в один.

## Имя нативного синглтона, который регистрирует iOS-плагин. Не `Haptics`:
## это имя уже занято автолоадом, и `Engine.get_singleton()` путался бы.
const SINGLETON := "HapticsIOS"
## Минимум между двумя сериями (мс).
const THROTTLE_MS := 40
## Пауза между тиками одной серии (с): 30 мс — ещё одно событие, но уже слышно 2–3.
const TICK_GAP := 0.03

## Длина серии: LIGHT — 1 тик, MEDIUM — 2, HEAVY — 3.
enum Strength { LIGHT, MEDIUM, HEAVY }

## Запасная вибрация для платформ без плагина: (ms, amplitude) на один тик.
const FALLBACK := {
	Strength.LIGHT: {"ms": 10, "amplitude": 0.35},
	Strength.MEDIUM: {"ms": 16, "amplitude": 0.6},
	Strength.HEAVY: {"ms": 24, "amplitude": 0.9},
}

var enabled := true

var _muted_for_ads := false
## Время последней серии (мс). Ключ один: все отклики — тики selection.
var _last_ms: int = 0
var _plugin: Object = null
var _plugin_checked := false


func _ready() -> void:
	SaveManager.load_game()
	# haptics_enabled — текущий ключ; audio_haptics — старый, для сейвов игроков.
	enabled = _saved_bool("haptics_enabled", _saved_bool("audio_haptics", true))


# --- Публичное API -----------------------------------------------------------

## Тик выбора; `strength` задаёт длину серии (enum Strength, по умолчанию LIGHT).
func selection(strength := Strength.LIGHT) -> void:
	if not _gate():
		return
	var ticks := clampi(int(strength) + 1, 1, 3)
	for index in ticks:
		if index > 0:
			await get_tree().create_timer(TICK_GAP).timeout
		if not enabled or _muted_for_ads or not is_inside_tree():
			return
		_emit_tick(strength)


## Прогреть генератор заранее — убирает задержку первого тика серии.
## Безопасно на любой платформе (без плагина — no-op).
func prepare() -> void:
	var plugin := _native()
	if plugin != null:
		plugin.prepare()


## Заглушить вибрацию на время рекламы (GDD §15).
func mute_for_ads(muted: bool) -> void:
	_muted_for_ads = muted


func set_enabled(value: bool) -> void:
	enabled = value
	SaveManager.set_value("haptics_enabled", value)


# --- Внутреннее --------------------------------------------------------------

## Ворота серии: включено, не реклама, мобилка, троттлинг.
func _gate() -> bool:
	if not enabled or _muted_for_ads or not OS.has_feature("mobile"):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_ms < THROTTLE_MS:
		return false
	_last_ms = now
	return true


func _emit_tick(strength: int) -> void:
	var plugin := _native()
	if plugin != null:
		plugin.selection()
		return
	var fallback: Dictionary = FALLBACK.get(strength, FALLBACK[Strength.LIGHT])
	Input.vibrate_handheld(int(fallback["ms"]), float(fallback["amplitude"]))


func _native() -> Object:
	if not _plugin_checked:
		_plugin_checked = true
		if Engine.has_singleton(SINGLETON):
			_plugin = Engine.get_singleton(SINGLETON)
	return _plugin


func _saved_bool(key: String, fallback: bool) -> bool:
	var value = SaveManager.get_value(key)
	return fallback if value == null else bool(value)

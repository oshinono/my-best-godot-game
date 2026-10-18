extends Node
## Тактильная отдача (GDD §15, docs/haptics.md). Автолоад: Haptics.
##
## Звука в прототипе нет: вся «сочность» — вибрация. Отклик всего двух видов:
## - `selection()` — лёгкий «щелчок» выбора, как системный тик пикера iOS
##   (UISelectionFeedbackGenerator.selectionChanged): тапы, кнопки, шаги;
## - `impact(strength, count)` — удар ощутимой силы (UIImpactFeedbackGenerator):
##   слияние, награда, покупка, ошибка.
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
## - частые отклики гасятся троттлингом THROTTLE_MS, чтобы скролл и
##   перетаскивание не превращались в сплошное дрожание.

## Имя нативного синглтона, который регистрирует iOS-плагин. Не `Haptics`:
## это имя уже занято автолоадом, и `Engine.get_singleton()` путался бы.
const SINGLETON := "HapticsIOS"
## Минимум между двумя откликами (мс).
const THROTTLE_MS := 40

## Сила удара. Номера совпадают с UIImpactFeedbackStyle в iOS (LIGHT = 0 …
## RIGID = 4), поэтому нативная сторона передаёт их без маппинга.
enum Strength { LIGHT, MEDIUM, HEAVY, SOFT, RIGID }

## Запасной импульс для платформ без плагина (ms, amplitude 0.0..1.0).
const FALLBACK := {
	Strength.LIGHT: {"ms": 10, "amplitude": 0.3},
	Strength.MEDIUM: {"ms": 20, "amplitude": 0.6},
	Strength.HEAVY: {"ms": 35, "amplitude": 1.0},
	Strength.SOFT: {"ms": 14, "amplitude": 0.4},
	Strength.RIGID: {"ms": 22, "amplitude": 0.7},
}

var enabled := true

var _muted_for_ads := false
var _last_ms := 0
var _plugin: Object = null
var _plugin_checked := false


func _ready() -> void:
	SaveManager.load_game()
	# haptics_enabled — текущий ключ; audio_haptics — старый, для сейвов игроков.
	enabled = _saved_bool("haptics_enabled", _saved_bool("audio_haptics", true))


# --- Публичное API -----------------------------------------------------------

## Лёгкий «щелчок» выбора: тапы, кнопки, тап генератора, монеты, старт рекламы.
func selection() -> void:
	if not _gate():
		return
	var plugin := _native()
	if plugin != null:
		plugin.selection()
	else:
		Input.vibrate_handheld(10, 0.3)


## Удар силы `strength` (enum Strength), повторённый `count` раз (пауза 80 мс).
func impact(strength := Strength.MEDIUM, count := 1) -> void:
	if not _gate():
		return
	for index in maxi(1, count):
		if not enabled or _muted_for_ads or not is_inside_tree():
			return
		_emit_impact(strength)
		if index < count - 1:
			await get_tree().create_timer(0.08).timeout


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

## Общие ворота отклика: включено, не реклама, мобилка, троттлинг.
func _gate() -> bool:
	if not enabled or _muted_for_ads or not OS.has_feature("mobile"):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_ms < THROTTLE_MS:
		return false
	_last_ms = now
	return true


func _emit_impact(strength: int) -> void:
	var plugin := _native()
	if plugin != null:
		plugin.impact(strength)
		return
	var fallback: Dictionary = FALLBACK.get(strength, FALLBACK[Strength.MEDIUM])
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

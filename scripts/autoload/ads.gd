extends Node

## Обёртка над рекламой: rewarded + interstitial. См. docs/technspike.md.
##
## Геймплей зовёт только этот автолоад, поэтому подключение реального плагина
## AdMob не меняет ни один вызов в игре. Три режима:
##   1. десктоп / аддона нет  → заглушка: результат отдаётся сразу (отладка);
##   2. мобилка + addons/admob → реальный AdMob через scripts/ads/admob_backend.gd;
##   3. Config.ads_use_real = false → заглушка даже на устройстве.
##
## Адаптер грузится через load(), а не preload(): классы плагина (MobileAds,
## RewardedAdLoader, ...) существуют только когда аддон лежит в проекте.

signal rewarded_earned(placement: String, reward: Dictionary)
signal rewarded_failed(placement: String, reason: String)
signal interstitial_shown(placement: String)
signal interstitial_failed(placement: String, reason: String)
signal consent_finished(ok: bool, reason: String)

const ADMOB_BACKEND_PATH := "res://scripts/ads/admob_backend.gd"
## Путь, по которому оказывается аддон после установки (AssetLib «AdMob by poing.studios»).
const ADMOB_ADDON_CFG := "res://addons/admob/plugin.cfg"
## Тестовые unit id Google (безопасны для техспайка, живые деньги не тратятся).
const TEST_UNITS := {
	"admob_rewarded_unit_ios": "ca-app-pub-3940256099942544/1712485313",
	"admob_rewarded_unit_android": "ca-app-pub-3940256099942544/5224354917",
	"admob_interstitial_unit_ios": "ca-app-pub-3940256099942544/4411468910",
	"admob_interstitial_unit_android": "ca-app-pub-3940256099942544/1033173712",
}

## Включено ли реальное SDK (ставится из Config.ads_use_real при _ready()).
var use_real_ads := false

var _backend: RefCounted
var _last_interstitial_ms := 0


func _ready() -> void:
	use_real_ads = bool(_cfg("ads_use_real", false))
	if use_real_ads:
		_backend = _create_backend()
	if _backend == null:
		print("[Ads] заглушка: %s" % _stub_note())


func show_rewarded(placement: String, reward: Dictionary = {}) -> void:
	if _backend == null:
		print("[Ads] rewarded (stub): %s" % placement)
		rewarded_earned.emit(placement, reward)
		return
	var unit := _unit_id("admob_rewarded_unit")
	if unit.is_empty():
		rewarded_failed.emit(placement, "no_unit_id")
		return
	_backend.load_rewarded(
		unit,
		func() -> void:
			_backend.show_rewarded(
				func(_amount: int, _kind: String) -> void:
					rewarded_earned.emit(placement, reward),
				func(reason: String) -> void:
					rewarded_failed.emit(placement, reason)
			),
		func(reason: String) -> void:
			rewarded_failed.emit(placement, reason)
	)


func show_interstitial(placement: String) -> void:
	if _backend == null:
		print("[Ads] interstitial (stub): %s" % placement)
		interstitial_shown.emit(placement)
		return
	var gap := int(_cfg("ads_interstitial_min_interval_sec", 180))
	if gap > 0 and Time.get_ticks_msec() - _last_interstitial_ms < gap * 1000:
		interstitial_failed.emit(placement, "cooldown")
		return
	var unit := _unit_id("admob_interstitial_unit")
	if unit.is_empty():
		interstitial_failed.emit(placement, "no_unit_id")
		return
	_backend.load_interstitial(
		unit,
		func() -> void:
			_last_interstitial_ms = Time.get_ticks_msec()
			_backend.show_interstitial(
				func() -> void:
					interstitial_shown.emit(placement),
				func(reason: String) -> void:
					interstitial_failed.emit(placement, reason)
			),
		func(reason: String) -> void:
			interstitial_failed.emit(placement, reason)
	)


## Запросить UMP-консент (GDPR). Результат — сигнал consent_finished.
## В заглушке считаем консент выданным, чтобы не блокировать тесты.
func request_consent() -> void:
	if _backend == null:
		print("[Ads] consent (stub): сразу разрешено")
		consent_finished.emit(true, "stub")
		return
	_backend.request_consent(
		func(ok: bool, reason: String) -> void:
			consent_finished.emit(ok, reason)
	)


## Работает ли реальное SDK в этой сборке.
func is_real() -> bool:
	return _backend != null


func _create_backend() -> RefCounted:
	var platform := OS.get_name()
	if platform != "iOS" and platform != "Android":
		return null
	if not FileAccess.file_exists(ADMOB_ADDON_CFG):
		return null
	var script := load(ADMOB_BACKEND_PATH) as GDScript
	if script == null:
		push_warning("[Ads] не удалось загрузить адаптер %s" % ADMOB_BACKEND_PATH)
		return null
	var backend: RefCounted = script.new()
	if backend.has_method("initialize"):
		backend.initialize()
	print("[Ads] AdMob подключён (%s)" % platform)
	return backend


## Unit id: сначала Config, потом тестовый Google-id. Пусто → нет рекламы.
func _unit_id(base_key: String) -> String:
	var platform := "ios" if OS.get_name() == "iOS" else "android"
	var key := "%s_%s" % [base_key, platform]
	var value := String(_cfg(key, ""))
	if value.is_empty():
		value = String(TEST_UNITS.get(key, ""))
		if not value.is_empty():
			print("[Ads] %s не задан — беру тестовый Google-id" % key)
	return value


func _stub_note() -> String:
	if not use_real_ads:
		return "Config.ads_use_real = false"
	if OS.get_name() != "iOS" and OS.get_name() != "Android":
		return "десктоп — SDK недоступен"
	return "аддон %s не установлен" % ADMOB_ADDON_CFG


func _cfg(key: String, fallback: Variant) -> Variant:
	var value = Config.get_value(key)
	return fallback if value == null else value

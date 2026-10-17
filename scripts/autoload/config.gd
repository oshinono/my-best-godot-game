extends Node
## Глобальный конфиг и числа баланса.
## Значения по умолчанию лежат локально, при старте могут быть
## перезаписаны удалённым конфигом (server-driven economy, plan §5).

signal config_loaded
signal config_failed(reason: String)

## Пусто = только локальный конфиг. Заполним, когда появится бэкенд.
const REMOTE_CONFIG_URL := ""

## Баланс по умолчанию. Все числа игры держим здесь, не разбрасываем по коду.
var values := {
	# Прототип: сетка 4×5 — клетки и предметы крупные (720/4 ≈ 155 px).
	# Для продакшена вернуть 7×8 (docs/GDD.md §3) или подобрать по метрикам.
	"board_width": 4,
	"board_height": 5,
	"energy_max": 100,
	"energy_regen_seconds": 60,
	"energy_regen_amount": 1,
	"energy_cost_spawn": 1,
	"merge_chain_min_level": 1,

	# --- Экономика (docs/economy.md) ---
	"item_value_base": 5,
	"item_value_growth": 2.05,
	"sell_value_mult": 0.6,
	"order_reward_mult": 2.0,
	"order_xp_mult": 0.5,
	"order_speed_bonus": 1.5,
	"order_speed_window_sec": 1200,
	"order_reroll_cost_gems": 5,
	"gem_chance_order": 0.1,
	"xp_per_level_base": 50,
	"cafe_level_max": 20,
	"order_slots_start": 2,
	"order_slots_level3": 6,
	"order_slots_level4": 12,
	"generator_unlock_pastry": 4,
	"generator_unlock_flowers": 8,
	"rewarded_energy_amount": 15,
	"rewarded_energy_daily_cap": 5,

	# --- Бустеры (docs/GDD.md §18) ---
	"booster_hammer_gems": 5,
	"booster_shuffle_gems": 10,
	"booster_magnet_gems": 15,
	"booster_magnet_count": 3,
	"booster_per_session_limit": 1,
	# Стартовые гемы для тестов (dev). Перед софт-лончем выставить 0.
	"start_gems": 60,

	# --- Аналитика: PostHog (docs/analytics.md) ---
	# Вставить проектный ключ `phc_...` из настроек проекта PostHog.
	"posthog_api_key": "phc_Cz9ydSC2dU83zAzcdhrpc2Sv3BTq6CdcfQBUu8NyjV8M",
	"posthog_host": "https://eu.i.posthog.com",
	"analytics_enabled": true,
	# false = события не уходят, пока игрок не дал согласие (требование GDPR).
	"analytics_consent_default": true,

	# --- Реклама (docs/technspike.md) ---
	# true + аддон addons/admob → реальный AdMob, иначе заглушка.
	"ads_use_real": false,
	"ads_interstitial_min_interval_sec": 180,
	# Пусто = берём тестовый unit id Google (см. Ads.TEST_UNITS).
	"admob_app_id_ios": "",
	"admob_app_id_android": "",
	"admob_rewarded_unit_ios": "",
	"admob_rewarded_unit_android": "",
	"admob_interstitial_unit_ios": "",
	"admob_interstitial_unit_android": "",
	# UMP-форма согласия (GDPR/ATT) — дёргается кнопкой в настройках прототипа.
	"consent_use_ump": true,

	# --- IAP ---
	"iap_use_real": false,
	# Строка через запятую: "gems_small,gems_medium,no_ads" (создать в App Store
	# Connect / Play Console; для техспайка — тестовые товары).
	"iap_products": "gems_small",
	"iap_test_sku": "gems_small",
}

var _loaded := false


func _ready() -> void:
	_load()


func _load() -> void:
	# Локальный override из ресурса, если он есть.
	var path := "res://resources/config_default.tres"
	if ResourceLoader.exists(path):
		var res := load(path)
		if res != null and res.has_method("to_dict"):
			values.merge(res.to_dict(), true)

	_loaded = true
	config_loaded.emit()

	if not REMOTE_CONFIG_URL.is_empty():
		_fetch_remote()


func get_value(key: String) -> Variant:
	return values.get(key)


func _fetch_remote() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_remote_completed.bind(http))
	var err := http.request(REMOTE_CONFIG_URL)
	if err != OK:
		config_failed.emit("request error %d" % err)
		http.queue_free()


func _on_remote_completed(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			values.merge(parsed, true)
			config_loaded.emit()
		else:
			config_failed.emit("bad json")
	else:
		config_failed.emit("http %d result %d" % [code, result])
	http.queue_free()

extends Node
## Аналитика через PostHog (capture API, обычный HTTP POST).
##
## Почему PostHog: бесплатный тариф (1M событий/мес), воронки и retention из коробки,
## нет Firebase-зависимости, можно self-host. Проектный ключ (`phc_...`) — публичный,
## его безопасно держать в клиенте. Персональные API-ключи (`phx_...`) в игру НЕ кладём.
##
## Что собираем о пользователе/платформе, зачем и как это экономит квоту:
## docs/analytics.md §3. Кратко:
##   - профиль устройства/платформы — один раз за установку через `$set_once`;
##   - изменяемое состояние (уровень, монеты, гемы, энергия) — через `$set`,
##     не чаще `analytics_person_interval` секунд;
##   - в каждом событии — только `$lib`, `$lib_version`, `$session_id`,
##     номер сессии и «первый ли это запуск».
## Ничего личного (ни email, ни IDFA) не собирается: distinct_id — случайные 16 байт.

signal event_logged(event_name: String, params: Dictionary)
signal batch_sent(count: int)
signal batch_failed(count: int, reason: String)

const FLUSH_INTERVAL := 30.0
const MAX_BUFFER := 100
const MAX_RETRIES := 3
const RETRY_DELAY := 10.0
const DEFAULT_HOST := "https://us.i.posthog.com"
const LIB_NAME := "godot"
const LIB_VERSION := "0.1.0"
## Профиль установки: id, время первого запуска, число запусков.
const PROFILE_PATH := "user://analytics.cfg"
const SECONDS_IN_DAY := 86400
## Реестр событий: системный id → человекочитаемое английское название.
## В PostHog в колонке Event лежит название («Item: merged»), а системный id
## уезжает свойством `event_id` (`item_merged`): по нему строятся фильтры,
## выгрузки и старые дашборды.
## Новое событие обязательно добавлять сюда: без записи log_event пишет warning.
const EVENTS: Dictionary = {
	"game_opened": "Game: opened",
	"main_ready": "Main: scene ready",
	"session_start": "Session: started",
	"first_open": "Install: very first launch",
	"consent_granted": "Consent: granted",
	"consent_finished": "Consent: dialog closed",
	"ftue_step": "Tutorial: step passed",
	"generator_tap": "Generator: tapped",
	"item_merged": "Item: merged",
	"item_sold": "Item: sold",
	"sell_all": "Board: sold everything",
	"booster_used": "Booster: used",
	"booster_target": "Hammer: target picked",
	"energy_empty_shown": "Energy: out-of-energy screen shown",
	"order_completed": "Order: completed",
	"order_rerolled": "Order: rerolled for gems",
	"level_up": "Level: up",
	"rewarded_started": "Rewarded ad: started",
	"rewarded_completed": "Rewarded ad: reward granted",
	"rewarded_failed": "Rewarded ad: failed",
	"interstitial_shown": "Interstitial ad: shown",
	"interstitial_failed": "Interstitial ad: failed",
	"purchase_succeeded": "Purchase: succeeded",
	"purchase_failed": "Purchase: failed",
	"purchases_restored": "Purchases: restored",
	"technospike_action": "Tech spike: action",
}

## Заполняется из Config. Без `posthog_api_key` события не уходят.
var enabled := false
## Согласие пользователя (UMP на Android / ATT+UMP на iOS). Без согласия события не отправляются.
var consent_granted := true
var api_key := ""
var host := DEFAULT_HOST
var distinct_id := ""
var session_id := ""
## Номер сессии (запуска) у этого устройства: 1 — первый запуск.
var session_number: int = 1
## Unix-время первого запуска (для `days_since_install`).
var first_seen_at: int = 0

## Изменяемое состояние игрока, ждёт отправки через `$set` (троттлинг).
var _person: Dictionary = {}
var _person_sent_at: int = 0
var _person_interval: float = 60.0
var _collect_device := true
## Профиль устройства/платформы — считается один раз в _ready().
var _device: Dictionary = {}
## Профиль установки из user://analytics.cfg.
var _profile: Dictionary = {}

var _buffer: Array[Dictionary] = []
var _inflight: Array[Dictionary] = []
var _sending := false
var _retries := 0
var _http: HTTPRequest
var _timer: Timer
var _retry_timer: Timer


func _ready() -> void:
	api_key = str(_cfg("posthog_api_key", ""))
	host = str(_cfg("posthog_host", DEFAULT_HOST))
	enabled = bool(_cfg("analytics_enabled", true)) and not api_key.is_empty()
	consent_granted = bool(_cfg("analytics_consent_default", true))
	_person_interval = float(_cfg("analytics_person_interval", 60.0))
	_collect_device = bool(_cfg("analytics_collect_device", true))

	_load_profile()
	distinct_id = String(_profile.get("id", ""))
	first_seen_at = int(_profile.get("first_seen_at", 0))
	session_number = int(_profile.get("sessions", 0)) + 1
	_profile["sessions"] = session_number
	_save_profile()
	session_id = _new_id()
	_device = _collect_device_props() if _collect_device else {}

	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_timer = Timer.new()
	_timer.wait_time = FLUSH_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(flush)
	add_child(_timer)

	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_DELAY
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(flush)
	add_child(_retry_timer)

	if not enabled:
		print("[Analytics] выключено: не задан posthog_api_key в Config")
		return

	# Профиль устройства уходит один раз за установку: `$set_once` не перезапишет
	# значения при следующих запусках (модель железа не меняется).
	if not _device.is_empty():
		identify(_device, true)
	identify(_session_person_props())
	log_event("session_start", {
		"session_number": session_number,
		"days_since_install": _days_since_install(),
		"is_first_session": session_number <= 1,
	})
	if session_number <= 1:
		log_event("first_open", {
			"app_version": _app_version(),
			"platform": OS.get_name(),
			"device_type": _device_type(),
			"locale": OS.get_locale(),
		})


func _notification(what: int) -> void:
	# Отправляем накопленное, когда приложение сворачивают или закрывают.
	# force_person: состояние игрока на выходе пишем, не дожидаясь троттлинга.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush(true)


## Публичное API. Все игровые события — через него.
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not enabled or not consent_granted or event_name.is_empty():
		return

	# В колонке Event в PostHog лежит читаемое название, а системный id едет
	# свойством event_id: по нему строятся фильтры (docs/analytics.md, §5).
	var title := _event_title(event_name)
	var props := {
		"$lib": LIB_NAME,
		"$lib_version": LIB_VERSION,
		"$session_id": session_id,
		"session_number": session_number,
		"is_first_session": session_number <= 1,
	}
	if title != event_name:
		props["event_id"] = event_name
	props.merge(params, true)

	_buffer.append({
		"event": title,
		"distinct_id": distinct_id,
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"properties": props,
	})
	event_logged.emit(event_name, params)

	if _buffer.size() >= MAX_BUFFER:
		flush()


## Человекочитаемое название события для PostHog. Служебные события PostHog
## (`$set`, `$set_once`) и незарегистрированные имена уходят без изменений.
func _event_title(event_name: String) -> String:
	if event_name.begins_with("$"):
		return event_name
	if EVENTS.has(event_name):
		return String(EVENTS[event_name])
	push_warning("[Analytics] у события %s нет названия в EVENTS (analytics.gd)" % event_name)
	return event_name


## Обновить свойства пользователя (person properties) в PostHog.
## `once = true` → `$set_once`: значение не перезапишется при следующих запусках
## (железо, платформа, первая версия приложения).
func identify(person_properties: Dictionary, once: bool = false) -> void:
	if person_properties.is_empty():
		return
	log_event("$set_once" if once else "$set", person_properties)


## Изменяемое состояние игрока (уровень, монеты, гемы, энергия, поле).
## Копится и уходит не чаще `analytics_person_interval` секунд: каждое `$set`
## — это отдельное событие в квоте PostHog.
func update_user_props(props: Dictionary) -> void:
	if not enabled or not consent_granted or props.is_empty():
		return
	_person.merge(props, true)
	_send_person()


## Вызывать после экрана согласия (UMP/ATT).
func set_consent(granted: bool) -> void:
	consent_granted = granted
	if granted:
		log_event("consent_granted")
	else:
		_buffer.clear()
		_person.clear()


## Отправить накопленный буфер. Безопасно вызывать часто.
## `force_person` — не ждать троттлинга (вызов на сворачивании/закрытии).
func flush(force_person: bool = false) -> void:
	if not enabled or not consent_granted or api_key.is_empty():
		return

	_send_person(force_person)
	if _sending or _buffer.is_empty():
		return

	_inflight = _buffer.duplicate()
	_buffer.clear()
	_sending = true

	var payload := {"api_key": api_key, "batch": _inflight}
	var url := host.path_join("batch/")
	var err := _http.request(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_sending = false
		_requeue("request error %d" % err)


func _on_request_completed(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var sent := _inflight.size()
	_sending = false

	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_retries = 0
		_inflight.clear()
		batch_sent.emit(sent)
		return

	_requeue("result %d http %d %s" % [result, code, body.get_string_from_utf8().substr(0, 200)])


func _requeue(reason: String) -> void:
	var count := _inflight.size()
	batch_failed.emit(count, reason)
	push_warning("[Analytics] %s" % reason)

	var restored := _inflight.duplicate()
	_inflight.clear()

	if _retries >= MAX_RETRIES:
		_retries = 0
		return  # события теряем, чтобы не течь памятью

	_retries += 1
	restored.append_array(_buffer)
	_buffer = restored.slice(0, MAX_BUFFER * 2)
	_retry_timer.start()


# --- Профиль пользователя ----------------------------------------------------

## Отправить накопленное состояние игрока, если прошёл интервал (или force).
func _send_person(force: bool = false) -> void:
	if _person.is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	if not force and now - _person_sent_at < int(_person_interval):
		return
	_person_sent_at = now
	var snapshot := _person.duplicate()
	_person.clear()
	identify(snapshot)


## Изменяемые свойства, которые обновляем каждый запуск.
func _session_person_props() -> Dictionary:
	return {
		"platform": OS.get_name(),
		"app_version": _app_version(),
		"session_number": session_number,
		"days_since_install": _days_since_install(),
		"locale": OS.get_locale(),
		"device_type": _device_type(),
		"last_seen_at": int(Time.get_unix_time_from_system()),
	}


## Профиль устройства/платформы. Свойства с `$` — «родные» для PostHog: по ним
## из коробки работают дашборды Devices/OS/GeoIP и разбивка по сегментам.
func _collect_device_props() -> Dictionary:
	var window := DisplayServer.window_get_size()
	var screen := DisplayServer.screen_get_size()
	var memory := OS.get_memory_info()
	var info := Engine.get_version_info()
	var tz := Time.get_time_zone_from_system()
	return {
		"$os": OS.get_name(),
		"$os_version": OS.get_version(),
		"$device_type": _device_type(),
		"$device_model": OS.get_model_name(),
		"$app_version": _app_version(),
		"$app_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"$locale": OS.get_locale(),
		"$timezone": String(tz.get("name", "")),
		"$screen_width": window.x,
		"$screen_height": window.y,
		"screen_native_width": screen.x,
		"screen_native_height": screen.y,
		"screen_dpi": DisplayServer.screen_get_dpi(),
		"screen_count": DisplayServer.get_screen_count(),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"touchscreen": DisplayServer.is_touchscreen_available(),
		"cpu_count": OS.get_processor_count(),
		"cpu_name": OS.get_processor_name(),
		"memory_mb": int(floor(float(memory.get("physical", 0)) / 1048576.0)),
		"renderer": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"renderer_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"engine_version": str(info.get("string", "")),
		"engine_build": str(info.get("build", "")),
		"engine_arch": Engine.get_architecture_name(),
		"is_debug_build": OS.is_debug_build(),
		"is_editor": OS.has_feature("editor"),
		"locale_language": OS.get_locale_language(),
		"install_id_created_at": first_seen_at,
	}


## mobile / desktop / web — грубая категория для сегментации.
func _device_type() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("mobile"):
		return "mobile"
	return "desktop"


func _app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))


func _days_since_install() -> int:
	if first_seen_at <= 0:
		return 0
	var seconds := float(Time.get_unix_time_from_system() - first_seen_at)
	return maxi(0, int(floor(seconds / float(SECONDS_IN_DAY))))


# --- Профиль установки -------------------------------------------------------

## Читает user://analytics.cfg: id, время первого запуска, число запусков.
func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		_profile = {
			"id": str(cfg.get_value("user", "id", "")),
			"first_seen_at": int(cfg.get_value("user", "first_seen_at", 0)),
			"sessions": int(cfg.get_value("user", "sessions", 0)),
		}
	if String(_profile.get("id", "")).is_empty():
		_profile["id"] = _new_id()
	if int(_profile.get("first_seen_at", 0)) <= 0:
		_profile["first_seen_at"] = int(Time.get_unix_time_from_system())


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("user", "id", String(_profile.get("id", "")))
	cfg.set_value("user", "first_seen_at", int(_profile.get("first_seen_at", 0)))
	cfg.set_value("user", "sessions", int(_profile.get("sessions", 0)))
	cfg.set_value("user", "last_seen_at", int(Time.get_unix_time_from_system()))
	cfg.save(PROFILE_PATH)


func _cfg(key: String, default_value: Variant) -> Variant:
	if Config == null:
		return default_value
	var v: Variant = Config.get_value(key)
	return default_value if v == null else v


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

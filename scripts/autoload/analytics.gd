extends Node
## Аналитика через PostHog (capture API, обычный HTTP POST).
##
## Почему PostHog: бесплатный тариф (1M событий/мес), воронки и retention из коробки,
## нет Firebase-зависимости, можно self-host. Проектный ключ (`phc_...`) — публичный,
## его безопасно держать в клиенте. Персональные API-ключи (`phx_...`) в игру НЕ кладём.
##
## Подробности и список событий: docs/analytics.md

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

## Заполняется из Config. Без `posthog_api_key` события не уходят.
var enabled := false
## Согласие пользователя (UMP на Android / ATT+UMP на iOS). Без согласия события не отправляются.
var consent_granted := true
var api_key := ""
var host := DEFAULT_HOST
var distinct_id := ""
var session_id := ""

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
	distinct_id = _ensure_distinct_id()
	session_id = _new_id()

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

	identify({
		"platform": OS.get_name(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
	})
	log_event("session_start")


func _notification(what: int) -> void:
	# Отправляем накопленное, когда приложение сворачивают или закрывают.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


## Публичное API. Все игровые события — через него.
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not enabled or not consent_granted or event_name.is_empty():
		return

	var props := {
		"$lib": LIB_NAME,
		"$lib_version": LIB_VERSION,
		"$session_id": session_id,
	}
	props.merge(params, true)

	_buffer.append({
		"event": event_name,
		"distinct_id": distinct_id,
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"properties": props,
	})
	event_logged.emit(event_name, params)

	if _buffer.size() >= MAX_BUFFER:
		flush()


## Обновить свойства пользователя (person properties) в PostHog.
func identify(person_properties: Dictionary) -> void:
	log_event("$set", person_properties)


## Вызывать после экрана согласия (UMP/ATT).
func set_consent(granted: bool) -> void:
	consent_granted = granted
	if granted:
		log_event("consent_granted")
	else:
		_buffer.clear()


## Отправить накопленный буфер. Безопасно вызывать часто.
func flush() -> void:
	if not enabled or not consent_granted or api_key.is_empty():
		return
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


func _cfg(key: String, default_value: Variant) -> Variant:
	if Config == null:
		return default_value
	var v: Variant = Config.get_value(key)
	return default_value if v == null else v


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _ensure_distinct_id() -> String:
	var cfg := ConfigFile.new()
	var path := "user://analytics.cfg"
	if cfg.load(path) == OK:
		var existing := str(cfg.get_value("user", "id", ""))
		if not existing.is_empty():
			return existing

	var id := _new_id()
	cfg.set_value("user", "id", id)
	cfg.save(path)
	return id

extends Node

## Обёртка над покупками. См. docs/technspike.md.
##
## iOS: нативный синглтон `InAppStore` (godot-sdk-integrations/godot-ios-plugins).
##   События приходят в очередь: get_pending_event_count()/pop_pending_event().
## Android: синглтон `GodotGooglePlayBilling` (addons/GodotGooglePlayBilling):
##   вызовы напрямую, результаты — сигналами плагина.
##
## Заглушка (десктоп/редактор/плагина нет/iap_use_real = false): покупка сразу
## успешна, чтобы логику магазина можно было отлаживать без устройств.
## Серверную валидацию чеков добавим в фазе 3 (plan §3).

signal purchase_succeeded(sku: String, receipt: Dictionary)
signal purchase_failed(sku: String, reason: String)
signal purchases_restored(skus: PackedStringArray)

## Тип продукта для Google Play: 0 — in-app, 1 — подписка.
const ANDROID_INAPP := 0
## Состояния покупки Google Play: 1 — оплачено, 2 — ожидает оплаты (наличные,
## банковский перевод): это не ошибка, покупка придёт позже через purchase_updated.
const ANDROID_PURCHASED := 1
const ANDROID_PENDING := 2
const IOS_POLL_SEC := 1.0

## Включены ли реальные покупки (ставится из Config.iap_use_real при _ready()).
var use_real_iap := false
## Что уже куплено в этой сессии/на устройстве (дублирует SaveManager в game.gd).
var owned: Dictionary = {}

var _ios: Object
var _android: Object
var _android_ready := false
var _ios_restored := PackedStringArray()


func _ready() -> void:
	use_real_iap = bool(_cfg("iap_use_real", false))
	if not use_real_iap:
		print("[Iap] заглушка: Config.iap_use_real = false")
		return
	var platform := OS.get_name()
	if platform == "iOS" and Engine.has_singleton("InAppStore"):
		_setup_ios(Engine.get_singleton("InAppStore"))
	elif platform == "Android" and Engine.has_singleton("GodotGooglePlayBilling"):
		_setup_android(Engine.get_singleton("GodotGooglePlayBilling"))
	else:
		print("[Iap] плагин покупок не найден (%s) — заглушка" % platform)


func purchase(sku: String) -> void:
	if _ios != null:
		_ios.purchase({"product_id": sku})
		return
	if _android != null:
		_call(_android, "purchase", [sku])
		return
	print("[Iap] purchase (stub): %s" % sku)
	owned[sku] = true
	purchase_succeeded.emit(sku, {"stub": true})


func restore() -> void:
	if _ios != null:
		_ios_restored = PackedStringArray()
		_ios.restore_purchases()
		return
	if _android != null:
		_call(_android, "query_purchases", [ANDROID_INAPP])
		return
	purchases_restored.emit(PackedStringArray(owned.keys()))


func is_owned(sku: String) -> bool:
	return owned.get(sku, false)


# --- iOS ---------------------------------------------------------------------

func _setup_ios(appstore: Object) -> void:
	_ios = appstore
	_call(_ios, "set_auto_finish_transaction", [true])
	var timer := Timer.new()
	timer.wait_time = IOS_POLL_SEC
	timer.autostart = true
	timer.timeout.connect(_poll_ios)
	add_child(timer)
	_ios.request_product_info({"product_ids": _product_ids()})
	print("[Iap] iOS InAppStore подключён")


func _poll_ios() -> void:
	if _ios == null:
		return
	while int(_ios.get_pending_event_count()) > 0:
		var event: Variant = _ios.pop_pending_event()
		if typeof(event) == TYPE_DICTIONARY:
			_handle_ios_event(event)


func _handle_ios_event(event: Dictionary) -> void:
	var result := String(event.get("result", ""))
	var type := String(event.get("type", ""))
	if result == "error" or result == "unhandled":
		var reason := String(event.get("error", {}).get("message", result))
		print("[Iap] iOS %s: %s" % [type, reason])
		if type == "purchase":
			purchase_failed.emit(String(event.get("product_id", "")), reason)
		return
	match type:
		"product_info":
			print("[Iap] iOS каталог: %s" % str(event.get("ids", [])))
		"purchase":
			var sku := String(event.get("product_id", ""))
			owned[sku] = true
			purchase_succeeded.emit(sku, event)
		"restore":
			var sku2 := String(event.get("product_id", ""))
			owned[sku2] = true
			_ios_restored.append(sku2)
		"completed":
			purchases_restored.emit(_ios_restored)
			_ios_restored = PackedStringArray()


# --- Android -----------------------------------------------------------------

func _setup_android(billing: Object) -> void:
	_android = billing
	if _android.has_signal("connected"):
		_android.connected.connect(_on_android_connected)
	if _android.has_signal("disconnected"):
		_android.disconnected.connect(func() -> void: _android_ready = false)
	if _android.has_signal("purchase_completed"):
		_android.purchase_completed.connect(_on_android_purchase)
	if _android.has_signal("purchase_updated"):
		_android.purchase_updated.connect(_on_android_purchase)
	if _android.has_signal("purchases_query_completed"):
		_android.purchases_query_completed.connect(_on_android_restore)
	if not _call(_android, "start_connection", []):
		print("[Iap] Android Billing: нет метода start_connection — сверь версию плагина")
	print("[Iap] Android Billing подключён")


func _on_android_connected() -> void:
	_android_ready = true
	_call(_android, "query_product_details", [_product_ids(), ANDROID_INAPP])
	_call(_android, "query_purchases", [ANDROID_INAPP])


func _on_android_purchase(data: Dictionary) -> void:
	var sku := String(data.get("sku", ""))
	var ids: Variant = data.get("ids")
	if sku.is_empty() and typeof(ids) == TYPE_ARRAY and not (ids as Array).is_empty():
		sku = String((ids as Array)[0])
	var state := int(data.get("state", -1))
	if sku.is_empty():
		return
	if state == ANDROID_PENDING:
		print("[Iap] Android: покупка %s ожидает оплаты" % sku)
		return
	if state != ANDROID_PURCHASED:
		purchase_failed.emit(sku, "state_%d" % state)
		return
	owned[sku] = true
	purchase_succeeded.emit(sku, data)
	var token := String(data.get("purchase_token", ""))
	# Расходуемые товары (гемы) нужно consume, иначе повторная покупка невозможна.
	# Одноразовые (starter_pack) — acknowledge, чтобы не откатились через 3 дня.
	if _is_consumable(sku):
		if not _call(_android, "consume_purchase", [token]):
			_call(_android, "acknowledge_purchase", [token])
	else:
		_call(_android, "acknowledge_purchase", [token])


## Расходуемый ли SKU: true, если грант без once (см. Config.iap_grants).
func _is_consumable(sku: String) -> bool:
	var table = Config.get_value("iap_grants")
	if typeof(table) != TYPE_DICTIONARY:
		return false
	var raw = (table as Dictionary).get(sku)
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	return not bool((raw as Dictionary).get("once", false))


func _on_android_restore(purchases: Array) -> void:
	var skus := PackedStringArray()
	for entry in purchases:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = entry
		if int(data.get("state", -1)) != ANDROID_PURCHASED:
			continue
		var sku := String(data.get("sku", ""))
		if not sku.is_empty():
			owned[sku] = true
			skus.append(sku)
	purchases_restored.emit(skus)


# --- Общее -------------------------------------------------------------------

## Список товаров из Config: "gems_small,gems_medium,no_ads" → PackedStringArray.
func _product_ids() -> PackedStringArray:
	var raw := String(_cfg("iap_products", ""))
	var result := PackedStringArray()
	for part in raw.split(",", false):
		var id := part.strip_edges()
		if not id.is_empty():
			result.append(id)
	if result.is_empty():
		var test := String(_cfg("iap_test_sku", ""))
		if not test.is_empty():
			result.append(test)
	return result


## Динамический вызов: метода может не быть в другой версии плагина.
func _call(target: Object, method: String, args: Array) -> bool:
	if target == null or not target.has_method(method):
		return false
	target.callv(method, args)
	return true


func _cfg(key: String, fallback: Variant) -> Variant:
	var value = Config.get_value(key)
	return fallback if value == null else value

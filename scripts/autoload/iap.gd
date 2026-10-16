extends Node
## Обёртка над покупками. Заглушка для MVP-логики.
## Серверную валидацию добавим в фазе 3 (plan §3).

signal purchase_succeeded(sku: String, receipt: Dictionary)
signal purchase_failed(sku: String, reason: String)
signal purchases_restored(skus: PackedStringArray)

## Переключим на true после техспайка плагина.
var use_real_iap := false
var owned: Dictionary = {}


func purchase(sku: String) -> void:
	if use_real_iap:
		_purchase_real(sku)
		return
	print("[Iap] purchase (stub): %s" % sku)
	owned[sku] = true
	purchase_succeeded.emit(sku, {"stub": true})


func restore() -> void:
	if use_real_iap:
		_restore_real()
		return
	purchases_restored.emit(PackedStringArray(owned.keys()))


func is_owned(sku: String) -> bool:
	return owned.get(sku, false)


func _purchase_real(sku: String) -> void:
	# TODO(техспайк): вызвать Google Play Billing / iOS IAP плагин.
	purchase_failed.emit(sku, "not_implemented")


func _restore_real() -> void:
	# TODO(техспайк): запросить список владений у плагина.
	purchases_restored.emit(PackedStringArray())

extends Node

## Монетизация: rewarded-энергия, interstitial, консент и покупки (IAP), а также
## кнопки техспайка в настройках (docs/technspike.md, docs/GDD.md §6, §9).
## Дочерний узел Game: слушает автолоады Ads/Iap, начисляет награды через
## Wallet/Energy/Meta, а с интерфейсом говорит только сигналами.
##
## Ключи сейва: `iap_owned` (купленные sku), `rewarded_energy_day` и
## `rewarded_energy_count` (лимит rewarded-энергии на день).

## Сообщение игроку (тост). kind: "info" | "error" | "success".
signal toast_requested(text: String, kind: String, icon: Texture2D)
## Поменялась доступность «энергии за рекламу» — перерисовать экран энергии.
signal reward_state_changed

## Силы вибрации — константой скрипта, см. комментарий у HAPTICS в game.gd.
const HAPTICS := preload("res://scripts/autoload/haptics.gd")
const ENERGY_ICON := preload("res://assets/ui/theme/icon_energy.png")


func _ready() -> void:
	Ads.rewarded_earned.connect(_on_rewarded_earned)
	Ads.rewarded_failed.connect(_on_rewarded_failed)
	Ads.interstitial_shown.connect(_on_interstitial_shown)
	Ads.interstitial_failed.connect(_on_interstitial_failed)
	Ads.consent_finished.connect(_on_consent_finished)
	Iap.purchase_succeeded.connect(_on_purchase_succeeded)
	Iap.purchase_failed.connect(_on_purchase_failed)
	Iap.purchases_restored.connect(_on_purchases_restored)


# --- Rewarded-энергия (docs/GDD.md §6, §9) -----------------------------------

## Кнопка «энергия за рекламу» на экране энергии.
func request_rewarded_energy() -> void:
	var amount := int(_cfg_num("rewarded_energy_amount", 15.0))
	var cap := int(_cfg_num("rewarded_energy_daily_cap", 5.0))
	if cap > 0 and rewarded_energy_today() >= cap:
		_toast("Лимит rewarded за сегодня исчерпан (%d)" % cap, "error")
		reward_state_changed.emit()
		return
	Haptics.selection()
	Haptics.mute_for_ads(true)
	Analytics.log_event("rewarded_started", {"placement": "energy"})
	Ads.show_rewarded("energy", {"energy": amount})


## Состояние кнопки в попапе энергии: {available, text, hint}.
func energy_reward_state() -> Dictionary:
	var amount := int(_cfg_num("rewarded_energy_amount", 15.0))
	var cap := int(_cfg_num("rewarded_energy_daily_cap", 5.0))
	var left := maxi(0, cap - rewarded_energy_today())
	var available := cap <= 0 or left > 0
	var hint := "Осталось сегодня: %d" % left
	if not available:
		hint = "Лимит на сегодня исчерпан — приходи завтра"
	return {"available": available, "text": "+%d энергии за рекламу" % amount, "hint": hint}


func rewarded_energy_today() -> int:
	var day := Meta.local_day()
	if int(SaveManager.get_value("rewarded_energy_day", -1)) != day:
		return 0
	return int(SaveManager.get_value("rewarded_energy_count", 0))


func _count_rewarded_energy() -> void:
	var day := Meta.local_day()
	var count := rewarded_energy_today() + 1
	SaveManager.set_value("rewarded_energy_day", day)
	SaveManager.set_value("rewarded_energy_count", count)


func _on_rewarded_earned(placement: String, reward: Dictionary) -> void:
	Haptics.mute_for_ads(false)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	# Техспайк: rewarded из настроек не выдаёт энергию — только подтверждает,
	# что колбэк награды дошёл с устройства.
	if placement != "energy":
		Analytics.log_event("rewarded_completed", {"placement": placement, "reward": reward})
		_toast("Реклама: награда получена (%s)" % placement, "success")
		return
	var amount := int(reward.get("energy", int(_cfg_num("rewarded_energy_amount", 15.0))))
	Energy.add(amount)
	_count_rewarded_energy()
	Analytics.log_event("rewarded_completed", {"placement": placement, "amount": amount})
	_toast("Энергия: +%d" % amount, "success", ENERGY_ICON)
	reward_state_changed.emit()


func _on_rewarded_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	Analytics.log_event("rewarded_failed", {"placement": placement, "reason": reason})
	_toast("Реклама недоступна: %s" % reason, "error")
	reward_state_changed.emit()


# --- Техспайк: реклама, консент, покупки (docs/technspike.md) ----------------

## Кнопки в настройках прототипа: проверяем рекламу/консент/IAP на устройстве.
## action: "rewarded" | "interstitial" | "consent" | "purchase" | "restore".
func technospike(action: String) -> void:
	Analytics.log_event("technospike_action", {"action": action})
	match action:
		"rewarded":
			_toast("Техспайк: запрашиваем rewarded…", "info")
			Haptics.mute_for_ads(true)
			Ads.show_rewarded("technospike", {})
		"interstitial":
			_toast("Техспайк: запрашиваем interstitial…", "info")
			Haptics.mute_for_ads(true)
			Ads.show_interstitial("technospike")
		"consent":
			_toast("Техспайк: запрашиваем консент…", "info")
			Ads.request_consent()
		"purchase":
			var sku := String(Config.get_value("iap_test_sku"))
			if sku.is_empty():
				sku = "gems_small"
			_toast("Техспайк: покупка %s…" % sku, "info")
			Iap.purchase(sku)
		"restore":
			_toast("Техспайк: восстановление покупок…", "info")
			Iap.restore()
		_:
			_toast("Неизвестное действие техспайка: %s" % action, "error")


func _on_interstitial_shown(placement: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_shown", {"placement": placement})
	_toast("Interstitial показан (%s)" % placement, "success")


func _on_interstitial_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_failed", {"placement": placement, "reason": reason})
	_toast("Interstitial недоступен: %s" % reason, "error")


func _on_consent_finished(ok: bool, reason: String) -> void:
	Analytics.log_event("consent_finished", {"ok": ok, "reason": reason})
	if ok:
		Analytics.set_consent(true)
		_toast("Консент получен (%s)" % reason, "success")
	else:
		# Без согласия аналитика не должна отправлять события.
		Analytics.set_consent(false)
		_toast("Консент не получен: %s" % reason, "error")


# --- Покупки -------------------------------------------------------------------

func _on_purchase_succeeded(sku: String, receipt: Dictionary) -> void:
	var list := _iap_owned()
	var first_purchase := not list.has(sku)
	if first_purchase:
		list.append(sku)
	SaveManager.set_value("iap_owned", list)
	var suffix := _grant_iap(sku, first_purchase)
	Haptics.selection(HAPTICS.Strength.HEAVY)
	Analytics.log_event("purchase_succeeded", {"sku": sku, "keys": receipt.keys()})
	_toast("Покупка ок: %s%s" % [sku, suffix], "success")
	# Покупка за реальные деньги — на диск сразу, без отложенного таймера.
	SaveManager.flush()


func _on_purchase_failed(sku: String, reason: String) -> void:
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	Analytics.log_event("purchase_failed", {"sku": sku, "reason": reason})
	_toast("Покупка не прошла (%s): %s" % [sku, reason], "error")


func _on_purchases_restored(skus: PackedStringArray) -> void:
	var list := _iap_owned()
	var granted := PackedStringArray()
	for sku in skus:
		if list.has(sku):
			continue
		list.append(sku)
		# После переустановки save пуст: одноразовые товары нужно выдать заново,
		# расходуемые (гемы) при restore не начисляем.
		var suffix := _grant_restored_iap(sku)
		if not suffix.is_empty():
			granted.append(sku)
	SaveManager.set_value("iap_owned", list)
	Analytics.log_event("purchases_restored", {"count": skus.size()})
	var text := "Восстановлено покупок: %d" % skus.size()
	if not granted.is_empty():
		text += " (+" + ", ".join(granted) + ")"
	_toast(text, "success")
	SaveManager.flush()


## Выдать одноразовый товар при восстановлении. Расходуемые — пропускаем.
func _grant_restored_iap(sku: String) -> String:
	var table = Config.get_value("iap_grants")
	if typeof(table) != TYPE_DICTIONARY:
		return ""
	var raw = (table as Dictionary).get(sku)
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	if not bool((raw as Dictionary).get("once", false)):
		return ""
	return _grant_iap(sku, true)


## Список sku, которые игрок уже купил (ключ save: iap_owned).
func _iap_owned() -> Array:
	var saved = SaveManager.get_value("iap_owned", [])
	if typeof(saved) == TYPE_ARRAY:
		return (saved as Array).duplicate()
	return []


## Выдать товар за SKU. Возвращает текстовый суффикс для статуса.
## Гранты описаны в Config.iap_grants; restore использует _grant_restored_iap().
func _grant_iap(sku: String, first_purchase: bool) -> String:
	var table = Config.get_value("iap_grants")
	if typeof(table) != TYPE_DICTIONARY:
		return ""
	var raw = (table as Dictionary).get(sku)
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	var grant: Dictionary = raw
	if bool(grant.get("once", false)) and not first_purchase:
		return ""
	var parts := PackedStringArray()
	var gems := int(grant.get("gems", 0))
	if gems > 0:
		Wallet.add_gems(gems)
		parts.append("+%d гемов" % gems)
	var coins := int(grant.get("coins", 0))
	if coins > 0:
		Wallet.add_coins(coins)
		parts.append("+%d монет" % coins)
	var energy := int(grant.get("energy", 0))
	if energy > 0:
		Energy.add(energy)
		parts.append("+%d энергии" % energy)
	var cat := String(grant.get("cat", ""))
	if not cat.is_empty() and Meta.grant_cat(cat):
		parts.append("кот открыт")
	if parts.is_empty():
		return ""
	return " (%s)" % ", ".join(parts)


func _toast(text: String, kind := "info", icon: Texture2D = null) -> void:
	toast_requested.emit(text, kind, icon)


func _cfg_num(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

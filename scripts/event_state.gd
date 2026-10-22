extends RefCounted

## Ивент «на неделю» (MVP): очки за заказы и крупные слияния → шкала наград.
##
## Ивент стартует при первом запуске игры с этим event_id и длится
## Config.event_days суток. Всё состояние — в сейве под ключами
## event_<id>_start / _points / _claimed, поэтому новый ивент = новый event_id
## в Config (в т. ч. удалённом), старый прогресс не мешает.
## Отдельной временной цепочки предметов пока нет — см. plan.md.

const DAY := 86400


static func event_id() -> String:
	return String(Config.get_value("event_id"))


static func title() -> String:
	return String(Config.get_value("event_title"))


static func _key(suffix: String) -> String:
	return "event_%s_%s" % [event_id(), suffix]


## Запомнить старт при первом знакомстве с ивентом.
static func ensure_started() -> void:
	if int(SaveManager.get_value(_key("start"), 0)) <= 0:
		SaveManager.set_value(_key("start"), int(Time.get_unix_time_from_system()))


static func end_time() -> int:
	var start := int(SaveManager.get_value(_key("start"), 0))
	return start + int(Config.get_value("event_days")) * DAY


static func is_active() -> bool:
	return int(Time.get_unix_time_from_system()) < end_time()


static func points() -> int:
	return int(SaveManager.get_value(_key("points"), 0))


static func add_points(amount: int) -> void:
	if amount <= 0 or not is_active():
		return
	SaveManager.set_value(_key("points"), points() + amount)


static func milestones() -> Array:
	var list = Config.get_value("event_milestones")
	return list if typeof(list) == TYPE_ARRAY else []


static func goal() -> int:
	var list := milestones()
	return int((list.back() as Dictionary).get("points", 1)) if not list.is_empty() else 1


static func claimed() -> Array:
	var list = SaveManager.get_value(_key("claimed"), [])
	return list if typeof(list) == TYPE_ARRAY else []


static func is_claimable(index: int) -> bool:
	var list := milestones()
	if index < 0 or index >= list.size() or claimed().has(index):
		return false
	return points() >= int((list[index] as Dictionary).get("points", 0))


static func has_claimable() -> bool:
	for i in milestones().size():
		if is_claimable(i):
			return true
	return false


## Отметить награду полученной и вернуть её словарь ({coins, gems, energy}).
## Пусто — забирать нечего.
static func claim(index: int) -> Dictionary:
	if not is_claimable(index):
		return {}
	var list := claimed()
	list.append(index)
	SaveManager.set_value(_key("claimed"), list)
	return (milestones()[index] as Dictionary).get("reward", {})


## Строки шкалы для попапа: [{points, text, state, missing}].
static func rows() -> Array:
	var out := []
	var have := points()
	var done := claimed()
	var list := milestones()
	for i in list.size():
		var m: Dictionary = list[i]
		var need := int(m.get("points", 0))
		var state := "claimed" if done.has(i) else ("ready" if have >= need else "locked")
		out.append({"points": need, "text": reward_text(m.get("reward", {})),
			"state": state, "missing": maxi(0, need - have)})
	return out


static func reward_text(reward: Dictionary) -> String:
	var parts := PackedStringArray()
	if reward.has("coins"):
		parts.append("+%d монет" % int(reward["coins"]))
	if reward.has("gems"):
		parts.append("+%d гемов" % int(reward["gems"]))
	if reward.has("energy"):
		parts.append("+%d энергии" % int(reward["energy"]))
	return ", ".join(parts)


static func time_left_text() -> String:
	var left := maxi(0, end_time() - int(Time.get_unix_time_from_system()))
	var days := floori(left / float(DAY))
	var hours := floori((left % DAY) / 3600.0)
	if days > 0:
		return "%d д %d ч" % [days, hours]
	return "%d ч %d мин" % [hours, floori((left % 3600) / 60.0)]

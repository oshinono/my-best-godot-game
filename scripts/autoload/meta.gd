extends Node
## Мета-прогрессия (GDD §8): ежедневная награда, коты-помощники, декор кофейни.
## Автолоад: Meta.
##
## Уровень кофейни — это уровень игрока (`Progress.level`), отдельного счётчика
## нет: декор даёт XP, а коты гейтятся уровнем и числом выполненных заказов.
##
## Ключи сохранения: `cats` (массив id), `decor` (массив id),
## `daily_streak` (день стрика 0..7), `daily_last_day` (unix-день последней выдачи),
## `decor_layout` (словарь decor_id → {tx, ty, rot} — свободная расстановка
## мебели по тайлам; старые `decor_placed`/`decor_rot` со слотами переносятся
## в него при загрузке).
## События аналитики (shop_open / daily_reward_claim / cat_unlocked /
## decor_purchased / decor_placed) пишет game.gd — здесь только состояние.

signal daily_changed(streak: int)
signal cat_unlocked(cat: Dictionary)
signal decor_changed(item: Dictionary)
## Предмет поставлен, сдвинут, повёрнут или убран в инвентарь.
signal placement_changed(decor_id: String)

const DATA := preload("res://scripts/data/meta.gd")

var unlocked_cats: Array[String] = []
var owned_decor: Array[String] = []
var daily_streak := 0
var daily_last_day := -1
## Расстановка: decor_id → {"tx", "ty", "rot"} — левый верхний тайл занятой
## области и поворот 0..3 (у невращаемых всегда 0).
var placed: Dictionary = {}


func _ready() -> void:
	SaveManager.ensure_loaded()
	SaveManager.reset_done.connect(_restore)
	_restore()


# --- Ежедневная награда (GDD §8.3) -------------------------------------------

## Доступна ли награда сегодня.
func can_claim() -> bool:
	return _today() > daily_last_day


## Какой день стрика будет выдан следующим (1..DAILY_DAYS).
func next_day() -> int:
	return daily_streak % DATA.DAILY_DAYS + 1


## Забрать награду. Возвращает {"ok", "day", "reward", "cat", "gems"}.
## Пропуск дня сбрасывает стрик на 1 (жёсткий режим, GDD §8.3).
func claim() -> Dictionary:
	if not can_claim():
		return {"ok": false, "reason": "Награда уже получена"}
	var today := _today()
	if daily_last_day < 0 or today - daily_last_day > 1 or daily_streak >= DATA.DAILY_DAYS:
		daily_streak = 0
	daily_streak += 1
	daily_last_day = today
	SaveManager.set_value("daily_streak", daily_streak)
	SaveManager.set_value("daily_last_day", daily_last_day)

	var reward: Dictionary = DATA.daily_reward(daily_streak)
	var result := {"ok": true, "day": daily_streak, "reward": reward, "cat": "", "gems": 0}
	if String(reward.get("chest", "")) == "cat":
		var chest_cat := _open_cat_chest()
		if chest_cat == "":
			result["gems"] = int(_cfg("daily_chest_gems", 15))
		else:
			result["cat"] = chest_cat
	daily_changed.emit(daily_streak)
	return result


# --- Коты (GDD §8.2) ----------------------------------------------------------

func is_cat_unlocked(cat_id: String) -> bool:
	return unlocked_cats.has(cat_id)


func cat_count() -> int:
	return unlocked_cats.size()


## Пассивный бонус котов: +5% монет за заказ за каждого (множитель, ≥1.0).
func cat_bonus() -> float:
	return 1.0 + float(unlocked_cats.size()) * float(_cfg("cat_bonus_per_cat", 0.05))


## Бонус в процентах — для текста в интерфейсе.
func cat_bonus_percent() -> int:
	return int(round(float(unlocked_cats.size()) * float(_cfg("cat_bonus_per_cat", 0.05)) * 100.0))


## Проверить условия открытия котов (уровень + число заказов).
## Возвращает список только что открытых котов.
func check_cat_unlocks(orders_done: int) -> Array:
	var opened := []
	for item in DATA.CATS:
		if bool(item.get("chest", false)):
			continue
		var cat_id := String(item.get("id", ""))
		if unlocked_cats.has(cat_id):
			continue
		if Progress.level < int(item.get("level", 1)):
			continue
		if orders_done < int(item.get("orders", 0)):
			continue
		var unlocked: Dictionary = _unlock(cat_id)
		if not unlocked.is_empty():
			opened.append(unlocked)
	return opened


## Текст условия для карточки альбома.
func cat_status(item: Dictionary) -> String:
	if unlocked_cats.has(String(item.get("id", ""))):
		return "В кафе"
	return DATA.cat_requirement(item)


# --- Декор (GDD §8.1) --------------------------------------------------------

func owns_decor(decor_id: String) -> bool:
	return owned_decor.has(decor_id)


func decor_count() -> int:
	return owned_decor.size()


## Купить декор за монеты: списывает монеты и начисляет XP (→ уровень кофейни).
## Возвращает {"ok", "decor", "xp"} либо {"ok": false, "reason"}.
func buy_decor(decor_id: String) -> Dictionary:
	if owns_decor(decor_id):
		return {"ok": false, "reason": "Уже куплено"}
	var item: Dictionary = DATA.decor(decor_id)
	if item.is_empty():
		return {"ok": false, "reason": "Нет такого декора"}
	var cost := int(item.get("cost", 0))
	if not Wallet.spend_coins(cost):
		return {"ok": false, "reason": "Не хватает монет: нужно %d 🪙" % cost}
	owned_decor.append(decor_id)
	SaveManager.set_value("decor", owned_decor)
	var xp := int(item.get("xp", 0))
	if xp > 0:
		Progress.add_xp(xp)
	decor_changed.emit(item)
	return {"ok": true, "decor": item, "xp": xp}


# --- Расстановка мебели (GDD §8.1) -------------------------------------------
#
# Свободная расстановка: предмет встаёт на любые тайлы, если его область
# (с учётом поворота) целиком лежит в одной комнате и не пересекается с другой
# мебелью. Состояние — `placed` в сейве под ключом `decor_layout`.

## Стоит ли предмет в кофейне.
func is_placed(decor_id: String) -> bool:
	return placed.has(decor_id)


## Где стоит предмет: {"tx", "ty", "rot"} или пустой словарь.
func placement(decor_id: String) -> Dictionary:
	return placed.get(decor_id, {})


## Поворот поставленного предмета (0, если не стоит или не вращается).
func decor_rot(decor_id: String) -> int:
	return int(placement(decor_id).get("rot", 0))


## Занятая предметом область в тайлах (позиция + размер с учётом поворота).
func decor_area(decor_id: String) -> Rect2i:
	var spot := placement(decor_id)
	if spot.is_empty():
		return Rect2i()
	var size := DATA.rotated_size(DATA.decor(decor_id), int(spot["rot"]))
	return Rect2i(int(spot["tx"]), int(spot["ty"]), size.x, size.y)


## Какой предмет занимает тайл ("" — свободно).
func decor_at(tile: Vector2i) -> String:
	for decor_id in placed:
		if decor_area(String(decor_id)).has_point(tile):
			return String(decor_id)
	return ""


## Сколько предметов расставлено.
func placed_count() -> int:
	return placed.size()


## Купленный, но ещё не поставленный декор — для инвентаря кофейни.
func unplaced_decor() -> Array:
	var out := []
	for decor_id in owned_decor:
		if not placed.has(decor_id):
			out.append(DATA.decor(decor_id))
	return out


## Можно ли поставить предмет левым верхним углом на тайл `tile` с поворотом
## `rot`. Сам предмет своё старое место не занимает (перенос на соседний тайл).
## Возвращает {"ok", "room"} либо {"ok": false, "reason"}.
func can_place(decor_id: String, tile: Vector2i, rot: int = 0) -> Dictionary:
	var item: Dictionary = DATA.decor(decor_id)
	if item.is_empty():
		return {"ok": false, "reason": "Нет такого предмета"}
	var size := DATA.rotated_size(item, rot)
	var room: Dictionary = DATA.area_room(tile, size)
	if room.is_empty():
		return {"ok": false, "reason": "Здесь нет места"}
	var area := Rect2i(tile, size)
	for other in placed:
		if String(other) != decor_id and decor_area(String(other)).intersects(area):
			return {"ok": false, "reason": "Место занято"}
	return {"ok": true, "room": String(room.get("name", ""))}


## Поставить купленный предмет на тайл (или перенести, если уже стоит).
## Возвращает {"ok", "room", "rot"} либо {"ok": false, "reason"}.
func place_decor(decor_id: String, tile: Vector2i, rot: int = 0) -> Dictionary:
	if not owns_decor(decor_id):
		return {"ok": false, "reason": "Предмет не куплен"}
	var item: Dictionary = DATA.decor(decor_id)
	var turn := ((rot % 4) + 4) % 4 if DATA.is_rotatable(item) else 0
	var check := can_place(decor_id, tile, turn)
	if not bool(check.get("ok", false)):
		return check
	placed[decor_id] = {"tx": tile.x, "ty": tile.y, "rot": turn}
	_save_layout()
	placement_changed.emit(decor_id)
	return {"ok": true, "room": check["room"], "rot": turn}


## Повернуть поставленный предмет на месте. Не квадратный предмет при
## повороте может упереться в стену или соседа — тогда пробуем сдвинуть его
## на тайл, чтобы игроку не приходилось сначала переносить вручную.
## Возвращает {"ok", "rot"} либо {"ok": false, "reason"}.
func set_rotation(decor_id: String, rot: int) -> Dictionary:
	var spot := placement(decor_id)
	if spot.is_empty():
		return {"ok": false, "reason": "Предмет не стоит в кофейне"}
	if not DATA.is_rotatable(DATA.decor(decor_id)):
		return {"ok": false, "reason": "Этот предмет нельзя поворачивать"}
	var turn := ((rot % 4) + 4) % 4
	var origin := Vector2i(int(spot["tx"]), int(spot["ty"]))
	for shift in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1),
			Vector2i(1, 0), Vector2i(0, 1)]:
		if bool(can_place(decor_id, origin + shift, turn).get("ok", false)):
			placed[decor_id] = {"tx": origin.x + shift.x, "ty": origin.y + shift.y, "rot": turn}
			_save_layout()
			placement_changed.emit(decor_id)
			return {"ok": true, "rot": turn}
	return {"ok": false, "reason": "Для поворота не хватает места"}


## Убрать предмет в инвентарь (остаётся купленным).
func remove_decor(decor_id: String) -> Dictionary:
	if not placed.has(decor_id):
		return {"ok": false, "reason": "Предмет не стоит в кофейне"}
	placed.erase(decor_id)
	_save_layout()
	placement_changed.emit(decor_id)
	return {"ok": true}


## Свободное место под предмет: сначала в его «родной» комнате (DECOR.room),
## потом в любой. Обход — от дальних тайлов к ближним, как расставили бы руками.
## Vector2i(-1, -1) — места нет нигде.
func find_free_spot(decor_id: String, rot: int = 0) -> Vector2i:
	var item: Dictionary = DATA.decor(decor_id)
	if item.is_empty():
		return Vector2i(-1, -1)
	var home := String(item.get("room", ""))
	var rooms: Array = DATA.ROOMS.duplicate()
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) == home and String(b["name"]) != home)
	for room: Dictionary in rooms:
		for ty in range(int(room["ty"]), int(room["ty"]) + int(room["h"])):
			for tx in range(int(room["tx"]), int(room["tx"]) + int(room["w"])):
				var tile := Vector2i(tx, ty)
				if bool(can_place(decor_id, tile, rot).get("ok", false)):
					return tile
	return Vector2i(-1, -1)


func _save_layout() -> void:
	SaveManager.set_value("decor_layout", placed.duplicate(true))


# --- Внутреннее --------------------------------------------------------------

func _restore() -> void:
	unlocked_cats.clear()
	for value in SaveManager.get_value("cats", []):
		unlocked_cats.append(String(value))
	owned_decor.clear()
	for value in SaveManager.get_value("decor", []):
		owned_decor.append(String(value))
	daily_streak = clampi(int(SaveManager.get_value("daily_streak", 0)), 0, DATA.DAILY_DAYS)
	daily_last_day = maxi(-1, int(SaveManager.get_value("daily_last_day", -1)))
	placed.clear()
	var layout: Variant = SaveManager.get_value("decor_layout", null)
	if layout is Dictionary:
		for key in (layout as Dictionary).keys():
			var spot: Variant = (layout as Dictionary)[key]
			if spot is Dictionary:
				_restore_spot(String(key), Vector2i(int(spot.get("tx", -1)), int(spot.get("ty", -1))),
					int(spot.get("rot", 0)))
	else:
		_migrate_slots()


## Старый сейв: slot_id → decor_id в `decor_placed`, поворот в `decor_rot`.
## Переносим в координаты слотов (левый верхний тайл) — расстановка игрока
## остаётся той же. Старые ключи не трогаем: их перезапишет только новый.
func _migrate_slots() -> void:
	var saved_placed: Variant = SaveManager.get_value("decor_placed", {})
	var saved_rot: Variant = SaveManager.get_value("decor_rot", {})
	if not (saved_placed is Dictionary):
		return
	for slot_id in (saved_placed as Dictionary).keys():
		var key := String(slot_id)
		if not DATA.LEGACY_SLOT_TILES.has(key):
			continue
		var rot := 0
		if saved_rot is Dictionary:
			rot = int((saved_rot as Dictionary).get(key, 0))
		_restore_spot(String((saved_placed as Dictionary)[slot_id]), DATA.LEGACY_SLOT_TILES[key], rot)
	if not placed.is_empty():
		_save_layout()


## Битый или устаревший сейв мог сохранить место, которое теперь не годится
## (пересечение, не куплен): такой предмет просто возвращается в инвентарь.
func _restore_spot(decor_id: String, tile: Vector2i, rot: int) -> void:
	if not owned_decor.has(decor_id) or placed.has(decor_id):
		return
	var item: Dictionary = DATA.decor(decor_id)
	var turn := ((rot % 4) + 4) % 4 if DATA.is_rotatable(item) else 0
	if bool(can_place(decor_id, tile, turn).get("ok", false)):
		placed[decor_id] = {"tx": tile.x, "ty": tile.y, "rot": turn}


## Номер текущего дня по МЕСТНОМУ времени игрока: «новый день» наступает
## в его полночь, а не в полночь UTC (в Москве это было бы 03:00).
## Им же считается дневной лимит rewarded-рекламы (game.gd).
func local_day() -> int:
	var bias_min := int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + bias_min * 60.0) / 86400.0))


func _today() -> int:
	return local_day()


## Открыть эпика из котового сундука; "" — если открывать некого.
func _open_cat_chest() -> String:
	for item in DATA.chest_cats():
		var cat_id := String(item.get("id", ""))
		if unlocked_cats.has(cat_id):
			continue
		if Progress.level < int(item.get("level", 1)):
			continue
		if _unlock(cat_id).is_empty():
			continue
		return cat_id
	return ""


func _unlock(cat_id: String) -> Dictionary:
	if cat_id == "" or unlocked_cats.has(cat_id):
		return {}
	var item: Dictionary = DATA.cat(cat_id)
	if item.is_empty():
		return {}
	unlocked_cats.append(cat_id)
	SaveManager.set_value("cats", unlocked_cats)
	cat_unlocked.emit(item)
	return item


## Публичное открытие кота за покупку/награду. true — кот был открыт сейчас.
func grant_cat(cat_id: String) -> bool:
	return not _unlock(cat_id).is_empty()


func _cfg(key: String, fallback: Variant) -> Variant:
	var value = Config.get_value(key)
	return fallback if value == null else value

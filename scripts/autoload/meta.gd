extends Node
## Мета-прогрессия (GDD §8): ежедневная награда, коты-помощники, декор кофейни.
## Автолоад: Meta.
##
## Уровень кофейни — это уровень игрока (`Progress.level`), отдельного счётчика
## нет: декор даёт XP, а коты гейтятся уровнем и числом выполненных заказов.
##
## Ключи сохранения: `cats` (массив id), `decor` (массив id),
## `daily_streak` (день стрика 0..7), `daily_last_day` (unix-день последней выдачи),
## `decor_placed` (словарь slot_id → decor_id — расстановка мебели),
## `decor_rot` (словарь slot_id → поворот 0..3 = N/E/S/W).
## События аналитики (shop_open / daily_reward_claim / cat_unlocked /
## decor_purchased / decor_placed) пишет game.gd — здесь только состояние.

signal daily_changed(streak: int)
signal cat_unlocked(cat: Dictionary)
signal decor_changed(item: Dictionary)
signal placement_changed(slot_id: String, decor_id: String)
signal rotation_changed(slot_id: String, rot: int)

const DATA := preload("res://scripts/data/meta.gd")

var unlocked_cats: Array[String] = []
var owned_decor: Array[String] = []
var daily_streak := 0
var daily_last_day := -1
## Расстановка: slot_id → decor_id (предмет ставится максимум в один слот).
var placed: Dictionary = {}
## Поворот предмета в слоте: slot_id → 0..3 (N/E/S/W). Есть только у вращаемых.
var placed_rot: Dictionary = {}


func _ready() -> void:
	SaveManager.load_game()
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
	var coins := int(SaveManager.get_value("coins", 0))
	if coins < cost:
		return {"ok": false, "reason": "Не хватает монет: нужно %d 🪙" % cost}
	SaveManager.set_value("coins", coins - cost)
	owned_decor.append(decor_id)
	SaveManager.set_value("decor", owned_decor)
	var xp := int(item.get("xp", 0))
	if xp > 0:
		Progress.add_xp(xp)
	decor_changed.emit(item)
	return {"ok": true, "decor": item, "xp": xp}


# --- Расстановка мебели (GDD §8.1) -------------------------------------------
#
# Минимальная версия: у каждой комнаты есть слоты (DATA.SLOTS), предмет можно
# поставить только в слот своей комнаты и максимум в один слот. Состояние —
# словарь `placed` (slot_id → decor_id) в сейве под ключом `decor_placed`.

## Какой предмет стоит в слоте ("" — слот пуст).
func slot_decor(slot_id: String) -> String:
	return String(placed.get(slot_id, ""))


## Слот, в котором стоит предмет ("" — не стоит нигде).
func decor_slot(decor_id: String) -> String:
	for slot_id in placed.keys():
		if String(placed[slot_id]) == decor_id:
			return String(slot_id)
	return ""


## Сколько предметов расставлено.
func placed_count() -> int:
	return placed.size()


## Купленный, но ещё не поставленный декор — для списка «полки» в попапе.
func unplaced_decor() -> Array:
	var out := []
	for decor_id in owned_decor:
		if decor_slot(decor_id) == "":
			out.append(DATA.decor(decor_id))
	return out


## Поставить купленный предмет в слот. Предмет можно ставить только в слот
## своей комнаты и подходящего размера (с учётом поворота); повторная
## постановка переносит его из старого слота.
## Возвращает {"ok"} либо {"ok": false, "reason"}.
func place_decor(decor_id: String, slot_id: String, rot: int = 0) -> Dictionary:
	if not owns_decor(decor_id):
		return {"ok": false, "reason": "Предмет не куплен"}
	var item: Dictionary = DATA.decor(decor_id)
	var slot: Dictionary = DATA.slot(slot_id)
	if item.is_empty() or slot.is_empty():
		return {"ok": false, "reason": "Нет такого слота"}
	if String(slot.get("room", "")) != String(item.get("room", "")):
		return {"ok": false, "reason": "Сюда можно ставить только: %s" % String(item.get("room", ""))}
	if bool(slot.get("wall", false)) != bool(item.get("wall", false)):
		return {"ok": false, "reason": "Это место не подходит для предмета"}
	if not DATA.fits(item, slot, rot):
		return {"ok": false, "reason": "Предмет не помещается в это место"}
	var previous := decor_slot(decor_id)
	if previous != "":
		placed.erase(previous)
		placed_rot.erase(previous)
		placement_changed.emit(previous, "")
	placed[slot_id] = decor_id
	var turn := 0
	if DATA.is_rotatable(item):
		turn = ((rot % 4) + 4) % 4
		placed_rot[slot_id] = turn
	else:
		placed_rot.erase(slot_id)
	SaveManager.set_value("decor_placed", placed)
	SaveManager.set_value("decor_rot", placed_rot)
	placement_changed.emit(slot_id, decor_id)
	rotation_changed.emit(slot_id, turn)
	return {"ok": true}


## Повернуть предмет в слоте. Возвращает {"ok", "rot"} либо {"ok": false, "reason"}.
func set_rotation(slot_id: String, rot: int) -> Dictionary:
	if not placed.has(slot_id):
		return {"ok": false, "reason": "Слот пуст"}
	var decor_id := String(placed[slot_id])
	var item: Dictionary = DATA.decor(decor_id)
	if not DATA.is_rotatable(item):
		return {"ok": false, "reason": "Этот предмет нельзя поворачивать"}
	var turn := ((rot % 4) + 4) % 4
	placed_rot[slot_id] = turn
	SaveManager.set_value("decor_rot", placed_rot)
	rotation_changed.emit(slot_id, turn)
	return {"ok": true, "rot": turn}


## Поворот предмета в слоте (0, если слот пуст или предмет не вращается).
func slot_rot(slot_id: String) -> int:
	return int(placed_rot.get(slot_id, 0))


## Снять предмет со слота (предмет остаётся купленным).
func clear_slot(slot_id: String) -> Dictionary:
	if not placed.has(slot_id):
		return {"ok": false, "reason": "Слот пуст"}
	placed.erase(slot_id)
	placed_rot.erase(slot_id)
	SaveManager.set_value("decor_placed", placed)
	SaveManager.set_value("decor_rot", placed_rot)
	placement_changed.emit(slot_id, "")
	return {"ok": true}


# --- Внутреннее --------------------------------------------------------------

func _restore() -> void:
	unlocked_cats.clear()
	for value in SaveManager.get_value("cats", []):
		unlocked_cats.append(String(value))
	owned_decor.clear()
	for value in SaveManager.get_value("decor", []):
		owned_decor.append(String(value))
	daily_streak = int(SaveManager.get_value("daily_streak", 0))
	daily_last_day = int(SaveManager.get_value("daily_last_day", -1))
	placed.clear()
	var saved_placed: Variant = SaveManager.get_value("decor_placed", {})
	if saved_placed is Dictionary:
		for slot_id in (saved_placed as Dictionary).keys():
			var decor_id := String((saved_placed as Dictionary)[slot_id])
			if DATA.slot(String(slot_id)).is_empty():
				continue
			if not owned_decor.has(decor_id):
				continue
			if decor_slot(decor_id) != "":
				continue
			placed[String(slot_id)] = decor_id
	placed_rot.clear()
	var saved_rot: Variant = SaveManager.get_value("decor_rot", {})
	if saved_rot is Dictionary:
		for slot_id in (saved_rot as Dictionary).keys():
			var key := String(slot_id)
			if not placed.has(key):
				continue
			placed_rot[key] = int((saved_rot as Dictionary)[slot_id]) % 4


## unix-день (сегодня), по нему считается стрик.
func _today() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))


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


func _cfg(key: String, fallback: Variant) -> Variant:
	var value = Config.get_value(key)
	return fallback if value == null else value

class_name OrderManager
extends Node

## Заказы котов: 1–2 предмета за монеты и XP.
##
## Один заказ — словарь:
##   {"items": [{"chain": "coffee", "level": 1}, ...], "coins": int, "xp": int,
##    "created_at": int}  # unix-время создания — для бонуса за скорость
## См. docs/GDD.md §7 (Заказы) и docs/economy.md (формулы награды).

signal orders_changed

const MIN_ITEMS := 1
const MAX_ITEMS := 2
## Насколько высокий уровень просим на старте (позже — от уровня игрока).
const MAX_LEVEL_EARLY := 3

var _orders: Array = []


## Заполнить слоты заказами (существующие сбрасываются).
func setup(slots: int) -> void:
	_orders.clear()
	while _orders.size() < maxi(1, slots):
		_orders.append(make_order())
	orders_changed.emit()


## Восстановить сохранённые заказы (как есть, без валидации).
## Заказам из старых сохранений дописываем created_at, иначе бонус за скорость
## никогда не сработает (и таймер покажет 0).
func load_orders(data: Array) -> void:
	_orders.clear()
	var now := int(Time.get_unix_time_from_system())
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var order: Dictionary = entry
		if order.is_empty():
			continue
		if not order.has("created_at"):
			order["created_at"] = now
		if not is_order_reachable(order):
			# Сохранённый заказ может просить закрытую цепочку или слишком
			# высокий уровень — заменяем на достижимый.
			order = make_order()
		_orders.append(order)
	orders_changed.emit()


func orders() -> Array:
	return _orders


func order_at(index: int) -> Dictionary:
	if index < 0 or index >= _orders.size():
		return {}
	return _orders[index]


## Сгенерировать новый заказ.
## Просим только то, что игрок реально может получить: цепочки берём из уже
## открытых генераторов, уровень предмета — не выше освоенного (см.
## _available_chains() / _max_order_level()).
func make_order() -> Dictionary:
	var chains := _available_chains()
	var chain: StringName = chains[randi() % chains.size()]
	var max_level := _max_order_level(chain)
	var count := randi_range(MIN_ITEMS, MAX_ITEMS)

	var items: Array = []
	for i in count:
		items.append({
			"chain": String(chain),
			"level": randi_range(1, max_level),
		})

	var order := {"items": items, "coins": 0, "xp": 0, "created_at": int(Time.get_unix_time_from_system())}
	order["coins"] = compute_coins(order)
	order["xp"] = compute_xp(order)
	return order


## Цепочки, доступные игроку: их генераторы уже открыты по уровню.
## Если открытых почему-то нет — падаем на кофе (стартовая цепочка).
func _available_chains() -> Array:
	var chains: Array = []
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain):
			chains.append(chain)
	if chains.is_empty():
		chains.append(Chains.COFFEE)
	return chains


## Максимальный уровень предмета в заказе: растёт вместе с уровнем игрока,
## но не выше MAX_LEVEL_EARLY и потолка цепочки. На 1-м уровне просим L1–L2.
func _max_order_level(chain: StringName) -> int:
	var by_player := 2 + int(floor(float(Progress.level) / 2.0))
	return maxi(1, mini(mini(MAX_LEVEL_EARLY, by_player), Chains.max_level(chain)))


## Заказ можно получить, только если все его предметы доступны игроку.
func is_order_reachable(order: Dictionary) -> bool:
	for req in order.get("items", []):
		var chain := StringName(req.get("chain", ""))
		if not Progress.is_generator_unlocked(chain):
			return false
		if int(req.get("level", 1)) > _max_order_level(chain):
			return false
	return true


# --- Экономика ---------------------------------------------------------------

func compute_coins(order: Dictionary) -> int:
	var total := 0
	for req in order.get("items", []):
		total += item_value(StringName(req.get("chain", "")), int(req.get("level", 1)))
	return int(round(float(total) * _cfg_float("order_reward_mult", 2.0)))


func compute_xp(order: Dictionary) -> int:
	return int(round(float(order.get("coins", 0)) * _cfg_float("order_xp_mult", 0.5)))


func item_value(_chain: StringName, level: int) -> int:
	return Chains.sell_value(level, _cfg_float("item_value_base", 5.0), _cfg_float("item_value_growth", 2.05))


# --- Награда и бонусы (docs/GDD.md §7) ---------------------------------------

## Итоговая награда: бонус ×1.5, если заказ сдан быстрее окна (order_speed_window_sec).
## Возвращает {"coins": int, "xp": int, "bonus": float, "seconds_left": int}.
func reward_for(order: Dictionary) -> Dictionary:
	var base_coins := int(order.get("coins", 0))
	var bonus := 1.0
	var seconds_left := 0
	var created := float(order.get("created_at", 0))
	if created > 0.0:
		var window := _cfg_float("order_speed_window_sec", 1200.0)
		var elapsed := Time.get_unix_time_from_system() - created
		if elapsed <= window:
			bonus = _cfg_float("order_speed_bonus", 1.5)
			seconds_left = maxi(0, int(window - elapsed))
	var coins := int(round(float(base_coins) * bonus))
	return {
		"coins": coins,
		"xp": int(round(float(coins) * _cfg_float("order_xp_mult", 0.5))),
		"bonus": bonus,
		"seconds_left": seconds_left,
	}


## Сколько секунд осталось на бонус за скорость (0 — бонуса уже нет).
func bonus_seconds_left(index: int) -> int:
	var order := order_at(index)
	if order.is_empty():
		return 0
	return int(reward_for(order).get("seconds_left", 0))


## Заменить заказ новым (стоимость реролла списывает вызывающий).
func replace(index: int) -> bool:
	if index < 0 or index >= _orders.size():
		return false
	_orders[index] = make_order()
	orders_changed.emit()
	return true


# --- Доставка ----------------------------------------------------------------

## Забрать предметы с поля и наградить. Возвращает
## {"ok": bool, "coins": int, "xp": int, "gems": int, "bonus": float, "reason": String}.
func try_deliver(index: int, board: Board) -> Dictionary:
	if board == null or index < 0 or index >= _orders.size():
		return _fail("нет такого заказа")

	var order: Dictionary = _orders[index]
	var used: Array = []
	for req in order.get("items", []):
		var cell := _find_cell(board, req, used)
		if cell < 0:
			return _fail("нужен предмет: %s" % Chains.item_name(
				StringName(req.get("chain", "")), int(req.get("level", 1))
			))
		used.append(cell)

	for cell in used:
		board.remove_at_cell(cell)

	var reward := reward_for(order)
	var coins := int(reward.get("coins", 0))
	var xp := int(reward.get("xp", 0))
	var gems := 0
	if randf() < _cfg_float("gem_chance_order", 0.1):
		gems = 1
	_orders[index] = make_order()
	orders_changed.emit()
	return {
		"ok": true,
		"coins": coins,
		"xp": xp,
		"gems": gems,
		"bonus": float(reward.get("bonus", 1.0)),
		"reason": "",
	}


func _find_cell(board: Board, req: Dictionary, taken: Array) -> int:
	var want_chain := String(req.get("chain", ""))
	var want_level := int(req.get("level", 1))
	for i in board.cell_count():
		if taken.has(i):
			continue
		var item := board.item_at(i)
		if item == null:
			continue
		if String(item.data.chain) == want_chain and item.data.level == want_level:
			return i
	return -1


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "coins": 0, "xp": 0, "reason": reason}


func _cfg_float(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

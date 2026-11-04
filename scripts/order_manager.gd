class_name OrderManager
extends Node

## Заказы котов = очередь «Живой кофейни» (GDD §26): один заказ — один гость.
##
## Один заказ — словарь:
##   {"items": [{"chain": "coffee", "level": 1}, ...], "coins": int, "xp": int,
##    "created_at": int,      # unix-время создания — бонус за скорость
##    "id": int,              # номер гостя: связывает карточку заказа и кота
##    "cat_id": String,       # кто пришёл (scripts/data/meta.gd)
##    "patience_sec": float,  # сколько всего готов ждать
##    "elapsed": float,       # сколько уже ждёт
##    "state": "waiting"}     # waiting / served / timeout
## См. docs/GDD.md §7 (Заказы), §25 (формулы награды), §26 (очередь).

signal orders_changed
## Гость пришёл: cafe_window анимирует вход.
signal customer_arrived(order: Dictionary)
## Гость ушёл: state = "served" | "timeout" | "queue_full" (не дошёл до стойки).
signal customer_left(order: Dictionary)
signal queue_changed(size: int, capacity: int)
signal barista_changed(cat_id: String)

const META_DATA := preload("res://scripts/data/meta.gd")
const MIN_ITEMS := 1
const MAX_ITEMS := 2
## Насколько высокий уровень просим на старте (позже — от уровня игрока).
const MAX_LEVEL_EARLY := 3

var _orders: Array = []
## Тикаем только когда game.gd загрузил состояние: иначе гости приходят
## во время самопроверки и сброса прогресса.
var _running := false
var _spawn_left := 0.0
var _next_id := 1
var _barista := ""
var _barista_save_left := 0.0

func _ready() -> void:
	SaveManager.ensure_loaded()
	SaveManager.reset_done.connect(_restore_barista)
	_restore_barista()

func _process(delta: float) -> void:
	if _running:
		tick(delta)

## Один тик очереди: приход гостей и терпение. Публичный — для самопроверки.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_barista_save_left = maxf(0.0, _barista_save_left - delta)
	_tick_spawn(delta)
	_tick_patience(delta)

## Начать приём гостей (когда состояние загружено).
func start() -> void:
	_running = true
	_spawn_left = _cfg_float("queue_first_spawn_sec", 1.0)
	queue_changed.emit(_orders.size(), capacity())

## Сколько гостей очередь держит одновременно: слоты заказов по уровню
## плюс бонус бариста.
func capacity() -> int:
	var slots := Progress.order_slots()
	if _perk() == "queue_plus_1":
		slots += 1
	return maxi(1, slots)

## Пришёл новый гость. false — очередь полна (гость ушёл не дождавшись).
func spawn_customer() -> bool:
	if _orders.size() >= capacity():
		return false
	_orders.append(make_order())
	orders_changed.emit()
	queue_changed.emit(_orders.size(), capacity())
	customer_arrived.emit(_orders.back())
	return true

# --- Слот бариста (GDD §26.4) -----------------------------------------------

## Кто стоит за стойкой (пустая строка — никого).
func active_barista() -> String:
	return _barista

## Открытые коты, кого можно поставить за стойку.
func barista_cats() -> Array:
	var out: Array = []
	for cat_id in Meta.unlocked_cats:
		out.append(String(cat_id))
	return out

func barista_perk() -> String:
	return _perk()

## Поставить кота за стойку. false — кот закрыт или уже там.
func set_active_barista(cat_id: String) -> bool:
	if not Meta.is_cat_unlocked(cat_id) or cat_id == _barista:
		return false
	_barista = cat_id
	_barista_save_left = 0.0
	SaveManager.set_value("active_barista", _barista)
	SaveManager.request_save()
	barista_changed.emit(_barista)
	queue_changed.emit(_orders.size(), capacity())
	return true

## Перк «бесплатный тап генератора»: спрашивает game.gd перед Energy.spend.
func take_free_energy() -> bool:
	if _perk() != "slot_free_20":
		return false
	return randf() < _cfg_float("queue_perk_energy_free_chance", 0.2)

func customers_served() -> int:
	return int(SaveManager.get_value("customers_served_total", 0))

func customers_lost() -> int:
	return int(SaveManager.get_value("customers_lost_total", 0))

func _restore_barista() -> void:
	var saved := String(SaveManager.get_value("active_barista", ""))
	_barista = saved if Meta.is_cat_unlocked(saved) else ""
	if _barista.is_empty() and not Meta.unlocked_cats.is_empty():
		_barista = String(Meta.unlocked_cats[0])
	barista_changed.emit(_barista)

func _perk() -> String:
	return META_DATA.barista_perk(_barista)

func _tick_spawn(delta: float) -> void:
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	_spawn_left = randf_range(
		_cfg_float("queue_spawn_min_sec", 20.0), _cfg_float("queue_spawn_max_sec", 45.0)
	)
	if not spawn_customer():
		# Очередь полна: гость развернулся у двери — бейдж и аналитика в game.gd.
		customer_left.emit({"state": "queue_full", "id": 0, "cat_id": ""})

## Терпение: кто не дождался — уходит злым (счётчик customers_lost_total).
func _tick_patience(delta: float) -> void:
	var lost := false
	for i in range(_orders.size() - 1, -1, -1):
		var order: Dictionary = _orders[i]
		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta
		if float(order["elapsed"]) < float(order.get("patience_sec", 0.0)):
			continue
		if _perk() == "save_once_per_min" and _barista_save_left <= 0.0:
			# Перк Эспрессо: раз в минуту гость всё-таки дожидается заказа.
			_barista_save_left = _cfg_float("queue_perk_save_cooldown_sec", 60.0)
			order["elapsed"] = maxf(0.0, float(order["patience_sec"])
				- _cfg_float("queue_perk_save_bonus_sec", 20.0))
			continue
		order["state"] = "timeout"
		_orders.remove_at(i)
		_bump("customers_lost_total")
		lost = true
		customer_left.emit(order)
	if lost:
		orders_changed.emit()
		queue_changed.emit(_orders.size(), capacity())

## Гость-«эстет» ждёт дольше в обставленном кафе; перк бариста — множитель.
func _patience_sec(order: Dictionary) -> float:
	var patience := _cfg_float("queue_patience_sec", 90.0)
	var esthete := _cfg_str("queue_esthete_cat", "mimi")
	var decor_min := int(_cfg_float("queue_esthete_decor_min", 5.0))
	if String(order.get("cat_id", "")) == esthete and Meta.owned_decor.size() >= decor_min:
		patience += _cfg_float("queue_esthete_bonus_sec", 30.0)
	if _perk() == "patience_plus_30":
		patience *= _cfg_float("queue_perk_patience_mult", 1.3)
	return patience

func _bump(key: String) -> void:
	SaveManager.set_value(key, int(SaveManager.get_value(key, 0)) + 1)
	SaveManager.request_save()

func _add_customer(order: Dictionary) -> void:
	order["id"] = _next_id
	_next_id += 1
	order["cat_id"] = _pick_cat()
	order["patience_sec"] = 0.0
	order["elapsed"] = 0.0
	order["state"] = "waiting"
	order["patience_sec"] = _patience_sec(order)

## Кто пришёл: любой открытый кот, кроме того, что стоит за стойкой.
func _pick_cat() -> String:
	var pool: Array = []
	for cat_id in Meta.unlocked_cats:
		if String(cat_id) != _barista:
			pool.append(String(cat_id))
	if pool.is_empty():
		return _barista if not _barista.is_empty() else "mocha"
	return String(pool[randi() % pool.size()])



## Заполнить очередь заказами (существующие сбрасываются).
func setup(slots: int) -> void:
	_orders.clear()
	var target := mini(maxi(1, slots), capacity())
	while _orders.size() < target:
		_orders.append(make_order())
	orders_changed.emit()
	queue_changed.emit(_orders.size(), capacity())


## Восстановить сохранённые заказы (недостижимые заменяются новыми).
## Заказам из старых сохранений дописываем created_at, иначе бонус за скорость
## никогда не сработает (и таймер покажет 0).
## Заказы копируются: список не должен делить память с сейвом — иначе
## `load_orders(orders())` очищал бы сам себя, а сейв менялся бы в обход save.
func load_orders(data: Array) -> void:
	var source := data.duplicate(true)
	_orders.clear()
	var now := int(Time.get_unix_time_from_system())
	for entry in source:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var order: Dictionary = entry
		if order.is_empty():
			continue
		if not order.has("created_at"):
			order["created_at"] = now
		if not order.has("cat_id"):
			# Старый сейв: заказ без гостя — досоздаём гостя с терпением.
			_add_customer(order)
		if not is_order_reachable(order):
			# Сохранённый заказ может просить закрытую цепочку или слишком
			# высокий уровень — заменяем на достижимый.
			order = make_order()
		_orders.append(order)
	# Слотов могло стать меньше (новый уровень/другой бариста) — лишние уходят.
	while _orders.size() > capacity():
		_orders.pop_back()
	orders_changed.emit()
	queue_changed.emit(_orders.size(), capacity())


## Догрузить очередь до `slots` гостей (после level up слотов больше).
## Гости именно приходят — с анимацией входа, как обычно.
func top_up(slots: int) -> void:
	var target := mini(maxi(1, slots), capacity())
	while _orders.size() < target:
		if not spawn_customer():
			return


## Текущие заказы (живой список — не менять снаружи; для сейва — duplicate).
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
	_add_customer(order)
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
## Гость остаётся тот же: меняется только заказ и терпение.
func replace(index: int) -> bool:
	if index < 0 or index >= _orders.size():
		return false
	var cat_id := String(_orders[index].get("cat_id", ""))
	_orders[index] = make_order()
	if not cat_id.is_empty():
		_orders[index]["cat_id"] = cat_id
	orders_changed.emit()
	return true


# --- Доставка ----------------------------------------------------------------

## Забрать предметы с поля и наградить. Возвращает
## {"ok": bool, "coins": int, "xp": int, "gems": int, "bonus": float, "reason": String}.
func try_deliver(index: int, board) -> Dictionary:
	if board == null or index < 0 or index >= _orders.size():
		return _fail("нет такого заказа")

	var order: Dictionary = _orders[index]
	var used: Array = []
	for req in order.get("items", []):
		var cell := _find_cell(board, req, used)
		if cell < 0:
			var fail := _fail("нужен предмет: %s" % Chains.item_name(
				StringName(req.get("chain", "")), int(req.get("level", 1))
			))
			# Чего не хватает — game.gd показывает иконку в тосте.
			fail["missing"] = req
			return fail
		used.append(cell)

	# Какие предметы ушли в заказ: game.gd анимирует их полёт в карточку.
	var taken: Array = []
	for cell in used:
		var item = board.item_at(cell)
		taken.append({"cell": cell, "chain": item.data.chain, "level": item.data.level})
		board.remove_at_cell(cell)

	var reward := reward_for(order)
	var coins := int(reward.get("coins", 0))
	# Перк бариста «+30% за заказ» действует, пока кот стоит за стойкой.
	if _perk() == "next_order_x1_3":
		coins = int(round(float(coins) * _cfg_float("queue_perk_reward_mult", 1.3)))
	var xp := int(round(float(coins) * _cfg_float("order_xp_mult", 0.5)))
	var gems := 0
	if randf() < _cfg_float("gem_chance_order", 0.1):
		gems = 1
	# Гость ушёл довольным: место в очереди освободилось, следующий придёт
	# по таймеру (spawn). Карточки пересобираются по orders_changed.
	var served := order.duplicate(true)
	served["state"] = "served"
	_orders.remove_at(index)
	_bump("customers_served_total")
	orders_changed.emit()
	queue_changed.emit(_orders.size(), capacity())
	customer_left.emit(served)
	return {
		"ok": true,
		"coins": coins,
		"xp": xp,
		"gems": gems,
		"bonus": float(reward.get("bonus", 1.0)),
		"items": taken,
		"reason": "",
	}


## Какие предметы заказа уже лежат на поле: [bool] по порядку items (один
## предмет поля засчитывается только одному требованию — как при сдаче).
func availability(index: int, board) -> Array:
	var out: Array = []
	var used: Array = []
	for req in order_at(index).get("items", []):
		var cell := _find_cell(board, req, used)
		if cell >= 0:
			used.append(cell)
		out.append(cell >= 0)
	return out


func _find_cell(board, req: Dictionary, taken: Array) -> int:
	var want_chain := String(req.get("chain", ""))
	var want_level := int(req.get("level", 1))
	for i in board.cell_count():
		if taken.has(i):
			continue
		var item = board.item_at(i)
		if item == null or item.is_bubble():
			continue
		if String(item.data.chain) == want_chain and item.data.level == want_level:
			return i
	return -1


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "coins": 0, "xp": 0, "reason": reason}


func _cfg_float(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback

func _cfg_str(key: String, fallback: String) -> String:
	var value = Config.get_value(key)
	return String(value) if value != null else fallback

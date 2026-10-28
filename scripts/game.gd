extends Node2D

## Прототип ядра (фаза 1): поле 7×8, генераторы, drag-and-drop, слияние,
## энергия, заказы, монеты, сохранение. Арт — плейсхолдеры (scripts/placeholders.gd).
##
## Дерево экрана — сцена scenes/game.tscn (фон, поле, HUD, эффекты, попапы,
## кофейня, менеджеры). Здесь — только подписки на сигналы и восстановление
## состояния. HUD не мешает вводу (mouse_filter = IGNORE), поле перехватывает
## drag в _unhandled_input.

## Самопроверка и файловый лог запуска (scripts/dev/selftest.gd): только в
## debug-сборке и только по запросу — настройка dev/selftest/enabled или --selftest.
const SELFTEST := preload("res://scripts/dev/selftest.gd")
## Менеджер заказов берём через preload, а не через глобальный class_name:
## global_script_class_cache.cfg обновляется только импортом (редактор), и без
## него строгий тип `OrderManager` ломает компиляцию game.gd.
const ORDER_MANAGER := preload("res://scripts/order_manager.gd")
## Резолвер реального арта (assets/) — тоже через preload, см. комментарий выше.
const ART := preload("res://scripts/data/art.gd")
## Таблицы меты (12 котов, 7 наград, 9 предметов декора) — scripts/data/meta.gd.
const META_DATA := preload("res://scripts/data/meta.gd")
## Силы вибрации (enum Strength) — scripts/autoload/haptics.gd, docs/haptics.md.
## Берём константой, а не через автолоад: `Haptics.Strength` через узел
## разрешается нестабильно, а `HAPTICS.Strength` — обычная константа скрипта.
const HAPTICS := preload("res://scripts/autoload/haptics.gd")
## Безопасные зоны iPhone (вырез/home-индикатор) — см. scripts/ui/safe_area.gd.
const SAFE_AREA := preload("res://scripts/ui/safe_area.gd")
## Константы полётов (FLY_TIME, COIN_STAGGER) слоя эффектов.
const FX_LAYER := preload("res://scripts/ui/fx_layer.gd")
## Реклама, консент и покупки — дочерний узел (scripts/monetization.gd).
const MONETIZATION := preload("res://scripts/monetization.gd")
const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
const GEM_ICON := preload("res://assets/ui/theme/icon_gem.png")
## Летящие монеты — покадровая анимация assets/vfx/coins_*.png (fx_layer.gd).
const COIN_VFX := "coins"
const COIN_VFX_SIZE := 64.0
## Цвет искр слияния по цепочке.
## Яркие тона: на кремовом поле тёмные искры не видны.
const MERGE_COLORS := {
	&"coffee": Color("FFB347"),
	&"pastry": Color("FFD35C"),
	&"flowers": Color("FF7FB8"),
}

# --- Узлы сцены (scenes/game.tscn) --------------------------------------------

## Фон главного экрана (прячется вместе с полем, пока открыта кофейня).
@onready var _bg_layer: CanvasLayer = $Background
@onready var _board: Board = $Board
## Слой HUD: прячется целиком, пока открыта кофейня.
@onready var _hud_layer: CanvasLayer = $HudLayer
## HUD (scripts/ui/game_hud.gd): уровень, энергия/монеты/гемы, магазин
## и нижний ряд кнопок. Само поле, заказы и меню действий живут отдельно.
## Без типа: GameHUD берём через preload, global class cache может быть пуст.
@onready var _hud = %GameHUD
## Отклик: полёты монет/предметов, частицы, тосты (scripts/ui/fx_layer.gd).
@onready var _fx: CanvasLayer = $Fx
## Окно нового уровня (scenes/ui/level_up.tscn).
@onready var _level_up: CanvasLayer = $LevelUp
## Меню действий по тапу на предмет (scenes/ui/item_actions.tscn).
@onready var _item_actions: CanvasLayer = $ItemActions
@onready var _orders: ORDER_MANAGER = $Orders
@onready var _monetization: MONETIZATION = $Monetization
## Попапы: экран энергии (docs/GDD.md §6) и настройки тестового билда (§20).
@onready var _energy_popup: CanvasLayer = $EnergyPopup
@onready var _settings_popup: CanvasLayer = $SettingsPopup
@onready var _meta_popup: CanvasLayer = $MetaPopup
## Экран кофейни (изометрия) — открывается кнопкой ▶ в нижнем ряду.
@onready var _cafe_view: CanvasLayer = $CafeView
@onready var _chain_popup: CanvasLayer = $ChainPopup
## Магазин мебели за монеты (scenes/ui/decor_shop.tscn) — открывается из кофейни.
@onready var _decor_shop: CanvasLayer = $DecorShop
## Раз в секунду — то, что зависит только от времени (_on_tick).
@onready var _ticker: Timer = $Ticker

## Когда игрок последний раз касался экрана (для подсказки «что слить»).
var _last_input_ms := 0
## Клетка, для которой открыто меню действий (-1 — закрыто).
var _action_cell: int = -1
## Выполнено заказов всего (условие открытия котов, GDD §8.2), ключ сейва orders_done.
var _orders_done: int = 0
## Лимит применений бустера за сессию (docs/GDD.md §18): kind → сколько раз уже применили.
var _booster_used: Dictionary = {}
var _selftesting: bool = false
## Идёт сброс прогресса: старая сцена не должна записать своё поле в свежий сейв.
var _resetting := false
## Идёт «продать всё»: отдельные продажи без тостов и полётов монет.
var _bulk_selling := false
var _orders_refresh_queued := false
## Тикал ли на прошлой секунде бонус за скорость (последний тик — убрать таймер).
var _bonus_running := false
## Местные сутки на прошлом тике: их смену ловит _on_tick.
var _day := -1


func _ready() -> void:
	# «Назад» на Android закрывает верхний экран, а не всю игру (_on_back).
	get_tree().quit_on_go_back = false
	SELFTEST.reset_log()
	SELFTEST.log_step("ready: start")
	SaveManager.ensure_loaded()
	# Запись сейва (отложенная и на сворачивании) ведёт SaveManager; поле и
	# заказы он забирает у нас через провайдер (_save_state).
	SaveManager.register_provider(_save_state)
	SELFTEST.log_step("ready: save loaded")
	_connect_board()
	SELFTEST.log_step("ready: board ready")
	_connect_hud()
	_connect_orders()
	_connect_monetization()
	_connect_popups()
	Wallet.coins_changed.connect(_on_coins_changed)
	Wallet.gems_changed.connect(_on_gems_changed)
	var safe := SAFE_AREA.insets()
	SELFTEST.log_step("ready: hud + orders ready")
	SELFTEST.log_step("safe area: L%.0f T%.0f R%.0f B%.0f" % [safe.x, safe.y, safe.z, safe.w])
	SELFTEST.log_step("art: предметов найдено %d/%d" % [ART.count_item_art(), _total_item_art()])
	_run_selftest()
	_restore()
	SELFTEST.log_step("ready: restored")

	Energy.energy_changed.connect(_on_energy_changed)
	Energy.energy_not_enough.connect(_on_energy_not_enough)
	Progress.xp_changed.connect(_on_xp_changed)
	Progress.level_changed.connect(_on_level_changed)
	Meta.cat_unlocked.connect(_on_cat_unlocked)
	# Бейдж меню (награда дня) — по сигналу Meta.
	Meta.daily_changed.connect(_refresh_meta_badge.unbind(1))
	_refresh_energy()
	_day = Meta.local_day()

	_ticker.timeout.connect(_on_tick)

	_last_input_ms = Time.get_ticks_msec()
	Analytics.log_event("game_opened")
	_ftue_step("opened")
	SELFTEST.log_step("ready: done")


## Раз в секунду — только то, что зависит от времени, а не от сигналов:
## заряды генераторов и пузыри (Board.tick), таймер бонуса заказов, смена
## суток и подсказка «что слить». Энергия, монеты, гемы, уровень, мета —
## обновляются по сигналам.
func _on_tick() -> void:
	_board.tick()
	# Кофейня закрывает главный экран целиком: HUD обновится при её закрытии.
	if _cafe_view.visible:
		return
	_refresh_bonus_timers()
	_check_day()
	_idle_hint()


## Таймер бонуса за скорость на карточках заказов: перерисовываем, пока он
## идёт у какого-нибудь заказа, и ещё раз, когда последний истёк (награда
## падает до базовой).
func _refresh_bonus_timers() -> void:
	var running := false
	for i in _orders.orders().size():
		if _orders.bonus_seconds_left(i) > 0:
			running = true
			break
	if running or _bonus_running:
		_refresh_orders()
	_bonus_running = running


## Наступили новые местные сутки (награда дня, лимит rewarded) — сигнала
## на это нет, сверяемся с часами.
func _check_day() -> void:
	var day: int = Meta.local_day()
	if day == _day:
		return
	_day = day
	_refresh_meta_badge()
	if _energy_popup.visible:
		_refresh_energy_popup_state()


## Подсказка: если игрок долго ничего не делает, покачать пару для слияния.
func _idle_hint() -> void:
	var idle := Time.get_ticks_msec() - _last_input_ms
	if idle < int(_cfg_num("idle_hint_seconds", 6.0) * 1000.0) or _any_overlay_open():
		return
	var pair: Vector2i = _board.find_merge_pair()
	if pair.x >= 0:
		_board.hint_pair(pair)
	# Следующая подсказка — снова через паузу, а не каждую секунду.
	_last_input_ms = Time.get_ticks_msec()


func _any_overlay_open() -> bool:
	for layer in [_energy_popup, _settings_popup, _meta_popup, _cafe_view, _item_actions,
			_chain_popup, _decor_shop, _level_up]:
		if layer != null and (layer as CanvasLayer).visible:
			return true
	return false


## Любое касание сбрасывает таймер подсказки и останавливает покачивание.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		_last_input_ms = Time.get_ticks_msec()
		if _board != null:
			_board.stop_hint()


## Сворачивание и закрытие сохраняет SaveManager (свой _notification);
## здесь — только «назад» на Android.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


## «Назад» (Android): закрыть верхний открытый экран; на главном — сохранить
## и выйти. Порядок — сверху вниз по слоям (магазин мебели лежит поверх кофейни).
func _on_back() -> void:
	if _board != null and _board.take_target:
		_cancel_hammer_aim()
		_notify("Хаммер отменён", "info")
		return
	if _item_actions != null and _item_actions.visible:
		_close_item_actions()
		return
	for layer in [_level_up, _decor_shop, _chain_popup,
			_energy_popup, _settings_popup, _meta_popup, _cafe_view]:
		if layer != null and (layer as CanvasLayer).visible:
			layer.close()
			return
	SaveManager.flush()
	get_tree().quit()


## Сцена уходит (выход, перезагрузка): дописать поле, пока оно живо, и
## отписаться от SaveManager. После сброса прогресса старое поле не пишем.
func _exit_tree() -> void:
	if not _resetting:
		SaveManager.flush()
	SaveManager.unregister_provider(_save_state)


# --- Подписки на узлы сцены ----------------------------------------------------

func _connect_board() -> void:
	_board.items_merged.connect(_on_items_merged)
	_board.generator_tapped.connect(_on_generator_tapped)
	_board.bubble_popped.connect(_on_bubble_popped)
	_board.item_placed.connect(_on_item_placed)
	_board.board_filled.connect(_on_board_filled)
	_board.invalid_drop.connect(_on_invalid_drop)
	_board.item_sold.connect(_on_item_sold)
	_board.booster_target_picked.connect(_on_booster_target)
	_board.item_tapped.connect(_on_item_tapped)
	_board.contents_changed.connect(_queue_orders_refresh)
	# Любое изменение поля (и перестановка) — отложенная запись сейва.
	_board.contents_changed.connect(SaveManager.request_save)
	_board.item_moved.connect(SaveManager.request_save.unbind(2))


func _connect_orders() -> void:
	_orders.orders_changed.connect(_refresh_orders)
	_orders.orders_changed.connect(SaveManager.request_save)
	# Заказы нужны уже к selftest; _restore() поле не трогает.
	_restore_orders()


func _restore_orders() -> void:
	var slots := Progress.order_slots()
	var saved = SaveManager.get_value("orders", [])
	if typeof(saved) == TYPE_ARRAY and not (saved as Array).is_empty():
		_orders.load_orders(saved)
		_orders.top_up(slots)
	else:
		_orders.setup(slots)


## Ряд заказов: карточка на слот (scenes/ui/order_card.tscn) — иконки нужных
## предметов, награда, таймер бонуса и кнопка смены за гемы. Обновляется по
## сигналам (заказы, поле, гемы) и раз в секунду, пока идёт таймер бонуса.
func _refresh_orders() -> void:
	if _hud == null or _orders == null:
		return
	var list: Array = _orders.orders()
	var cards: Array = _hud.ensure_order_cards(list.size(), _on_order_pressed, _on_order_reroll)
	var cost := _reroll_cost()
	for i in mini(cards.size(), list.size()):
		var order: Dictionary = list[i]
		cards[i].show_order(order, int(_orders.reward_for(order).get("coins", 0)),
			_orders.bonus_seconds_left(i), _orders.availability(i, _board))
		cards[i].set_reroll(cost, Wallet.gems() >= cost)


## Поле поменялось — карточки заказов (что уже есть на поле) обновим один раз
## в конце кадра, а не на каждый предмет из серии.
func _queue_orders_refresh() -> void:
	if _orders_refresh_queued or _selftesting:
		return
	_orders_refresh_queued = true
	_run_orders_refresh.call_deferred()


func _run_orders_refresh() -> void:
	_orders_refresh_queued = false
	_refresh_orders()


func _reroll_cost() -> int:
	return int(_cfg_num("order_reroll_cost_gems", 5.0))


func _connect_hud() -> void:
	# HUD — сцена scenes/ui/game_hud.tscn на контейнерах: шапка, заказы, статус,
	# область поля, генераторы, нижний ряд. Сама держит safe area и не ловит
	# ввод в области поля (mouse_filter = IGNORE), поэтому поле кликабельно.
	_hud.level_pressed.connect(_on_hud_level_pressed)
	_hud.energy_plus_pressed.connect(_on_hud_energy_plus_pressed)
	_hud.gems_plus_pressed.connect(_on_hud_gems_plus_pressed)
	_hud.settings_pressed.connect(_on_settings_pressed)
	_hud.menu_pressed.connect(_on_meta_pressed)
	_hud.play_pressed.connect(_on_hud_play_pressed)
	# Поле (Node2D) вписывается в область %BoardArea: контейнеры HUD решают,
	# сколько места ему осталось между заказами и нижним рядом кнопок.
	# Тосты появляются под рядом заказов (верх области поля).
	_hud.board_area_changed.connect(_on_board_area_changed)
	var area: Rect2 = _hud.board_rect()
	if area.size.x > 0.0 and area.size.y > 0.0:
		_on_board_area_changed(area)

	# Меню действий по тапу на предмет (docs/GDD.md §18): тапнул предмет —
	# палец ничего не закрывает, промахнуться некуда.
	_item_actions.sell_pressed.connect(_on_action_sell)
	_item_actions.chain_pressed.connect(_on_action_chain)
	_item_actions.closed.connect(func() -> void: _action_cell = -1)


func _on_board_area_changed(rect: Rect2) -> void:
	_board.set_area(rect)
	_fx.set_toast_top(rect.position.y + 8.0)


## Попапы и кофейня.
func _connect_popups() -> void:
	_energy_popup.rewarded_requested.connect(_monetization.request_rewarded_energy)

	_settings_popup.sell_all_requested.connect(_on_sell_all)
	_settings_popup.reset_requested.connect(_on_reset_progress)
	_settings_popup.technospike_action.connect(_monetization.technospike)
	## Бустеры переехали из HUD в настройки (нижняя полоса убрана).
	_settings_popup.booster_requested.connect(_on_booster_pressed)

	_meta_popup.daily_claim_requested.connect(_on_daily_claim)

	_cafe_view.decor_place_requested.connect(_on_decor_place)
	_cafe_view.decor_rotate_requested.connect(_on_decor_rotate)
	_cafe_view.decor_remove_requested.connect(_on_decor_remove)
	_cafe_view.closed.connect(_on_cafe_closed)
	_cafe_view.shop_requested.connect(_open_decor_shop)
	# Магазин — слой поверх кофейни: пока он открыт, мир кофейни не трогаем.
	_cafe_view.overlays = [_decor_shop]
	_decor_shop.buy_requested.connect(_on_decor_buy)


# --- Состояние ---------------------------------------------------------------

func _restore() -> void:
	var saved = SaveManager.get_value("board", [])
	if typeof(saved) == TYPE_ARRAY and not (saved as Array).is_empty():
		_board.load_from(saved)
	_migrate_removed_features()
	_ensure_generators()
	_orders_done = int(SaveManager.get_value("orders_done", 0))
	_refresh_hud()
	_refresh_meta_badge()


## Склад, ремонт за звёзды и ивент убраны из игры. Предметы со склада
## возвращаем на поле в свободные клетки (что не влезло — пропадает), ключи
## склада, звёзд и ивента (event_<id>_start/points/claimed) стираем.
func _migrate_removed_features() -> void:
	var stored = SaveManager.get_value("storage", [])
	if typeof(stored) == TYPE_ARRAY:
		var returned := 0
		var dropped := 0
		for entry in stored:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if _board.free_cells().is_empty():
				dropped += 1
				continue
			_board.place_data(ItemData.from_dict(entry))
			returned += 1
		if returned + dropped > 0:
			print("[Game] склад убран: на поле вернули %d, не влезло %d" % [returned, dropped])
	for key in ["storage", "storage_slots", "stars"]:
		SaveManager.erase_value(key)
	for key: String in SaveManager.data.keys():
		if key.begins_with("event_"):
			SaveManager.erase_value(key)


## Провайдер SaveManager: состояние, которое живёт в узлах сцены, а не в
## SaveManager.data. Ключи прежние (board/orders/energy) — сейвы совместимы.
## Пока идёт самопроверка или сброс, отдаём пусто: в data остаётся прежнее.
func _save_state() -> Dictionary:
	if _selftesting or _resetting or _board == null or _orders == null:
		return {}
	return {
		"board": _board.serialize(),
		"energy": Energy.current(),
		"orders": _orders.orders().duplicate(true),
	}


# --- HUD ---------------------------------------------------------------------

func _refresh_hud() -> void:
	if _hud != null:
		_hud.set_coins(Wallet.coins())
		_hud.set_gems(Wallet.gems())
	_refresh_boosters()
	_refresh_progress()
	_push_analytics_state()


## Медленно меняющееся состояние — в профиль ($set, троттлинг внутри Analytics).
## Моментальные значения (монеты, гемы, энергия, свободные клетки) в профиль НЕ
## идут: они уезжают свойствами важных событий через _log_game_event() — иначе
## профиль переписывался бы на каждый тап (docs/analytics.md §3).
func _push_analytics_state() -> void:
	if _board == null:
		return
	Analytics.update_user_props({
		"level": Progress.level,
		"xp": Progress.xp,
		"board_cells": _board.cell_count(),
		"order_slots": Progress.order_slots(),
		"boosters_used": _booster_used.size(),
	})


## Моментальный срез для свойств события: что было у игрока в этот момент.
func _analytics_snapshot() -> Dictionary:
	if _board == null:
		return {}
	return {
		"player_level": Progress.level,
		"coins": Wallet.coins(),
		"gems": Wallet.gems(),
		"energy": Energy.current(),
		"free_cells": _board.free_cells().size(),
	}


## Игровое событие со снимком состояния. Ключи из params перекрывают снимок:
## например item_sold.level — уровень предмета, а не игрока.
func _log_game_event(event_name: String, params: Dictionary = {}) -> void:
	# Без ключа/согласия событие всё равно отбросится — не считаем снимок зря.
	if not Analytics.enabled or not Analytics.consent_granted:
		return
	var merged := _analytics_snapshot()
	merged.merge(params, true)
	Analytics.log_event(event_name, merged)


func _refresh_progress() -> void:
	if _hud != null:
		_hud.set_level(Progress.level)
		_hud.set_xp(Progress.progress_ratio())


## Бустеры живут в попапе настроек (нижняя полоса HUD убрана): состояние уезжает
## туда словарём kind → {text, enabled}.
func _refresh_boosters() -> void:
	if _settings_popup == null:
		return
	var limit := int(_cfg_num("booster_per_session_limit", 1.0))
	var info := {}
	for kind in ["hammer", "shuffle", "magnet"]:
		var cost := _booster_cost(kind)
		var used_up := limit > 0 and int(_booster_used.get(kind, 0)) >= limit
		info[kind] = {
			"text": "Использован" if used_up else "%d гемов" % cost,
			"enabled": not used_up and Wallet.gems() >= cost,
		}
	_settings_popup.refresh_boosters(info)


func _booster_cost(kind: String) -> int:
	match kind:
		"hammer":
			return int(_cfg_num("booster_hammer_gems", 5.0))
		"shuffle":
			return int(_cfg_num("booster_shuffle_gems", 10.0))
		"magnet":
			return int(_cfg_num("booster_magnet_gems", 15.0))
	return 0


func _refresh_energy() -> void:
	if _hud != null:
		_hud.set_energy(Energy.current())


## Сообщение игроку — тост (scripts/ui/fx_layer.gd). kind: "info" | "error" |
## "success"; ошибки — то, что игрок попробовал сделать, а не вышло.
func _notify(text: String, kind := "info", icon: Texture2D = null) -> void:
	if _fx != null:
		# В кофейне внизу — панель инвентаря: тосты остаются сверху, над планом.
		var cafe_only := _cafe_view.visible and not _decor_shop.visible
		_fx.set_toasts_bottom(_any_overlay_open() and not _item_actions.visible and not cafe_only)
		_fx.toast(text, icon, kind)


# --- Обработчики -------------------------------------------------------------

func _on_booster_pressed(kind: String) -> void:
	if _board == null:
		return
	var limit := int(_cfg_num("booster_per_session_limit", 1.0))
	if limit > 0 and int(_booster_used.get(kind, 0)) >= limit:
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Этот бустер уже использован в сессии", "error")
		return
	var cost := _booster_cost(kind)

	if kind == "hammer":
		# Гемы не списываем до выбора цели: отмена/уход в меню не должны стоить денег.
		if Wallet.gems() < cost:
			Haptics.selection(HAPTICS.Strength.MEDIUM)
			_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
			return
		_board.take_target = true
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Хаммер: тапни предмет, чтобы убрать", "info")
		return

	if not Wallet.spend_gems(cost):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
		return

	var applied := false
	match kind:
		"shuffle":
			applied = _board.shuffle()
			if applied:
				_notify("Поле перемешано", "success")
			else:
				_notify("Нечего перемешивать", "error")
		"magnet":
			var chain := _magnet_chain()
			var count := int(_cfg_num("booster_magnet_count", 3.0))
			var placed := 0
			for i in count:
				if _board.spawn(chain, 1):
					placed += 1
			applied = placed > 0
			_notify("Магнит: +%d %s" % [placed, _plural(placed, "предмет", "предмета", "предметов")], "success")

	if not applied:
		# Эффекта не было — возвращаем гемы.
		Haptics.selection(HAPTICS.Strength.LIGHT)
		Wallet.add_gems(cost)
		return

	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_booster_used[kind] = int(_booster_used.get(kind, 0)) + 1
	Analytics.log_event("booster_used", {"kind": kind, "cost": cost})
	_refresh_boosters()
	# Шафл переставляет предметы без сигналов поля — сохранение просим сами.
	SaveManager.request_save()


## Хаммер выбрал цель. cell < 0 — тап мимо предмета: просто снимаем прицел.
func _on_booster_target(cell: int) -> void:
	if cell < 0:
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Хаммер отменён", "info")
		return
	var target_item := _board.item_at(cell)
	if target_item != null and target_item.is_generator():
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Генератор молотком не убрать", "error")
		return
	var cost := _booster_cost("hammer")
	if not Wallet.spend_gems(cost):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
		return
	Haptics.selection()
	_board.remove_at_cell(cell)
	_booster_used["hammer"] = int(_booster_used.get("hammer", 0)) + 1
	Analytics.log_event("booster_used", {"kind": "hammer", "cost": cost})
	Analytics.log_event("booster_target", {"kind": "hammer", "cell": cell})
	_notify("Хаммер: предмет убран", "success")
	_refresh_boosters()


## Снять прицел хаммера при открытии любого модального экрана.
func _cancel_hammer_aim() -> void:
	if _board != null:
		_board.cancel_take_target()


## Магнит даёт предметы той цепочки, которую сейчас просят заказы.
func _magnet_chain() -> StringName:
	for order in _orders.orders():
		for req in (order as Dictionary).get("items", []):
			var chain := StringName(String(req.get("chain", "")))
			if Progress.is_generator_unlocked(chain):
				return chain
	return _first_unlocked_chain()


func _first_unlocked_chain() -> StringName:
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain):
			return chain
	return Chains.COFFEE


## Тап по генератору на поле: L1 его цепочки (иногда L2) в ближайшую
## свободную клетку. Тратит энергию и заряд; без зарядов генератор отдыхает.
func _on_generator_tapped(cell: int) -> void:
	var gen := _board.item_at(cell)
	if gen == null or not gen.is_generator():
		return
	var data := gen.data
	var now := int(Time.get_unix_time_from_system())
	if data.charges <= 0:
		Haptics.selection(HAPTICS.Strength.LIGHT)
		var left := maxi(0, data.recharge_at - now)
		_notify("%s отдыхает: %d:%02d" % [Chains.title(data.chain), floori(left / 60.0), left % 60], "info")
		return
	if _board.free_cell_near(cell) < 0:
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Поле заполнено — слей пары или продай лишнее", "error")
		return
	# Не хватило — Energy шлёт energy_not_enough, экран энергии открывает
	# _on_energy_not_enough (вибрация и аналитика там же).
	if not Energy.spend(_generator_cost()):
		return
	var target := Chains.generator_target(data.chain)
	var level := 2 if randf() < Chains.gen_param("gen_bonus_chance", data.level, 0.0) else 1
	var spawned := _board.item_at(_board.place_data(Chains.make(target, level), cell))
	if spawned != null:
		spawned.merge_pop()
	data.charges -= 1
	if data.charges <= 0:
		data.recharge_at = now + int(Chains.gen_param("gen_recharge_sec", data.level, 180.0))
	gen.punch()
	gen.refresh_overlay()
	Haptics.selection()
	_log_game_event("generator_tap", {"chain": String(target), "gen_level": data.level, "level": level})
	_ftue_step("first_generator")
	_refresh_energy()


## У каждой открытой цепочки должен быть генератор на поле.
## Нет (старый сейв, новая цепочка открылась) — выдаём L1.
func _ensure_generators() -> void:
	var have := {}
	for i in _board.cells.size():
		var item := _board.item_at(i)
		if item != null and item.is_generator():
			have[Chains.generator_target(item.data.chain)] = true
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain) and not have.has(chain):
			_give_item(Chains.make(Chains.generator_for(chain), 1))


## Выдать предмет на поле. Возвращает false, если места нет (предмет не выдан).
func _give_item(data: ItemData) -> bool:
	return _board.place_data(data) >= 0


func _on_items_merged(_from_cell: int, to_cell: int, chain: StringName, level: int) -> void:
	# Самопроверка гоняет слияния: ни вибрации, ни FTUE, ни аналитики.
	if _selftesting:
		return
	# Слияние — единственный «сочный» удар: системный impact medium, не серия тиков.
	Haptics.impact(HAPTICS.ImpactStyle.MEDIUM)
	_log_game_event("item_merged", {"chain": String(chain), "level": level})
	var item := _board.item_at(to_cell)
	if item != null:
		item.merge_pop()
	# Искры: чем выше уровень, тем пышнее вспышка.
	var power := clampf(1.0 + float(level - 2) * 0.35, 1.0, 3.0)
	var spark_chain := Chains.generator_target(chain) if Chains.is_generator(chain) else chain
	_fx.burst(_cell_screen(to_cell), MERGE_COLORS.get(spark_chain, Color("FFD27A")), power)
	if Chains.is_generator(chain):
		_notify("%s улучшена: ур. %d" % [Chains.title(chain), level], "success")
	else:
		_maybe_spawn_bubble(to_cell, chain, level)
	_ftue_step("first_merge")


## «Пузырь»: после слияния высокого уровня иногда рядом всплывает копия —
## её можно забрать за гемы, пока не лопнула.
func _maybe_spawn_bubble(near: int, chain: StringName, level: int) -> void:
	if level < int(_cfg_num("bubble_min_level", 4.0)) or randf() >= _cfg_num("bubble_chance", 0.12):
		return
	if _board.free_cell_near(near) < 0:
		return
	var bubble := _board.item_at(_board.place_data(Chains.make(chain, level), near))
	if bubble != null:
		bubble.set_bubble(_cfg_num("bubble_seconds", 60.0))
		bubble.merge_pop()
		_notify("Пузырь! Забери копию, пока не лопнула", "info")


func _bubble_price(level: int) -> int:
	return level * int(_cfg_num("bubble_gems_per_level", 2.0))


func _on_bubble_popped(cell: int, _data: ItemData) -> void:
	_fx.play("smoke", _cell_screen(cell), _board.cell_size * 1.1)
	if _action_cell == cell:
		_close_item_actions()


## Каждый новый предмет — в «открытые» уровни цепочки (экран цепочки).
func _on_item_placed(_cell: int, data: ItemData) -> void:
	if data == null or Chains.is_generator(data.chain) or _selftesting:
		return
	var discovered: Dictionary = SaveManager.get_value("discovered", {})
	if int(discovered.get(String(data.chain), 0)) < data.level:
		discovered[String(data.chain)] = data.level
		SaveManager.set_value("discovered", discovered)


func _on_board_filled() -> void:
	Haptics.selection(HAPTICS.Strength.LIGHT)
	_notify("Поле заполнено — слей пары или продай лишнее", "error")


func _on_invalid_drop(_from_cell: int, to_cell: int) -> void:
	Haptics.selection(HAPTICS.Strength.LIGHT)
	if to_cell < 0:
		_notify("Продажа — тапни по предмету", "info")
		return
	_notify("Сюда нельзя — нужен такой же предмет", "error")


## Тап по предмету: открываем меню действий вместо «брось мимо поля».
func _on_item_tapped(cell: int) -> void:
	var node := _board.item_at(cell)
	if node == null or node.data == null or _item_actions == null:
		return
	var data: ItemData = node.data
	_action_cell = cell
	Haptics.selection()
	# Карточка встаёт рядом с предметом: передаём его экранный прямоугольник.
	var center := _board.to_global(_board.cell_center(cell))
	var half := Vector2.ONE * _board.cell_size * 0.5
	var anchor := Rect2(center - half, half * 2.0)
	if node.is_bubble():
		var price := _bubble_price(data.level)
		var left := maxi(0, ceili((node.bubble_until - Time.get_ticks_msec()) / 1000.0))
		_item_actions.open_bubble("Пузырь: " + Chains.item_name(data.chain, data.level),
			"Лопнет через %d с" % left, price, Wallet.gems() >= price, anchor)
		return
	var hint := "Такой предмет ждут заказы — сдача даст монет больше" \
		if _order_wants(data.chain, data.level) else ""
	_item_actions.open(Chains.item_name(data.chain, data.level), hint, _sell_price(data), anchor)
	node.punch()


func _close_item_actions() -> void:
	_action_cell = -1
	if _item_actions != null:
		_item_actions.close()


func _on_action_sell() -> void:
	var cell := _action_cell
	_close_item_actions()
	if cell < 0:
		return
	var node := _board.item_at(cell)
	if node != null and node.is_bubble():
		_buy_bubble(cell)
		return
	_board.sell_at(cell)


## Забрать пузырь: гемы → обычный предмет на том же месте.
func _buy_bubble(cell: int) -> void:
	var node := _board.item_at(cell)
	if node == null:
		return
	var price := _bubble_price(node.data.level)
	if not Wallet.spend_gems(price):
		_notify("Не хватает гемов: нужно %d" % price, "error", GEM_ICON)
		return
	var data := node.data
	_board.remove_at_cell(cell)
	_board.place_data(data, cell)
	var fresh := _board.item_at(cell)
	if fresh != null:
		fresh.merge_pop()
	_fx.play("smoke", _cell_screen(cell), _board.cell_size * 1.1)
	_fx.play("sparkle", _cell_screen(cell), _board.cell_size * 0.9)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_log_game_event("bubble_bought", {"chain": String(data.chain), "level": data.level, "gems": price})
	_notify("Забрано: %s" % Chains.item_name(data.chain, data.level), "success")


# --- Цепочка предмета ----------------------------------------------------------

func _on_action_chain() -> void:
	var node := _board.item_at(_action_cell)
	_close_item_actions()
	if node == null:
		return
	var discovered: Dictionary = SaveManager.get_value("discovered", {})
	var known := maxi(node.data.level, int(discovered.get(String(node.data.chain), 0)))
	_chain_popup.show_chain(node.data.chain, node.data.level, known)


static func _item_icon(data: ItemData) -> Texture2D:
	var chain := Chains.generator_target(data.chain) if Chains.is_generator(data.chain) else data.chain
	var level := 1 if Chains.is_generator(data.chain) else data.level
	var tex: Texture2D = ART.item_texture(chain, level)
	return tex if tex != null else Placeholders.item_texture(chain, level)


# --- Магазин мебели (scripts/ui/decor_shop.gd) ------------------------------

func _open_decor_shop() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_decor_shop.open()


## Покупка за монеты: предмет уходит в инвентарь кофейни (не ставится сам).
func _on_decor_buy(decor_id: String) -> void:
	var result: Dictionary = Meta.buy_decor(decor_id)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify(_sentence(String(result.get("reason", ""))), "error", COIN_ICON)
		return
	var decor: Dictionary = result.get("decor", META_DATA.decor(decor_id))
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_log_game_event("decor_purchased", {"decor": decor_id, "cost": int(decor.get("cost", 0)),
		"xp": int(result.get("xp", 0)), "via": "shop"})
	_notify("Куплено: %s — в инвентаре кофейни" % String(decor.get("name", decor_id)), "success")
	_refresh_hud()
	_decor_shop.refresh()
	_meta_popup.refresh()


## Цена продажи предмета (docs/economy.md): sell_value × sell_value_mult.
func _sell_price(data: ItemData) -> int:
	return int(round(float(Chains.sell_value(data.level, _cfg_num("item_value_base", 5.0), _cfg_num("item_value_growth", 2.05))) * _cfg_num("sell_value_mult", 0.6)))


## Просят ли такой предмет текущие заказы — подсказка в меню действий.
func _order_wants(chain: StringName, level: int) -> bool:
	for order in _orders.orders():
		for req in order.get("items", []):
			if StringName(req.get("chain", "")) == chain and int(req.get("level", 0)) == level:
				return true
	return false


func _on_energy_changed(_value: int, _maximum: int) -> void:
	_refresh_energy()


func _on_energy_not_enough(required: int, left: int) -> void:
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	Analytics.log_event("energy_empty_shown", {"required": required, "left": left})
	_energy_popup.open()
	_refresh_energy_popup_state()
	_ftue_step("out_of_energy")


func _on_order_pressed(index: int) -> void:
	var result: Dictionary = _orders.try_deliver(index, _board)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.LIGHT)
		# Не хватает предмета: карточка встряхивается, в тосте — его иконка.
		_hud.shake_order(index)
		var icon: Texture2D = null
		var missing: Dictionary = result.get("missing", {})
		if not missing.is_empty():
			icon = ART.item_texture(StringName(missing.get("chain", "")), int(missing.get("level", 1)))
		_notify(_sentence(String(result.get("reason", ""))), "error", icon)
		return
	var cat_bonus := Meta.cat_bonus()
	var coins := int(round(float(result.get("coins", 0)) * cat_bonus))
	var xp := int(result.get("xp", 0))
	var gems := int(result.get("gems", 0))
	var bonus := float(result.get("bonus", 1.0))
	# Предметы летят с поля в карточку заказа, карточка «подпрыгивает», и из неё
	# к счётчикам вылетают монеты (и гем). Счётчики придержаны до прилёта.
	var card: Vector2 = _hud.order_center(index)
	for taken: Dictionary in result.get("items", []):
		var chain := StringName(taken.get("chain", ""))
		var level := int(taken.get("level", 1))
		var tex: Texture2D = ART.item_texture(chain, level)
		if tex == null:
			tex = Placeholders.item_texture(chain, level)
		_fx.fly(tex, _cell_screen(int(taken.get("cell", 0))), card, _board.cell_size * 0.6, 0.4)
	var coin_count := clampi(int(coins / 10.0), 3, 10)
	var reward_time := 0.4 + FX_LAYER.FLY_TIME + (coin_count - 1) * FX_LAYER.COIN_STAGGER
	_hud.hold_coins(reward_time)
	if gems > 0:
		_hud.hold_gems(reward_time)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		_hud.punch_order(index)
		_fx.play("check", card, 150.0)
		_fx.fly_many(COIN_VFX, card, _hud.coin_target(), coin_count, _hud.punch_coins, COIN_VFX_SIZE)
		if gems > 0:
			_fx.fly_many(GEM_ICON, card, _hud.gem_target(), gems, _hud.punch_gems, 48.0))
	Wallet.add_coins(coins)
	if gems > 0:
		Wallet.add_gems(gems)
	Progress.add_xp(xp)
	_log_game_event("order_completed", {"coins": coins, "xp": xp, "gems": gems, "bonus": bonus})
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	if gems > 0:
		Haptics.selection(HAPTICS.Strength.LIGHT)
	var details := PackedStringArray()
	if bonus > 1.0:
		details.append("×%.1f за скорость" % bonus)
	if cat_bonus > 1.0:
		details.append("коты +%d%%" % Meta.cat_bonus_percent())
	if gems > 0:
		details.append("+%d %s" % [gems, _plural(gems, "гем", "гема", "гемов")])
	var text := "Заказ готов! +%d %s · +%d XP" % [coins, _plural(coins, "монета", "монеты", "монет"), xp]
	if not details.is_empty():
		text += "\n" + ", ".join(details)
	_fx.toast(text, COIN_ICON)
	_ftue_step("first_order")
	_orders_done += 1
	SaveManager.set_value("orders_done", _orders_done)
	_check_cat_unlocks()


## Реролл заказа за гемы (цена — Config.order_reroll_cost_gems, см. docs/economy.md).
func _on_order_reroll(index: int) -> void:
	if _orders == null or _orders.order_at(index).is_empty():
		return
	var cost := _reroll_cost()
	if not Wallet.spend_gems(cost):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
		return
	if not _orders.replace(index):
		# Замена не удалась — не берём гемы за пустоту.
		Wallet.add_gems(cost)
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не удалось обновить заказ", "error")
		return
	Analytics.log_event("order_rerolled", {"index": index, "cost": cost})
	_notify("Заказ обновлён", "success")


func _on_xp_changed(_xp: int, _next: int) -> void:
	_refresh_progress()


func _on_level_changed(level: int, previous: int) -> void:
	_refresh_progress()
	_push_analytics_state()
	# Слотов могло стать больше: догружаем текущие заказы (не перечитываем сейв —
	# в нём может быть состояние до только что сданного заказа).
	_orders.top_up(Progress.order_slots())
	_check_cat_unlocks()
	if not _selftesting:
		_ensure_generators()
		_gift_generator(level)
	Haptics.selection(HAPTICS.Strength.HEAVY)
	_log_game_event("level_up", {"level": level, "previous": previous})
	var note := Progress.unlock_note(previous)
	_hud.punch_level()
	# Окно уровня — после полёта наград заказа, чтобы они не терялись под ним.
	if not _selftesting:
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			_level_up.show_level(level, note))


## Каждые N уровней — копия генератора открытой цепочки: её можно слить
## с имеющимся и получить генератор уровнем выше.
func _gift_generator(level: int) -> void:
	var every := int(_cfg_num("gen_gift_every_levels", 2.0))
	if every <= 0 or level % every != 0:
		return
	var open: Array = []
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain):
			open.append(chain)
	if open.is_empty():
		return
	var chain: StringName = open[randi() % open.size()]
	if _give_item(Chains.make(Chains.generator_for(chain), 1)):
		_notify("Подарок за уровень: %s" % Chains.title(Chains.generator_for(chain)), "success")
	else:
		_notify("Подарок за уровень не влез — освободи клетку на поле", "error")


func _on_item_sold(cell: int, data: ItemData) -> void:
	if data == null:
		return
	var coins := _sell_price(data)
	if _selftesting or _bulk_selling:
		# Самопроверка проверяет только начисление; «продать всё» даёт один тост.
		Wallet.add_coins(coins)
		return
	# Монеты вылетают из клетки проданного предмета к счётчику.
	var count := clampi(int(coins / 10.0), 2, 6)
	_hud.hold_coins(_fx.fly_many(COIN_VFX, _cell_screen(cell), _hud.coin_target(), count,
		_hud.punch_coins, COIN_VFX_SIZE))
	Wallet.add_coins(coins)
	Haptics.selection()
	_log_game_event("item_sold", {"chain": String(data.chain), "level": data.level, "coins": coins})
	_fx.toast("Продано: +%d %s" % [coins, _plural(coins, "монета", "монеты", "монет")], COIN_ICON)


## Кофейня закрывает экран целиком: поле и HUD под ней не рисуем
## (экономит ~45 draw call'ов и обход их узлов каждый кадр).
func _set_main_screen_visible(value: bool) -> void:
	_board.visible = value
	_hud_layer.visible = value
	_bg_layer.visible = value


## Экранная точка центра клетки поля (для полётов и частиц).
func _cell_screen(cell: int) -> Vector2:
	return _board.to_global(_board.cell_center(cell))


## «нужен предмет: X» → «Нужен предмет: X» (причины приходят со строчной).
static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1) if not text.is_empty() else text


## Форма слова по числу: 1 монета, 3 монеты, 5 монет.
static func _plural(n: int, one: String, few: String, many: String) -> String:
	var n10 := absi(n) % 10
	var n100 := absi(n) % 100
	if n10 == 1 and n100 != 11:
		return one
	if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14):
		return few
	return many


## Кошелёк изменился (scripts/autoload/wallet.gd): счётчики HUD.
func _on_coins_changed(value: int) -> void:
	if _hud != null:
		_hud.set_coins(value)


func _on_gems_changed(value: int) -> void:
	if _hud != null:
		_hud.set_gems(value)
	_refresh_boosters()
	# Кнопки смены заказа за гемы: хватает ли теперь.
	_queue_orders_refresh()


# --- Настройки тестового билда (docs/GDD.md §20) -----------------------------

func _on_settings_pressed() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_settings_popup.open()


# --- Мета: попап, награды, коты (docs/GDD.md §8) -----------------------------

## Кнопка «🐱»: попап меты (ежедневная награда, коты, декор).
func _on_meta_pressed() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	Analytics.log_event("shop_open")
	_meta_popup.open()


# --- Кнопки нового HUD (scripts/ui/game_hud.gd) ------------------------------

## Значок уровня: сколько XP до следующего уровня и что он откроет.
func _on_hud_level_pressed() -> void:
	Haptics.selection()
	if Progress.is_max_level():
		_notify("Уровень %d — максимальный" % Progress.level, "info")
		return
	var text := "Уровень %d · %d / %d XP" % [Progress.level, Progress.xp, Progress.xp_next()]
	var next := _next_unlock_text()
	if not next.is_empty():
		text += "\n" + next
	_notify(text, "info")


## Ближайшая разблокировка генератора (или пусто, если все открыты).
func _next_unlock_text() -> String:
	var best_level := 0
	var best_chain: StringName = &""
	for chain in Chains.all_chains():
		var need := Progress.generator_unlock_level(chain)
		if need > Progress.level and (best_level == 0 or need < best_level):
			best_level = need
			best_chain = chain
	if best_level == 0:
		return ""
	return "Ур. %d: генератор «%s»" % [best_level, Chains.title(best_chain)]


## ⚡+ : экран энергии (реклама за +15).
func _on_hud_energy_plus_pressed() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_energy_popup.open()
	_refresh_energy_popup_state()


## 💎+ : покупка гемов (техспайк-заглушка).
func _on_hud_gems_plus_pressed() -> void:
	_cancel_hammer_aim()
	_monetization.technospike("purchase")


## ▶ btn_play: ведёт в изо-кафе. Генераторы переехали на поле прямоугольниками,
## кнопок инвентаря и карточек в нижнем ряду больше нет.
func _on_hud_play_pressed() -> void:
	Haptics.selection()
	_on_open_cafe()


## Ежедневная награда: выдать по таблице META_DATA.DAILY_REWARDS; 7-й день — котовый сундук.
func _on_daily_claim() -> void:
	var result: Dictionary = Meta.claim()
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify(_sentence(String(result.get("reason", ""))), "error")
		return
	var reward: Dictionary = result.get("reward", {})
	var coins := int(reward.get("coins", 0))
	var gems := int(reward.get("gems", 0)) + int(result.get("gems", 0))
	var energy := int(reward.get("energy", 0))
	if coins > 0:
		Wallet.add_coins(coins)
	if gems > 0:
		Wallet.add_gems(gems)
	if energy > 0:
		Energy.add(energy)
	var cat_id := String(result.get("cat", ""))
	if cat_id != "":
		Haptics.selection(HAPTICS.Strength.HEAVY)
	else:
		Haptics.selection(HAPTICS.Strength.MEDIUM)
	var text := "Награда за день %d: " % int(result.get("day", 0))
	if coins > 0:
		text += "+%d %s " % [coins, _plural(coins, "монета", "монеты", "монет")]
	if gems > 0:
		text += "+%d %s " % [gems, _plural(gems, "гем", "гема", "гемов")]
	if energy > 0:
		text += "+%d энергии " % energy
	if cat_id != "":
		var cat := META_DATA.cat(cat_id)
		text += "кот %s!" % String(cat.get("name", cat_id))
	_log_game_event("daily_reward_claim", {"day": int(result.get("day", 0)), "coins": coins, "gems": gems, "energy": energy, "cat": cat_id})
	_notify(text.strip_edges(), "success")
	_refresh_hud()
	_refresh_meta_badge()
	_meta_popup.refresh()


## Поставить мебель в кофейне (docs/GDD.md §8.1): свободная расстановка по
## тайлам — drag из инвентаря или перенос уже стоящего предмета.
func _on_decor_place(decor_id: String, tile: Vector2i, rot: int = 0) -> void:
	var was_placed := Meta.is_placed(decor_id)
	var result: Dictionary = Meta.place_decor(decor_id, tile, rot)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify(_sentence(String(result.get("reason", ""))), "error")
		return
	var decor: Dictionary = META_DATA.decor(decor_id)
	Haptics.selection()
	if not was_placed:
		_notify("%s → %s" % [META_DATA.decor_short(decor), String(result.get("room", ""))], "info")
	_log_game_event("decor_placed", {
		"decor": decor_id,
		"tx": tile.x,
		"ty": tile.y,
		"room": String(result.get("room", "")),
		"rot": int(result.get("rot", rot)),
		"moved": was_placed,
	})
	_meta_popup.refresh()


## Повернуть мебель на месте (GDD §8.1): поворот 0..3 = N/E/S/W.
func _on_decor_rotate(decor_id: String) -> void:
	if decor_id.is_empty():
		return
	var turn := (Meta.decor_rot(decor_id) + 1) % 4
	var result: Dictionary = Meta.set_rotation(decor_id, turn)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify(_sentence(String(result.get("reason", ""))), "error")
		return
	Haptics.selection()
	_log_game_event("decor_rotated", {"decor": decor_id, "rot": int(result.get("rot", turn))})


## Из меты («🏠 Карта») открыть изометрическую кофейню.
func _on_open_cafe() -> void:
	if _cafe_view == null:
		return
	_cancel_hammer_aim()
	_meta_popup.close()
	Haptics.selection()
	_log_game_event("shop_open", {"where": "cafe"})
	_cafe_view.open()
	_set_main_screen_visible(false)


func _on_cafe_closed() -> void:
	_set_main_screen_visible(true)
	_refresh_hud()
	_refresh_energy()
	_refresh_orders()
	_refresh_meta_badge()


## Убрать мебель в инвентарь (предмет остаётся купленным).
func _on_decor_remove(decor_id: String) -> void:
	var result: Dictionary = Meta.remove_decor(decor_id)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.LIGHT)
		return
	Haptics.selection()
	_meta_popup.refresh()


## Новый кот: сигнал Meta (уровень кофейни / заказы / котовый сундук).
func _on_cat_unlocked(cat: Dictionary) -> void:
	Haptics.selection(HAPTICS.Strength.HEAVY)
	_notify("Новый кот: %s (%s)" % [String(cat.get("name", "")), String(cat.get("role", ""))], "success")
	_log_game_event("cat_unlocked", {"cat": String(cat.get("id", "")), "rarity": String(cat.get("rarity", "common")), "total": Meta.cat_count()})
	_refresh_meta_badge()


## Проверить условия открытия котов: звать после заказа и после повышения уровня.
func _check_cat_unlocks() -> void:
	Meta.check_cat_unlocks(_orders_done)
	# Бейдж «есть кот к открытию» зависит от уровня и числа заказов.
	_refresh_meta_badge()


## Точка-бейдж на кнопке меню: готова ежедневная награда и/или есть кот,
## чьи условия уже выполнены (альбом «Коты» ждёт).
func _refresh_meta_badge() -> void:
	if _hud == null:
		return
	_hud.set_menu_notification(Meta.can_claim() or _has_pending_cat())


## Есть ли кот, которого можно открыть прямо сейчас (уровень + число заказов).
func _has_pending_cat() -> bool:
	for item in META_DATA.CATS:
		var cat: Dictionary = item
		if bool(cat.get("chest", false)):
			continue
		if Meta.is_cat_unlocked(String(cat.get("id", ""))):
			continue
		if Progress.level >= int(cat.get("level", 1)) and _orders_done >= int(cat.get("orders", 0)):
			return true
	return false


## Продать всё поле разом: монеты приходят через _on_item_sold.
## Генераторы и пузыри не продаются: генератор поштучно продать нельзя, и
## без него цепочка встала бы до перезапуска. Тост — один общий, а не по
## тосту и струйке монет на каждый предмет.
func _on_sell_all() -> void:
	var sold := 0
	var coins_before := Wallet.coins()
	_bulk_selling = true
	for cell in _board.cell_count():
		var item := _board.item_at(cell)
		if item == null or item.is_generator() or item.is_bubble():
			continue
		if _board.sell_at(cell):
			sold += 1
	_bulk_selling = false
	var coins := Wallet.coins() - coins_before
	if sold > 0:
		Haptics.selection()
		_notify("Продано предметов: %d · +%d %s" % [sold, coins,
			_plural(coins, "монета", "монеты", "монет")], "success", COIN_ICON)
	else:
		_notify("Продавать нечего", "info")
	Analytics.log_event("sell_all", {"count": sold, "coins": coins})


## Сброс прогресса для плейтеста: чистим save и перезагружаем сцену.
func _on_reset_progress() -> void:
	_resetting = true
	SaveManager.unregister_provider(_save_state)
	SaveManager.reset()
	get_tree().reload_current_scene()


# --- Монетизация (scripts/monetization.gd) -----------------------------------

## Реклама, консент и покупки живут в отдельном узле; сюда приходят только
## тосты и «перерисуй экран энергии». Деньги/энергию он начисляет через
## Wallet/Energy — HUD обновится по их сигналам.
func _connect_monetization() -> void:
	_monetization.toast_requested.connect(_notify)
	_monetization.reward_state_changed.connect(_refresh_energy_popup_state)


## Состояние кнопки «энергия за рекламу» в попапе энергии.
func _refresh_energy_popup_state() -> void:
	if _energy_popup == null or _monetization == null:
		return
	var state: Dictionary = _monetization.energy_reward_state()
	_energy_popup.set_reward_state(bool(state["available"]), String(state["text"]), String(state["hint"]))


# --- FTUE --------------------------------------------------------------------

## Один раз на шаг: пишем в save и в аналитику (docs/analytics.md §6).
func _ftue_step(step: String) -> void:
	var key := "ftue_" + step
	if bool(SaveManager.get_value(key, false)):
		return
	SaveManager.set_value(key, true)
	Analytics.log_event("ftue_step", {"step": step})


func _cfg_num(key: String, fallback: float) -> float:
	var value = Config.get_value(key)
	return float(value) if value != null else fallback


## Сколько предметов всего в цепочках — знаменатель для лога арта.
func _total_item_art() -> int:
	var total := 0
	for chain in Chains.all_chains():
		total += Chains.max_level(chain)
	return total


func _generator_cost() -> int:
	var value = Config.get_value("energy_cost_spawn")
	return int(value) if value != null else 1


# --- Самопроверка ------------------------------------------------------------

## Прогон scripts/dev/selftest.gd. Сам модуль решает, включён ли он (debug +
## dev/selftest/enabled или --selftest), и откатывает всё, что тесты меняли.
func _run_selftest() -> void:
	if not SELFTEST.enabled():
		return
	_selftesting = true
	_fx.enabled = false
	SELFTEST.run(_board, _orders)
	_selftesting = false
	_fx.enabled = true
	# Тесты меняли монеты/гемы и успели показать их в HUD — возвращаем реальные.
	_refresh_hud()
	_refresh_orders()

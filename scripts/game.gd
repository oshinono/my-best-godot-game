extends Node2D

## Прототип ядра (фаза 1): поле 7×8, генераторы, drag-and-drop, слияние,
## энергия, заказы, монеты, сохранение. Арт — плейсхолдеры (scripts/placeholders.gd).
##
## Всё строится в коде: HUD не мешает вводу (mouse_filter = IGNORE),
## поле перехватывает drag в _unhandled_input.

const SELFTEST := true
## Менеджер заказов берём через preload, а не через глобальный class_name:
## global_script_class_cache.cfg обновляется только импортом (редактор), и без
## него строгий тип `OrderManager` ломает компиляцию game.gd.
const ORDER_MANAGER := preload("res://scripts/order_manager.gd")
## Резолвер реального арта (assets/) — тоже через preload, см. комментарий выше.
const ART := preload("res://scripts/data/art.gd")
## Попапы — сцены на контейнерах + Theme (scenes/ui/*.tscn).
const ENERGY_POPUP := preload("res://scenes/ui/energy_popup.tscn")
const SETTINGS_POPUP := preload("res://scenes/ui/settings_popup.tscn")
## Мета-прогрессия (коты, ежедневная награда) — docs/GDD.md §8.
const META_POPUP := preload("res://scenes/ui/meta_popup.tscn")
## Таблицы меты (12 котов, 7 наград, 9 предметов декора) — scripts/data/meta.gd.
const META_DATA := preload("res://scripts/data/meta.gd")
## Силы вибрации (enum Strength) — scripts/autoload/haptics.gd, docs/haptics.md.
## Берём константой, а не через автолоад: `Haptics.Strength` через узел
## разрешается нестабильно, а `HAPTICS.Strength` — обычная константа скрипта.
const HAPTICS := preload("res://scripts/autoload/haptics.gd")
## Безопасные зоны iPhone (вырез/home-индикатор) — см. scripts/ui/safe_area.gd.
const SAFE_AREA := preload("res://scripts/ui/safe_area.gd")
## Изометрический экран кофейни (GDD §8): панорама, зум, перетаскивание мебели.
const CAFE_VIEW := preload("res://scripts/ui/cafe_view.gd")
## Изометрия: тайл → экран (scripts/data/iso.gd).
const ISO := preload("res://scripts/data/iso.gd")
## HUD (значок уровня, плашки ресурсов, нижний ряд кнопок) — сцена.
const GAME_HUD := preload("res://scenes/ui/game_hud.tscn")
## Меню действий по тапу на предмет — сцена (затемнение + карточка).
const ITEM_ACTIONS := preload("res://scenes/ui/item_actions.tscn")
## Отклик: полёты монет/предметов, частицы, тосты (scripts/ui/fx_layer.gd)
## и окно нового уровня (scenes/ui/level_up.tscn).
const FX_LAYER := preload("res://scripts/ui/fx_layer.gd")
const LEVEL_UP := preload("res://scenes/ui/level_up.tscn")
## Склад, цепочка предмета, ремонт кафе, ивент.
const STORAGE_POPUP := preload("res://scenes/ui/storage_popup.tscn")
const CHAIN_POPUP := preload("res://scenes/ui/chain_popup.tscn")
const TASKS_POPUP := preload("res://scenes/ui/tasks_popup.tscn")
const EVENT_POPUP := preload("res://scenes/ui/event_popup.tscn")
const EVENT := preload("res://scripts/event_state.gd")
const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
const GEM_ICON := preload("res://assets/ui/theme/icon_gem.png")
const ENERGY_ICON := preload("res://assets/ui/theme/icon_energy.png")
## Звезда ремонта (арта нет — рисуем текстурой в коде, см. _make_star_icon).
var _star_icon: Texture2D = _make_star_icon()
## Цвет искр слияния по цепочке.
## Яркие тона: на кремовом поле тёмные искры не видны.
const MERGE_COLORS := {
	&"coffee": Color("FFB347"),
	&"pastry": Color("FFD35C"),
	&"flowers": Color("FF7FB8"),
}
## Самопроверка пишет результат в файл: stdout при headless-запуске через MCP
## перехватывается не всегда. Путь внутри .godot/ — он в .gitignore.
const LOG_PATH := "user://selftest_result.txt"
var _board: Board
var _orders: ORDER_MANAGER
## Новый HUD (scripts/ui/game_hud.gd): уровень, энергия/монеты/гемы, магазин
## и нижний ряд кнопок. Само поле, заказы и меню действий живут отдельно.
## Без типа: GameHUD берём через preload, global class cache может быть пуст.
var _hud
## Меню действий по тапу на предмет (scenes/ui/item_actions.tscn).
var _item_actions: CanvasLayer
var _fx: CanvasLayer
## Фон главного экрана (прячется вместе с полем, пока открыта кофейня).
var _bg_layer: CanvasLayer
var _storage_popup: CanvasLayer
var _chain_popup: CanvasLayer
var _tasks_popup: CanvasLayer
var _event_popup: CanvasLayer
## Когда игрок последний раз касался экрана (для подсказки «что слить»).
var _last_input_ms := 0
var _level_up: CanvasLayer
## Клетка, для которой открыто меню действий (-1 — закрыто).
var _action_cell: int = -1
## Попапы: экран энергии (docs/GDD.md §6) и настройки тестового билда (§20).
var _energy_popup: CanvasLayer
var _settings_popup: CanvasLayer
var _meta_popup: CanvasLayer
## Экран кофейни (изометрия) — открывается из вкладки «🏠 Карта» в мете.
var _cafe_view: CanvasLayer
## Выполнено заказов всего (условие открытия котов, GDD §8.2), ключ сейва orders_done.
var _orders_done: int = 0
## Лимит применений бустера за сессию (docs/GDD.md §18): kind → сколько раз уже применили.
var _booster_used: Dictionary = {}
var _selftesting: bool = false


func _ready() -> void:
	_reset_log()
	_log_step("ready: start")
	SaveManager.load_game()
	_log_step("ready: save loaded")
	_ensure_dev_gems()
	_setup_background()
	_setup_board()
	_log_step("ready: board ready")
	_setup_hud()
	_setup_orders()
	_setup_popups()
	var safe := SAFE_AREA.insets()
	_log_step("ready: hud + orders ready")
	_log_step("safe area: L%.0f T%.0f R%.0f B%.0f" % [safe.x, safe.y, safe.z, safe.w])
	_log_step("art: предметов найдено %d/%d" % [ART.count_item_art(), _total_item_art()])
	_run_selftest()
	_restore()
	_log_step("ready: restored")

	Energy.energy_changed.connect(_on_energy_changed)
	Energy.energy_not_enough.connect(_on_energy_not_enough)
	Progress.xp_changed.connect(_on_xp_changed)
	Progress.level_changed.connect(_on_level_changed)
	Ads.rewarded_earned.connect(_on_rewarded_earned)
	Ads.rewarded_failed.connect(_on_rewarded_failed)
	Ads.interstitial_shown.connect(_on_interstitial_shown)
	Ads.interstitial_failed.connect(_on_interstitial_failed)
	Ads.consent_finished.connect(_on_consent_finished)
	Iap.purchase_succeeded.connect(_on_purchase_succeeded)
	Iap.purchase_failed.connect(_on_purchase_failed)
	Iap.purchases_restored.connect(_on_purchases_restored)
	Meta.cat_unlocked.connect(_on_cat_unlocked)
	_refresh_energy()

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	ticker.timeout.connect(_on_tick)
	add_child(ticker)

	_last_input_ms = Time.get_ticks_msec()
	Analytics.log_event("game_opened")
	_ftue_step("opened")
	_log_step("ready: done")


## Раз в секунду: таймеры энергии и бонуса заказов.
func _on_tick() -> void:
	_refresh_energy()
	if _energy_popup != null and _energy_popup.visible:
		_refresh_energy_popup_state()
	_refresh_orders()
	_refresh_meta_badge()
	_board.tick()
	_refresh_meta_buttons()
	if _event_popup != null and _event_popup.visible:
		_show_event()
	_idle_hint()


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
			_storage_popup, _chain_popup, _tasks_popup, _event_popup, _level_up]:
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()


# --- Сборка сцены ------------------------------------------------------------

func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_bg_layer = layer

	var bg := ColorRect.new()
	bg.color = Color("F6E7D8")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)


func _setup_board() -> void:
	_board = Board.new()
	_board.name = "Board"
	add_child(_board)
	_board.items_merged.connect(_on_items_merged)
	_board.generator_tapped.connect(_on_generator_tapped)
	_board.bubble_popped.connect(_on_bubble_popped)
	_board.item_placed.connect(_on_item_placed)
	_board.board_filled.connect(_on_board_filled)
	_board.invalid_drop.connect(_on_invalid_drop)
	_board.item_sold.connect(_on_item_sold)
	_board.booster_target_picked.connect(_on_booster_target)


func _setup_orders() -> void:
	_orders = ORDER_MANAGER.new()
	_orders.name = "Orders"
	add_child(_orders)
	_orders.orders_changed.connect(_refresh_orders)
	# Заказы нужны уже к selftest; _restore() поле не трогает.
	_restore_orders()


func _restore_orders() -> void:
	var slots := Progress.order_slots()
	var saved = SaveManager.get_value("orders", [])
	if typeof(saved) == TYPE_ARRAY and not (saved as Array).is_empty():
		_orders.load_orders(saved)
		_top_up_orders(slots)
	else:
		_orders.setup(slots)


## Догружает заказы до текущего числа слотов (после level up слотов больше).
func _top_up_orders(slots: int) -> void:
	var have := _orders.orders().size()
	if have >= slots:
		return
	var merged: Array = _orders.orders()
	while merged.size() < slots:
		merged.append(_orders.make_order())
	_orders.load_orders(merged)


## Ряд заказов: карточка на слот (scenes/ui/order_card.tscn) — иконки нужных
## предметов, награда, таймер бонуса и кнопка смены за гемы. Обновляется
## раз в секунду (_on_tick) из-за таймера бонуса.
func _refresh_orders() -> void:
	if _hud == null or _orders == null:
		return
	var list: Array = _orders.orders()
	var cards: Array = _hud.ensure_order_cards(list.size(), _on_order_pressed, _on_order_reroll)
	var cost := _reroll_cost()
	for i in mini(cards.size(), list.size()):
		var order: Dictionary = list[i]
		cards[i].show_order(order, int(_orders.reward_for(order).get("coins", 0)),
			_orders.bonus_seconds_left(i))
		cards[i].set_reroll(cost, _gems() >= cost)


func _reroll_cost() -> int:
	return int(_cfg_num("order_reroll_cost_gems", 5.0))


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	# HUD — сцена scenes/ui/game_hud.tscn на контейнерах: шапка, заказы, статус,
	# область поля, генераторы, нижний ряд. Сама держит safe area и не ловит
	# ввод в области поля (mouse_filter = IGNORE), поэтому поле кликабельно.
	_hud = GAME_HUD.instantiate()
	_hud.name = "GameHUD"
	layer.add_child(_hud)
	_hud.level_pressed.connect(_on_hud_level_pressed)
	_hud.energy_plus_pressed.connect(_on_hud_energy_plus_pressed)
	_hud.gems_plus_pressed.connect(_on_hud_gems_plus_pressed)
	_hud.settings_pressed.connect(_on_settings_pressed)
	_hud.menu_pressed.connect(_on_meta_pressed)
	_hud.play_pressed.connect(_on_hud_play_pressed)
	_hud.storage_pressed.connect(_open_storage)
	_hud.tasks_pressed.connect(_open_tasks)
	_hud.event_pressed.connect(_open_event)
	# Поле (Node2D) вписывается в область %BoardArea: контейнеры HUD решают,
	# сколько места ему осталось между заказами и нижним рядом кнопок.
	_hud.board_area_changed.connect(_board.set_area)

	# Эффекты поверх HUD; тосты появляются под рядом заказов (верх области поля).
	_fx = FX_LAYER.new()
	_fx.name = "Fx"
	add_child(_fx)
	_hud.board_area_changed.connect(func(rect: Rect2) -> void:
		_fx.set_toast_top(rect.position.y + 8.0))
	_level_up = LEVEL_UP.instantiate()
	add_child(_level_up)

	# Меню действий по тапу на предмет (docs/GDD.md §18): тапнул предмет —
	# палец ничего не закрывает, промахнуться некуда.
	_item_actions = ITEM_ACTIONS.instantiate()
	add_child(_item_actions)
	_item_actions.sell_pressed.connect(_on_action_sell)
	_item_actions.store_pressed.connect(_on_action_store)
	_item_actions.chain_pressed.connect(_on_action_chain)
	_item_actions.closed.connect(func() -> void: _action_cell = -1)
	if not _board.item_tapped.is_connected(_on_item_tapped):
		_board.item_tapped.connect(_on_item_tapped)


## Попапы: экран энергии и настройки тестового билда.
func _setup_popups() -> void:
	_energy_popup = ENERGY_POPUP.instantiate()
	_energy_popup.name = "EnergyPopup"
	add_child(_energy_popup)
	_energy_popup.rewarded_requested.connect(_on_rewarded_requested)

	_settings_popup = SETTINGS_POPUP.instantiate()
	_settings_popup.name = "SettingsPopup"
	add_child(_settings_popup)
	_settings_popup.sell_all_requested.connect(_on_sell_all)
	_settings_popup.reset_requested.connect(_on_reset_progress)
	_settings_popup.technospike_action.connect(_on_technospike)
	## Бустеры переехали из HUD в настройки (нижняя полоса убрана).
	_settings_popup.booster_requested.connect(_on_booster_pressed)

	_meta_popup = META_POPUP.instantiate()
	_meta_popup.name = "MetaPopup"
	add_child(_meta_popup)
	_meta_popup.daily_claim_requested.connect(_on_daily_claim)

	_cafe_view = CAFE_VIEW.new()
	_cafe_view.name = "CafeView"
	add_child(_cafe_view)
	_cafe_view.decor_place_requested.connect(_on_decor_place)
	_cafe_view.decor_rotate_requested.connect(_on_decor_rotate)
	_cafe_view.decor_clear_requested.connect(_on_slot_clear)
	_cafe_view.closed.connect(_on_cafe_closed)
	_cafe_view.tasks_requested.connect(_open_tasks)

	_storage_popup = STORAGE_POPUP.instantiate()
	add_child(_storage_popup)
	_storage_popup.take_requested.connect(_on_storage_take)
	_storage_popup.buy_slot_requested.connect(_on_storage_buy_slot)

	_chain_popup = CHAIN_POPUP.instantiate()
	add_child(_chain_popup)

	# Ремонт открывается и с главного экрана, и из кофейни (слой поверх неё).
	_tasks_popup = TASKS_POPUP.instantiate()
	add_child(_tasks_popup)
	_tasks_popup.task_requested.connect(_on_task_requested)
	_cafe_view.overlays = [_tasks_popup]

	_event_popup = EVENT_POPUP.instantiate()
	add_child(_event_popup)
	_event_popup.claim_requested.connect(_on_event_claim)
	EVENT.ensure_started()


# --- Состояние ---------------------------------------------------------------

func _restore() -> void:
	var saved = SaveManager.get_value("board", [])
	if typeof(saved) == TYPE_ARRAY and not (saved as Array).is_empty():
		_board.load_from(saved)
	_ensure_generators()
	_orders_done = int(SaveManager.get_value("orders_done", 0))
	_refresh_hud()
	_refresh_meta_badge()


func _save_game() -> void:
	if _selftesting or _board == null:
		return
	SaveManager.set_value("board", _board.serialize())
	SaveManager.set_value("energy", Energy.current())
	SaveManager.set_value("orders", _orders.orders())
	SaveManager.save_game()


# --- HUD ---------------------------------------------------------------------

func _refresh_hud() -> void:
	if _hud != null:
		_hud.set_coins(int(SaveManager.get_value("coins", 0)))
		_hud.set_gems(_gems())
	_refresh_boosters()
	_refresh_progress()
	_refresh_meta_buttons()
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
		"coins": int(SaveManager.get_value("coins", 0)),
		"gems": _gems(),
		"energy": Energy.current(),
		"free_cells": _board.free_cells().size(),
	}


## Игровое событие со снимком состояния. Ключи из params перекрывают снимок:
## например item_sold.level — уровень предмета, а не игрока.
func _log_game_event(event_name: String, params: Dictionary = {}) -> void:
	var merged := _analytics_snapshot()
	merged.merge(params, true)
	Analytics.log_event(event_name, merged)


func _refresh_progress() -> void:
	if _hud != null:
		_hud.set_level(Progress.level)


## Кнопки «Ремонт» (звёзды, точка — есть доступное задание) и «Ивент».
func _refresh_meta_buttons() -> void:
	if _hud == null:
		return
	var ready := false
	for task: Dictionary in _task_list():
		if bool(task.get("ready", false)):
			ready = true
			break
	_hud.set_stars(_stars(), ready)
	_hud.set_event(EVENT.is_active(), EVENT.has_claimable())


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
			"enabled": not used_up and _gems() >= cost,
		}
	_settings_popup.refresh_boosters(info)


func _booster_icon(kind: String) -> String:
	match kind:
		"hammer":
			return "hammer"
		"shuffle":
			return "shuffle"
		"magnet":
			return "magnet"
	return "star"


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
		_fx.set_toasts_bottom(_any_overlay_open() and not _item_actions.visible)
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
		if _gems() < cost:
			Haptics.selection(HAPTICS.Strength.MEDIUM)
			_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
			return
		_board.take_target = true
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Хаммер: тапни предмет, чтобы убрать", "info")
		return

	if not _spend_gems(cost):
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
			var chain := _first_unlocked_chain()
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
		_add_gems(cost)
		return

	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_booster_used[kind] = int(_booster_used.get(kind, 0)) + 1
	Analytics.log_event("booster_used", {"kind": kind, "cost": cost})
	_refresh_boosters()
	_save_game()


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
	if not _spend_gems(cost):
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
	_save_game()


## Снять прицел хаммера при открытии любого модального экрана.
func _cancel_hammer_aim() -> void:
	if _board != null:
		_board.cancel_take_target()


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
	var spot := _board.free_cell_near(cell)
	if spot < 0:
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Поле заполнено — слей пары или убери лишнее на склад", "error")
		return
	if not Energy.spend(_generator_cost()):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_energy_popup.open()
		_refresh_energy_popup_state()
		return
	var target := Chains.generator_target(data.chain)
	var level := 2 if randf() < Chains.gen_param("gen_bonus_chance", data.level, 0.0) else 1
	_board.place_data(Chains.make(target, level), cell)
	var spawned := _board.item_at(spot)
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
	_save_game()


## У каждой открытой цепочки должен быть генератор — на поле или на складе.
## Нет (старый сейв, новая цепочка открылась) — выдаём L1.
func _ensure_generators() -> void:
	var have := {}
	for i in _board.cells.size():
		var item := _board.item_at(i)
		if item != null and item.is_generator():
			have[Chains.generator_target(item.data.chain)] = true
	for entry in _storage():
		var chain := StringName(String((entry as Dictionary).get("chain", "")))
		if Chains.is_generator(chain):
			have[Chains.generator_target(chain)] = true
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain) and not have.has(chain):
			_give_item(Chains.make(Chains.generator_for(chain), 1))


## Выдать предмет: на поле, а если места нет — на склад (даже сверх ячеек:
## подарок не должен пропасть). Возвращает true, если попал на поле.
func _give_item(data: ItemData) -> bool:
	if not _board.free_cells().is_empty():
		_board.place_data(data)
		return true
	var list := _storage()
	list.append(data.to_dict())
	SaveManager.set_value("storage", list)
	return false


func _on_items_merged(_from_cell: int, to_cell: int, chain: StringName, level: int) -> void:
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
		if level >= int(_cfg_num("event_points_merge_level", 4.0)):
			EVENT.add_points(1)
			_refresh_meta_buttons()
	_ftue_step("first_merge")
	_save_game()


## «Пузырь»: после слияния высокого уровня иногда рядом всплывает копия —
## её можно забрать за гемы, пока не лопнула.
func _maybe_spawn_bubble(near: int, chain: StringName, level: int) -> void:
	if level < int(_cfg_num("bubble_min_level", 4.0)) or randf() >= _cfg_num("bubble_chance", 0.12):
		return
	var spot := _board.free_cell_near(near)
	if spot < 0:
		return
	_board.place_data(Chains.make(chain, level), near)
	var bubble := _board.item_at(spot)
	if bubble != null:
		bubble.set_bubble(_cfg_num("bubble_seconds", 60.0))
		bubble.merge_pop()
		_notify("Пузырь! Забери копию, пока не лопнула", "info")


func _bubble_price(level: int) -> int:
	return level * int(_cfg_num("bubble_gems_per_level", 2.0))


func _on_bubble_popped(cell: int, _data: ItemData) -> void:
	_fx.burst(_cell_screen(cell), Color(0.85, 0.95, 1.0), 1.0)
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
			"Лопнет через %d с" % left, price, _gems() >= price, anchor)
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
	if not _spend_gems(price):
		_notify("Не хватает гемов: нужно %d" % price, "error", GEM_ICON)
		return
	var data := node.data
	_board.remove_at_cell(cell)
	_board.place_data(data, cell)
	var fresh := _board.item_at(cell)
	if fresh != null:
		fresh.merge_pop()
	_fx.burst(_cell_screen(cell), Color("BFE3FF"), 1.5)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_log_game_event("bubble_bought", {"chain": String(data.chain), "level": data.level, "gems": price})
	_notify("Забрано: %s" % Chains.item_name(data.chain, data.level), "success")
	_save_game()


# --- Склад -------------------------------------------------------------------

func _storage() -> Array:
	var list = SaveManager.get_value("storage", [])
	return (list as Array).duplicate() if typeof(list) == TYPE_ARRAY else []


func _storage_slots() -> int:
	return int(SaveManager.get_value("storage_slots", int(_cfg_num("storage_slots_start", 2.0))))


## Цена следующего слота: base × номер докупки.
func _storage_next_cost() -> int:
	var bought := _storage_slots() - int(_cfg_num("storage_slots_start", 2.0))
	return int(_cfg_num("storage_slot_cost_gems", 10.0)) * (bought + 1)


func _on_action_store() -> void:
	var cell := _action_cell
	_close_item_actions()
	var node := _board.item_at(cell)
	if node == null:
		return
	var list := _storage()
	if list.size() >= _storage_slots():
		Haptics.selection(HAPTICS.Strength.LIGHT)
		_notify("Склад полон — освободи ячейку или купи новую", "error")
		return
	var data := node.data
	list.append(data.to_dict())
	SaveManager.set_value("storage", list)
	# Предмет «улетает» к кнопке склада.
	_fx.fly(_item_icon(data), _cell_screen(cell), _hud.get_node("%Storage").get_global_rect().get_center(),
		_board.cell_size * 0.6, 0.45)
	_board.remove_at_cell(cell)
	Haptics.selection()
	_log_game_event("storage_put", {"chain": String(data.chain), "level": data.level})
	_notify("На складе: %s" % Chains.item_name(data.chain, data.level), "success")
	_save_game()


func _open_storage() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_show_storage()
	_storage_popup.open()


func _show_storage() -> void:
	var slots := _storage_slots()
	var can_buy := slots < int(_cfg_num("storage_slots_max", 6.0))
	_storage_popup.show_storage(_storage(), slots, can_buy, _storage_next_cost())


func _on_storage_take(index: int) -> void:
	var list := _storage()
	if index < 0 or index >= list.size():
		return
	if _board.free_cells().is_empty():
		_notify("На поле нет места", "error")
		return
	var data := ItemData.from_dict(list[index])
	list.remove_at(index)
	SaveManager.set_value("storage", list)
	var cell := _board.place_data(data)
	var placed := _board.item_at(cell)
	if placed != null:
		placed.merge_pop()
	Haptics.selection()
	_show_storage()
	_save_game()


func _on_storage_buy_slot() -> void:
	var cost := _storage_next_cost()
	if not _spend_gems(cost):
		_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
		return
	SaveManager.set_value("storage_slots", _storage_slots() + 1)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_log_game_event("storage_slot_bought", {"gems": cost, "slots": _storage_slots()})
	_notify("Склад: +1 ячейка", "success")
	_show_storage()
	_save_game()


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


# --- Ремонт кафе (звёзды → декор) -------------------------------------------

func _stars() -> int:
	return int(SaveManager.get_value("stars", 0))


## Звёзды задания: от цены декора в монетах, минимум одна.
func _task_stars(decor: Dictionary) -> int:
	return maxi(1, roundi(float(decor.get("cost", 0)) / _cfg_num("task_star_divisor", 150.0)))


## Ближайшие задания: ещё не обустроенный декор, от дешёвого к дорогому.
func _task_list() -> Array:
	var pending: Array = []
	for item in META_DATA.DECOR:
		var decor: Dictionary = item
		if not Meta.owns_decor(String(decor.get("id", ""))):
			pending.append(decor)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("cost", 0)) < int(b.get("cost", 0)))
	var coins := int(SaveManager.get_value("coins", 0))
	var out: Array = []
	for decor: Dictionary in pending.slice(0, int(_cfg_num("tasks_visible", 3.0))):
		var stars := _task_stars(decor)
		out.append({
			"id": String(decor.get("id", "")),
			"name": String(decor.get("name", "")),
			"room": String(decor.get("room", "")),
			"xp": int(decor.get("xp", 0)),
			"stars": stars,
			"coins": int(decor.get("cost", 0)),
			"ready": _stars() >= stars and coins >= int(decor.get("cost", 0)),
		})
	return out


func _open_tasks() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_show_tasks()
	_tasks_popup.open()


func _show_tasks() -> void:
	_tasks_popup.show_tasks(_stars(), _task_list(), Meta.decor_count(), META_DATA.DECOR.size())


## Выполнить задание: звёзды + монеты → предмет куплен и сразу стоит в своей
## комнате (первое подходящее свободное место).
func _on_task_requested(decor_id: String) -> void:
	var decor: Dictionary = META_DATA.decor(decor_id)
	var stars := _task_stars(decor)
	if _stars() < stars:
		_notify("Не хватает звёзд: нужно %d — выполняй заказы" % stars, "error")
		return
	var result: Dictionary = Meta.buy_decor(decor_id)
	if not bool(result.get("ok", false)):
		_notify(_sentence(String(result.get("reason", ""))), "error", COIN_ICON)
		return
	SaveManager.set_value("stars", _stars() - stars)
	var placed_in := ""
	for slot in META_DATA.SLOTS:
		var slot_id := String(slot["id"])
		if Meta.slot_decor(slot_id) != "" or String(slot.get("room", "")) != String(decor.get("room", "")):
			continue
		if bool(Meta.place_decor(decor_id, slot_id).get("ok", false)):
			placed_in = String(slot.get("room", ""))
			break
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	_log_game_event("task_done", {"decor": decor_id, "stars": stars, "coins": int(decor.get("cost", 0))})
	_log_game_event("decor_purchased", {"decor": decor_id, "cost": int(decor.get("cost", 0)),
		"xp": int(result.get("xp", 0)), "via": "task"})
	if placed_in != "":
		_notify("Готово: %s — %s" % [String(decor.get("name", "")), placed_in], "success")
	else:
		_notify("Готово: %s — поставь его в кафе" % String(decor.get("name", "")), "success")
	_refresh_hud()
	_show_tasks()
	_meta_popup.refresh()
	_save_game()


# --- Ивент ---------------------------------------------------------------------

func _open_event() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_show_event()
	_event_popup.open()


func _show_event() -> void:
	_event_popup.show_event(EVENT.title(), EVENT.time_left_text(), EVENT.points(), EVENT.goal(),
		EVENT.rows(), "Очки: +%d за заказ, +1 за слияние до ур. %d и выше." % [
			int(_cfg_num("event_points_order", 3.0)), int(_cfg_num("event_points_merge_level", 4.0))])


func _on_event_claim(index: int) -> void:
	var reward: Dictionary = EVENT.claim(index)
	if reward.is_empty():
		return
	if reward.has("coins"):
		_add_coins(int(reward["coins"]))
	if reward.has("gems"):
		_add_gems(int(reward["gems"]))
	if reward.has("energy"):
		Energy.add(int(reward["energy"]))
		_refresh_energy()
	Haptics.selection(HAPTICS.Strength.HEAVY)
	_log_game_event("event_claim", {"event": EVENT.event_id(), "index": index})
	_notify("Награда фестиваля: " + EVENT.reward_text(reward), "success")
	_show_event()
	_refresh_meta_buttons()
	_save_game()


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
		_fx.fly_many(COIN_ICON, card, _hud.coin_target(), coin_count, _hud.punch_coins)
		if gems > 0:
			_fx.fly_many(GEM_ICON, card, _hud.gem_target(), gems, _hud.punch_gems, 48.0))
	# Звёзды ремонта: по одной за каждый предмет заказа, летят к «Ремонту».
	var stars: int = int(_cfg_num("stars_per_order_item", 1.0)) * (result.get("items", []) as Array).size()
	if stars > 0:
		SaveManager.set_value("stars", _stars() + stars)
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			_fx.fly_many(_star_icon, card, _hud.tasks_target(), stars, _hud.punch_tasks, 40.0))
	EVENT.add_points(int(_cfg_num("event_points_order", 3.0)))
	_add_coins(coins)
	if gems > 0:
		_add_gems(gems)
	Progress.add_xp(xp)
	_log_game_event("order_completed", {"coins": coins, "xp": xp, "gems": gems, "bonus": bonus,
		"stars": stars})
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
	if stars > 0:
		details.append("+%d ★" % stars)
	var text := "Заказ готов! +%d %s · +%d XP" % [coins, _plural(coins, "монета", "монеты", "монет"), xp]
	if not details.is_empty():
		text += "\n" + ", ".join(details)
	_fx.toast(text, COIN_ICON)
	_ftue_step("first_order")
	_orders_done += 1
	SaveManager.set_value("orders_done", _orders_done)
	_check_cat_unlocks()
	_save_game()


## Реролл заказа за гемы (цена — Config.order_reroll_cost_gems, см. docs/economy.md).
func _on_order_reroll(index: int) -> void:
	if _orders == null or _orders.order_at(index).is_empty():
		return
	var cost := _reroll_cost()
	if not _spend_gems(cost):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не хватает гемов: нужно %d" % cost, "error", GEM_ICON)
		return
	if not _orders.replace(index):
		# Замена не удалась — не берём гемы за пустоту.
		_add_gems(cost)
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify("Не удалось обновить заказ", "error")
		return
	Analytics.log_event("order_rerolled", {"index": index, "cost": cost})
	_notify("Заказ обновлён", "success")
	_save_game()


func _on_xp_changed(_xp: int, _next: int) -> void:
	_refresh_progress()


func _on_level_changed(level: int, previous: int) -> void:
	_refresh_progress()
	_restore_orders()
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
	_save_game()


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
	var on_board := _give_item(Chains.make(Chains.generator_for(chain), 1))
	_notify("Подарок за уровень: %s%s" % [Chains.title(Chains.generator_for(chain)),
		"" if on_board else " (на складе)"], "success")


func _on_item_sold(cell: int, data: ItemData) -> void:
	if data == null:
		return
	var coins := _sell_price(data)
	# Монеты вылетают из клетки проданного предмета к счётчику.
	var count := clampi(int(coins / 10.0), 2, 6)
	_hud.hold_coins(_fx.fly_many(COIN_ICON, _cell_screen(cell), _hud.coin_target(), count,
		_hud.punch_coins))
	_add_coins(coins)
	Haptics.selection()
	_log_game_event("item_sold", {"chain": String(data.chain), "level": data.level, "coins": coins})
	_fx.toast("Продано: +%d %s" % [coins, _plural(coins, "монета", "монеты", "монет")], COIN_ICON)
	_save_game()


## Кофейня закрывает экран целиком: поле и HUD под ней не рисуем
## (экономит ~45 draw call'ов и обход их узлов каждый кадр).
func _set_main_screen_visible(value: bool) -> void:
	_board.visible = value
	(_hud.get_parent() as CanvasLayer).visible = value
	_bg_layer.visible = value


## Экранная точка центра клетки поля (для полётов и частиц).
func _cell_screen(cell: int) -> Vector2:
	return _board.to_global(_board.cell_center(cell))


## «нужен предмет: X» → «Нужен предмет: X» (причины приходят со строчной).
static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1) if not text.is_empty() else text


## Пятиконечная звезда для полёта звёзд ремонта (арта звезды в проекте нет).
static func _make_star_icon() -> Texture2D:
	var side := 64
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side, side) * 0.5
	var points := PackedVector2Array()
	for i in 10:
		var r := side * (0.48 if i % 2 == 0 else 0.2)
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(a), sin(a)) * r)
	for y in side:
		for x in side:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				img.set_pixel(x, y, Color("F2B01E"))
	return ImageTexture.create_from_image(img)


## Форма слова по числу: 1 монета, 3 монеты, 5 монет.
static func _plural(n: int, one: String, few: String, many: String) -> String:
	var n10 := absi(n) % 10
	var n100 := absi(n) % 100
	if n10 == 1 and n100 != 11:
		return one
	if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14):
		return few
	return many


func _add_coins(amount: int) -> void:
	SaveManager.set_value("coins", int(SaveManager.get_value("coins", 0)) + amount)
	_refresh_hud()


func _gems() -> int:
	return int(SaveManager.get_value("gems", 0))


func _add_gems(amount: int) -> void:
	SaveManager.set_value("gems", _gems() + amount)
	_refresh_hud()


func _spend_gems(cost: int) -> bool:
	if cost <= 0:
		return true
	if _gems() < cost:
		return false
	SaveManager.set_value("gems", _gems() - cost)
	_refresh_hud()
	return true


## dev-грант: стартовые гемы выдаём только если ключа ещё нет в сохранении.
func _ensure_dev_gems() -> void:
	if SaveManager.get_value("gems") != null:
		return
	var start := int(_cfg_num("start_gems", 0.0))
	if start > 0:
		SaveManager.set_value("gems", start)


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

## Значок уровня — только отображение.
func _on_hud_level_pressed() -> void:
	pass


## ⚡+ : экран энергии (реклама за +15).
func _on_hud_energy_plus_pressed() -> void:
	_cancel_hammer_aim()
	Haptics.selection()
	_energy_popup.open()
	_refresh_energy_popup_state()


## 💎+ : покупка гемов (техспайк-заглушка).
func _on_hud_gems_plus_pressed() -> void:
	_cancel_hammer_aim()
	_on_technospike("purchase")


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
		_add_coins(coins)
	if gems > 0:
		_add_gems(gems)
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
	_save_game()


## Покупка декора: монеты и XP выдаёт Meta.buy_decor (docs/GDD.md §8.1).
## Поставить мебель в слот кофейни (docs/GDD.md §8.1): drag из инвентаря.
func _on_decor_place(decor_id: String, slot_id: String, rot: int = 0) -> void:
	var result: Dictionary = Meta.place_decor(decor_id, slot_id, rot)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify(_sentence(String(result.get("reason", ""))), "error")
		return
	var decor: Dictionary = META_DATA.decor(decor_id)
	var slot: Dictionary = META_DATA.slot(slot_id)
	Haptics.selection()
	_notify("%s → %s" % [META_DATA.decor_short(decor), String(slot.get("room", ""))], "info")
	_log_game_event("decor_placed", {
		"decor": decor_id,
		"slot": slot_id,
		"room": String(slot.get("room", "")),
		"rot": int(result.get("rot", rot)),
	})
	_meta_popup.refresh()
	_save_game()


## Повернуть мебель на слоте (GDD §8.1): поворот 0..3 = N/E/S/W.
func _on_decor_rotate(slot_id: String) -> void:
	if slot_id.is_empty():
		return
	var turn := (Meta.slot_rot(slot_id) + 1) % 4
	var result: Dictionary = Meta.set_rotation(slot_id, turn)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.MEDIUM)
		_notify(_sentence(String(result.get("reason", ""))), "error")
		return
	Haptics.selection()
	_log_game_event("decor_rotated", {"slot": slot_id, "rot": int(result.get("rot", turn))})
	_save_game()


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
	_refresh_meta_badge()


## Снять мебель со слота (предмет остаётся купленным).
func _on_slot_clear(slot_id: String) -> void:
	var result: Dictionary = Meta.clear_slot(slot_id)
	if not bool(result.get("ok", false)):
		Haptics.selection(HAPTICS.Strength.LIGHT)
		return
	Haptics.selection()
	_meta_popup.refresh()
	_save_game()


## Новый кот: сигнал Meta (уровень кофейни / заказы / котовый сундук).
func _on_cat_unlocked(cat: Dictionary) -> void:
	Haptics.selection(HAPTICS.Strength.HEAVY)
	_notify("Новый кот: %s (%s)" % [String(cat.get("name", "")), String(cat.get("role", ""))], "success")
	_log_game_event("cat_unlocked", {"cat": String(cat.get("id", "")), "rarity": String(cat.get("rarity", "common")), "total": Meta.cat_count()})
	_refresh_meta_badge()


## Проверить условия открытия котов: звать после заказа и после повышения уровня.
func _check_cat_unlocks() -> void:
	Meta.check_cat_unlocks(_orders_done)


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
func _on_sell_all() -> void:
	var sold := 0
	for cell in _board.cell_count():
		if _board.has_item(cell) and _board.sell_at(cell):
			sold += 1
	_notify("Продано предметов: %d" % sold, "success")
	if sold > 0:
		Haptics.selection()
	Analytics.log_event("sell_all", {"count": sold})
	_save_game()


## Сброс прогресса для плейтеста: чистим save и перезагружаем сцену.
func _on_reset_progress() -> void:
	SaveManager.reset()
	get_tree().reload_current_scene()


# --- Rewarded-энергия (docs/GDD.md §6, §9) -----------------------------------

func _on_rewarded_requested() -> void:
	var amount := int(_cfg_num("rewarded_energy_amount", 15.0))
	var cap := int(_cfg_num("rewarded_energy_daily_cap", 5.0))
	if cap > 0 and _rewarded_energy_today() >= cap:
		_notify("Лимит rewarded за сегодня исчерпан (%d)" % cap, "error")
		_refresh_energy_popup_state()
		return
	Haptics.selection()
	Haptics.mute_for_ads(true)
	Analytics.log_event("rewarded_started", {"placement": "energy"})
	Ads.show_rewarded("energy", {"energy": amount})


func _on_rewarded_earned(placement: String, reward: Dictionary) -> void:
	Haptics.mute_for_ads(false)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	# Техспайк: rewarded из настроек не выдаёт энергию — только подтверждает,
	# что колбэк награды дошёл с устройства.
	if placement != "energy":
		Analytics.log_event("rewarded_completed", {"placement": placement, "reward": reward})
		_notify("Реклама: награда получена (%s)" % placement, "success")
		return
	var amount := int(reward.get("energy", int(_cfg_num("rewarded_energy_amount", 15.0))))
	Energy.add(amount)
	_count_rewarded_energy()
	Analytics.log_event("rewarded_completed", {"placement": placement, "amount": amount})
	_notify("Энергия: +%d" % amount, "success", ENERGY_ICON)
	_refresh_energy()
	_refresh_energy_popup_state()
	_save_game()


func _on_rewarded_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	Analytics.log_event("rewarded_failed", {"placement": placement, "reason": reason})
	_notify("Реклама недоступна: %s" % reason, "error")
	_refresh_energy_popup_state()


# --- Техспайк: реклама, консент, покупки (docs/technspike.md) ----------------

## Кнопки в настройках прототипа: проверяем рекламу/консент/IAP на устройстве.
## action: "rewarded" | "interstitial" | "consent" | "purchase" | "restore".
func _on_technospike(action: String) -> void:
	Analytics.log_event("technospike_action", {"action": action})
	match action:
		"rewarded":
			_notify("Техспайк: запрашиваем rewarded…", "info")
			Haptics.mute_for_ads(true)
			Ads.show_rewarded("technospike", {})
		"interstitial":
			_notify("Техспайк: запрашиваем interstitial…", "info")
			Haptics.mute_for_ads(true)
			Ads.show_interstitial("technospike")
		"consent":
			_notify("Техспайк: запрашиваем консент…", "info")
			Ads.request_consent()
		"purchase":
			var sku := String(Config.get_value("iap_test_sku"))
			if sku.is_empty():
				sku = "gems_small"
			_notify("Техспайк: покупка %s…" % sku, "info")
			Iap.purchase(sku)
		"restore":
			_notify("Техспайк: восстановление покупок…", "info")
			Iap.restore()
		_:
			_notify("Неизвестное действие техспайка: %s" % action, "error")


func _on_interstitial_shown(placement: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_shown", {"placement": placement})
	_notify("Interstitial показан (%s)" % placement, "success")


func _on_interstitial_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_failed", {"placement": placement, "reason": reason})
	_notify("Interstitial недоступен: %s" % reason, "error")


func _on_consent_finished(ok: bool, reason: String) -> void:
	Analytics.log_event("consent_finished", {"ok": ok, "reason": reason})
	if ok:
		Analytics.set_consent(true)
		_notify("Консент получен (%s)" % reason, "success")
	else:
		# Без согласия аналитика не должна отправлять события.
		Analytics.set_consent(false)
		_notify("Консент не получен: %s" % reason, "error")


func _on_purchase_succeeded(sku: String, receipt: Dictionary) -> void:
	var list := _iap_owned()
	var first_purchase := not list.has(sku)
	if first_purchase:
		list.append(sku)
	SaveManager.set_value("iap_owned", list)
	var suffix := _grant_iap(sku, first_purchase)
	Haptics.selection(HAPTICS.Strength.HEAVY)
	Analytics.log_event("purchase_succeeded", {"sku": sku, "keys": receipt.keys()})
	_notify("Покупка ок: %s%s" % [sku, suffix], "success")
	_save_game()


func _on_purchase_failed(sku: String, reason: String) -> void:
	Haptics.selection(HAPTICS.Strength.MEDIUM)
	Analytics.log_event("purchase_failed", {"sku": sku, "reason": reason})
	_notify("Покупка не прошла (%s): %s" % [sku, reason], "error")


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
	_notify(text, "success")
	_save_game()


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
		_add_gems(gems)
		parts.append("+%d гемов" % gems)
	var coins := int(grant.get("coins", 0))
	if coins > 0:
		_add_coins(coins)
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


## Состояние кнопки в попапе энергии: доступна ли реклама и текст.
func _refresh_energy_popup_state() -> void:
	if _energy_popup == null:
		return
	var amount := int(_cfg_num("rewarded_energy_amount", 15.0))
	var cap := int(_cfg_num("rewarded_energy_daily_cap", 5.0))
	var left := maxi(0, cap - _rewarded_energy_today())
	var available := cap <= 0 or left > 0
	var text := "+%d энергии за рекламу" % amount
	var hint := "Осталось сегодня: %d" % left
	if not available:
		hint = "Лимит на сегодня исчерпан — приходи завтра"
	_energy_popup.set_reward_state(available, text, hint)


func _rewarded_energy_today() -> int:
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	if int(SaveManager.get_value("rewarded_energy_day", -1)) != day:
		return 0
	return int(SaveManager.get_value("rewarded_energy_count", 0))


func _count_rewarded_energy() -> void:
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	var count := _rewarded_energy_today() + 1
	SaveManager.set_value("rewarded_energy_day", day)
	SaveManager.set_value("rewarded_energy_count", count)


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


func _reset_log() -> void:
	var handle := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if handle != null:
		handle.store_line("run at %s" % Time.get_datetime_string_from_system())
		handle.close()


func _log_step(text: String) -> void:
	print(text)
	var handle := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if handle == null:
		return
	handle.seek_end()
	handle.store_line(text)
	handle.flush()
	handle.close()


# --- Самопроверка ------------------------------------------------------------

## Прогоняется при старте: спавн → слияние → сериализация → загрузка.
## Печатает "[selftest] board: OK" — по этому логу видно, что ядро живо.
func _run_selftest() -> void:
	if not SELFTEST or not OS.is_debug_build():
		return
	_selftesting = true
	_fx.enabled = false
	var ok := true
	# Тесты не должны загрязнять сейв: снимаем экономику и поле, потом вернём.
	var coins_before := int(SaveManager.get_value("coins", 0))
	var gems_before := int(SaveManager.get_value("gems", 0))
	var board_before: Array = _board.serialize()
	var orders_before: Array = _orders.orders().duplicate(true) if _orders != null else []

	_board.clear()
	ok = _board.spawn(Chains.COFFEE, 1) and ok
	ok = _board.spawn(Chains.COFFEE, 1) and ok

	var first := -1
	var second := -1
	for i in _board.cells.size():
		if _board.has_item(i):
			if first < 0:
				first = i
			else:
				second = i

	ok = first >= 0 and second >= 0 and ok
	ok = _board.can_merge(first, second) and ok
	ok = _board.merge(first, second) and ok
	ok = _board.item_at(first) == null and ok
	ok = _board.item_at(second) != null and _board.item_at(second).data.level == 2 and ok
	ok = not _board.can_merge(second, second) and ok
	ok = not _board.merge(second, second) and ok

	var snapshot := _board.serialize()
	_board.clear()
	ok = _board.cells.size() == _board.columns * _board.rows and ok
	_board.load_from(snapshot)
	ok = _board.item_at(second) != null and _board.item_at(second).data.level == 2 and ok
	_board.clear()

	if ok:
		_log_step("[selftest] orders: %s" % ("OK" if _test_orders() > 0 else "FAILED"))
		_log_step("[selftest] progress: %s" % ("OK" if _test_progress() else "FAILED"))
		_log_step("[selftest] boosters: %s" % ("OK" if _test_boosters() else "FAILED"))
		_log_step("[selftest] rewards: %s" % ("OK" if _test_rewards() else "FAILED"))
		_log_step("[selftest] meta: %s" % ("OK" if _test_meta() else "FAILED"))
		_log_step("[selftest] icons: %s" % ("OK" if _test_icons() else "FAILED"))
		_log_step("[selftest] iso: %s" % ("OK" if _test_iso() else "FAILED"))
		_log_step("[selftest] board: OK")
	else:
		_log_step("[selftest] board FAILED")
		push_error("[selftest] board FAILED")

	_board.clear()
	_board.load_from(board_before)
	if _orders != null:
		_orders.load_orders(orders_before)
	SaveManager.set_value("coins", coins_before)
	SaveManager.set_value("gems", gems_before)
	_selftesting = false
	_fx.enabled = true
	# Тесты меняли монеты/гемы и успели показать их в HUD — возвращаем реальные.
	_refresh_hud()
	_refresh_orders()


## Проверка таблиц меты (docs/GDD.md §8): 12 котов, 7 дней стрика, декор, бонус котов.
func _test_meta() -> bool:
	if META_DATA.CATS.size() != 12:
		push_error("[selftest] meta: котов %d, ожидалось 12" % META_DATA.CATS.size())
		return false
	if META_DATA.DAILY_REWARDS.size() != 7 or not META_DATA.DAILY_REWARDS[6].has("chest"):
		push_error("[selftest] meta: таблица ежедневных наград не совпадает с 7-дневным стриком")
		return false
	if META_DATA.chest_cats().is_empty() or META_DATA.DECOR.size() < 5:
		push_error("[selftest] meta: пустой список котов из сундука или мало декора")
		return false
	if Meta.cat_bonus() < 1.0 or Meta.cat_bonus_percent() < 0:
		push_error("[selftest] meta: бонус котов меньше 1.0")
		return false
	if Meta.can_claim() and Meta.next_day() < 1:
		push_error("[selftest] meta: неверный номер следующего дня")
		return false
	if META_DATA.SLOTS.size() < META_DATA.DECOR.size():
		push_error("[selftest] meta: слотов расстановки меньше предметов")
		return false
	for room in META_DATA.ROOMS:
		var room_name := String(room.get("name", ""))
		if META_DATA.room_slots(room_name).is_empty():
			push_error("[selftest] meta: у комнаты %s нет слотов расстановки" % room_name)
			return false
	for item in META_DATA.DECOR:
		var room_of := String(item.get("room", ""))
		if META_DATA.room_slots(room_of).is_empty():
			push_error("[selftest] meta: для комнаты %s нет слотов" % room_of)
			return false
	if not META_DATA.slot("нет-такого-слота").is_empty() or Meta.slot_decor("нет-такого-слота") != "":
		push_error("[selftest] meta: неизвестный слот не пуст")
		return false
	if Meta.unplaced_decor().size() > Meta.decor_count():
		push_error("[selftest] meta: непоставленных предметов больше, чем куплено")
		return false
	for item in META_DATA.DECOR:
		var item_room := String(item.get("room", ""))
		var fits_anywhere := false
		for candidate in META_DATA.room_slots(item_room):
			if META_DATA.fits(item, candidate, 0):
				fits_anywhere = true
				break
		if not fits_anywhere:
			push_error("[selftest] meta: предмет %s никуда не помещается" % String(item.get("id", "")))
			return false
		if int(item.get("w", 1)) != int(item.get("h", 1)):
			var swapped: Vector2i = META_DATA.rotated_size(item, 1)
			if swapped != Vector2i(int(item.get("h", 1)), int(item.get("w", 1))):
				push_error("[selftest] meta: поворот не меняет габарит у %s" % String(item.get("id", "")))
				return false
		if bool(item.get("wall", false)):
			for candidate in META_DATA.room_slots(item_room):
				if META_DATA.fits(item, candidate, 0) and not bool(candidate.get("wall", false)):
					push_error("[selftest] meta: настенный предмет %s подходит к полу" % String(item.get("id", "")))
					return false
	return true


## Проверка изометрии (scripts/data/iso.gd): тайл ↔ экран без потерь, ромб.
func _test_iso() -> bool:
	var point: Vector2 = ISO.tile_to_screen(3.0, 5.0)
	var back: Vector2 = ISO.screen_to_tile(point)
	if back.distance_to(Vector2(3.0, 5.0)) > 0.001:
		push_error("[selftest] iso: tile_to_screen ↔ screen_to_tile не сходятся: %s" % str(back))
		return false

	var center_1: Vector2 = ISO.tile_center(2.0, 4.0, 1.0, 1.0)
	if center_1.distance_to(ISO.tile_to_screen(2.5, 4.5)) > 0.001:
		push_error("[selftest] iso: tile_center 1×1 не совпадает с центром тайла")
		return false

	var center_2: Vector2 = ISO.tile_center(2.0, 4.0, 2.0, 1.0)
	var expected_2: Vector2 = ISO.tile_to_screen(3.0, 4.5)
	if not is_equal_approx(center_2.x, expected_2.x) or not is_equal_approx(center_2.y, expected_2.y):
		push_error("[selftest] iso: tile_center 2×1 посчитан неверно: %s" % str(center_2))
		return false

	var diamond: PackedVector2Array = ISO.diamond(0.0, 0.0, 1.0, 1.0)
	if diamond.size() != 4:
		push_error("[selftest] iso: diamond вернул %d точек вместо 4" % diamond.size())
		return false
	var sum := Vector2.ZERO
	for corner in diamond:
		sum += corner
	if sum.distance_to(Vector2.ZERO) > 0.001:
		push_error("[selftest] iso: diamond не центрирован: %s" % str(sum))
		return false

	var sofa: Dictionary = META_DATA.decor("sofa")
	var narrow: Dictionary = META_DATA.slot("hall_2")
	if not META_DATA.fits(sofa, narrow, 0):
		push_error("[selftest] iso: диван не влезает в слот 2×1")
		return false
	if META_DATA.fits(sofa, narrow, 1):
		push_error("[selftest] iso: повёрнутый диван влез в слот 2×1 (не должен)")
		return false
	return true


## Проверка арта иконок: каждый используемый PNG на месте и разбирается в текстуру.
func _test_icons() -> bool:
	for art_name in Icons.USED_ART:
		if Icons.art_path(String(art_name)) == "":
			push_error("[selftest] icons: нет арта «%s»" % art_name)
			return false
		var texture := Icons.art(String(art_name))
		if texture == null or texture.get_width() <= 0:
			push_error("[selftest] icons: не загрузился арт «%s»" % art_name)
			return false
	return true


## Проверка прогресса: порог XP растёт с уровнем, на пороге уровень берётся.
func _test_progress() -> bool:
	var previous := 0
	for lvl in range(1, 11):
		var need := Progress.xp_next(lvl)
		if need <= previous:
			push_error("[selftest] progress: порог XP не растёт на уровне %d" % lvl)
			return false
		previous = need

	var level_before := Progress.level
	var xp_before := Progress.xp
	Progress.level = 1
	Progress.xp = 0
	var taken := Progress.add_xp(Progress.xp_next())
	var leveled := taken >= 1 and Progress.level == 2
	Progress.level = level_before
	Progress.xp = xp_before
	Progress._persist()
	if not leveled:
		push_error("[selftest] progress: уровень не поднялся на пороге")
		return false
	return true


## Проверка заказов и продажи: ставит предметы под требования и «сдаёт» их.
func _test_orders() -> int:
	_board.clear()
	var index := 0
	var order: Dictionary = _orders.order_at(index)
	if order.is_empty():
		push_error("[selftest] orders: пустой заказ")
		return 0

	var entries: Array = []
	var cell := 0
	for req in order.get("items", []):
		entries.append({
			"cell": cell,
			"chain": String(req.get("chain", "")),
			"level": int(req.get("level", 1)),
		})
		cell += 1
	_board.load_from(entries)

	var before := int(SaveManager.get_value("coins", 0))
	var result: Dictionary = _orders.try_deliver(index, _board)
	if not bool(result.get("ok", false)):
		push_error("[selftest] orders: отказ — " + String(result.get("reason", "")))
		return 0
	_add_coins(int(result.get("coins", 0)))
	var gained := int(SaveManager.get_value("coins", 0)) - before
	if gained <= 0:
		push_error("[selftest] orders: монеты не начислены")
		return 0

	# продажа идёт тем же путём, что drag мимо поля (board.sell_at → item_sold)
	_board.clear()
	_board.load_from([{"cell": 0, "chain": String(Chains.COFFEE), "level": 1}])
	var before_sell := int(SaveManager.get_value("coins", 0))
	if not _board.sell_at(0) or int(SaveManager.get_value("coins", 0)) <= before_sell:
		push_error("[selftest] sell: монеты не начислены")
		return 0
	return gained


## Проверка бустеров: шафл не теряет предметы, хаммер убирает один,
## магнит ставит 3, гемы списываются и возвращаются.
func _test_boosters() -> bool:
	_board.clear()
	_board.load_from([
		{"cell": 0, "chain": String(Chains.COFFEE), "level": 1},
		{"cell": 1, "chain": String(Chains.COFFEE), "level": 2},
		{"cell": 2, "chain": String(Chains.PASTRY), "level": 1},
	])
	var before := _board.serialize().size()
	if not _board.shuffle() or _board.serialize().size() != before:
		push_error("[selftest] boosters: шафл сломал поле")
		return false

	_board.remove_at_cell(1)
	if _board.serialize().size() != before - 1:
		push_error("[selftest] boosters: хаммер не убрал предмет")
		return false

	var gems_before := _gems()
	_add_gems(50)
	var spent := _spend_gems(5) and _gems() == gems_before + 45
	SaveManager.set_value("gems", gems_before)
	if not spent:
		push_error("[selftest] boosters: гемы не списались")
		return false

	var chain := _first_unlocked_chain()
	var placed := 0
	for i in 3:
		if _board.spawn(chain, 1):
			placed += 1
	if placed != 3:
		push_error("[selftest] boosters: магнит поставил %d из 3" % placed)
		return false

	_board.clear()
	return true


## Проверка наград заказа: свежий заказ даёт бонус за скорость,
## монеты/XP считаются из базы, реролл заменяет заказ.
func _test_rewards() -> bool:
	var order: Dictionary = _orders.make_order()
	var reward := _orders.reward_for(order)
	if float(reward.get("bonus", 1.0)) <= 1.0:
		push_error("[selftest] rewards: свежий заказ без бонуса за скорость")
		return false
	if int(reward.get("seconds_left", 0)) <= 0:
		push_error("[selftest] rewards: не посчитан таймер бонуса")
		return false
	var base := _orders.compute_coins(order)
	if int(reward.get("coins", 0)) != int(round(float(base) * float(reward.get("bonus", 1.0)))):
		push_error("[selftest] rewards: монеты не совпали с бонусом")
		return false
	if int(reward.get("xp", 0)) <= 0:
		push_error("[selftest] rewards: XP не начислен")
		return false

	if not _orders.replace(0):
		push_error("[selftest] rewards: реролл не сработал")
		return false
	var after: Dictionary = _orders.order_at(0)
	if after.is_empty():
		push_error("[selftest] rewards: реролл оставил пустой слот")
		return false
	return true

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
## Попапы (энергия, настройки) — тоже preload, чтобы не зависеть от class cache.
const ENERGY_POPUP := preload("res://scripts/ui/energy_popup.gd")
const SETTINGS_POPUP := preload("res://scripts/ui/settings_popup.gd")
## Стенд проверки вибрации (docs/haptics.md) — открывается из настроек.
const HAPTICS_TEST_POPUP := preload("res://scripts/ui/haptics_test_popup.gd")
## Мета-прогрессия (коты, ежедневная награда, декор) — docs/GDD.md §8.
const META_POPUP := preload("res://scripts/ui/meta_popup.gd")
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
## Новый HUD (значок уровня, плашки ресурсов, магазин, нижний ряд кнопок).
## Тоже через preload: строгий тип GameHUD зависит от global class cache.
const GAME_HUD := preload("res://scripts/ui/game_hud.gd")
## Попап «Генераторы» — открывается кнопкой ▶ нового HUD.
const GENERATORS_POPUP := preload("res://scripts/ui/generators_popup.gd")
## Самопроверка пишет результат в файл: stdout при headless-запуске через MCP
## перехватывается не всегда. Путь внутри .godot/ — он в .gitignore.
const LOG_PATH := "user://selftest_result.txt"
var _board: Board
var _orders: ORDER_MANAGER
## Новый HUD (scripts/ui/game_hud.gd): уровень, энергия/монеты/гемы, магазин
## и нижний ряд кнопок. Само поле, заказы и меню действий живут отдельно.
## Без типа: GameHUD берём через preload, global class cache может быть пуст.
var _hud
var _status_label: Label
var _order_bar: HBoxContainer
## Меню действий по тапу на предмет (docs/GDD.md §18): затемнение + карточка
## с названием, ценой и кнопками «Продать» / «Отмена».
var _action_scrim: ColorRect
var _action_card: PanelContainer
var _action_title: Label
var _action_hint: Label
var _action_sell: Button
## Клетка, для которой открыто меню действий (-1 — меню закрыто).
var _action_cell: int = -1
## Корень HUD: обычный Control, держит безопасные зоны iPhone (offset_* = safe area).
var _hud_root: Control
## Попапы: экран энергии (docs/GDD.md §6) и настройки тестового билда (§20).
var _energy_popup: CanvasLayer
var _settings_popup: CanvasLayer
## Стенд проверки всех видов вибрации: открывается из настроек (docs/haptics.md).
var _haptics_test_popup: CanvasLayer
var _meta_popup: CanvasLayer
## Попап «Генераторы» — открывается кнопкой ▶ в HUD. Без типа: preload.
var _generators_popup
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
	_apply_safe_area()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
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

	Analytics.log_event("game_opened")
	_ftue_step("opened")
	_log_step("ready: done")


## Поворот экрана / смена размера окна: безопасные зоны могли измениться.
func _on_viewport_resized() -> void:
	_apply_safe_area()


## Раз в секунду: таймеры энергии и бонуса заказов.
func _on_tick() -> void:
	_refresh_energy()
	if _energy_popup != null and _energy_popup.visible:
		_refresh_energy_popup_state()
	_refresh_orders()
	_refresh_meta_badge()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()


# --- Сборка сцены ------------------------------------------------------------

func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

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
	_board.board_filled.connect(_on_board_filled)
	_board.invalid_drop.connect(_on_invalid_drop)
	_board.item_sold.connect(_on_item_sold)
	_board.booster_target_picked.connect(_on_booster_target)


func _setup_orders() -> void:
	_orders = ORDER_MANAGER.new()
	_orders.name = "Orders"
	add_child(_orders)
	_orders.orders_changed.connect(_refresh_orders)
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


## Панель заказов: на каждый слот — кнопка «сдать» и кнопка реролла (5💎).
## Пересобирается раз в секунду (_on_tick), потому что показывает таймер бонуса.
func _refresh_orders() -> void:
	if _order_bar == null or _orders == null:
		return
	var list: Array = _orders.orders()
	if _order_bar.get_child_count() != list.size():
		_rebuild_order_cards(maxi(1, list.size()))
	for i in list.size():
		if i >= _order_bar.get_child_count():
			return
		var card: Node = _order_bar.get_child(i)
		var button := card.get_child(0) as Button
		var reroll := card.get_child(1) as Button
		if button != null:
			button.text = _order_text(list[i], i)
		if reroll != null:
			reroll.disabled = _gems() < _reroll_cost()


## Собрать карточки заказов под текущее число слотов (2–4).
## Карточки пересобираются только при смене числа слотов: иначе тап терялся бы
## (нажатие и отпускание попадали бы на разные Button).
func _rebuild_order_cards(slots: int) -> void:
	for child in _order_bar.get_children():
		_order_bar.remove_child(child)
		child.queue_free()
	var reroll_w := 80.0 if slots <= 2 else 64.0
	var font := 30 if slots <= 2 else (26 if slots == 3 else 22)
	var total := get_viewport_rect().size.x - 32.0
	var card_w := maxf(120.0, floor((total - float(slots) * (reroll_w + 8.0)) / float(slots)))
	for index in slots:
		var card := HBoxContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_constant_override("separation", 8)

		var button := Button.new()
		button.custom_minimum_size = Vector2(card_w, 112.0)
		button.add_theme_font_size_override("font_size", font)
		Icons.flat(button)
		button.pressed.connect(_on_order_pressed.bind(index))
		card.add_child(button)

		var reroll := Button.new()
		Icons.decorate(reroll, "reroll", 26.0)
		reroll.text = "%d" % _reroll_cost()
		reroll.custom_minimum_size = Vector2(reroll_w, 112.0)
		reroll.add_theme_font_size_override("font_size", 26)
		reroll.disabled = _gems() < _reroll_cost()
		Icons.flat(reroll, Color(0.78, 0.45, 0.16, 0.18), Vector2(8.0, 6.0))
		reroll.pressed.connect(_on_order_reroll.bind(index))
		card.add_child(reroll)

		_order_bar.add_child(card)


func _order_text(order: Dictionary, index: int) -> String:
	var lines := PackedStringArray()
	for req in order.get("items", []):
		lines.append(Chains.item_name(StringName(req.get("chain", "")), int(req.get("level", 1))))
	var reward := _orders.reward_for(order)
	var tail := "%d монет" % int(reward.get("coins", 0))
	var left := _orders.bonus_seconds_left(index)
	if left > 0:
		tail += " · %d:%02d" % [floori(float(left) / 60.0), left % 60]
	lines.append(tail)
	return "\n".join(lines)


func _reroll_cost() -> int:
	return int(_cfg_num("order_reroll_cost_gems", 5.0))


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	# Корень HUD: Control с якорями FULL_RECT, его offset_* = безопасные зоны
	# (вырез сверху, home-индикатор снизу) — см. _apply_safe_area().
	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_hud_root)

	# Новый HUD (scripts/ui/game_hud.gd): значок уровня, плашки ресурсов, кнопка
	# магазина сверху и ряд кнопок снизу. Собирается кодом, сам держит safe area
	# и не ловит ввод (mouse_filter = IGNORE), поэтому поле под ним кликабельно.
	_hud = GAME_HUD.new()
	_hud.name = "GameHUD"
	layer.add_child(_hud)
	_hud.level_pressed.connect(_on_hud_level_pressed)
	_hud.shop_pressed.connect(_on_hud_shop_pressed)
	_hud.energy_plus_pressed.connect(_on_hud_energy_plus_pressed)
	_hud.gems_plus_pressed.connect(_on_hud_gems_plus_pressed)
	_hud.settings_pressed.connect(_on_settings_pressed)
	_hud.menu_pressed.connect(_on_meta_pressed)
	_hud.inventory_pressed.connect(_on_hud_inventory_pressed)
	_hud.cards_pressed.connect(_on_hud_cards_pressed)
	_hud.play_pressed.connect(_on_hud_play_pressed)

	# Статус уходил под шапку — новая шапка HUD выше, поэтому текст ниже заказов.
	_status_label = _make_label(_hud_root, Vector2(0.5, 0.0), Vector2(-330, 236), Vector2(660, 36), HORIZONTAL_ALIGNMENT_CENTER, 28)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_order_bar = HBoxContainer.new()
	_order_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_order_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_order_bar.offset_left = 16.0
	_order_bar.offset_right = -16.0
	_order_bar.offset_top = 114.0
	_order_bar.offset_bottom = 226.0
	_order_bar.add_theme_constant_override("separation", 8)
	_hud_root.add_child(_order_bar)

	# Меню действий по тапу на предмет (docs/GDD.md §18): никуда тащить не надо —
	# тапнул предмет, палец ничего не закрывает, промахнуться некуда.
	_action_scrim = ColorRect.new()
	_action_scrim.color = Color(0, 0, 0, 0.45)
	_action_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_action_scrim.visible = false
	_action_scrim.gui_input.connect(_on_action_scrim_input)
	_hud_root.add_child(_action_scrim)

	_action_card = PanelContainer.new()
	_action_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_card.custom_minimum_size = Vector2(520, 0)
	_action_card.add_theme_stylebox_override("panel", _action_card_style())
	_action_scrim.add_child(_action_card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_action_card.add_child(rows)

	_action_title = Label.new()
	_action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_title.add_theme_font_size_override("font_size", 32)
	rows.add_child(_action_title)

	_action_hint = Label.new()
	_action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_hint.add_theme_font_size_override("font_size", 24)
	rows.add_child(_action_hint)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	rows.add_child(action_row)

	_action_sell = Button.new()
	_action_sell.custom_minimum_size = Vector2(250, 84)
	_action_sell.add_theme_font_size_override("font_size", 30)
	Icons.decorate(_action_sell, "coin", 32.0)
	Icons.flat(_action_sell)
	_action_sell.pressed.connect(_on_action_sell)
	action_row.add_child(_action_sell)

	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(170, 84)
	cancel.add_theme_font_size_override("font_size", 30)
	Icons.flat(cancel)
	cancel.pressed.connect(_close_item_actions)
	action_row.add_child(cancel)

	if not _board.item_tapped.is_connected(_on_item_tapped):
		_board.item_tapped.connect(_on_item_tapped)


## Отступы HUD под вырез/home-индикатор iPhone.
## Полю вставки нужны отдельно — см. Board._recompute_layout().
func _apply_safe_area() -> void:
	SAFE_AREA.apply_offsets(_hud_root)


## Попапы: экран энергии и настройки тестового билда.
func _setup_popups() -> void:
	_energy_popup = ENERGY_POPUP.new()
	_energy_popup.name = "EnergyPopup"
	add_child(_energy_popup)
	_energy_popup.rewarded_requested.connect(_on_rewarded_requested)

	_settings_popup = SETTINGS_POPUP.new()
	_settings_popup.name = "SettingsPopup"
	add_child(_settings_popup)
	_settings_popup.sell_all_requested.connect(_on_sell_all)
	_settings_popup.reset_requested.connect(_on_reset_progress)
	_settings_popup.technospike_action.connect(_on_technospike)
	## Бустеры переехали из HUD в настройки (нижняя полоса убрана).
	_settings_popup.booster_requested.connect(_on_booster_pressed)

	_haptics_test_popup = HAPTICS_TEST_POPUP.new()
	_haptics_test_popup.name = "HapticsTestPopup"
	add_child(_haptics_test_popup)
	_settings_popup.haptics_test_requested.connect(_on_haptics_test)

	_meta_popup = META_POPUP.new()
	_meta_popup.name = "MetaPopup"
	add_child(_meta_popup)
	_meta_popup.daily_claim_requested.connect(_on_daily_claim)
	_meta_popup.open_cafe_requested.connect(_on_open_cafe)

	_cafe_view = CAFE_VIEW.new()
	_cafe_view.name = "CafeView"
	add_child(_cafe_view)
	_cafe_view.decor_place_requested.connect(_on_decor_place)
	_cafe_view.decor_rotate_requested.connect(_on_decor_rotate)
	_cafe_view.decor_clear_requested.connect(_on_slot_clear)
	_cafe_view.decor_buy_requested.connect(_on_decor_buy)
	_cafe_view.closed.connect(_on_cafe_closed)

	_generators_popup = GENERATORS_POPUP.new()
	_generators_popup.name = "GeneratorsPopup"
	add_child(_generators_popup)
	_generators_popup.generator_requested.connect(_on_generator_pressed)


func _make_label(
	parent: Node,
	anchor: Vector2,
	offset: Vector2,
	size: Vector2,
	align: HorizontalAlignment,
	font_size: int = 34
) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = offset.x
	label.offset_top = offset.y
	label.offset_right = offset.x + size.x
	label.offset_bottom = offset.y + size.y
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


# --- Состояние ---------------------------------------------------------------

func _restore() -> void:
	var saved = SaveManager.get_value("board", [])
	if typeof(saved) == TYPE_ARRAY and not (saved as Array).is_empty():
		_board.load_from(saved)
	else:
		_board.spawn(Chains.COFFEE, 1)
	_restore_orders()
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
	_refresh_generators()
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


## Карточки генераторов в попапе «Генераторы» (кнопка ▶): открытая цепочка
## показывает цену в энергии, закрытая — требуемый уровень.
func _refresh_generators() -> void:
	if _generators_popup == null:
		return
	_generators_popup.refresh(_generator_cost(), _generator_entries())


## Список генераторов для попапа: {chain, text, icon, enabled}.
func _generator_entries() -> Array:
	var entries := []
	for chain in Chains.all_chains():
		var unlocked := Progress.is_generator_unlocked(chain)
		var text := ""
		var icon := "lock"
		if unlocked:
			icon = "energy"
			text = "%s — %d энергии" % [Chains.title(chain), _generator_cost()]
		else:
			text = "%s — откроется на ур. %d" % [Chains.title(chain), Progress.generator_unlock_level(chain)]
		entries.append({"chain": chain, "text": text, "icon": icon, "enabled": unlocked})
	return entries


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


func _show_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


# --- Обработчики -------------------------------------------------------------

func _on_booster_pressed(kind: String) -> void:
	if _board == null:
		return
	var limit := int(_cfg_num("booster_per_session_limit", 1.0))
	if limit > 0 and int(_booster_used.get(kind, 0)) >= limit:
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status("Этот бустер уже использован в сессии")
		return
	var cost := _booster_cost(kind)
	if not _spend_gems(cost):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status("Не хватает гемов: нужно %d" % cost)
		return

	var applied := false
	match kind:
		"hammer":
			# Целимся следующим тапом по предмету (board.take_target → booster_target_picked).
			_board.take_target = true
			applied = true
			_show_status("Хаммер: тапни предмет, чтобы убрать")
		"shuffle":
			applied = _board.shuffle()
			_show_status("Перемешано" if applied else "Нечего перемешивать")
		"magnet":
			var chain := _first_unlocked_chain()
			var count := int(_cfg_num("booster_magnet_count", 3.0))
			var placed := 0
			for i in count:
				if _board.spawn(chain, 1):
					placed += 1
			applied = placed > 0
			_show_status("Магнит: +%d предметов" % placed)

	if not applied:
		# Эффекта не было — возвращаем гемы.
		_add_gems(cost)
		return

	Haptics.selection()
	_booster_used[kind] = int(_booster_used.get(kind, 0)) + 1
	Analytics.log_event("booster_used", {"kind": kind, "cost": cost})
	_refresh_boosters()
	_save_game()


## Хаммер выбрал цель. cell < 0 — тап мимо предмета: отменяем и возвращаем гемы.
func _on_booster_target(cell: int) -> void:
	if cell < 0:
		var cost := _booster_cost("hammer")
		_booster_used["hammer"] = maxi(0, int(_booster_used.get("hammer", 0)) - 1)
		_add_gems(cost)
		_show_status("Хаммер отменён — гемы возвращены")
		return
	Haptics.selection()
	_board.remove_at_cell(cell)
	Analytics.log_event("booster_target", {"kind": "hammer", "cell": cell})
	_show_status("Хаммер: предмет убран")
	_save_game()


func _first_unlocked_chain() -> StringName:
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain):
			return chain
	return Chains.COFFEE


func _on_generator_pressed(chain: StringName) -> void:
	if not Progress.is_generator_unlocked(chain):
		_show_status("Генератор откроется на уровне %d" % Progress.generator_unlock_level(chain))
		return
	if _board.is_full():
		_show_status("Поле заполнено: слей пары или тапни по лишнему — продашь")
		return
	if not Energy.spend(_generator_cost()):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_energy_popup.open()
		_refresh_energy_popup_state()
		return
	_board.spawn(chain, 1)
	_show_status("")
	Haptics.selection()
	_log_game_event("generator_tap", {"chain": String(chain)})
	_ftue_step("first_generator")
	_refresh_energy()
	_save_game()


func _on_items_merged(_from_cell: int, to_cell: int, chain: StringName, level: int) -> void:
	var high := level >= 4
	Haptics.impact(HAPTICS.Strength.HEAVY if high else HAPTICS.Strength.MEDIUM)
	_log_game_event("item_merged", {"chain": String(chain), "level": level})
	var item := _board.item_at(to_cell)
	if item != null:
		item.punch()
	_ftue_step("first_merge")
	_save_game()


func _on_board_filled() -> void:
	_show_status("Поле заполнено: слей пары или тапни по лишнему — продашь")


func _on_invalid_drop(_from_cell: int, to_cell: int) -> void:
	Haptics.impact(HAPTICS.Strength.SOFT)
	if to_cell < 0:
		_show_status("Продажа — тапни по предмету")
		return
	_show_status("Сюда нельзя — нужен такой же предмет")


## Тап по предмету: открываем меню действий вместо «брось мимо поля».
func _on_item_tapped(cell: int) -> void:
	var node := _board.item_at(cell)
	if node == null or node.data == null or _action_scrim == null:
		return
	var data: ItemData = node.data
	_action_cell = cell
	Haptics.selection()
	_action_title.text = Chains.item_name(data.chain, data.level)
	_action_hint.text = "Такой предмет ждут заказы — сдача даст монет больше" if _order_wants(data.chain, data.level) else ""
	_action_sell.text = "Продать за %d" % _sell_price(data)

	# Карточка рядом с предметом, но всегда целиком в экране.
	_action_scrim.visible = true
	_action_card.reset_size()
	var card := _action_card.size
	var safe := SAFE_AREA.insets()
	var anchor := _board.to_global(_board.cell_center(cell)) - Vector2(safe.x, safe.y)
	var view := get_viewport_rect().size
	var half := _board.cell_size * 0.5
	var pos := Vector2(anchor.x - card.x * 0.5, anchor.y + half + 16.0)
	if pos.y + card.y > view.y - 16.0:
		pos.y = anchor.y - half - 16.0 - card.y
	pos.x = clampf(pos.x, 16.0, maxf(16.0, view.x - card.x - 16.0))
	pos.y = clampf(pos.y, 16.0, maxf(16.0, view.y - card.y - 16.0))
	_action_card.position = pos

	node.punch()


func _close_item_actions() -> void:
	_action_cell = -1
	if _action_scrim != null:
		_action_scrim.visible = false


func _on_action_sell() -> void:
	var cell := _action_cell
	_close_item_actions()
	if cell >= 0:
		_board.sell_at(cell)


## Тап по затемнению мимо карточки закрывает меню.
func _on_action_scrim_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		_close_item_actions()


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


## Оформление карточки меню действий.
func _action_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2A1B10", 0.97)
	style.set_corner_radius_all(24)
	style.set_border_width_all(3)
	style.border_color = Color("C98A5E", 0.9)
	style.set_content_margin_all(20)
	return style


func _on_energy_changed(_value: int, _maximum: int) -> void:
	_refresh_energy()


func _on_energy_not_enough(required: int, left: int) -> void:
	Haptics.impact(HAPTICS.Strength.SOFT, 2)
	_show_status("Мало энергии: %d/%d" % [left, required])
	Analytics.log_event("energy_empty_shown", {"required": required, "left": left})
	_energy_popup.open()
	_refresh_energy_popup_state()
	_ftue_step("out_of_energy")


func _on_order_pressed(index: int) -> void:
	var result: Dictionary = _orders.try_deliver(index, _board)
	if not bool(result.get("ok", false)):
		_show_status(String(result.get("reason", "")))
		return
	var cat_bonus := Meta.cat_bonus()
	var coins := int(round(float(result.get("coins", 0)) * cat_bonus))
	var xp := int(result.get("xp", 0))
	var gems := int(result.get("gems", 0))
	var bonus := float(result.get("bonus", 1.0))
	_add_coins(coins)
	if gems > 0:
		_add_gems(gems)
	Progress.add_xp(xp)
	_log_game_event("order_completed", {"coins": coins, "xp": xp, "gems": gems, "bonus": bonus})
	Haptics.impact(HAPTICS.Strength.MEDIUM)
	if gems > 0:
		Haptics.impact(HAPTICS.Strength.LIGHT)
	var text := "Заказ готов: +%d монет, +%d XP" % [coins, xp]
	if bonus > 1.0:
		text += " (×%.1f за скорость)" % bonus
	if gems > 0:
		text += " +%d гемов" % gems
	if cat_bonus > 1.0:
		text += " (коты +%d%%)" % Meta.cat_bonus_percent()
	_show_status(text)
	_ftue_step("first_order")
	_orders_done += 1
	SaveManager.set_value("orders_done", _orders_done)
	_check_cat_unlocks()
	_save_game()


## Реролл заказа за гемы (цена — Config.order_reroll_cost_gems, см. docs/economy.md).
func _on_order_reroll(index: int) -> void:
	var cost := _reroll_cost()
	if not _spend_gems(cost):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status("Не хватает гемов: нужно %d" % cost)
		return
	_orders.replace(index)
	Analytics.log_event("order_rerolled", {"index": index, "cost": cost})
	_show_status("Заказ обновлён")
	_save_game()


func _on_xp_changed(_xp: int, _next: int) -> void:
	_refresh_progress()


func _on_level_changed(level: int, previous: int) -> void:
	_refresh_progress()
	_refresh_generators()
	_restore_orders()
	_check_cat_unlocks()
	Haptics.impact(HAPTICS.Strength.HEAVY, 2)
	_log_game_event("level_up", {"level": level, "previous": previous})
	var note := Progress.unlock_note(previous)
	_show_status("Уровень %d!%s" % [level, (" " + note) if not note.is_empty() else ""])
	_save_game()


func _on_item_sold(_cell: int, data: ItemData) -> void:
	if data == null:
		return
	var coins := _sell_price(data)
	_add_coins(coins)
	Haptics.selection()
	_log_game_event("item_sold", {"chain": String(data.chain), "level": data.level, "coins": coins})
	_show_status("Продано: +%d монет" % coins)
	_save_game()


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
	Haptics.selection()
	_settings_popup.open()


## Кнопка «🎛 Тест вибрации» в настройках: попап со всеми видами отклика
## (scripts/ui/haptics_test_popup.gd). Настройки остаются открытыми под ним.
func _on_haptics_test() -> void:
	Haptics.selection()
	_haptics_test_popup.open()


# --- Мета: попап, награды, коты (docs/GDD.md §8) -----------------------------

## Кнопка «🐱»: попап меты (ежедневная награда, коты, декор).
func _on_meta_pressed() -> void:
	Haptics.selection()
	Analytics.log_event("shop_open")
	_meta_popup.open()


# --- Кнопки нового HUD (scripts/ui/game_hud.gd) ------------------------------

## Значок уровня — только отображение.
func _on_hud_level_pressed() -> void:
	pass


## 🏪 Магазин: кофейня сразу с каталогом мебели (покупка живёт только там).
func _on_hud_shop_pressed() -> void:
	if _cafe_view == null:
		return
	Haptics.selection()
	_log_game_event("shop_open", {"where": "catalog"})
	_cafe_view.open_shop()


## ⚡+ : экран энергии (реклама за +15).
func _on_hud_energy_plus_pressed() -> void:
	Haptics.selection()
	_energy_popup.open()
	_refresh_energy_popup_state()


## 💎+ : покупка гемов (техспайк-заглушка).
func _on_hud_gems_plus_pressed() -> void:
	_on_technospike("purchase")


## 📦 Инвентарь: кофейня для расстановки декора.
func _on_hud_inventory_pressed() -> void:
	_on_open_cafe()


## 🗂 Карточки: попап меты на вкладке «Коты» (красная точка — есть что открыть).
func _on_hud_cards_pressed() -> void:
	Haptics.selection()
	Analytics.log_event("shop_open", {"where": "cats"})
	_meta_popup.open_tab(1)


## ▶ : попап «Генераторы» — тап по цепочке ставит предмет на поле.
func _on_hud_play_pressed() -> void:
	Haptics.selection()
	_refresh_generators()
	_generators_popup.open(_generator_cost(), _generator_entries())


## Ежедневная награда: выдать по таблице META_DATA.DAILY_REWARDS; 7-й день — котовый сундук.
func _on_daily_claim() -> void:
	var result: Dictionary = Meta.claim()
	if not bool(result.get("ok", false)):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status(String(result.get("reason", "")))
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
		Haptics.impact(HAPTICS.Strength.HEAVY, 3)
	else:
		Haptics.impact(HAPTICS.Strength.MEDIUM)
	var text := "Награда за день %d: " % int(result.get("day", 0))
	if coins > 0:
		text += "+%d монет " % coins
	if gems > 0:
		text += "+%d гемов " % gems
	if energy > 0:
		text += "+%d энергии " % energy
	if cat_id != "":
		var cat := META_DATA.cat(cat_id)
		text += "кот %s!" % String(cat.get("name", cat_id))
	_log_game_event("daily_reward_claim", {"day": int(result.get("day", 0)), "coins": coins, "gems": gems, "energy": energy, "cat": cat_id})
	_show_status(text.strip_edges())
	_refresh_hud()
	_refresh_meta_badge()
	_meta_popup.refresh()
	_save_game()


## Покупка декора: монеты и XP выдаёт Meta.buy_decor (docs/GDD.md §8.1).
func _on_decor_buy(decor_id: String) -> void:
	var result: Dictionary = Meta.buy_decor(decor_id)
	if not bool(result.get("ok", false)):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status(String(result.get("reason", "")))
		return
	var decor: Dictionary = result.get("decor", {})
	Haptics.impact(HAPTICS.Strength.HEAVY, 2)
	_show_status("Куплено: %s (+%d XP)" % [String(decor.get("name", decor_id)), int(result.get("xp", 0))])
	_log_game_event("decor_purchased", {"decor": decor_id, "cost": int(decor.get("cost", 0)), "xp": int(result.get("xp", 0))})
	_refresh_hud()
	_refresh_meta_badge()
	_meta_popup.refresh()
	_save_game()


## Поставить мебель в слот кофейни (docs/GDD.md §8.1): drag из инвентаря.
func _on_decor_place(decor_id: String, slot_id: String, rot: int = 0) -> void:
	var result: Dictionary = Meta.place_decor(decor_id, slot_id, rot)
	if not bool(result.get("ok", false)):
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status(String(result.get("reason", "")))
		return
	var decor: Dictionary = META_DATA.decor(decor_id)
	var slot: Dictionary = META_DATA.slot(slot_id)
	Haptics.selection()
	_show_status("%s → %s" % [META_DATA.decor_short(decor), String(slot.get("room", ""))])
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
		Haptics.impact(HAPTICS.Strength.SOFT, 2)
		_show_status(String(result.get("reason", "")))
		return
	Haptics.selection()
	_log_game_event("decor_rotated", {"slot": slot_id, "rot": int(result.get("rot", turn))})
	_save_game()


## Из меты («🏠 Карта») открыть изометрическую кофейню.
func _on_open_cafe() -> void:
	if _cafe_view == null:
		return
	_meta_popup.close()
	Haptics.selection()
	_log_game_event("shop_open", {"where": "cafe"})
	_cafe_view.open()


func _on_cafe_closed() -> void:
	_refresh_hud()
	_refresh_meta_badge()


## Снять мебель со слота (предмет остаётся купленным).
func _on_slot_clear(slot_id: String) -> void:
	var result: Dictionary = Meta.clear_slot(slot_id)
	if not bool(result.get("ok", false)):
		return
	Haptics.selection()
	_meta_popup.refresh()
	_save_game()


## Новый кот: сигнал Meta (уровень кофейни / заказы / котовый сундук).
func _on_cat_unlocked(cat: Dictionary) -> void:
	Haptics.impact(HAPTICS.Strength.HEAVY, 2)
	_show_status("Новый кот: %s (%s)" % [String(cat.get("name", "")), String(cat.get("role", ""))])
	_log_game_event("cat_unlocked", {"cat": String(cat.get("id", "")), "rarity": String(cat.get("rarity", "common")), "total": Meta.cat_count()})
	_refresh_meta_badge()


## Проверить условия открытия котов: звать после заказа и после повышения уровня.
func _check_cat_unlocks() -> void:
	Meta.check_cat_unlocks(_orders_done)


## Точка-бейдж на кнопке «🐱», если ежедневная награда готова.
## Красная точка на кнопке карточек: готова ежедневная награда и/или есть кот,
## чьи условия уже выполнены (альбом «Коты» ждёт).
func _refresh_meta_badge() -> void:
	if _hud == null:
		return
	_hud.set_cards_notification(Meta.can_claim() or _has_pending_cat())


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
	_show_status("Продано предметов: %d" % sold)
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
		_show_status("Лимит rewarded за сегодня исчерпан (%d)" % cap)
		_refresh_energy_popup_state()
		return
	Haptics.selection()
	Haptics.mute_for_ads(true)
	Analytics.log_event("rewarded_started", {"placement": "energy"})
	Ads.show_rewarded("energy", {"energy": amount})


func _on_rewarded_earned(placement: String, reward: Dictionary) -> void:
	Haptics.mute_for_ads(false)
	Haptics.impact(HAPTICS.Strength.MEDIUM)
	# Техспайк: rewarded из настроек не выдаёт энергию — только подтверждает,
	# что колбэк награды дошёл с устройства.
	if placement != "energy":
		Analytics.log_event("rewarded_completed", {"placement": placement, "reward": reward})
		_show_status("Реклама: награда получена (%s)" % placement)
		return
	var amount := int(reward.get("energy", int(_cfg_num("rewarded_energy_amount", 15.0))))
	Energy.add(amount)
	_count_rewarded_energy()
	Analytics.log_event("rewarded_completed", {"placement": placement, "amount": amount})
	_show_status("Энергия: +%d" % amount)
	_refresh_energy()
	_refresh_energy_popup_state()
	_save_game()


func _on_rewarded_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Haptics.impact(HAPTICS.Strength.SOFT, 2)
	Analytics.log_event("rewarded_failed", {"placement": placement, "reason": reason})
	_show_status("Реклама недоступна: %s" % reason)
	_refresh_energy_popup_state()


# --- Техспайк: реклама, консент, покупки (docs/technspike.md) ----------------

## Кнопки в настройках прототипа: проверяем рекламу/консент/IAP на устройстве.
## action: "rewarded" | "interstitial" | "consent" | "purchase" | "restore".
func _on_technospike(action: String) -> void:
	Analytics.log_event("technospike_action", {"action": action})
	match action:
		"rewarded":
			_show_status("Техспайк: запрашиваем rewarded…")
			Haptics.mute_for_ads(true)
			Ads.show_rewarded("technospike", {})
		"interstitial":
			_show_status("Техспайк: запрашиваем interstitial…")
			Haptics.mute_for_ads(true)
			Ads.show_interstitial("technospike")
		"consent":
			_show_status("Техспайк: запрашиваем консент…")
			Ads.request_consent()
		"purchase":
			var sku := String(Config.get_value("iap_test_sku"))
			if sku.is_empty():
				sku = "gems_small"
			_show_status("Техспайк: покупка %s…" % sku)
			Iap.purchase(sku)
		"restore":
			_show_status("Техспайк: восстановление покупок…")
			Iap.restore()
		_:
			_show_status("Неизвестное действие техспайка: %s" % action)


func _on_interstitial_shown(placement: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_shown", {"placement": placement})
	_show_status("Interstitial показан (%s)" % placement)


func _on_interstitial_failed(placement: String, reason: String) -> void:
	Haptics.mute_for_ads(false)
	Analytics.log_event("interstitial_failed", {"placement": placement, "reason": reason})
	_show_status("Interstitial недоступен: %s" % reason)


func _on_consent_finished(ok: bool, reason: String) -> void:
	Analytics.log_event("consent_finished", {"ok": ok, "reason": reason})
	if ok:
		Analytics.set_consent(true)
		_show_status("Консент получен (%s)" % reason)
	else:
		_show_status("Консент не получен: %s" % reason)


func _on_purchase_succeeded(sku: String, receipt: Dictionary) -> void:
	var list := _iap_owned()
	if not list.has(sku):
		list.append(sku)
	SaveManager.set_value("iap_owned", list)
	Haptics.impact(HAPTICS.Strength.HEAVY, 2)
	Analytics.log_event("purchase_succeeded", {"sku": sku, "keys": receipt.keys()})
	_show_status("Покупка ок: %s" % sku)
	_save_game()


func _on_purchase_failed(sku: String, reason: String) -> void:
	Haptics.impact(HAPTICS.Strength.SOFT, 2)
	Analytics.log_event("purchase_failed", {"sku": sku, "reason": reason})
	_show_status("Покупка не прошла (%s): %s" % [sku, reason])


func _on_purchases_restored(skus: PackedStringArray) -> void:
	var list := _iap_owned()
	for sku in skus:
		if not list.has(sku):
			list.append(sku)
	SaveManager.set_value("iap_owned", list)
	Analytics.log_event("purchases_restored", {"count": skus.size()})
	_show_status("Восстановлено покупок: %d" % skus.size())
	_save_game()


## Список sku, которые игрок уже купил (ключ save: iap_owned).
func _iap_owned() -> Array:
	var saved = SaveManager.get_value("iap_owned", [])
	if typeof(saved) == TYPE_ARRAY:
		return (saved as Array).duplicate()
	return []


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
	if not SELFTEST:
		return
	_selftesting = true
	var ok := true

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
		_log_step("[selftest] haptics: %s" % ("OK" if _test_haptics() else "FAILED"))
		_log_step("[selftest] icons: %s" % ("OK" if _test_icons() else "FAILED"))
		_log_step("[selftest] iso: %s" % ("OK" if _test_iso() else "FAILED"))
		_log_step("[selftest] board: OK")
	else:
		_log_step("[selftest] board FAILED")
		push_error("[selftest] board FAILED")
	_selftesting = false


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


## Проверка вибрации: у каждой силы есть запасной импульс, имя нативного
## синглтона совпадает с плагином, автолоад отдаёт оба вида отклика.
func _test_haptics() -> bool:
	if HAPTICS.Strength.size() != 5:
		push_error("[selftest] haptics: ожидалось 5 уровней силы, а не %d" % HAPTICS.Strength.size())
		return false
	for strength in HAPTICS.Strength.values():
		if not HAPTICS.FALLBACK.has(strength):
			push_error("[selftest] haptics: нет запасного импульса для силы %d" % strength)
			return false
	if HAPTICS.SINGLETON != "HapticsIOS":
		push_error("[selftest] haptics: имя синглтона «%s» разошлось с плагином" % HAPTICS.SINGLETON)
		return false
	if not Haptics.has_method("selection") or not Haptics.has_method("impact"):
		push_error("[selftest] haptics: автолоад не отдаёт selection()/impact()")
		return false
	return true


## Проверка иконок вместо эмодзи (docs/ui-icons.md): каждый используемый файл
## на месте и разбирается в текстуру.
func _test_icons() -> bool:
	for icon_id in Icons.USED:
		if not Icons.has(icon_id):
			push_error("[selftest] icons: нет файла «%s»" % icon_id)
			return false
		var texture := Icons.texture(icon_id)
		if texture == null or texture.get_width() <= 0:
			push_error("[selftest] icons: не загрузилась «%s»" % icon_id)
			return false
	if Icons.has("нет-такой-иконки"):
		push_error("[selftest] icons: нашлась несуществующая иконка")
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

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
## Самопроверка пишет результат в файл: stdout при headless-запуске через MCP
## перехватывается не всегда. Путь внутри .godot/ — он в .gitignore.
const LOG_PATH := "user://selftest_result.txt"

var _board: Board
var _orders: ORDER_MANAGER
var _energy_label: Label
var _coins_label: Label
var _gems_label: Label
var _status_label: Label
var _level_label: Label
var _order_bar: HBoxContainer
var _booster_bar: HBoxContainer
var _generator_buttons: Dictionary = {}
var _booster_buttons: Dictionary = {}
## Попапы: экран энергии (docs/GDD.md §6) и настройки тестового билда (§20).
var _energy_popup: CanvasLayer
var _settings_popup: CanvasLayer
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
	_log_step("ready: hud + orders ready")
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
	_refresh_energy()

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	ticker.timeout.connect(_on_tick)
	add_child(ticker)

	Analytics.log_event("game_opened")
	_ftue_step("opened")
	_log_step("ready: done")


## Раз в секунду: таймеры энергии и бонуса заказов.
func _on_tick() -> void:
	_refresh_energy()
	if _energy_popup != null and _energy_popup.visible:
		_refresh_energy_popup_state()
	_refresh_orders()


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
	for child in _order_bar.get_children():
		_order_bar.remove_child(child)
		child.queue_free()
	var index := 0
	for order in _orders.orders():
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 4)

		var button := Button.new()
		button.text = _order_text(order, index)
		button.custom_minimum_size = Vector2(210, 84)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_order_pressed.bind(index))
		card.add_child(button)

		var reroll := Button.new()
		var cost := _reroll_cost()
		reroll.text = "🔄\n%d💎" % cost
		reroll.custom_minimum_size = Vector2(64, 84)
		reroll.add_theme_font_size_override("font_size", 16)
		reroll.disabled = _gems() < cost
		reroll.pressed.connect(_on_order_reroll.bind(index))
		card.add_child(reroll)

		_order_bar.add_child(card)
		index += 1


func _order_text(order: Dictionary, index: int) -> String:
	var parts := PackedStringArray()
	for req in order.get("items", []):
		parts.append(Chains.item_name(StringName(req.get("chain", "")), int(req.get("level", 1))))
	var reward := _orders.reward_for(order)
	var tail := "🪙 %d" % int(reward.get("coins", 0))
	var left := _orders.bonus_seconds_left(index)
	if left > 0:
		tail += "  ⏱ %d:%02d" % [floori(float(left) / 60.0), left % 60]
	return "%s\n%s" % [", ".join(parts), tail]


func _reroll_cost() -> int:
	return int(_cfg_num("order_reroll_cost_gems", 5.0))


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	_energy_label = _make_label(layer, Vector2(0.0, 0.0), Vector2(16, 12), Vector2(360, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_gems_label = _make_label(layer, Vector2(0.0, 0.0), Vector2(16, 52), Vector2(360, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_coins_label = _make_label(layer, Vector2(1.0, 0.0), Vector2(-376, 12), Vector2(360, 40), HORIZONTAL_ALIGNMENT_RIGHT)
	_level_label = _make_label(layer, Vector2(0.5, 0.0), Vector2(-180, 12), Vector2(360, 40), HORIZONTAL_ALIGNMENT_CENTER)
	_status_label = _make_label(layer, Vector2(0.5, 1.0), Vector2(-220, -170), Vector2(440, 40), HORIZONTAL_ALIGNMENT_CENTER)

	_order_bar = HBoxContainer.new()
	_order_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_order_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_order_bar.offset_left = 16.0
	_order_bar.offset_right = -16.0
	_order_bar.offset_top = 60.0
	_order_bar.offset_bottom = 200.0
	_order_bar.add_theme_constant_override("separation", 10)
	layer.add_child(_order_bar)

	_booster_bar = HBoxContainer.new()
	_booster_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_booster_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_booster_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_booster_bar.offset_top = -196.0
	_booster_bar.offset_bottom = -122.0
	_booster_bar.add_theme_constant_override("separation", 12)
	layer.add_child(_booster_bar)

	for kind in ["hammer", "shuffle", "magnet"]:
		var booster := Button.new()
		booster.custom_minimum_size = Vector2(140, 62)
		booster.add_theme_font_size_override("font_size", 20)
		booster.pressed.connect(_on_booster_pressed.bind(kind))
		_booster_bar.add_child(booster)
		_booster_buttons[kind] = booster

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -110.0
	bar.offset_bottom = -20.0
	bar.add_theme_constant_override("separation", 12)
	layer.add_child(bar)

	for chain in Chains.all_chains():
		var button := Button.new()
		button.text = "%s\n⚡%d" % [Chains.title(chain), _generator_cost()]
		button.custom_minimum_size = Vector2(140, 80)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_generator_pressed.bind(chain))
		bar.add_child(button)
		_generator_buttons[chain] = button
	_refresh_generators()
	_refresh_boosters()

	var gear := Button.new()
	gear.text = "⚙"
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.anchor_top = 0.0
	gear.anchor_bottom = 0.0
	gear.offset_left = -72.0
	gear.offset_right = -16.0
	gear.offset_top = 52.0
	gear.offset_bottom = 108.0
	gear.add_theme_font_size_override("font_size", 24)
	gear.pressed.connect(_on_settings_pressed)
	layer.add_child(gear)


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


func _make_label(parent: Node, anchor: Vector2, offset: Vector2, size: Vector2, align: HorizontalAlignment) -> Label:
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
	label.add_theme_font_size_override("font_size", 26)
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
	_refresh_hud()


func _save_game() -> void:
	if _selftesting or _board == null:
		return
	SaveManager.set_value("board", _board.serialize())
	SaveManager.set_value("energy", Energy.current())
	SaveManager.set_value("orders", _orders.orders())
	SaveManager.save_game()


# --- HUD ---------------------------------------------------------------------

func _refresh_hud() -> void:
	if _coins_label != null:
		_coins_label.text = "🪙 %d" % int(SaveManager.get_value("coins", 0))
	if _gems_label != null:
		_gems_label.text = "💎 %d" % _gems()
	_refresh_boosters()
	_refresh_progress()


func _refresh_progress() -> void:
	if _level_label == null:
		return
	if Progress.is_max_level():
		_level_label.text = "☕ Ур. %d — максимум" % Progress.level
		return
	_level_label.text = "☕ Ур. %d · %d/%d XP" % [Progress.level, Progress.xp, Progress.xp_next()]


## Кнопки генераторов: заблокированные показывают требуемый уровень.
func _refresh_generators() -> void:
	for chain in _generator_buttons.keys():
		var button: Button = _generator_buttons[chain]
		if button == null:
			continue
		var unlocked := Progress.is_generator_unlocked(chain)
		button.disabled = not unlocked
		if unlocked:
			button.text = "%s\n⚡%d" % [Chains.title(chain), _generator_cost()]
		else:
			button.text = "🔒 %s\nур. %d" % [Chains.title(chain), Progress.generator_unlock_level(chain)]


## Бустеры: кнопка блокируется, если гемов не хватает или лимит сессии исчерпан.
func _refresh_boosters() -> void:
	var limit := int(_cfg_num("booster_per_session_limit", 1.0))
	for kind in _booster_buttons.keys():
		var button: Button = _booster_buttons[kind]
		if button == null:
			continue
		var cost := _booster_cost(kind)
		var used_up := limit > 0 and int(_booster_used.get(kind, 0)) >= limit
		button.disabled = used_up or _gems() < cost
		var icon := _booster_icon(kind)
		button.text = ("%s ✓" % icon) if used_up else ("%s %d💎" % [icon, cost])


func _booster_icon(kind: String) -> String:
	match kind:
		"hammer":
			return "🔨"
		"shuffle":
			return "🔀"
		"magnet":
			return "🧲"
	return "?"


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
	if _energy_label == null:
		return
	var value := Energy.current()
	var suffix := ""
	if not Energy.is_full():
		suffix = "   +%d через %d с" % [int(Config.get_value("energy_regen_amount")), Energy.seconds_to_next()]
	_energy_label.text = "⚡ %d/%d%s" % [value, Energy.maximum, suffix]


func _show_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


# --- Обработчики -------------------------------------------------------------

func _on_booster_pressed(kind: String) -> void:
	if _board == null:
		return
	var limit := int(_cfg_num("booster_per_session_limit", 1.0))
	if limit > 0 and int(_booster_used.get(kind, 0)) >= limit:
		_show_status("Этот бустер уже использован в сессии")
		return
	var cost := _booster_cost(kind)
	if not _spend_gems(cost):
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
		_show_status("Поле заполнено — продай или слей что-нибудь")
		return
	if not Energy.spend(_generator_cost()):
		_energy_popup.open()
		_refresh_energy_popup_state()
		return
	_board.spawn(chain, 1)
	_show_status("")
	Analytics.log_event("generator_tap", {"chain": String(chain)})
	_ftue_step("first_generator")
	_refresh_energy()
	_save_game()


func _on_items_merged(_from_cell: int, to_cell: int, chain: StringName, level: int) -> void:
	Analytics.log_event("item_merged", {"chain": String(chain), "level": level})
	var item := _board.item_at(to_cell)
	if item != null:
		item.punch()
	_ftue_step("first_merge")
	_save_game()


func _on_board_filled() -> void:
	_show_status("Поле заполнено — продай или слей что-нибудь")


func _on_invalid_drop(_from_cell: int, _to_cell: int) -> void:
	_show_status("Сюда нельзя — нужен такой же предмет")


func _on_energy_changed(_value: int, _maximum: int) -> void:
	_refresh_energy()


func _on_energy_not_enough(required: int, left: int) -> void:
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
	var coins := int(result.get("coins", 0))
	var xp := int(result.get("xp", 0))
	var gems := int(result.get("gems", 0))
	var bonus := float(result.get("bonus", 1.0))
	_add_coins(coins)
	if gems > 0:
		_add_gems(gems)
	Progress.add_xp(xp)
	Analytics.log_event("order_completed", {"coins": coins, "xp": xp, "gems": gems, "bonus": bonus})
	var text := "Заказ готов: +%d 🪙, +%d XP" % [coins, xp]
	if bonus > 1.0:
		text += " (×%.1f за скорость)" % bonus
	if gems > 0:
		text += " +%d💎" % gems
	_show_status(text)
	_ftue_step("first_order")
	_save_game()


## Реролл заказа за гемы (цена — Config.order_reroll_cost_gems, см. docs/economy.md).
func _on_order_reroll(index: int) -> void:
	var cost := _reroll_cost()
	if not _spend_gems(cost):
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
	Analytics.log_event("level_up", {"level": level, "previous": previous})
	var note := Progress.unlock_note(previous)
	_show_status("Уровень %d!%s" % [level, (" " + note) if not note.is_empty() else ""])
	_save_game()


func _on_item_sold(_cell: int, data: ItemData) -> void:
	if data == null:
		return
	var coins := int(round(float(Chains.sell_value(data.level, _cfg_num("item_value_base", 5.0), _cfg_num("item_value_growth", 2.05))) * _cfg_num("sell_value_mult", 0.6)))
	_add_coins(coins)
	Analytics.log_event("item_sold", {"chain": String(data.chain), "level": data.level, "coins": coins})
	_show_status("Продано: +%d 🪙" % coins)
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
	_settings_popup.open()


## Продать всё поле разом: монеты приходят через _on_item_sold.
func _on_sell_all() -> void:
	var sold := 0
	for cell in _board.cell_count():
		if _board.has_item(cell) and _board.sell_at(cell):
			sold += 1
	_show_status("Продано предметов: %d" % sold)
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
	Analytics.log_event("rewarded_started", {"placement": "energy"})
	Ads.show_rewarded("energy", {"energy": amount})


func _on_rewarded_earned(placement: String, reward: Dictionary) -> void:
	if placement != "energy":
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
	Analytics.log_event("rewarded_failed", {"placement": placement, "reason": reason})
	_show_status("Реклама недоступна: %s" % reason)
	_refresh_energy_popup_state()


## Состояние кнопки в попапе энергии: доступна ли реклама и текст.
func _refresh_energy_popup_state() -> void:
	if _energy_popup == null:
		return
	var amount := int(_cfg_num("rewarded_energy_amount", 15.0))
	var cap := int(_cfg_num("rewarded_energy_daily_cap", 5.0))
	var left := maxi(0, cap - _rewarded_energy_today())
	var available := cap <= 0 or left > 0
	var text := "⚡ +%d за рекламу" % amount
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
		_log_step("[selftest] board: OK")
	else:
		_log_step("[selftest] board FAILED")
		push_error("[selftest] board FAILED")
	_selftesting = false


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

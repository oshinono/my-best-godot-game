class_name GameHUD
extends Control

## Главный экран поверх поля (scenes/ui/game_hud.tscn): значок уровня и плашки
## ресурсов, ряд заказов, строка статуса, область поля, кнопки генераторов,
## нижний ряд кнопок.
##
## Вёрстка — сцена на контейнерах: %Safe (MarginContainer, safe area +
## SCREEN_MARGIN) → VBox [Top, Orders, BoardArea, Bottom]. Генераторы — предметы
## на поле (scripts/board.gd), отдельного ряда кнопок под полем нет.
## Сообщения игроку — тосты (scripts/ui/fx_layer.gd), строки статуса нет.
## Поле (Node2D, scripts/board.gd) вписывается в прямоугольник %BoardArea —
## о его изменении сообщает signal board_area_changed. Оформление
## кнопок — Theme (SquareButton), картинки — assets/ui/theme/. Скрипт только
## пишет значения и пробрасывает сигналы. HUD не ловит ввод (mouse_filter =
## IGNORE на контейнерах), поэтому поле под ним кликабельно.

signal level_pressed
signal energy_plus_pressed
signal gems_plus_pressed
signal settings_pressed
signal menu_pressed
signal play_pressed
signal storage_pressed
signal tasks_pressed
signal event_pressed
## Прямоугольник области поля изменился (раскладка, safe area, поворот).
signal board_area_changed(rect: Rect2)

const SAFE := preload("res://scripts/ui/safe_area.gd")
const SCREEN_MARGIN := 16.0
const ORDER_CARD := preload("res://scenes/ui/order_card.tscn")


func _ready() -> void:
	(%LevelButton as BaseButton).pressed.connect(func() -> void: level_pressed.emit())
	%EnergyBar.plus_pressed.connect(func() -> void: energy_plus_pressed.emit())
	%GemBar.plus_pressed.connect(func() -> void: gems_plus_pressed.emit())
	(%Settings as BaseButton).pressed.connect(func() -> void: settings_pressed.emit())
	(%Menu as BaseButton).pressed.connect(func() -> void: menu_pressed.emit())
	(%Play as BaseButton).pressed.connect(func() -> void: play_pressed.emit())
	(%Storage as BaseButton).pressed.connect(func() -> void: storage_pressed.emit())
	(%Tasks as BaseButton).pressed.connect(func() -> void: tasks_pressed.emit())
	(%Event as BaseButton).pressed.connect(func() -> void: event_pressed.emit())
	for button: BaseButton in [%LevelButton, %Settings, %Menu, %Play, %Storage, %Tasks, %Event]:
		_bind_press(button)
	(%BoardArea as Control).resized.connect(func() -> void:
		board_area_changed.emit(board_rect()))
	_apply_safe_area()
	# Вставки safe area меняются при повороте/смене окна — держим их актуальными.
	get_viewport().size_changed.connect(_apply_safe_area)


# ---------------------------------------------------------------- ПУБЛИЧНОЕ API
func set_level(v: int) -> void:
	(%Level as Label).text = str(v)


func set_energy(v: int) -> void:
	%EnergyBar.value = v


func set_coins(v: int) -> void:
	%CoinBar.value = v


func set_gems(v: int) -> void:
	%GemBar.value = v


func set_menu_notification(show_dot: bool) -> void:
	(%Notif as Control).visible = show_dot


# ---------------------------------------------------------------- ЦЕЛИ ЭФФЕКТОВ
## Экранные точки, куда летят монеты/гемы (fx_layer.gd), и «пружины» на прилёт.
func coin_target() -> Vector2:
	return %CoinBar.icon_center()


func gem_target() -> Vector2:
	return %GemBar.icon_center()


## Придержать счётчик, пока к нему летят иконки: потом он докрутится сам.
func hold_coins(seconds: float) -> void:
	%CoinBar.hold(seconds)


func hold_gems(seconds: float) -> void:
	%GemBar.hold(seconds)


func punch_coins() -> void:
	%CoinBar.punch()


func punch_gems() -> void:
	%GemBar.punch()


func punch_level() -> void:
	_bounce(%Badge as Control, 1.3)


## Центр карточки заказа `index` на экране (цель для предметов заказа).
func order_center(index: int) -> Vector2:
	var box := %Orders as Control
	if index < 0 or index >= box.get_child_count():
		return box.get_global_rect().get_center()
	return (box.get_child(index).get_node("%Card") as Control).get_global_rect().get_center()


## Заказ пока не сдать — карточка встряхивается.
func shake_order(index: int) -> void:
	var box := %Orders as Control
	if index >= 0 and index < box.get_child_count():
		box.get_child(index).shake()


## Карточка заказа «подпрыгивает» — заказ принят.
func punch_order(index: int) -> void:
	var box := %Orders as Control
	if index >= 0 and index < box.get_child_count():
		_bounce(box.get_child(index) as Control, 1.12)


## Экранный прямоугольник области поля (в координатах viewport).
func board_rect() -> Rect2:
	return (%BoardArea as Control).get_global_rect()


## Карточки заказов (scenes/ui/order_card.tscn): пересобираются только при
## смене числа слотов, иначе тап терялся бы между нажатием и отпусканием.
## Возвращает список карточек в порядке слотов.
func ensure_order_cards(count: int, on_order: Callable, on_reroll: Callable) -> Array:
	var box := %Orders as GridContainer
	# Две карточки в ряд: при 3-4 заказах — два ряда, а не четыре крошки.
	box.columns = clampi(count, 1, 2)
	if box.get_child_count() != count:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		for index in count:
			var card := ORDER_CARD.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(card)
			card.order_pressed.connect(on_order.bind(index))
			card.reroll_pressed.connect(on_reroll.bind(index))
	return box.get_children()


## Звёзды ремонта на кнопке «Ремонт»; точка — есть задание, на которое хватает.
func set_stars(stars: int, task_ready: bool) -> void:
	(%Tasks as Button).text = "★ %d" % stars
	(%TasksDot as Control).visible = task_ready


## Кнопка ивента: видна, пока ивент идёт; точка — есть награда забрать.
func set_event(active: bool, claimable: bool) -> void:
	(%Event as Control).visible = active
	(%EventDot as Control).visible = claimable


## Экранный центр кнопки (цель для летящих звёзд).
func tasks_target() -> Vector2:
	return (%Tasks as Control).get_global_rect().get_center()


func punch_tasks() -> void:
	_bounce(%Tasks as Control, 1.2)


# ---------------------------------------------------------------- УТИЛИТЫ
func _apply_safe_area() -> void:
	SAFE.apply_margins(%Safe as MarginContainer, SCREEN_MARGIN)


## «Пружина» при нажатии: контейнер владеет position/size, поэтому
## анимируем только scale вокруг центра (pivot_offset).
func _bind_press(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _scale_to(b, 0.92))
	b.button_up.connect(func() -> void: _scale_to(b, 1.0))


## Пружина: scale вверх и обратно вокруг центра (контейнер владеет position).
func _bounce(node: Control, peak: float) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * peak
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _scale_to(node: Control, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * s, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

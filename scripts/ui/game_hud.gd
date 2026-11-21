class_name GameHUD
extends Control

## Поле центрируется по viewport независимо от числа заказов.

signal level_pressed
signal energy_plus_pressed
signal currency_pressed(kind: String)
signal settings_pressed
signal menu_pressed
signal play_pressed
signal chooser_requested(active: String, cats: Array)
## Прямоугольник области поля изменился (раскладка, safe area, поворот).
signal board_area_changed(rect: Rect2)

const SAFE := preload("res://scripts/ui/safe_area.gd")
const SCREEN_MARGIN := 16.0
const ORDER_CARD := preload("res://scenes/ui/order_card.tscn")

var _xp_tween: Tween
var _queue_view: HBoxContainer
var _orders_grid: GridContainer


func _ready() -> void:
	_queue_view = %Queue
	_orders_grid = %Orders
	_queue_view.chooser_requested.connect(chooser_requested.emit)
	_queue_view.cafe_pressed.connect(func() -> void: play_pressed.emit())
	(%LevelButton as BaseButton).pressed.connect(func() -> void: level_pressed.emit())
	%EnergyBar.plus_pressed.connect(func() -> void: energy_plus_pressed.emit())
	%GemBar.plus_pressed.connect(func() -> void: currency_pressed.emit("gems"))
	%CoinBar.plus_pressed.connect(func() -> void: currency_pressed.emit("coins"))
	(%Settings as BaseButton).pressed.connect(func() -> void: settings_pressed.emit())
	(%Menu as BaseButton).pressed.connect(func() -> void: menu_pressed.emit())
	(%Play as BaseButton).pressed.connect(func() -> void: play_pressed.emit())
	for button: BaseButton in [%LevelButton, %Settings, %Menu, %Play]:
		_bind_press(button)
	_apply_safe_area()
	# Вставки safe area меняются при повороте/смене окна — держим их актуальными.
	get_viewport().size_changed.connect(_apply_safe_area)


# ---------------------------------------------------------------- ПУБЛИЧНОЕ API
func set_queue(orders: Array, barista_id: String, cats: Array) -> void:
	_queue_view.refresh(orders, barista_id, cats)

func set_level(v: int) -> void:
	(%Level as Label).text = str(v)


## Полоска XP под значком уровня: доля 0..1 до следующего уровня.
## Рост — плавно; откат (новый уровень начался с нуля) — сразу.
func set_xp(ratio: float) -> void:
	var bar := %XpBar as ProgressBar
	ratio = clampf(ratio, 0.0, 1.0)
	if _xp_tween != null and _xp_tween.is_valid():
		_xp_tween.kill()
	if ratio < bar.value or not is_visible_in_tree():
		bar.value = ratio
		return
	_xp_tween = create_tween()
	_xp_tween.tween_property(bar, "value", ratio, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	var box := _orders_grid as Control
	if index < 0 or index >= box.get_child_count():
		return box.get_global_rect().get_center()
	return (box.get_child(index).get_node("%Card") as Control).get_global_rect().get_center()


## Заказ пока не сдать — карточка встряхивается.
func shake_order(index: int) -> void:
	var box := _orders_grid as Control
	if index >= 0 and index < box.get_child_count():
		box.get_child(index).shake()


## Карточка заказа «подпрыгивает» — заказ принят.
func punch_order(index: int) -> void:
	var box := _orders_grid as Control
	if index >= 0 and index < box.get_child_count():
		_bounce(box.get_child(index) as Control, 1.12)


## Экранный прямоугольник области поля (в координатах viewport).
func board_rect() -> Rect2:
	var ins := SAFE.insets()
	var side := maxf(ins.x, ins.z) + SCREEN_MARGIN
	var gap := $Safe/Layout.get_theme_constant("separation") as int
	var top: float = $Safe/Layout/Top.get_combined_minimum_size().y + %Queue.custom_minimum_size.y
	var bottom: float = $Safe/Layout/Bottom.get_combined_minimum_size().y + $Safe/Layout/OrderStrip.custom_minimum_size.y
	var reserve := maxf(ins.y + top, ins.w + bottom) + SCREEN_MARGIN + gap * 2
	return get_viewport_rect().grow_individual(-side, -reserve, -side, -reserve)


## Карточки заказов (scenes/ui/order_card.tscn): пересобираются только при
## смене числа слотов, иначе тап терялся бы между нажатием и отпусканием.
## Возвращает список карточек в порядке слотов.
func ensure_order_cards(count: int, on_order: Callable, on_reroll: Callable) -> Array:
	var box := _orders_grid
	box.columns = maxi(1, count)
	if box.get_child_count() != count:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		for index in count:
			var card := ORDER_CARD.instantiate()
			card.name = "Order_%d" % index
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(card)
			card.order_pressed.connect(on_order.bind(index))
			card.reroll_pressed.connect(on_reroll.bind(index))
	return box.get_children()


# ---------------------------------------------------------------- УТИЛИТЫ
func _apply_safe_area() -> void:
	SAFE.apply_margins(%Safe as MarginContainer, SCREEN_MARGIN)
	board_area_changed.emit(board_rect())


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

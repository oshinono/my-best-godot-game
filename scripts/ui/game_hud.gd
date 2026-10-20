class_name GameHUD
extends Control

## Главный экран поверх поля (scenes/ui/game_hud.tscn): значок уровня и плашки
## ресурсов, ряд заказов, строка статуса, область поля, кнопки генераторов,
## нижний ряд кнопок.
##
## Вёрстка — сцена на контейнерах: %Safe (MarginContainer, safe area +
## SCREEN_MARGIN) → VBox [Top, Orders, Status, BoardArea, Generators, Bottom].
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
## Тап по генератору цепочки (кнопки под полем).
signal generator_pressed(chain: StringName)
## Прямоугольник области поля изменился (раскладка, safe area, поворот).
signal board_area_changed(rect: Rect2)

const SAFE := preload("res://scripts/ui/safe_area.gd")
const SCREEN_MARGIN := 16.0
const GENERATOR_H := 64.0
const ORDER_CARD := preload("res://scenes/ui/order_card.tscn")
const ENERGY_ICON := preload("res://assets/ui/theme/icon_energy.png")


func _ready() -> void:
	(%LevelButton as BaseButton).pressed.connect(func() -> void: level_pressed.emit())
	%EnergyBar.plus_pressed.connect(func() -> void: energy_plus_pressed.emit())
	%GemBar.plus_pressed.connect(func() -> void: gems_plus_pressed.emit())
	(%Settings as BaseButton).pressed.connect(func() -> void: settings_pressed.emit())
	(%Menu as BaseButton).pressed.connect(func() -> void: menu_pressed.emit())
	(%Play as BaseButton).pressed.connect(func() -> void: play_pressed.emit())
	for button: BaseButton in [%LevelButton, %Settings, %Menu, %Play]:
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


## Экранный прямоугольник области поля (в координатах viewport).
func board_rect() -> Rect2:
	return (%BoardArea as Control).get_global_rect()


func set_status(text: String) -> void:
	(%Status as Label).text = text


## Карточки заказов (scenes/ui/order_card.tscn): пересобираются только при
## смене числа слотов, иначе тап терялся бы между нажатием и отпусканием.
## Возвращает список карточек в порядке слотов.
func ensure_order_cards(count: int, on_order: Callable, on_reroll: Callable) -> Array:
	var box := %Orders as HBoxContainer
	if box.get_child_count() != count:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		for index in count:
			var card := ORDER_CARD.instantiate()
			box.add_child(card)
			card.order_pressed.connect(on_order.bind(index))
			card.reroll_pressed.connect(on_reroll.bind(index))
	return box.get_children()


## Кнопки генераторов: entries — [{chain, title, cost, enabled}] из game.gd.
func set_generators(entries: Array) -> void:
	var box := %Generators as HBoxContainer
	if box.get_child_count() != entries.size():
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		for entry: Dictionary in entries:
			var button := Button.new()
			button.theme_type_variation = &"GeneratorButton"
			button.custom_minimum_size = Vector2(0, GENERATOR_H)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			box.add_child(button)
			var chain := StringName(String(entry.get("chain", "")))
			button.pressed.connect(func() -> void: generator_pressed.emit(chain))
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var button := box.get_child(i) as Button
		var enabled := bool(entry.get("enabled", false))
		button.text = "%s · %s" % [String(entry.get("title", "")), String(entry.get("cost", ""))]
		button.icon = ENERGY_ICON if enabled else null
		# Закрытый генератор кликабелен: тап показывает, с какого уровня он
		# откроется, поэтому не disabled, а только приглушён.
		button.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.55)


# ---------------------------------------------------------------- УТИЛИТЫ
func _apply_safe_area() -> void:
	SAFE.apply_margins(%Safe as MarginContainer, SCREEN_MARGIN)


## «Пружина» при нажатии: контейнер владеет position/size, поэтому
## анимируем только scale вокруг центра (pivot_offset).
func _bind_press(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _scale_to(b, 0.92))
	b.button_up.connect(func() -> void: _scale_to(b, 1.0))


func _scale_to(node: Control, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * s, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

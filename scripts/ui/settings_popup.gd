extends CanvasLayer

## Настройки прототипа (docs/GDD.md §20, §21): «продать всё поле» для тестов
## тупиков и «сбросить прогресс» (чистый save для плейтеста).
##
## Строится кодом. Логику делают обработчики в game.gd.
## Размеры рассчитаны на портретный viewport 720x1280.

signal sell_all_requested
signal reset_requested
## Техспайк фазы 0 (docs/technspike.md): проверка рекламы, консента и покупок
## на живом устройстве. action: "rewarded" | "interstitial" | "consent" |
## "purchase" | "restore".
signal technospike_action(action: String)
signal closed

var _hint: Label


func _ready() -> void:
	layer = 3
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color("F6E7D8")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -550.0
	panel.offset_bottom = 550.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "⚙ Настройки прототипа", -500)

	# --- Техспайк фазы 0: реклама, консент, покупки (docs/technspike.md) ---
	_tech_button(panel, "🔎 Реклама: rewarded", "rewarded", -392)
	_tech_button(panel, "🎬 Реклама: interstitial", "interstitial", -288)
	_tech_button(panel, "🔒 Консент (UMP/ATT)", "consent", -184)
	_tech_button(panel, "🛒 Купить тестовый SKU", "purchase", -80)
	_tech_button(panel, "♻ Восстановить покупки", "restore", 24)

	# --- Игровые тесты ---
	var sell := _button(panel, "🪙 Продать всё поле", 128)
	sell.pressed.connect(func() -> void: sell_all_requested.emit())

	var reset := _button(panel, "♻ Сбросить прогресс", 232)
	reset.pressed.connect(func() -> void: reset_requested.emit())

	var close_button := _button(panel, "Закрыть", 336)
	close_button.pressed.connect(close)

	# --- Вибрация (GDD §15, docs/haptics.md) ---
	# Звука в прототипе нет: вся обратная связь — тактильная (iOS-плагин
	# HapticsIOS, на Android — Input.vibrate_handheld).
	_toggle(panel, "📳 Вибрация", Haptics.enabled, func(value: bool) -> void: Haptics.set_enabled(value))

	_hint = Label.new()
	_hint.text = "Техспайк: rewarded/interstitial дадут статус, консент — UMP, покупки — тестовый SKU из Config. Сброс удаляет save (поле, монеты, гемы, XP, котов)."
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = 24.0
	_hint.offset_right = -24.0
	_hint.offset_top = 508.0
	_hint.offset_bottom = 548.0
	_hint.add_theme_font_size_override("font_size", 18)
	panel.add_child(_hint)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _title(parent: Node, text: String, top: float) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = top
	label.offset_bottom = top + 80.0
	label.add_theme_font_size_override("font_size", 42)
	parent.add_child(label)


func _button(parent: Node, text: String, top: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -290.0
	button.offset_right = 290.0
	button.offset_top = top
	button.offset_bottom = top + 88.0
	button.add_theme_font_size_override("font_size", 28)
	parent.add_child(button)
	return button


## Тумблер «вкл/выкл» на всю ширину панели: состояние применяет переданный Callable.
## Флаг вибрации живёт в сохранении (см. scripts/autoload/haptics.gd), так что
## переключатель просто читает текущее состояние автолоада Haptics.
func _toggle(parent: Node, label_text: String, value: bool, apply: Callable) -> void:
	var button := Button.new()
	button.text = _toggle_text(label_text, value)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -290.0
	button.offset_right = 290.0
	button.offset_top = 424.0
	button.offset_bottom = 500.0
	button.toggle_mode = true
	button.button_pressed = value
	button.add_theme_font_size_override("font_size", 24)
	button.toggled.connect(func(pressed: bool) -> void:
		apply.call(pressed)
		button.text = _toggle_text(label_text, pressed)
	)
	parent.add_child(button)


func _toggle_text(label_text: String, value: bool) -> String:
	return "%s: %s" % [label_text, "Вкл" if value else "Выкл"]


## Кнопка техспайка: наружу уходит только имя действия.
func _tech_button(parent: Node, text: String, action: String, top: float) -> Button:
	var button := _button(parent, text, top)
	button.pressed.connect(func() -> void: technospike_action.emit(action))
	return button

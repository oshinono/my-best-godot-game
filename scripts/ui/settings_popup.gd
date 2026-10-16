extends CanvasLayer

## Настройки прототипа (docs/GDD.md §20, §21): «продать всё поле» для тестов
## тупиков и «сбросить прогресс» (чистый save для плейтеста).
##
## Строится кодом. Логику делают обработчики в game.gd.

signal sell_all_requested
signal reset_requested
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
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -190.0
	panel.offset_bottom = 190.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "⚙ Настройки прототипа", -150)

	var sell := _button(panel, "🪙 Продать всё поле", -70)
	sell.pressed.connect(func() -> void: sell_all_requested.emit())

	var reset := _button(panel, "♻ Сбросить прогресс", 10)
	reset.pressed.connect(func() -> void: reset_requested.emit())

	var close_button := _button(panel, "Закрыть", 90)
	close_button.pressed.connect(close)

	_hint = Label.new()
	_hint.text = "Сброс удаляет save (поле, монеты, гемы, XP, котов)."
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = 24.0
	_hint.offset_right = -24.0
	_hint.offset_top = 155.0
	_hint.offset_bottom = 195.0
	_hint.add_theme_font_size_override("font_size", 16)
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
	label.offset_bottom = top + 48.0
	label.add_theme_font_size_override("font_size", 26)
	parent.add_child(label)


func _button(parent: Node, text: String, top: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -230.0
	button.offset_right = 230.0
	button.offset_top = top
	button.offset_bottom = top + 58.0
	button.add_theme_font_size_override("font_size", 22)
	parent.add_child(button)
	return button

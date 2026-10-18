extends CanvasLayer

## Тест всех видов вибрации, которые умеет проект (docs/haptics.md).
## Открывается кнопкой «🎛 Тест вибрации» в настройках (scripts/ui/settings_popup.gd).
## Логики здесь нет: каждая кнопка дёргает соответствующий вызов автолоада Haptics
## в обход игры — удобно проверять на живом устройстве.
##
## Полезно помнить: в симуляторе iOS вибрации нет вообще, на Android нативного
## плагина нет и работает запасной Input.vibrate_handheld, а между откликами
## действует тот же троттлинг THROTTLE_MS, что и в игре.
##
## Строится кодом. Размеры рассчитаны на портретный viewport 720x1280.

## Константы автолоада берём через preload, а не через узел: так же сделано
## в scripts/game.gd (см. комментарий про global_script_class_cache.cfg).
const HAPTICS := preload("res://scripts/autoload/haptics.gd")

signal closed

var _status: Label


func _ready() -> void:
	layer = 4
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
	panel.offset_top = -700.0
	panel.offset_bottom = 700.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "🎛 Тест вибрации", -620)

	# --- Два вида отклика: тик выбора и удар одной из пяти сил ---
	_caption(panel, "Отклик", -528)
	_button(panel, "Тик выбора — selection()", -488,
			func() -> void: Haptics.selection())
	_button(panel, "LIGHT — лёгкий удар", -384,
			func() -> void: Haptics.impact(HAPTICS.Strength.LIGHT))
	_button(panel, "MEDIUM — средний удар", -280,
			func() -> void: Haptics.impact(HAPTICS.Strength.MEDIUM))
	_button(panel, "HEAVY — сильный удар", -176,
			func() -> void: Haptics.impact(HAPTICS.Strength.HEAVY))
	_button(panel, "SOFT — глухой удар", -72,
			func() -> void: Haptics.impact(HAPTICS.Strength.SOFT))
	_button(panel, "RIGID — резкий удар", 32,
			func() -> void: Haptics.impact(HAPTICS.Strength.RIGID))

	# --- То, из чего собраны игровые события: повтор и прогрев ---
	_caption(panel, "Повторы", 128)
	_button(panel, "SOFT ×2 — как ошибка", 168,
			func() -> void: Haptics.impact(HAPTICS.Strength.SOFT, 2))
	_button(panel, "HEAVY ×3 — как сундук", 272,
			func() -> void: Haptics.impact(HAPTICS.Strength.HEAVY, 3))
	_button(panel, "Прогрев — prepare()", 376,
			func() -> void: Haptics.prepare())

	_status = _label(panel, 480, 92)
	_button(panel, "Закрыть", 584, close)


func open() -> void:
	_refresh_status()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


## Стенд сам говорит, куда он попал: есть ли нативный синглтон и включён ли тумблер.
func _refresh_status() -> void:
	var native := "есть" if Engine.has_singleton(HAPTICS.SINGLETON) else "нет"
	_status.text = "Синглтон %s (нативный плагин): %s · вибрация: %s\nТроттлинг %d мс. В симуляторе iOS вибрации нет вовсе." % [
		HAPTICS.SINGLETON,
		native,
		"Вкл" if Haptics.enabled else "Выкл",
		HAPTICS.THROTTLE_MS,
	]


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


func _caption(parent: Node, text: String, top: float) -> void:
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
	label.offset_bottom = top + 32.0
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)


func _label(parent: Node, top: float, height: float) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = top
	label.offset_bottom = top + height
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


## Кнопка на всю ширину панели, нажатие отдаётся в переданный Callable.
func _button(parent: Node, text: String, top: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -290.0
	button.offset_right = 290.0
	button.offset_top = top
	button.offset_bottom = top + 84.0
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

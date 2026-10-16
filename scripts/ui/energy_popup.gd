extends CanvasLayer

## Экран «энергия закончилась» (docs/GDD.md §6, §9): таймер до следующей
## единицы + rewarded-кнопка (лимит в сутки — из Config) + закрыть.
##
## Строится кодом, сцена не нужна. Рекламу дёргает не этот экран, а game.gd:
## он слушает signal rewarded_requested и зовёт Ads.show_rewarded.
## Размеры рассчитаны на портретный viewport 720x1280.

signal rewarded_requested
signal closed

var _title: Label
var _timer_label: Label
var _reward_button: Button
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
	panel.offset_top = -300.0
	panel.offset_bottom = 300.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title = _label(panel, "⚡ Энергия закончилась", -250, 44)
	_timer_label = _label(panel, "", -170, 36)
	_hint = _label(panel, "", -90, 26)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_reward_button = _button(panel, "⚡ +15 за рекламу", 50)
	_reward_button.pressed.connect(func() -> void: rewarded_requested.emit())

	var close_button := _button(panel, "Закрыть", 170)
	close_button.pressed.connect(close)

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	ticker.timeout.connect(_refresh)
	add_child(ticker)

	_refresh()


# --- API ---------------------------------------------------------------------

func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


## Состояние rewarded-кнопки задаёт game.gd (лимит в сутки из Config).
func set_reward_state(available: bool, text: String, hint: String) -> void:
	if _reward_button != null:
		_reward_button.disabled = not available
		_reward_button.text = text
	if _hint != null:
		_hint.text = hint


# --- Внутреннее --------------------------------------------------------------

func _refresh() -> void:
	if _timer_label == null:
		return
	var seconds := Energy.seconds_to_next()
	if Energy.is_full():
		_timer_label.text = "Энергия полная: %d/%d" % [Energy.current(), Energy.maximum]
		return
	_timer_label.text = "⚡ %d/%d · до +%d через %d с" % [
		Energy.current(),
		Energy.maximum,
		int(Config.get_value("energy_regen_amount")),
		seconds,
	]


func _label(parent: Node, text: String, top: float, font_size: int) -> Label:
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
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


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
	button.offset_bottom = top + 96.0
	button.add_theme_font_size_override("font_size", 34)
	parent.add_child(button)
	return button

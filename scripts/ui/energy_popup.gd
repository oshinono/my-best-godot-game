extends CanvasLayer

## Экран «энергия закончилась» (docs/GDD.md §6, §9): таймер до следующей
## единицы + rewarded-кнопка (лимит в сутки — из Config) + закрыть.
##
## Строится кодом, сцена не нужна. Рекламу дёргает не этот экран, а game.gd:
## он слушает signal rewarded_requested и зовёт Ads.show_rewarded.
##
## Раскладка — PanelContainer + VBoxContainer, а не абсолютные координаты:
## высота панели считается по контенту, а отступы от рамки 9-slice даёт
## `Icons.skin_panel` (content_margin = кромка popup_panel + 8). Из-за этого
## содержимое больше не налезает на рамку арта и не требует ручных позиций.
##
## Эмодзи в текстах нет: стандартный шрифт Godot рисует их квадратами,
## вместо ⚡ на кнопке стоит PNG-иконка энергии (оверлей `Icons.icon_label`),
## а сами кнопки — чистые спрайты `Icons.plain_button` (без StyleBox).
##
## Размеры рассчитаны на портретный viewport 720x1280.

signal rewarded_requested
signal closed

const PANEL_WIDTH := 680.0

var _title: Label
var _timer_label: Label
var _reward_button: TextureButton
var _reward_value: Label
var _hint: Label


func _ready() -> void:
	layer = 3
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not Icons.skin_panel(panel, "popup_panel"):
		panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_title = _label(box, "Энергия закончилась", 34)
	_timer_label = _label(box, "", 28)
	_hint = _label(box, "", 18)

	_reward_button = _button(box, "", "popup_primary_button", 28)
	_reward_button.custom_minimum_size = Vector2(0, 84)
	_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Подпись с PNG-иконкой энергии — оверлеем: у TextureButton нет ни text, ни icon.
	var reward_overlay := CenterContainer.new()
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_button.add_child(reward_overlay)
	reward_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var reward_line := Icons.icon_label("energy", "+15 энергии за рекламу", 32.0,
		Icons.DEFAULT_TINT, 28)
	reward_overlay.add_child(reward_line)
	_reward_value = reward_line.get_child(1) as Label
	_reward_button.pressed.connect(func() -> void: rewarded_requested.emit())

	var close_button := _button(box, "Закрыть", "popup_secondary_button", 26)
	close_button.custom_minimum_size = Vector2(250, 84)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	ticker.timeout.connect(_refresh)
	add_child(ticker)

	_refresh()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


## Текст/доступность кнопки рекламы задаёт game.gd (кэп на сутки — из Config).
func set_reward_state(available: bool, text: String, hint: String) -> void:
	if _reward_button == null:
		return
	_reward_button.disabled = not available
	if _reward_value != null:
		_reward_value.text = text
	_hint.text = hint


func _refresh() -> void:
	if _timer_label == null:
		return
	if Energy.is_full():
		_timer_label.text = "Энергия полная: %d/%d" % [Energy.current(), Energy.maximum]
		return
	var seconds := maxi(0, Energy.seconds_to_next())
	_timer_label.text = "%d/%d · до +%d через %d:%02d" % [
		Energy.current(), Energy.maximum,
		int(Config.get_value("energy_regen_amount")),
		seconds / 60.0, seconds % 60,
	]


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("4A3A2E"))
	parent.add_child(label)
	return label


## Кнопка на чистом спрайте popup_*.png + подпись поверх (без StyleBox).
func _button(parent: Node, text: String, base := "popup_secondary_button",
		font_size := 26) -> TextureButton:
	var button := Icons.plain_button(base, Vector2(250, 84))
	if text != "":
		Icons.button_text(button, text, font_size)
	parent.add_child(button)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("F6E7D8")
	style.set_corner_radius_all(28)
	style.set_content_margin_all(56.0)
	return style

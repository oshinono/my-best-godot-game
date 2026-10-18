extends CanvasLayer

## Попап «Генераторы» (docs/GDD.md §5): тап по цепочке ставит предмет на поле.
## Заменяет нижнюю полосу генераторов из старого HUD — открывается кнопкой ▶.
##
## Содержимое задаёт game.gd через refresh(cost, entries): стоимости и условия
## открытия живут там же, попап только рисует карточки.
## Строится кодом, размеры рассчитаны на портретный viewport 720x1280.

signal generator_requested(chain: StringName)
signal closed

var _list: VBoxContainer
var _cost: int = 0
var _entries: Array = []


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
	panel.offset_top = -360.0
	panel.offset_bottom = 360.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "🔧 Генераторы", -310)

	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", 14)
	_list.anchor_left = 0.5
	_list.anchor_right = 0.5
	_list.anchor_top = 0.5
	_list.anchor_bottom = 0.5
	_list.offset_left = -280.0
	_list.offset_right = 280.0
	_list.offset_top = -200.0
	_list.offset_bottom = 120.0
	panel.add_child(_list)

	var hint := Label.new()
	hint.text = "Тап — предмет на поле. Цена указана в энергии."
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.5
	hint.anchor_bottom = 0.5
	hint.offset_left = 24.0
	hint.offset_right = -24.0
	hint.offset_top = 150.0
	hint.offset_bottom = 230.0
	hint.add_theme_font_size_override("font_size", 20)
	panel.add_child(hint)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.anchor_left = 0.5
	close_button.anchor_right = 0.5
	close_button.anchor_top = 0.5
	close_button.anchor_bottom = 0.5
	close_button.offset_left = -290.0
	close_button.offset_right = 290.0
	close_button.offset_top = 250.0
	close_button.offset_bottom = 338.0
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	_rebuild()


# --- Публичное API -----------------------------------------------------------

## Открыть со свежими данными (их готовит game.gd).
func open(cost: int, entries: Array) -> void:
	refresh(cost, entries)
	visible = true


## Обновить список, не открывая попап (состояние могло измениться).
func refresh(cost: int, entries: Array) -> void:
	_cost = cost
	_entries = entries
	if _list != null:
		_rebuild()


func close() -> void:
	visible = false
	closed.emit()


# --- Сборка ------------------------------------------------------------------

## entries: [{chain, text, icon, enabled}]
func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	for entry in _entries:
		var data: Dictionary = entry
		var button := Button.new()
		button.custom_minimum_size = Vector2(560, 88)
		button.add_theme_font_size_override("font_size", 28)
		button.text = String(data.get("text", ""))
		button.disabled = not bool(data.get("enabled", true))
		var icon := String(data.get("icon", ""))
		if icon != "":
			Icons.decorate(button, icon, 30.0)
		Icons.flat(button)
		var chain: StringName = data.get("chain", &"")
		button.pressed.connect(func() -> void:
			generator_requested.emit(chain)
			close()
		)
		_list.add_child(button)


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

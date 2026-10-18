class_name IconChip
extends PanelContainer

## Чип шапки: фон-панель, внутри «иконка + число» вместо прежнего эмодзи в тексте
## (docs/ui-icons.md). Свойство `text` пишет во внутренний Label, поэтому вызовы
## вида `chip.text = "%d" % value` работают как раньше.

var _icon: TextureRect
var _value: Label
var _text: String = ""

var text: String:
	get:
		return _text
	set(value):
		_text = value
		if _value != null:
			_value.text = value


func setup(icon_id: String, font_size: int = 28, tint: Color = Icons.DEFAULT_TINT) -> IconChip:
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.2, 0.15, 0.13)
	style.set_corner_radius_all(18)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_icon = Icons.rect(icon_id, Icons.SIZES["chip"], tint)
	row.add_child(_icon)

	_value = Label.new()
	_value.text = _text
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.add_theme_font_size_override("font_size", font_size)
	_value.add_theme_color_override("font_color", tint)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_value)
	return self

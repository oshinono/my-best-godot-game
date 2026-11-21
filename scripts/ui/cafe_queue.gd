extends HBoxContainer

## Витрина читает очередь из game.gd, не создаёт гостей и не меняет баланс.
signal chooser_requested(active: String, cats: Array)
signal cafe_pressed

const ART := preload("res://scripts/data/art.gd")
const DATA := preload("res://scripts/data/meta.gd")
var _barista: TextureButton
var _cafe_button: TextureButton
var _guests: HBoxContainer
var _active := ""
var _cats: Array = []

func _ready() -> void:
	custom_minimum_size.y = 104
	add_theme_constant_override("separation", 12)
	_barista = TextureButton.new()
	_barista.custom_minimum_size = Vector2(76, 76)
	_barista.texture_normal = preload("res://assets/ui/theme/barista_slot.png")
	_barista.texture_pressed = _barista.texture_normal
	_barista.texture_hover = _barista.texture_normal
	_barista.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_barista.ignore_texture_size = true
	_barista.tooltip_text = "Выбрать бариста"
	add_child(_barista)
	_barista.pressed.connect(func() -> void: chooser_requested.emit(_active, _cats))
	_guests = HBoxContainer.new()
	_guests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guests.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_guests)
	_cafe_button = TextureButton.new()
	_cafe_button.custom_minimum_size = Vector2(64, 64)
	_cafe_button.texture_normal = preload("res://assets/ui/theme/shop.png")
	_cafe_button.texture_pressed = _cafe_button.texture_normal
	_cafe_button.texture_hover = _cafe_button.texture_normal
	_cafe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_cafe_button.ignore_texture_size = true
	_cafe_button.tooltip_text = "Открыть кофейню"
	_cafe_button.pressed.connect(func() -> void: cafe_pressed.emit())
	add_child(_cafe_button)

func refresh(orders: Array, barista_id: String, cats: Array) -> void:
	var barista_portrait := ART.cat_texture(barista_id)
	_barista.texture_normal = barista_portrait
	_barista.texture_pressed = barista_portrait
	_barista.texture_hover = barista_portrait
	_barista.texture_focused = barista_portrait
	_barista.tooltip_text = TranslationServer.translate("%s: %s — выбрать бариста") % [tr(String(DATA.cat(barista_id).get("name", "Бариста"))),
		tr(DATA.PERK_TEXT.get(DATA.barista_perk(barista_id), "Без перка"))]
	_cats = cats
	_active = barista_id
	for child in _guests.get_children():
		_guests.remove_child(child)
		child.queue_free()
	_guests.add_theme_constant_override("separation", 8)
	for order: Dictionary in orders:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 52
		_guests.add_child(column)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(48, 76)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = ART.cat_texture(String(order.get("cat_id", "")))
		portrait.tooltip_text = String(DATA.cat(String(order.get("cat_id", ""))).get("name", "Гость"))
		column.add_child(portrait)
		var patience := ProgressBar.new()
		patience.custom_minimum_size.y = 8
		patience.show_percentage = false
		patience.max_value = maxf(1.0, float(order.get("patience_sec", 90.0)))
		patience.value = maxf(0.0, patience.max_value - float(order.get("elapsed", 0.0)))
		column.add_child(patience)

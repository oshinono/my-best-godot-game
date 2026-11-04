extends HBoxContainer

## Витрина читает очередь из game.gd, не создаёт гостей и не меняет баланс.
signal barista_selected(cat_id: String)
signal cafe_pressed

const ART := preload("res://scripts/data/art.gd")
const DATA := preload("res://scripts/data/meta.gd")
var _barista: Button
var _guests: HBoxContainer
var _chooser: PopupMenu
var _cats: Array = []

func _ready() -> void:
	custom_minimum_size.y = 104
	add_theme_constant_override("separation", 12)
	_barista = Button.new()
	_barista.custom_minimum_size = Vector2(140, 96)
	_barista.expand_icon = true
	_barista.add_theme_constant_override("icon_max_width", 64)
	_barista.text = "Бариста"
	_barista.tooltip_text = "Выбрать бариста"
	add_child(_barista)
	_chooser = PopupMenu.new()
	add_child(_chooser)
	_barista.pressed.connect(func() -> void: _chooser.popup_centered())
	_chooser.id_pressed.connect(func(index: int) -> void:
		if index >= 0 and index < _cats.size():
			barista_selected.emit(String(_cats[index])))
	_guests = HBoxContainer.new()
	_guests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_guests)
	var cafe := Button.new()
	cafe.text = "Кафе"
	cafe.icon = preload("res://assets/ui/theme/shop.png")
	cafe.expand_icon = true
	cafe.add_theme_constant_override("icon_max_width", 48)
	cafe.tooltip_text = "Открыть расстановку мебели"
	cafe.pressed.connect(func() -> void: cafe_pressed.emit())
	add_child(cafe)

func refresh(orders: Array, barista_id: String, cats: Array) -> void:
	_barista.icon = ART.cat_texture(barista_id)
	_barista.tooltip_text = "%s: %s" % [String(DATA.cat(barista_id).get("name", "Бариста")),
		DATA.PERK_TEXT.get(DATA.barista_perk(barista_id), "Без перка")]
	_cats = cats
	_chooser.clear()
	for i in cats.size():
		var id := String(cats[i])
		_chooser.add_icon_item(ART.cat_texture(id), String(DATA.cat(id).get("name", id)), i)
		_chooser.set_item_icon_max_width(i, 48)
	for child in _guests.get_children():
		_guests.remove_child(child)
		child.queue_free()
	for order: Dictionary in orders:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

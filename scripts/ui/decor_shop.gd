extends "res://scripts/ui/popup_base.gd"

## Магазин мебели (scenes/ui/decor_shop.tscn): весь ещё не купленный декор
## из meta.gd DECOR, дешёвый сверху. Покупка — только за монеты. Сам магазин
## ничего не покупает: шлёт buy_requested, а game.gd зовёт Meta.buy_decor,
## показывает тост и дёргает refresh().

signal buy_requested(decor_id: String)

const DATA := preload("res://scripts/data/meta.gd")
const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
## Слот арта ListCard: 21..73 по X, контент начинается с 92 (см. тему).
const SLOT_LEFT := 21.0 - 92.0
const SLOT_RIGHT := 73.0 - 92.0
const PLACEHOLDER_SIZE := 48

@onready var _list: VBoxContainer = %List

## Заглушки-ромбы по id предмета: рисуются один раз.
var _placeholder_icons: Dictionary = {}


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)
	# Монеты меняются и при открытом магазине (заказы, покупка) — кнопки
	# «хватает / не хватает» пересчитываем сразу.
	Wallet.coins_changed.connect(_on_coins_changed)


func open() -> void:
	refresh()
	super()


## Пересобирает список из Meta/Wallet: не купленное, по цене по возрастанию.
func refresh() -> void:
	var coins := Wallet.coins()
	(%Coins as Label).text = str(coins)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var items: Array = []
	for item: Dictionary in DATA.DECOR:
		if not Meta.owns_decor(String(item.get("id", ""))):
			items.append(item)
	items.sort_custom(_cheaper_first)

	if items.is_empty():
		var all_done := Label.new()
		all_done.theme_type_variation = &"BodyLabel"
		all_done.text = "Вся мебель куплена"
		all_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(all_done)
	for item: Dictionary in items:
		_list.add_child(_decor_card(item, coins))
	if visible:
		_relayout.call_deferred()


## Дешёвое сверху; при равной цене — по имени, чтобы порядок не прыгал.
func _cheaper_first(a: Dictionary, b: Dictionary) -> bool:
	var ca := int(a.get("cost", 0))
	var cb := int(b.get("cost", 0))
	if ca != cb:
		return ca < cb
	return String(a.get("name", "")) < String(b.get("name", ""))


func _on_coins_changed(_value: int) -> void:
	if visible:
		refresh()


## Карточка предмета на арте ListCard: в слоте — S-ракурс (или ромб-заглушка).
func _decor_card(item: Dictionary, coins: int) -> Control:
	var decor_id := String(item.get("id", ""))
	var cost := int(item.get("cost", 0))

	var card := PanelContainer.new()
	card.theme_type_variation = &"ListCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Арт декора крупный — ужат до слота, с мипмапами без ряби.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.texture = _decor_texture(decor_id)
	holder.add_child(icon)
	icon.anchor_bottom = 1.0
	icon.offset_left = SLOT_LEFT
	icon.offset_right = SLOT_RIGHT
	icon.offset_top = -4.0
	icon.offset_bottom = 4.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var title := Label.new()
	title.theme_type_variation = &"BodyLabel"
	title.text = String(item.get("name", decor_id))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"HintLabel"
	sub.text = "%s · %d×%d · +%d XP" % [
		String(item.get("room", "")),
		int(item.get("w", 1)), int(item.get("h", 1)),
		int(item.get("xp", 0)),
	]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(sub)
	var affordable := coins >= cost
	if not affordable:
		var missing := Label.new()
		missing.theme_type_variation = &"CaptionLabel"
		missing.text = "Не хватает %d" % (cost - coins)
		info.add_child(missing)

	var buy := Button.new()
	buy.theme_type_variation = &"PrimaryButton"
	buy.custom_minimum_size = Vector2(170, 76)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 22)
	buy.text = str(cost)
	buy.icon = COIN_ICON
	buy.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy.expand_icon = false
	buy.disabled = not affordable
	buy.pressed.connect(_on_buy_pressed.bind(decor_id))
	row.add_child(buy)
	return card


func _on_buy_pressed(decor_id: String) -> void:
	Haptics.selection()
	buy_requested.emit(decor_id)


func _decor_texture(decor_id: String) -> Texture2D:
	var path: String = DATA.decor_sprite(decor_id, 0)
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	return _placeholder_icon(decor_id)


## Заглушка: ромб цвета предмета, как у чипов в cafe_view.gd.
func _placeholder_icon(decor_id: String) -> Texture2D:
	if _placeholder_icons.has(decor_id):
		return _placeholder_icons[decor_id]
	var size := PLACEHOLDER_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var hue := float(abs(decor_id.hash()) % 360) / 360.0
	var color := Color.from_hsv(hue, 0.28, 0.92)
	var edge := color.darkened(0.25)
	for y in size:
		for x in size:
			# Ромб 2:1, как тайл изо-сетки.
			var d := absf(x - size * 0.5) / (size * 0.5) + absf(y - size * 0.5) / (size * 0.27)
			if d <= 1.0:
				img.set_pixel(x, y, edge if d > 0.86 else color)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_icons[decor_id] = tex
	return tex

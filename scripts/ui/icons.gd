class_name Icons
extends RefCounted

## Иконки интерфейса — только PNG-арт (SVG в проекте больше нет).
##
## Логические id (`coin`, `energy`, `plus`, …) маппятся на файлы растрового
## арта через `ICON_ART`; см. `ART_DIRS` и `ART`. Файлы — из листа спрайтов
## `assets/ui/**` (размеры в 4x от проектных, делим на `ART_SCALE`).
##
## Использование:
##   button.icon = Icons.texture("coin")
##   Icons.decorate(button, "coin", 40.0)
##   var chip := Icons.icon_label("coin", "12", 22.0)

## Тёплый коричневый по умолчанию: им же подкрашивается арт там, где нужно.
## Базовый цвет иконок: тот же коричневый, что у текста интерфейса.
const DEFAULT_TINT := Color("4A3A2E")
const SIZES := {
	"chip": 32.0,
	"button": 36.0,
	"small": 22.0,
}
## Растровый арт интерфейса: PNG-экспорты из листа спрайтов (разложены по
## папкам ниже). Размеры в файлах — 4x от проектных (720x1280), поэтому делим
## на ART_SCALE и дожимаем в коде. Поиск идёт по папкам по порядку — файл
## ищется в первой, где он есть.
const ART_DIRS := [
	"res://assets/ui/hud/",
	"res://assets/ui/buttons/",
	"res://assets/ui/panels/",
	"res://assets/ui/cafe/",
]
const ART_SCALE := 4.0
## Проектные размеры (px, база 720x1280) — и одновременно кромка 9-slice.
const ART := {
	"bar_bg": Vector2(225, 45),
	"bar_bg_short": Vector2(225, 45),
	"btn_blue": Vector2(96, 96),
	"btn_cards": Vector2(46, 44),
	"btn_play": Vector2(144, 126),
	"cafe_buy_button": Vector2(250, 84),
	"cafe_coin_counter": Vector2(225, 45),
	"cafe_product_card": Vector2(185, 250),
	"cafe_top_bar": Vector2(680, 84),
	"icon_coin": Vector2(69, 69),
	"icon_coin_main": Vector2(69, 69),
	"icon_energy": Vector2(69, 69),
	"icon_energy_main": Vector2(69, 69),
	"icon_gem": Vector2(69, 69),
	"icon_gem_main": Vector2(69, 69),
	"icon_inventory": Vector2(96, 96),
	"icon_menu": Vector2(96, 96),
	"icon_play": Vector2(76, 37),
	"icon_settings": Vector2(96, 96),
	"item_action_panel": Vector2(520, 300),
	"level_badge": Vector2(96, 96),
	"level_badge_main": Vector2(96, 96),
	"notif_dot": Vector2(33, 33),
	"order_card": Vector2(580, 112),
	"plus_badge": Vector2(33, 33),
	"popup_booster_card": Vector2(185, 80),
	"popup_close": Vector2(111, 31),
	"popup_danger_button": Vector2(250, 84),
	"popup_list_card": Vector2(580, 84),
	"popup_panel": Vector2(680, 720),
	"popup_primary_button": Vector2(250, 84),
	"popup_secondary_button": Vector2(250, 84),
	"shop": Vector2(81, 81),
	"tab_active": Vector2(170, 84),
	"tab_inactive": Vector2(170, 84),
}
## Кромка 9-slice по имени арта (проектные px): углы не растягиваются.
const ART_MARGIN := {
	"bar_bg": 22.0,
	"bar_bg_short": 22.0,
	"cafe_buy_button": 26.0,
	"cafe_coin_counter": 22.0,
	"cafe_product_card": 26.0,
	"cafe_top_bar": 28.0,
	"item_action_panel": 40.0,
	"order_card": 30.0,
	"popup_booster_card": 26.0,
	"popup_close": 14.0,
	"popup_danger_button": 26.0,
	"popup_list_card": 30.0,
	"popup_panel": 48.0,
	"popup_primary_button": 26.0,
	"popup_secondary_button": 26.0,
	"tab_active": 26.0,
	"tab_inactive": 26.0,
}
## Логический id иконки → файл арта (без папки и расширения).
const ICON_ART := {
	"coin": "icon_coin",
	"gem": "icon_gem",
	"energy": "icon_energy",
	"plus": "plus_badge",
	"cart": "shop",
	"gear": "icon_settings",
	"settings": "icon_settings",
	"menu": "icon_menu",
	"play": "btn_play",
}
## Арт, который реально зовёт интерфейс: selftest проверяет, что все файлы на
## месте. Добавили новый — допишите имя сюда.
const USED_ART := [
	"bar_bg", "btn_blue", "btn_play", "cafe_buy_button", "cafe_coin_counter",
	"cafe_product_card", "cafe_top_bar", "icon_coin_main", "icon_energy_main",
	"icon_gem_main", "icon_menu", "icon_settings", "item_action_panel",
	"level_badge_main", "notif_dot", "order_card", "plus_badge", "popup_close",
	"popup_danger_button", "popup_list_card", "popup_panel",
	"popup_primary_button", "popup_secondary_button", "shop",
	"tab_active", "tab_inactive",
]

static var _art_cache: Dictionary = {}


## Текстура иконки по логическому id или null, если PNG для него нет.
static func texture(id: String, size: float = SIZES["chip"]) -> Texture2D:
	var base: String = String(ICON_ART.get(id, ""))
	if base == "":
		return null
	return art(base, Vector2(size, size))


static func has(id: String) -> bool:
	var base: String = String(ICON_ART.get(id, ""))
	return base != "" and art_path(base) != ""


## Готовый прямоугольник с иконкой: размер задан, пропорции сохранены.
## Цвет по умолчанию белый (не тонируем): цветной арт (монета, гем, энергия)
## от коричневого `DEFAULT_TINT` становится грязным. Тёмный tint — только для
## одноцветных иконок, передавайте его явно.
static func rect(id: String, size: float = SIZES["small"], color: Color = Color.WHITE) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(id, size)
	node.custom_minimum_size = Vector2(size, size)
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.modulate = color
	node.visible = node.texture != null
	return node


## Иконка на кнопке: сама кнопка получает `icon`, текст остаётся текстом.
## Нет PNG для id — кнопка остаётся с одним текстом.
static func decorate(button: Button, id: String, size: float = SIZES["button"], color: Color = Color.WHITE) -> void:
	var tex := texture(id, size)
	if tex == null:
		return
	button.icon = tex
	button.add_theme_constant_override("icon_max_width", int(size))
	button.add_theme_color_override("icon_normal_color", color)
	button.add_theme_color_override("icon_hover_color", color)
	button.add_theme_color_override("icon_pressed_color", color)
	button.add_theme_color_override("icon_disabled_color", Color(color, 0.45))
	button.add_theme_constant_override("h_separation", 10)


## Плоская кнопка: фон убран совсем, остаются только иконка и текст
## (тёмный тёплый цвет вместо светлого шрифта темы Godot — иначе текст
## пропал бы на бежевом фоне). При нажатии — мягкая подсветка, поэтому
## у toggle-кнопок выбранное состояние всё ещё видно.
static func flat(
	button: Button,
	tint: Color = Color(0.78, 0.45, 0.16, 0.22),
	pad: Vector2 = Vector2(12.0, 8.0)
) -> void:
	button.add_theme_stylebox_override("normal", _flat_box(Color(0, 0, 0, 0), pad))
	button.add_theme_stylebox_override("hover", _flat_box(Color(1, 1, 1, 0.10), pad))
	button.add_theme_stylebox_override("pressed", _flat_box(tint, pad))
	button.add_theme_stylebox_override("disabled", _flat_box(Color(0, 0, 0, 0.05), pad))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, DEFAULT_TINT)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_disabled_color", Color(DEFAULT_TINT, 0.45))


## Прямоугольник без рамок: используется как «состояние» плоской кнопки.
static func _flat_box(bg: Color, pad: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	return box


## Кнопка на чистом PNG-спрайте: TextureButton без StyleBox, 9-slice и
## тональных состояний — рисуется ровно исходный файл, вписанный в `size_px`
## только пропорционально (ни одна ось не растягивается отдельно).
static func plain_button(base: String, size_px: Vector2) -> TextureButton:
	var button := TextureButton.new()
	var tex := art(base, size_px)
	button.texture_normal = tex
	# Текстура для disabled: иначе в неактивном состоянии кнопка пустая.
	button.texture_disabled = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = size_px
	return button


## Подпись поверх спрайт-кнопки: по центру всей кнопки, тапы пропускает.
static func button_text(button: Control, text: String, font_size: int,
		color: Color = DEFAULT_TINT) -> Label:
	var label := Label.new()
	label.name = "__label"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


## «Иконка + текст» в ряд: для строк, где раньше эмодзи стоял прямо в тексте.
## Возвращает HBoxContainer с полем `value` — Label, куда пишется текст.
## `color` красит ТЕКСТ, иконка всегда белая (арт цветной сам по себе).
static func icon_label(
	icon_id: String,
	text: String = "",
	size: float = SIZES["small"],
	color: Color = DEFAULT_TINT,
	font_size: int = 22
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rect(icon_id, size, Color.WHITE))

	var value := Label.new()
	value.text = text
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	return row


## Ряд из `count` звёзд (редкость кота): PNG-звезды нет, рисуем «★» текстом.
static func stars(count: int, size: float = SIZES["small"], color: Color = DEFAULT_TINT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in maxi(count, 0):
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", int(round(size * 1.2)))
		star.add_theme_color_override("font_color", color)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(star)
	return row


## Путь к PNG арта: первая папка из `ART_DIRS`, где файл реально лежит.
## Пустая строка — файла нет нигде. `.png` в имени можно не писать.
static func art_path(base_name: String) -> String:
	var stem := base_name.trim_suffix(".png")
	for dir in ART_DIRS:
		var path: String = dir + stem + ".png"
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


## Пропорциональная усадка: вписывает `src` в `box`, сохраняя аспект.
## Растягивать арт по одной оси нельзя — верстка «поедет».
static func fit(src: Vector2, box: Vector2) -> Vector2:
	if src.x <= 0.0 or src.y <= 0.0 or box.x <= 0.0 or box.y <= 0.0:
		return box
	var k: float = minf(box.x / src.x, box.y / src.y)
	return Vector2(maxf(1.0, floorf(src.x * k)), maxf(1.0, floorf(src.y * k)))


## Растровая текстура арта: `<base>.png` из `ART_DIRS`, ужатая до проектного
## размера (или до `size_px`, если он задан). null — файла нет, рисуем запасной вариант.
static func art(base: String, size_px := Vector2.ZERO) -> Texture2D:
	if base == "":
		return null
	var target: Vector2 = size_px if size_px != Vector2.ZERO else ART.get(base, Vector2.ZERO)
	var key := "%s@%dx%d" % [base, int(target.x), int(target.y)]
	if _art_cache.has(key):
		return _art_cache[key]

	var path := art_path(base)
	var img := _load_png(path)
	if img == null:
		_art_cache[key] = null
		push_warning("[Icons] нет арта %s" % path)
		return null
	var src := Vector2(img.get_size())
	if target.x > 0.0 and target.y > 0.0 and src != target:
		var fitted := fit(src, target)
		if fitted != src:
			img.resize(int(fitted.x), int(fitted.y), Image.INTERPOLATE_LANCZOS)

	var tex := ImageTexture.create_from_image(img)
	_art_cache[key] = tex
	return tex


## Иконка арта в готовом прямоугольнике (пропорции сохранены).
static func art_rect(base: String, size: float, color: Color = Color.WHITE) -> TextureRect:
	var node := TextureRect.new()
	node.texture = art(base, Vector2(size, size))
	node.custom_minimum_size = Vector2(size, size)
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.modulate = color
	return node


## StyleBoxTexture с 9-slice по имени арта (кромка — из ART_MARGIN, если не задана).
static func art_box(base: String, margin: float = -1.0, size_px := Vector2.ZERO) -> StyleBoxTexture:
	var tex := art(base, size_px)
	if tex == null:
		return null
	var edge := margin if margin >= 0.0 else float(ART_MARGIN.get(base, 24.0))
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(edge)
	return box


## Кромка 9-slice по имени арта: углы не искажаются никогда, тянется только
## прямая середина. Кнопки/строки делаем по пропорциям арта (см. ART), поэтому
## растяжение середины минимально.
static func edge_of(base: String, margin: float) -> float:
	return margin if margin >= 0.0 else float(ART_MARGIN.get(base, 24.0))


## Кнопка на арте: 9-slice фон во всех состояниях + тёплый цвет текста.
static func skin_button(button: Button, base: String, margin: float = -1.0,
		size_px := Vector2.ZERO) -> bool:
	var tex := art(base, size_px)
	if tex == null:
		return false
	var edge := edge_of(base, margin)
	var pad := Vector2(12.0, 8.0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.set_texture_margin_all(edge)
		box.content_margin_left = pad.x
		box.content_margin_right = pad.x
		box.content_margin_top = pad.y
		box.content_margin_bottom = pad.y
		if state == "hover":
			box.modulate_color = Color(1.06, 1.06, 1.06)
		elif state == "pressed":
			box.modulate_color = Color(0.90, 0.90, 0.90)
		elif state == "disabled":
			box.modulate_color = Color(1, 1, 1, 0.5)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, DEFAULT_TINT)
	button.add_theme_color_override("font_disabled_color", Color(DEFAULT_TINT, 0.45))
	# Фиксированный размер кнопки не должен раздуваться текстом: без clip_text
	# минимальная ширина кнопки = ширина текста, и кнопки наезжают друг на друга.
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return true


## Кнопка на арте по одной ширине: высота берётся из пропорций арта
## (`aspect_height`), поэтому 9-slice не сплющивается.
static func skin_button_w(button: Button, base: String, width: float) -> bool:
	button.custom_minimum_size = Vector2(width, aspect_height(base, width))
	return skin_button(button, base)


## Панель на арте: 9-slice фон (Panel и PanelContainer — одно и то же свойство).
## Внутренние отступы = кромка + 8: PanelContainer сам отодвигает детей от рамки
## (у popup_panel кромка 48 — контент на 24 просто лежал на рамке).
static func skin_panel(panel: Control, base: String, margin: float = -1.0,
		size_px := Vector2.ZERO) -> bool:
	var tex := art(base, size_px)
	if tex == null:
		return false
	var inner := edge_of(base, margin) + 8.0
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(edge_of(base, margin))
	box.content_margin_left = inner
	box.content_margin_right = inner
	box.content_margin_top = inner
	box.content_margin_bottom = inner
	panel.add_theme_stylebox_override("panel", box)
	return true


## Пропорциональный размер для кнопки/строки: ширина задаётся, высота — из арта.
## Так подложка занимает ровно свой прямоугольник и верстка не «плывёт».
static func aspect_height(base: String, width: float) -> float:
	var art_size: Vector2 = ART.get(base, Vector2.ZERO)
	if art_size.x <= 0.0 or art_size.y <= 0.0:
		return width
	return roundf(width * art_size.y / art_size.x)


## Чтение PNG без импорта Godot: сначала как ресурс, иначе напрямую из файла.
static func _load_png(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			img = (res as Texture2D).get_image()
	if img == null and FileAccess.file_exists(path):
		var raw := Image.new()
		if raw.load(path) == OK:
			img = raw
	if img == null or img.is_empty():
		return null
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	return img


## Все id, для которых есть файл (для самопроверки).
static func available() -> Array:
	var ids: Array = []
	for base in ART:
		if art_path(base) != "":
			ids.append(base)
	ids.sort()
	return ids

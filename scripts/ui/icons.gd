class_name Icons
extends RefCounted

## Иконки интерфейса вместо эмодзи (GDD §20, docs/ui-icons.md).
##
## Файлы — `res://assets/ui/icons/<id>.svg`, белой заливкой: цвет задаёт
## `modulate`, поэтому одна и та же иконка годится и на светлой панели, и на
## тёмной кнопке. Импорт Godot не нужен: SVG растеризуется в рантайме
## (`Image.load_svg_from_buffer`), значит и в экспортном билде файлы нужны
## как есть — см. `include_filter` в export_presets.cfg.
##
## Источник набора: Phosphor Icons (лицензия MIT), скачаны через
## `https://api.iconify.design/ph/<имя>.svg` — таблица соответствия в docs/ui-icons.md.
##
## Использование:
##   button.icon = Icons.texture("coin")
##   Icons.decorate(button, "restore", 40.0)
##   var chip := Icons.icon_label(parent, "coin", Vector2(130, 64))

const DIR := "res://assets/ui/icons/"
## Растеризация: файлы нарисованы 96×96, рисуем крупнее ради чёткости на retina.
const RASTER_SCALE := 2.0
## Базовый цвет иконок: тот же коричневый, что у текста интерфейса.
const DEFAULT_TINT := Color("4A3A2E")
const SIZES := {
	"chip": 32.0,
	"button": 36.0,
	"small": 22.0,
}
## Иконки, которые реально зовёт интерфейс: selftest проверяет, что все файлы на
## месте. Добавили новую — допишите id сюда и в docs/ui-icons.md.
const USED := [
	"coin", "gem", "energy", "coffee", "cat", "gift",
	"sofa", "home", "gear", "lock", "consent", "cart",
	"ad_play", "ad_film", "reroll", "restore", "sell",
	"hammer", "shuffle", "magnet", "pin", "plus",
	"star", "check", "vibrate",
]

static var _cache: Dictionary = {}


## Текстура иконки или null, если файла нет (тогда один раз пишем предупреждение).
static func texture(id: String, scale: float = RASTER_SCALE) -> Texture2D:
	var key := "%s@%.2f" % [id, scale]
	if _cache.has(key):
		return _cache[key]

	var path := DIR + id + ".svg"
	if not FileAccess.file_exists(path):
		_cache[key] = null
		push_warning("[Icons] нет файла %s" % path)
		return null

	var image := Image.new()
	var error := image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), scale)
	if error != OK:
		_cache[key] = null
		push_warning("[Icons] не удалось разобрать SVG %s (код %d)" % [path, error])
		return null

	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


static func has(id: String) -> bool:
	return FileAccess.file_exists(DIR + id + ".svg")


## Готовый прямоугольник с иконкой: размер задан, пропорции сохранены.
static func rect(id: String, size: float = SIZES["small"], color: Color = DEFAULT_TINT) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(id)
	node.custom_minimum_size = Vector2(size, size)
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.modulate = color
	return node


## Иконка на кнопке: сама кнопка получает `icon`, текст остаётся текстом.
static func decorate(button: Button, id: String, size: float = SIZES["button"], color: Color = DEFAULT_TINT) -> void:
	button.icon = texture(id)
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


## «Иконка + текст» в ряд: для строк, где раньше эмодзи стоял прямо в тексте.
## Возвращает HBoxContainer с полем `value` — Label, куда пишется текст.
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
	row.add_child(rect(icon_id, size, color))

	var value := Label.new()
	value.text = text
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	return row


## Ряд из `count` звёзд (редкость кота): рисуем столько иконок, сколько нужно.
static func stars(count: int, size: float = SIZES["small"], color: Color = DEFAULT_TINT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in maxi(count, 0):
		row.add_child(rect("star", size, color))
	return row


## Все id, для которых есть файл (для самопроверки).
static func available() -> Array:
	var ids: Array = []
	var directory := DirAccess.open(DIR)
	if directory == null:
		return ids
	for file_name in directory.get_files():
		if file_name.get_extension() == "svg":
			ids.append(file_name.get_basename())
	ids.sort()
	return ids

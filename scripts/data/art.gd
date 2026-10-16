class_name Art
extends RefCounted

## Резолвер арта: ищет реальные файлы в `res://assets/...`, а если их нет —
## возвращает null, и предмет рисуется плейсхолдером (`scripts/placeholders.gd`).
##
## Имена файлов (см. README, раздел про ассеты):
##   assets/items/<chain>/<chain>_<level>.png   — допускается .jpg и без ведущего нуля
##   assets/generators/<gen_*>.png
##   assets/ui/<...>.png
##
## У JPEG нет альфы, поэтому шахматка/однотонный фон вырезается флудфиллом от
## краёв (полупрозрачные края при этом грубеют — для предметов лучше PNG).

const ITEM_DIR := "res://assets/items/%s/"
const BOARD_TEXTURE_MAX := 256

static var _item_cache: Dictionary = {}


## Текстура предмета или null, если арта нет.
static func item_texture(chain: StringName, level: int) -> Texture2D:
	var key := "%s_%d" % [String(chain), level]
	if _item_cache.has(key):
		return _item_cache.get(key)

	var folder := ITEM_DIR % String(chain)
	var file := String(chain)
	var candidates := [
		folder + "%s_%02d.png" % [file, level],
		folder + "%s_%d.png" % [file, level],
		folder + "%s_%02d.jpg" % [file, level],
		folder + "%s_%d.jpg" % [file, level],
	]

	var found: Texture2D = null
	for path in candidates:
		if not ResourceLoader.exists(path):
			continue
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			found = _prepare(loaded, _needs_key(path))
			break

	_item_cache[key] = found
	return found


## Сколько файлов предметов реально найдено на диске (для лога самопроверки).
static func count_item_art() -> int:
	var found := 0
	for chain in Chains.all_chains():
		for level in range(1, Chains.max_level(chain) + 1):
			if item_texture(chain, level) != null:
				found += 1
	return found


## Текстура по точному пути или null.
static func texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var loaded := ResourceLoader.load(path)
	if loaded is Texture2D:
		return _prepare(loaded, _needs_key(path))
	return null


static func _needs_key(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".jpg") or lower.ends_with(".jpeg")


static func _prepare(source: Texture2D, needs_key: bool) -> Texture2D:
	if not needs_key:
		return source
	var image := source.get_image()
	if image == null:
		return source
	image = _downscale(image, BOARD_TEXTURE_MAX)
	_key_background(image)
	return ImageTexture.create_from_image(image)


static func _downscale(image: Image, max_side: int) -> Image:
	var out := image.duplicate() as Image
	var longest := maxi(out.get_width(), out.get_height())
	if longest <= max_side:
		return out
	var ratio := float(max_side) / float(longest)
	var width := maxi(1, int(round(out.get_width() * ratio)))
	var height := maxi(1, int(round(out.get_height() * ratio)))
	out.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return out


## Вырезает фон флудфиллом от краёв: убирает только светлую нейтральную заливку,
## связанную с границей (белая керамика внутри тёмной обводки остаётся).
static func _key_background(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var total := width * height
	var visited := PackedByteArray()
	visited.resize(total)

	var stack: Array[int] = []
	for x in width:
		stack.append(x)
		stack.append((height - 1) * width + x)
	for y in height:
		stack.append(y * width)
		stack.append(y * width + width - 1)

	while not stack.is_empty():
		var index: int = stack.pop_back()
		if index < 0 or index >= total or visited[index] == 1:
			continue
		var x := index % width
		var y := floori(float(index) / float(width))
		if not _is_background(image.get_pixel(x, y)):
			continue
		visited[index] = 1
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:
			stack.append(index - 1)
		if x < width - 1:
			stack.append(index + 1)
		if y > 0:
			stack.append(index - width)
		if y < height - 1:
			stack.append(index + width)


static func _is_background(color: Color) -> bool:
	var high := maxf(color.r, maxf(color.g, color.b))
	var low := minf(color.r, minf(color.g, color.b))
	return (high - low) < 0.07 and low > 0.62

class_name Art
extends RefCounted

## Резолвер арта: ищет реальные файлы в `res://assets/...`, а если их нет —
## возвращает null, и предмет рисуется плейсхолдером (`scripts/placeholders.gd`).
##
## Имена файлов (см. README, раздел про ассеты):
##   assets/items/<chain>/<chain>_<level>.png   — допускается без ведущего нуля
##   assets/generators/<gen_*>.png
##   assets/ui/<...>.png
##
## Только импортированные PNG с альфой: текстуры отдаются как есть, без
## обработки пикселей (они VRAM-сжаты, get_image дорог и с потерями).

const ITEM_DIR := "res://assets/items/%s/"

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
	]

	var found: Texture2D = null
	for path in candidates:
		if not ResourceLoader.exists(path):
			continue
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			found = loaded
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
		return loaded
	return null

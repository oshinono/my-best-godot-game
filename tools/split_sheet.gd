extends SceneTree
## split_sheet.gd — нарезка листа ассетов на отдельные PNG «по пустоте»,
## как Unity Auto Slice: связные непрозрачные области находятся сами, каждый
## кусок сохраняется в ИСХОДНОМ размере (никакого ресайза).
##
## Запуск из корня проекта:
##   godot --headless --script tools/split_sheet.gd -- \
##     --sheet assets/items/_src/bakery.png \
##     --out assets/items/pastry \
##     --prefix pastry_ --start 1
##
## Ключи:
##   --sheet <путь>        лист-исходник (обязателен). res:// или путь от корня
##   --out <каталог>       куда писать куски (обязателен)
##   --prefix <текст>      начало имени, по умолчанию "item_"
##   --start <n>           номер первого куска, по умолчанию 1
##   --names a,b,c         явные имена по порядку (перебивают prefix/start)
##   --min-alpha <0..255>  порог непрозрачности, по умолчанию 8
##   --key-bg              убрать фон по цвету пикселя (0,0) — для jpg без альфы
##   --bg-tolerance <f>    допуск совпадения с фоном 0.0..1.0, по умолчанию 0.12
##   --min-size <px>       выбросить мелочь меньше N px по стороне, по умолчанию 8
##   --merge-gap <px>      склеивать куски ближе N px (части одного предмета), 2;
##                         -1 — не склеивать (рамки соседних предметов
##                         пересекаются, а сами предметы цельные)
##   --pad <px>            добавить поля вокруг куска, по умолчанию 0
##   --grid WxH            резать равномерно по сетке вместо пустоты (напр. 3x3)
##   --rows                кадры анимаций рядами: сначала пустые горизонтальные
##                         полосы делят лист на ряды, затем в каждом ряду —
##                         пустые вертикальные полосы на кадры (части кадра
##                         ближе --merge-gap склеиваются). Для листов VFX, где
##                         лучи соседних кадров почти касаются
##   --help                эта справка

const USAGE := """split_sheet.gd — нарезка листа на PNG по пустоте (Unity Auto Slice).

  godot --headless --script tools/split_sheet.gd -- \\
    --sheet <лист.png> --out <каталог> [ключи]

Ключи: --prefix <текст> --start <n> --names a,b,c --min-alpha <0..255>
       --key-bg --bg-tolerance <f> --min-size <px> --merge-gap <px> --pad <px>
       --grid WxH --rows
"""

var _failed := 0


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		print(USAGE)
		quit(0)
		return
	if not args.has("sheet") or not args.has("out"):
		print(USAGE)
		push_error("[split_sheet] нужны --sheet и --out")
		quit(1)
		return

	var sheet_path := _absolute(String(args["sheet"]))
	var out_dir := _absolute(String(args["out"]))
	var image := Image.load_from_file(sheet_path)
	if image == null:
		push_error("[split_sheet] не открылся %s" % sheet_path)
		quit(1)
		return
	if image.is_empty():
		push_error("[split_sheet] пустое изображение %s" % sheet_path)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	var width := image.get_width()
	var height := image.get_height()
	var min_alpha := _int(args, "min-alpha", 8)
	var key_bg := args.has("key-bg")
	var tolerance := _float(args, "bg-tolerance", 0.12)
	var min_size := _int(args, "min-size", 8)
	var merge_gap := _int(args, "merge-gap", 2)
	var pad := _int(args, "pad", 0)

	var boxes: Array[Rect2i] = []
	if args.has("grid"):
		boxes = _grid_boxes(width, height, String(args["grid"]))
	elif args.has("rows"):
		var mask := _solid_mask(image, min_alpha, key_bg, tolerance)
		boxes = _row_boxes(mask, width, height, maxi(merge_gap, 0), min_size)
	else:
		var mask := _solid_mask(image, min_alpha, key_bg, tolerance)
		boxes = _find_boxes(mask, width, height, min_size)
		if merge_gap >= 0:
			boxes = _merge_boxes(boxes, merge_gap)
		boxes = _reading_order(boxes)

	if boxes.is_empty():
		push_error("[split_sheet] ничего не нашлось — проверь --min-alpha и --min-size")
		quit(1)
		return

	var error := DirAccess.make_dir_recursive_absolute(out_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[split_sheet] не создал каталог %s (код %d)" % [out_dir, error])
		quit(1)
		return

	var names := String(args.get("names", "")).split(",", false)
	var prefix := String(args.get("prefix", "item_"))
	var start := _int(args, "start", 1)
	var limit := Rect2i(0, 0, width, height)

	print("[split_sheet] %s — %dx%d, кусков: %d" % [sheet_path.get_file(), width, height, boxes.size()])
	for index in boxes.size():
		var rect := boxes[index]
		if pad > 0:
			rect = rect.grow(pad).intersection(limit)
		var name := ""
		if index < names.size() and names[index].strip_edges() != "":
			name = names[index].strip_edges()
		else:
			name = "%s%d" % [prefix, start + index]
		var target := "%s/%s.png" % [out_dir.trim_suffix("/"), name]
		var piece := image.get_region(rect)
		var save_error := piece.save_png(target)
		if save_error != OK:
			_failed += 1
			push_error("[split_sheet] не записал %s (код %d)" % [target, save_error])
		else:
			print("[split_sheet] %s.png — %dx%d (x%d y%d)" % [name, rect.size.x, rect.size.y, rect.position.x, rect.position.y])

	if _failed > 0:
		push_error("[split_sheet] не записано файлов: %d" % _failed)
		quit(1)
		return
	quit(0)


# --- Маски и области ---------------------------------------------------------

## Битовая карта «непустых» пикселей: альфа не ниже порога, а при `--key-bg`
## ещё и не совпадающие с цветом фона (взятым из пикселя 0,0).
func _solid_mask(image: Image, min_alpha: int, key_bg: bool, tolerance: float) -> PackedByteArray:
	var width := image.get_width()
	var height := image.get_height()
	var pixels := image.get_data()
	var mask := PackedByteArray()
	mask.resize(width * height)
	var key := image.get_pixel(0, 0)
	for index in width * height:
		var offset := index * 4
		var solid := pixels[offset + 3] >= min_alpha
		if solid and key_bg:
			var red := pixels[offset] / 255.0
			var green := pixels[offset + 1] / 255.0
			var blue := pixels[offset + 2] / 255.0
			if absf(red - key.r) <= tolerance and absf(green - key.g) <= tolerance and absf(blue - key.b) <= tolerance:
				solid = false
		mask[index] = 1 if solid else 0
	return mask


## Прямоугольники связных областей (8 соседей, чтобы не рвать предметы, которые
## соприкасаются только по диагонали).
func _find_boxes(mask: PackedByteArray, width: int, height: int, min_size: int) -> Array[Rect2i]:
	var boxes: Array[Rect2i] = []
	var seen := PackedByteArray()
	seen.resize(width * height)
	var stack: PackedInt32Array = []
	for start in width * height:
		if mask[start] == 0 or seen[start] == 1:
			continue
		seen[start] = 1
		stack.clear()
		stack.push_back(start)
		var min_x := width
		var min_y := height
		var max_x := -1
		var max_y := -1
		while not stack.is_empty():
			var index := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := index % width
			var y := index / width
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
			_push(mask, seen, stack, index - 1, x > 0)
			_push(mask, seen, stack, index + 1, x < width - 1)
			_push(mask, seen, stack, index - width, y > 0)
			_push(mask, seen, stack, index + width, y < height - 1)
			_push(mask, seen, stack, index - width - 1, x > 0 and y > 0)
			_push(mask, seen, stack, index - width + 1, x < width - 1 and y > 0)
			_push(mask, seen, stack, index + width - 1, x > 0 and y < height - 1)
			_push(mask, seen, stack, index + width + 1, x < width - 1 and y < height - 1)
		var box := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
		if box.size.x >= min_size and box.size.y >= min_size:
			boxes.append(box)
	return boxes


func _push(mask: PackedByteArray, seen: PackedByteArray, stack: PackedInt32Array, index: int, allowed: bool) -> void:
	if not allowed or index < 0 or index >= mask.size():
		return
	if mask[index] == 0 or seen[index] == 1:
		return
	seen[index] = 1
	stack.push_back(index)


## Склейка областей, которые ближе `gap` пикселей: латте из чашки и блюдца,
## витрина из двух половин и т.п. остаются одним куском.
func _merge_boxes(boxes: Array[Rect2i], gap: int) -> Array[Rect2i]:
	var current := boxes
	var changed := true
	while changed:
		changed = false
		var result: Array[Rect2i] = []
		for box in current:
			var merged := false
			for index in result.size():
				if box.grow(gap).intersects(result[index]):
					result[index] = box.merge(result[index])
					merged = true
					changed = true
					break
			if not merged:
				result.append(box)
		current = result
	return current


## Порядок чтения: слева направо, сверху вниз, с допуском на «одну строку».
func _reading_order(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var sorted := boxes.duplicate()
	sorted.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var a_center := a.position.y + a.size.y / 2
		var b_center := b.position.y + b.size.y / 2
		if absi(a_center - b_center) <= maxi(a.size.y, b.size.y) / 2:
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)
	return sorted


## Режим --rows: ряды по пустым строкам, кадры — по пустым столбцам внутри ряда.
## Каждый кадр ужимается до своих непрозрачных пикселей.
func _row_boxes(mask: PackedByteArray, width: int, height: int, gap: int,
		min_size: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for band in _runs(height, func(y: int) -> bool:
		for x in width:
			if mask[y * width + x] != 0:
				return true
		return false, 0):
		var top: int = band.x
		var bottom: int = band.y
		for cols in _runs(width, func(x: int) -> bool:
			for y in range(top, bottom):
				if mask[y * width + x] != 0:
					return true
			return false, gap):
			var box := _tight(mask, width, Rect2i(cols.x, top, cols.y - cols.x, bottom - top))
			if box.size.x >= min_size and box.size.y >= min_size:
				result.append(box)
	return result


## Отрезки [start, end) по оси длиной `length`, где `filled(i)` истинно;
## отрезки, разделённые пустотой не больше `gap`, склеиваются.
func _runs(length: int, filled: Callable, gap: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var start := -1
	for i in length:
		var on: bool = filled.call(i)
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			runs.append(Vector2i(start, i))
			start = -1
	if start >= 0:
		runs.append(Vector2i(start, length))
	var merged: Array[Vector2i] = []
	for run in runs:
		if not merged.is_empty() and run.x - merged.back().y <= gap:
			merged[merged.size() - 1] = Vector2i(merged.back().x, run.y)
		else:
			merged.append(run)
	return merged


## Рамка по непрозрачным пикселям внутри `area`.
func _tight(mask: PackedByteArray, width: int, area: Rect2i) -> Rect2i:
	var lo := area.end
	var hi := area.position - Vector2i.ONE
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if mask[y * width + x] != 0:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < lo.x:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Равномерная сетка `--grid 3x3` — на случай, когда «по пустоте» не подходит.
func _grid_boxes(width: int, height: int, spec: String) -> Array[Rect2i]:
	var boxes: Array[Rect2i] = []
	var parts := spec.to_lower().split("x", false)
	if parts.size() != 2:
		push_error("[split_sheet] --grid ждёт формат WxH, например 3x3")
		return boxes
	var columns := maxi(1, int(parts[0]))
	var rows := maxi(1, int(parts[1]))
	var cell_w := width / columns
	var cell_h := height / rows
	for row in rows:
		for column in columns:
			boxes.append(Rect2i(column * cell_w, row * cell_h, cell_w, cell_h))
	return boxes


# --- Аргументы ---------------------------------------------------------------

func _parse_args(list: PackedStringArray) -> Dictionary:
	var parsed := {}
	var index := 0
	while index < list.size():
		var token := String(list[index])
		if token.begins_with("--"):
			var key := token.trim_prefix("--")
			var value := "true"
			if index + 1 < list.size() and not String(list[index + 1]).begins_with("--"):
				value = String(list[index + 1])
				index += 1
			parsed[key] = value
		index += 1
	return parsed


func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://".path_join(path))


func _int(args: Dictionary, key: String, fallback: int) -> int:
	if not args.has(key):
		return fallback
	return int(String(args[key]))


func _float(args: Dictionary, key: String, fallback: float) -> float:
	if not args.has(key):
		return fallback
	return float(String(args[key]))

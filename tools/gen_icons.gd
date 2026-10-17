extends Node

## Разовый дев-инструмент: делает PNG нужных размеров для иконок iOS/Android
## и для boot splash из исходника в корне проекта.
##
## Источник: `res://icon.png` (растр, приоритет) или `res://icon.svg` (вектор).
##
## Углы скругляются как у иконок приложений Apple (радиус 22.37% стороны),
## а срезанные углы заливаются фоновым цветом BG — поэтому иконка одинаково
## выглядит и там, где ОС маску не применяет (Android legacy, сплэш).
##
## Запускается как автолоад из project.godot только вручную:
##   Icons="*res://tools/gen_icons.gd"
## Сам выходит после работы (get_tree().quit()).
## Потом строку автолоада из project.godot убрать.

const SRC_PNG := "res://icon.png"
const SRC_SVG := "res://icon.svg"
const OUT_DIR := "res://assets/icons"
## Размеры, которые ждут пресеты экспорта (iOS icons/*, Android launcher_icons/*).
const SIZES: Array[int] = [40, 58, 60, 76, 80, 87, 114, 120, 128, 136, 152, 167, 180, 192, 432, 512, 1024]
## Базовый размер, на котором считаем закругление; остальные — его скейлы.
const MASTER := 1024
## Радиус скругления как доля стороны иконки: 22.37% — как у масок iOS.
const CORNER_RATIO := 0.2237
## Размер иконки окна/дока для десктопного запуска.
## Отличие от мобильных иконок: углы ПРОЗРАЧНЫЕ, а не залитые BG.
const WINDOW := 512
## Фон adaptive-иконки Android (пипетка из старого icon.svg): #6A2E10.
const BG := Color(0.415686, 0.180392, 0.062745, 1.0)
## Допуск совпадения цвета при поиске «запечённого» светлого скругления.
const CORNER_TOL := 0.12
## Насколько далеко от угла ищем заливку (доля стороны). Защита от разъезда.
const CORNER_LIMIT := 0.12
## Порог альфы, ниже которого пиксель считается прозрачным.
const ALPHA_CUT := 0.5


func _ready() -> void:
	var err := _run()
	if err == OK:
		print("[icons] готово")
	else:
		printerr("[icons] ошибка %d" % err)
	get_tree().quit(0 if err == OK else 1)


func _run() -> int:
	var src := SRC_PNG if FileAccess.file_exists(SRC_PNG) else SRC_SVG
	if not FileAccess.file_exists(src):
		printerr("[icons] нет ни %s, ни %s" % [SRC_PNG, SRC_SVG])
		return ERR_FILE_NOT_FOUND

	var base := _load_source(src)
	if base == null:
		printerr("[icons] не удалось прочитать %s" % src)
		return ERR_CANT_CREATE
	print("[icons] источник %s, %dx%d" % [src, base.get_width(), base.get_height()])

	_fill_padding(base)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# Мастер-иконка: закругление считаем один раз на большом размере,
	# остальные размеры — её скейлы (кромка остаётся сглаженной).
	var master := _compose(base, MASTER)

	# Десктопная иконка окна: та же маска скругления, но углы прозрачные —
	# на светлом фоне окна не будет тёмных квадратов по углам.
	var win := _scaled(base, WINDOW)
	_apply_round(win)
	var win_path := "%s/window_%d.png" % [OUT_DIR, WINDOW]
	var win_err: int = win.save_png(win_path)
	if win_err != OK:
		printerr("[icons] не сохранился %s (err %d)" % [win_path, win_err])
		return win_err
	print("[icons] %s" % win_path)

	for size in SIZES:
		var img: Image = master if size == MASTER else _scaled(master, size)
		var path := "%s/icon_%d.png" % [OUT_DIR, size]
		var err := img.save_png(path)
		if err != OK:
			printerr("[icons] не сохранился %s (err %d)" % [path, err])
			return err
		print("[icons] %s" % path)

	# Android adaptive: фон — сплошной цвет, передний план — арт в safe zone (66%).
	var bg := Image.create_empty(432, 432, false, Image.FORMAT_RGB8)
	bg.fill(BG)
	var bg_err: int = bg.save_png("%s/bg_432.png" % OUT_DIR)
	if bg_err != OK:
		printerr("[icons] не сохранился bg_432.png (err %d)" % bg_err)
		return bg_err

	var inner := 285  # 432 * 0.66 — safe zone adaptive-иконки
	var fg := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	var art := _compose(base, inner)
	art.convert(Image.FORMAT_RGBA8)  # blend_rect требует одинаковый формат с fg
	var offset := int((432 - inner) * 0.5)
	fg.blend_rect(art, Rect2i(0, 0, inner, inner), Vector2i(offset, offset))
	var fg_err: int = fg.save_png("%s/fg_432.png" % OUT_DIR)
	if fg_err != OK:
		printerr("[icons] не сохранился fg_432.png (err %d)" % fg_err)
		return fg_err

	print("[icons] %s/bg_432.png, %s/fg_432.png" % [OUT_DIR, OUT_DIR])
	return OK


## Готовит иконку размера size: арт со скруглёнными углами, срезанные углы
## залиты фоном BG. Возвращает непрозрачную RGB8-картинку.
func _compose(base: Image, size: int) -> Image:
	var img := _scaled(base, size)
	_apply_round(img)
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	out.fill(BG)
	out.blend_rect(img, Rect2i(0, 0, size, size), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	return out


## Скруглить углы по маске иконки iOS: радиус CORNER_RATIO от стороны,
## кромка сглажена суперсэмплингом 2x2 (иначе на 40-58 px видна лесенка).
func _apply_round(img: Image) -> void:
	var size := img.get_width()
	var s := float(size)
	var r := maxf(1.0, s * CORNER_RATIO)
	var r2 := r * r
	var lo := int(ceil(r))
	var hi := int(floor(s - r))
	for y in size:
		var mid_y := y >= lo and y <= hi
		for x in size:
			var cover := 4
			if not (mid_y or (x >= lo and x <= hi)):
				cover = 0
				for sy in 2:
					for sx in 2:
						var px := float(x) + 0.25 + 0.5 * float(sx)
						var py := float(y) + 0.25 + 0.5 * float(sy)
						if _inside_round(px, py, s, r, r2):
							cover += 1
			if cover < 4:
				var c := img.get_pixel(x, y)
				c.a *= float(cover) * 0.25
				img.set_pixel(x, y, c)


## Внутри ли точка скруглённого прямоугольника (прямые кромки + круглые углы).
func _inside_round(px: float, py: float, s: float, r: float, r2: float) -> bool:
	if px >= r and px <= s - r:
		return true
	if py >= r and py <= s - r:
		return true
	var dx := px - clampf(px, r, s - r)
	var dy := py - clampf(py, r, s - r)
	return dx * dx + dy * dy <= r2


## Читает источник и нормализует в RGBA8.
func _load_source(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err := OK
	if path.get_extension().to_lower() == "svg":
		err = img.load_svg_from_buffer(bytes)
	else:
		err = img.load_png_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Убирает «мусорные» поля вокруг арта, чтобы иконка была квадратом, который
## ОС сама скруглит:
##  * прозрачные пиксели (арт с альфой),
##  * светлое «запечённое» скругление в углах (частый артефакт генераторов) —
##    иначе после маски ОС внутри останутся светлые клинья.
## Заполняем такие пиксели впитыванием цвета соседнего арта (BFS от границы
## внутрь): углы смазываются в цвет ближнего арта, а не в плоскую плашку.
func _fill_padding(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var pad := PackedByteArray()
	pad.resize(w * h)
	var count := 0

	if img.detect_alpha():
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a < ALPHA_CUT:
					pad[y * w + x] = 1
					count += 1
		print("[icons] прозрачных пикселей: %d" % count)
	else:
		var outer := img.get_pixel(0, 0)
		var limit := int(minf(w, h) * CORNER_LIMIT)
		var corners := [
			Vector2i(0, 0), Vector2i(w - 1, 0),
			Vector2i(0, h - 1), Vector2i(w - 1, h - 1),
		]
		for corner in corners:
			var region := _flood(img, corner, outer, CORNER_TOL, limit)
			count += region.size()
			for idx in region:
				pad[idx] = 1
		print("[icons] запечённое скругление: %d px (угол #%s)" % [count, outer.to_html(false)])

	if count == 0:
		print("[icons] полей нет — арт трогать не нужно")
		return

	_smear(img, pad, w, h)
	print("[icons] поля залиты цветом арта")


## Заливка от угла: собирает пиксели, похожие на цвет угла, в пределах limit.
## Возвращает индексы (y * width + x).
func _flood(img: Image, start: Vector2i, target: Color, tol: float, limit: int) -> PackedInt32Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out := PackedInt32Array()
	var stack := PackedInt32Array([start.y * w + start.x])
	while not stack.is_empty():
		var idx: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if seen[idx] != 0:
			continue
		var x := idx % w
		var y := int(floor(float(idx) / float(w)))
		if absi(x - start.x) > limit or absi(y - start.y) > limit:
			continue
		if not _similar(img.get_pixel(x, y), target, tol):
			continue
		seen[idx] = 1
		out.append(idx)
		if x > 0:
			stack.append(idx - 1)
		if x < w - 1:
			stack.append(idx + 1)
		if y > 0:
			stack.append(idx - w)
		if y < h - 1:
			stack.append(idx + w)
	return out


## BFS от границы «поля» внутрь: каждый пиксель берёт среднее уже известных
## соседей. Даёт плавное впитывание цвета арта без плоских клиньев.
func _smear(img: Image, pad: PackedByteArray, w: int, h: int) -> void:
	var filled := PackedByteArray()
	filled.resize(w * h)
	var queue := PackedInt32Array()
	var head := 0
	for idx in range(w * h):
		if pad[idx] == 0:
			continue
		if _has_solid_neighbor(pad, w, h, idx):
			queue.append(idx)
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		if filled[idx] != 0:
			continue
		var x := idx % w
		var y := int(floor(float(idx) / float(w)))
		var sum := Color(0, 0, 0, 1)
		var n := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nidx := ny * w + nx
				if pad[nidx] == 1 and filled[nidx] == 0:
					continue
				sum += img.get_pixel(nx, ny)
				n += 1
		if n == 0:
			continue
		sum /= float(n)
		sum.a = 1.0
		img.set_pixel(x, y, sum)
		filled[idx] = 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nidx := ny * w + nx
				if pad[nidx] == 1 and filled[nidx] == 0:
					queue.append(nidx)


func _has_solid_neighbor(pad: PackedByteArray, w: int, h: int, idx: int) -> bool:
	var x := idx % w
	var y := int(floor(float(idx) / float(w)))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if pad[ny * w + nx] == 0:
				return true
	return false


func _similar(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func _scaled(base: Image, size: int) -> Image:
	var img: Image = base.duplicate()
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return img

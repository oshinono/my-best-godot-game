extends Node2D

## Холст изометрической кофейни: склеивает фигуры (многоугольники, линии)
## в один массив треугольников с цветами вершин и рисует его ОДНИМ вызовом
## (RenderingServer.canvas_item_add_triangle_array). Подписи — отдельно.
##
## Зачем: пол, стены, окна и места под мебель — это сотни мелких фигур.
## Отдельными Polygon2D/Line2D это ~360 узлов, а в рендерере Compatibility
## каждая фигура или линия — свой draw call (~300 на кадр). Одним массивом —
## один узел и один вызов; перестраивается только по queue_redraw()
## (смена подсветки мест), а не каждый кадр.
##
## Все фигуры здесь выпуклые (ромбы и четырёхугольники), поэтому
## триангуляция — простым «веером» от первой вершины.

var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _texts: Array = []
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func clear() -> void:
	_points.clear()
	_colors.clear()
	_indices.clear()
	_texts.clear()
	queue_redraw()


## Залитый выпуклый многоугольник; `offset` — сдвиг точек (центр комнаты/места).
func poly(points: PackedVector2Array, color: Color, offset := Vector2.ZERO) -> void:
	if color.a <= 0.0 or points.size() < 3:
		return
	var base := _points.size()
	for p in points:
		_points.append(p + offset)
		_colors.append(color)
	for i in range(1, points.size() - 1):
		_indices.append(base)
		_indices.append(base + i)
		_indices.append(base + i + 1)
	queue_redraw()


## Ломаная толщиной `width`: каждый отрезок — прямоугольник, продлённый на
## полтолщины с концов, чтобы углы контуров смыкались без щелей.
func line(points: PackedVector2Array, color: Color, width: float,
		offset := Vector2.ZERO, closed := false) -> void:
	if color.a <= 0.0 or points.size() < 2:
		return
	var count := points.size() if closed else points.size() - 1
	var half := width * 0.5
	for i in count:
		var a := points[i] + offset
		var b := points[(i + 1) % points.size()] + offset
		var dir := (b - a).normalized()
		if dir == Vector2.ZERO:
			continue
		var n := Vector2(-dir.y, dir.x) * half
		a -= dir * half
		b += dir * half
		poly(PackedVector2Array([a + n, b + n, b - n, a - n]), color)


## Подпись по центру точки `center`.
func text(value: String, center: Vector2, size: int, color: Color, width := 220.0) -> void:
	_texts.append([value, center, size, color, width])
	queue_redraw()


func _draw() -> void:
	if not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)
	if _font == null:
		return
	for t in _texts:
		var width: float = t[4]
		var size: int = t[2]
		var pos: Vector2 = t[1] + Vector2(-width * 0.5, size * 0.35)
		draw_string(_font, pos, t[0], HORIZONTAL_ALIGNMENT_CENTER, width, size, t[3])

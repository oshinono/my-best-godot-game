extends CanvasLayer

## Изометрическая кофейня (GDD §8): панорама, зум, инвентарь, расстановка.
##
## Экран собирается кодом, как и остальные попапы проекта. Мир — обычный
## Node2D-слой, к которому применяются `position` (пан) и `scale` (зум).
## Экранные координаты: `screen = world * zoom + pan`.
##
## Управление:
##   один палец по полу/пустому месту — панорама;
##   один палец по предмету — перетаскивание предмета;
##   два пальца — панорама + пинч-зум;
##   колесо мыши (десктоп) — зум вокруг курсора;
##   тап по предмету — выбор (кнопки «Повернуть» / «Снять»);
##   перетаскивание из нижней панели — поставить предмет в слот.
##
## Сцена ничего не сохраняет: она только просит `game.gd`, а тот зовёт `Meta`
## и логирует аналитику. Ответ приходит обратно сигналами `Meta`.

signal closed
signal decor_place_requested(decor_id: String, slot_id: String, rot: int)
signal decor_clear_requested(slot_id: String)
signal decor_rotate_requested(slot_id: String)
signal decor_buy_requested(decor_id: String)

const DATA := preload("res://scripts/data/meta.gd")
const ISO := preload("res://scripts/data/iso.gd")
const SAFE := preload("res://scripts/ui/safe_area.gd")

## Панель инвентаря: два ряда чипов по 92 px (46 отступ + 92 + 10 + 92).
const BAR_HEIGHT := 268.0
const TOP_SAFE := 92.0
const TAP_SLOP := 16.0
const ZOOM_MIN := 0.55
const ZOOM_MAX := 2.6
const ZOOM_STEP := 1.12
const DROP_RADIUS := 130.0
const SLOT_HIT_RADIUS := 92.0

## Задние стены высокие — на них вешаем окна и занавески.
const WALL_H := 74.0
## Передние стены низкие: не закрывают мебель и слоты.
const WALL_FRONT_H := 20.0

const COL_GROUND := Color("D6C2A6")
const COL_FLOOR_BORDER := Color("B9A48C")
const COL_WALL := Color("8E6C4C")
const COL_WALL_TOP := Color("B58C63")
const COL_WALL_FRONT := Color("A07E5A")
const COL_SKIRT := Color("6E5138")
const COL_WINDOW := Color("C9DEEA")
const COL_WINDOW_FRAME := Color("6E5138")
const COL_CURTAIN := Color("C98A74")
const COL_CURTAIN_DARK := Color("A96B5C")
const COL_SLOT := Color(1, 1, 1, 0.42)
const COL_SLOT_LINE := Color("9C7C5A")
const COL_SLOT_OK := Color(0.32, 0.78, 0.42, 0.55)
const COL_SLOT_BAD := Color(0.85, 0.30, 0.25, 0.14)
const COL_SLOT_SELECT := Color(1.0, 0.80, 0.30, 0.60)
const COL_SLOT_OCCUPIED := Color(0, 0, 0, 0)
const COL_SHADOW := Color(0, 0, 0, 0.12)

## Слои поверх сцены: у предметов z_index = 100 + мировая Y (до ~1124),
## поэтому интерфейс и каталог держим выше. Потолок Godot — 4096.
const UI_Z := 3000
const CATALOG_Z := 3600

var _world: Node2D
var _floor_layer: Node2D
var _slot_layer: Node2D
var _item_layer: Node2D
var _bg: ColorRect

var _bar_panel: Panel
var _bar_hint: Label
var _chips: Array[Dictionary] = []
var _chip_nodes: Array[Control] = []

var _back_button: TextureButton
var _reset_button: TextureButton
var _buy_button: TextureButton
var _action_row: HBoxContainer
var _rotate_button: TextureButton
var _remove_button: TextureButton
var _zoom_hint: Label
var _map_hint: Label

## Каталог мебели: покупка живёт только здесь, внутри кофейни.
var _catalog_root: Control
var _catalog_panel: Panel
var _catalog_list: VBoxContainer
var _catalog_scroll: ScrollContainer
var _catalog_coins: Label
var _catalog_coins_value := -1
var _catalog_open := false

var _slot_nodes: Dictionary = {}
var _slot_lines: Dictionary = {}
var _slot_marks: Dictionary = {}
var _zoom := 1.0
var _pan := Vector2.ZERO
var _needs_fit := true
## Сколько тайлов плана максимум влезает по короткой стороне экрана.
var _max_zoom_span := 6.5

var _touches: Dictionary = {}
var _mode := ""
var _press_pos := Vector2.ZERO
var _pan_start := Vector2.ZERO
var _moved := false
var _mouse_down := false
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _pinch_focus := Vector2.ZERO

var _drag_decor := ""
var _drag_rot := 0
var _drag_from_slot := ""
var _drag_pos := Vector2.ZERO
var _ghost: Node2D

## Предмет, выбранный тапом в панели: тап по «+» ставит его.
var _pick_decor := ""

var _selected_slot := ""


func _ready() -> void:
	layer = 4
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_background()
	_build_world()
	_build_ui()

	Meta.placement_changed.connect(_on_placement_changed)
	Meta.rotation_changed.connect(_on_rotation_changed)
	Meta.decor_changed.connect(_on_decor_changed)

	get_viewport().size_changed.connect(_layout)
	_layout()


# --- Публичное API ---------------------------------------------------------

func open() -> void:
	if _needs_fit:
		_fit_view()
		_needs_fit = false
	else:
		_clamp_view()
	_deselect()
	_pick_decor = ""
	_close_catalog()
	_rebuild_items()
	_rebuild_bar()
	_refresh_slot_marks()
	visible = true


## Открыть кофейню сразу с каталогом мебели (кнопка 🏪 в HUD): покупка живёт
## только внутри кофейни, поэтому магазин — это тот же экран поверх каталога.
func open_shop() -> void:
	open()
	_open_catalog()


func close() -> void:
	_close_catalog()
	_deselect()
	_cancel_drag()
	_pick_decor = ""
	visible = false
	closed.emit()


# --- Сборка ---------------------------------------------------------------

func _build_background() -> void:
	_bg = ColorRect.new()
	_bg.color = Color("F3EDE4")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Фон обязан уйти под пол: слои мира живут в отрицательном z.
	# Без этого непрозрачный ColorRect на z=0 перекрывает пол и слоты.
	_bg.z_index = -2000
	add_child(_bg)


func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)

	_floor_layer = Node2D.new()
	_floor_layer.z_index = -1000
	_world.add_child(_floor_layer)

	_slot_layer = Node2D.new()
	_slot_layer.z_index = -50
	_world.add_child(_slot_layer)

	_item_layer = Node2D.new()
	_world.add_child(_item_layer)

	_build_floor()
	_build_slots()


func _build_floor() -> void:
	_build_ground()

	for room in DATA.ROOMS:
		var center: Vector2 = ISO.tile_center(room["tx"], room["ty"], room["w"], room["h"])
		var polygon: PackedVector2Array = ISO.diamond(
			room["tx"], room["ty"], room["w"], room["h"]
		)

		var poly := Polygon2D.new()
		poly.polygon = polygon
		poly.position = center
		poly.color = Color(room["floor"])
		_floor_layer.add_child(poly)

		# Контур комнаты — читается как стена пола и отделяет Зал/Кухню/Террасу/Сад.
		var border := Line2D.new()
		var border_points := polygon.duplicate()
		border_points.append(polygon[0])
		border.points = border_points
		border.position = center
		border.width = 4.0
		border.default_color = COL_FLOOR_BORDER
		_floor_layer.add_child(border)

		var label := Label.new()
		label.text = String(room["name"])
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.20, 0.65))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(220, 40)
		label.position = center + Vector2(-110, -ISO.TILE_H * 0.5 - 20)
		_floor_layer.add_child(label)

	_build_grid()
	_build_walls()


## Тайловая сетка поверх пола: помогает глазами понять масштаб места.
func _build_grid() -> void:
	var min_t := Vector2i(9999, 9999)
	var max_t := Vector2i(-9999, -9999)
	for room in DATA.ROOMS:
		min_t.x = mini(min_t.x, int(room["tx"]))
		min_t.y = mini(min_t.y, int(room["ty"]))
		max_t.x = maxi(max_t.x, int(room["tx"]) + int(room["w"]))
		max_t.y = maxi(max_t.y, int(room["ty"]) + int(room["h"]))

	var grid_color := Color(0, 0, 0, 0.07)
	for tx in range(min_t.x, max_t.x + 1):
		var line := Line2D.new()
		line.points = PackedVector2Array([
			ISO.tile_to_screen(float(tx), float(min_t.y)),
			ISO.tile_to_screen(float(tx), float(max_t.y)),
		])
		line.width = 1.5
		line.default_color = grid_color
		_floor_layer.add_child(line)
	for ty in range(min_t.y, max_t.y + 1):
		var line := Line2D.new()
		line.points = PackedVector2Array([
			ISO.tile_to_screen(float(min_t.x), float(ty)),
			ISO.tile_to_screen(float(max_t.x), float(ty)),
		])
		line.width = 1.5
		line.default_color = grid_color
		_floor_layer.add_child(line)


## Общая плита под всем планом — читается как пол зала.
func _build_ground() -> void:
	var min_tx := INF
	var min_ty := INF
	var max_tx := -INF
	var max_ty := -INF
	for room in DATA.ROOMS:
		min_tx = minf(min_tx, float(room["tx"]))
		min_ty = minf(min_ty, float(room["ty"]))
		max_tx = maxf(max_tx, float(room["tx"]) + float(room["w"]))
		max_ty = maxf(max_ty, float(room["ty"]) + float(room["h"]))

	var pad := 0.9
	var w := (max_tx - min_tx) + pad * 2.0
	var h := (max_ty - min_ty) + pad * 2.0

	# Мягкая тень под всей плитой — план перестаёт «плавать» на фоне.
	var shadow := Polygon2D.new()
	shadow.polygon = ISO.diamond(min_tx - pad, min_ty - pad, w, h)
	shadow.position = ISO.tile_center(min_tx - pad, min_ty - pad, w, h) + Vector2(6, 12)
	shadow.color = Color(0, 0, 0, 0.08)
	_floor_layer.add_child(shadow)

	var poly := Polygon2D.new()
	poly.polygon = ISO.diamond(min_tx - pad, min_ty - pad, w, h)
	poly.position = ISO.tile_center(min_tx - pad, min_ty - pad, w, h)
	poly.color = COL_GROUND
	_floor_layer.add_child(poly)

	var rim := Line2D.new()
	var rim_points := ISO.diamond(min_tx - pad, min_ty - pad, w, h)
	rim_points.append(rim_points[0])
	rim.points = rim_points
	rim.position = poly.position
	rim.width = 5.0
	rim.default_color = COL_FLOOR_BORDER
	_floor_layer.add_child(rim)


## Стены: только ВНЕШНИЙ контур плана, по одному ребру на границу.
##
## Считаем в тайлах, а не в экранных точках: ребро комнаты дробится на
## сегменты длиной в один тайл, поэтому частично совпадающие стенки
## соседних комнат (Кухня/Терраса, Терраса/Зал, Терраса/Сад) схлопываются
## в одну — раньше они рисовались дважды вместе с окнами и плинтусом.
## Внутренние границы комнат стены не получают: их показывают цвет пола и
## контур комнаты (см. _build_floor).
##
## Задние (тыл: минимальные tx/ty) — высокие с окнами и плинтусом,
## передние (фронт: максимальные tx/ty) — низкие, чтобы не закрывать мебель.
func _build_walls() -> void:
	var segments: Dictionary = {}
	for room in DATA.ROOMS:
		var tx := int(room["tx"])
		var ty := int(room["ty"])
		var w := int(room["w"])
		var h := int(room["h"])
		# Тыльная сторона идёт вдоль меньшего угла плана, фронтальная — вдоль
		# большего: в изометрии это «дальняя» и «ближняя» стены.
		_add_wall_side(segments, tx, ty, w, Vector2i(0, -1), true)
		_add_wall_side(segments, tx, ty + h, w, Vector2i(0, 1), false)
		_add_wall_side(segments, tx, ty, h, Vector2i(-1, 0), true)
		_add_wall_side(segments, tx + w, ty, h, Vector2i(1, 0), false)

	for run in _wall_runs(segments):
		var a: Vector2 = ISO.tile_to_screen(float(run["x0"]), float(run["y0"]))
		var b: Vector2 = ISO.tile_to_screen(float(run["x1"]), float(run["y1"]))
		var back: bool = run["back"]
		_build_wall(a, b, back)
		if back:
			_build_baseboard(a, b)
			_build_interior(a, b)


## Раскладывает сторону комнаты на тайловые сегменты. `x`,`y` — начало линии
## (в тайлах), `length` — длина в тайлах, `out_dir` — куда смотрит ребро
## (наружу от комнаты), `back` — тыльная ли сторона.
func _add_wall_side(
	segments: Dictionary, x: int, y: int, length: int, out_dir: Vector2i, back: bool
) -> void:
	var along_x := out_dir.x == 0
	for i in length:
		var cx := float(x) + (float(i) + 0.5 if along_x else 0.0)
		var cy := float(y) + (0.0 if along_x else float(i) + 0.5)
		# Тайл сразу за ребром: если он принадлежит другой комнате — это
		# внутренняя граница, стена там не нужна.
		var out_tile := Vector2i(
			floori(cx + float(out_dir.x) * 0.5),
			floori(cy + float(out_dir.y) * 0.5)
		)
		if not _room_at(out_tile).is_empty():
			continue
		var line: int = y if along_x else x
		var start: int = x + i if along_x else y + i
		var key := "%d|%d|%d" % [0 if along_x else 1, line, start]
		segments[key] = {
			"along_x": along_x, "line": line, "start": start, "back": back,
		}


## Склеивает соседние тайловые сегменты одной линии в непрерывные прогоны.
func _wall_runs(segments: Dictionary) -> Array:
	var lines: Dictionary = {}
	for key in segments:
		var seg: Dictionary = segments[key]
		var line_key := "%s|%d" % [str(seg["along_x"]), int(seg["line"])]
		if not lines.has(line_key):
			lines[line_key] = {
				"along_x": bool(seg["along_x"]),
				"line": int(seg["line"]),
				"back": bool(seg["back"]),
				"starts": {},
			}
		lines[line_key]["starts"][int(seg["start"])] = true

	var runs: Array = []
	for line_key in lines:
		var line: Dictionary = lines[line_key]
		var starts: Array = line["starts"].keys()
		starts.sort()
		var run_start := int(starts[0])
		var prev := run_start
		for i in range(1, starts.size()):
			var value := int(starts[i])
			if value != prev + 1:
				runs.append(_make_run(line, run_start, prev))
				run_start = value
			prev = value
		runs.append(_make_run(line, run_start, prev))
	return runs


func _make_run(line: Dictionary, start: int, last: int) -> Dictionary:
	var coord := int(line["line"])
	if bool(line["along_x"]):
		return {
			"x0": start, "y0": coord, "x1": last + 1, "y1": coord, "back": line["back"],
		}
	return {
		"x0": coord, "y0": start, "x1": coord, "y1": last + 1, "back": line["back"],
	}


## Идентификатор комнаты, которой принадлежит тайл ("" — тайл вне комнат).
func _room_at(tile: Vector2i) -> String:
	for room in DATA.ROOMS:
		var tx := int(room["tx"])
		var ty := int(room["ty"])
		if (
			tile.x >= tx and tile.x < tx + int(room["w"])
			and tile.y >= ty and tile.y < ty + int(room["h"])
		):
			return String(room["id"])
	return ""


func _build_wall(a: Vector2, b: Vector2, back: bool) -> void:
	var height := WALL_H if back else WALL_FRONT_H
	var lift := Vector2(0.0, -height)

	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([a, b, b + lift, a + lift])
	wall.color = COL_WALL if back else COL_WALL_FRONT
	_floor_layer.add_child(wall)

	var top := Line2D.new()
	top.points = PackedVector2Array([a + lift, b + lift])
	top.width = 5.0
	top.default_color = COL_WALL_TOP
	_floor_layer.add_child(top)


## Плинтус по низу задней стены — объём без спрайтов.
func _build_baseboard(a: Vector2, b: Vector2) -> void:
	var lift := Vector2(0.0, -WALL_H * 0.09)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([a, b, b + lift, a + lift])
	board.color = COL_SKIRT
	_floor_layer.add_child(board)


## Окна на наружной задней стене: сколько влезет по длине ребра.
func _build_interior(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var count := clampi(int(round(length / 190.0)), 1, 3)
	var span := 1.0 / float(count)
	for i in count:
		var t0 := span * float(i) + span * 0.16
		var t1 := span * float(i + 1) - span * 0.16
		_build_window(a, b, t0, t1)


## Окно: ниша, рама с переплётом, подоконник и занавески.
func _build_window(a: Vector2, b: Vector2, t0: float, t1: float) -> void:
	var dir := b - a
	var p0 := a + dir * t0
	var p1 := a + dir * t1
	var lift := Vector2(0.0, -WALL_H)
	var lo := 0.16
	var hi := 0.76

	var glass := Polygon2D.new()
	glass.polygon = PackedVector2Array([
		p0 + lift * lo, p1 + lift * lo, p1 + lift * hi, p0 + lift * hi,
	])
	glass.color = COL_WINDOW
	_floor_layer.add_child(glass)

	var frame := Line2D.new()
	frame.points = PackedVector2Array([
		p0 + lift * lo, p1 + lift * lo, p1 + lift * hi, p0 + lift * hi,
		p0 + lift * lo,
	])
	frame.width = 4.0
	frame.default_color = COL_WINDOW_FRAME
	_floor_layer.add_child(frame)

	var mid := p0.lerp(p1, 0.5)
	var mullion := Line2D.new()
	mullion.points = PackedVector2Array([mid + lift * lo, mid + lift * hi])
	mullion.width = 3.0
	mullion.default_color = COL_WINDOW_FRAME
	_floor_layer.add_child(mullion)

	var cross_y := (lo + hi) * 0.5
	var cross := Line2D.new()
	cross.points = PackedVector2Array([
		p0 + lift * cross_y, p1 + lift * cross_y,
	])
	cross.width = 3.0
	cross.default_color = COL_WINDOW_FRAME
	_floor_layer.add_child(cross)

	var sill := Line2D.new()
	sill.points = PackedVector2Array([p0 + lift * lo, p1 + lift * lo])
	sill.width = 6.0
	sill.default_color = COL_WINDOW_FRAME
	_floor_layer.add_child(sill)

	var drape_width := dir.length() * 0.10
	_build_drape(p0, dir, drape_width, lo, hi)
	_build_drape(p1, -dir, drape_width, lo, hi)

	var valance := Polygon2D.new()
	valance.polygon = PackedVector2Array([
		p0 + lift * (hi + 0.02), p1 + lift * (hi + 0.02),
		p1 + lift * (hi + 0.16), p0 + lift * (hi + 0.16),
	])
	valance.color = COL_CURTAIN_DARK
	_floor_layer.add_child(valance)


## Драпировка занавески у края окна. `dir` — внутрь окна.
func _build_drape(anchor: Vector2, dir: Vector2, width: float, lo: float, hi: float) -> void:
	var lift := Vector2(0.0, -WALL_H)
	var inward := dir.normalized() * width
	var drape := Polygon2D.new()
	drape.polygon = PackedVector2Array([
		anchor + lift * (lo - 0.04), anchor + inward + lift * (lo - 0.04),
		anchor + inward + lift * (hi + 0.14), anchor + lift * (hi + 0.14),
	])
	drape.color = COL_CURTAIN
	_floor_layer.add_child(drape)


## Место под мебель: ромб + контур + «плюс» в центре, чтобы было видно,
## куда можно ставить.
func _build_slots() -> void:
	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		var center: Vector2 = ISO.tile_center(slot["tx"], slot["ty"], slot["w"], slot["h"])
		var corners: PackedVector2Array = ISO.diamond(0, 0, slot["w"], slot["h"])

		var holder := Node2D.new()
		holder.position = center
		_slot_layer.add_child(holder)

		var fill := Polygon2D.new()
		fill.polygon = corners
		fill.color = COL_SLOT
		holder.add_child(fill)

		var outline := Line2D.new()
		var points := corners.duplicate()
		points.append(corners[0])
		outline.points = points
		outline.width = 3.0
		outline.default_color = COL_SLOT_LINE
		holder.add_child(outline)

		var mark := _build_slot_mark()
		holder.add_child(mark)

		_slot_nodes[slot_id] = fill
		_slot_lines[slot_id] = outline
		_slot_marks[slot_id] = mark


func _build_slot_mark() -> Node2D:
	var holder := Node2D.new()
	var half := 13.0
	var thickness := 5.0
	var bars := [
		PackedVector2Array([
			Vector2(-half, -thickness), Vector2(half, -thickness),
			Vector2(half, thickness), Vector2(-half, thickness),
		]),
		PackedVector2Array([
			Vector2(-thickness, -half), Vector2(thickness, -half),
			Vector2(thickness, half), Vector2(-thickness, half),
		]),
	]
	for polygon in bars:
		var bar := Polygon2D.new()
		bar.polygon = polygon
		bar.color = COL_SLOT_LINE
		holder.add_child(bar)
	return holder


func _build_ui() -> void:
	# Кнопки — чистые PNG-спрайты (TextureButton + подпись поверх): ни StyleBox,
	# ни 9-slice, ни modulate, поэтому картинка ровно из файла.
	_back_button = Icons.plain_button("btn_blue", Vector2(88, 88))
	Icons.button_text(_back_button, "←", 30)
	_back_button.pressed.connect(close)
	add_child(_back_button)

	_reset_button = Icons.plain_button("popup_secondary_button", Vector2(160, 88))
	Icons.button_text(_reset_button, "Сброс", 20)
	_reset_button.pressed.connect(_fit_view)
	add_child(_reset_button)

	# Магазин: спрайт shop.png, подписи нет — только иконка из арта.
	_buy_button = Icons.plain_button("shop", Vector2(96, 96))
	_buy_button.pressed.connect(_open_catalog)
	add_child(_buy_button)

	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 12)
	_action_row.visible = false
	add_child(_action_row)

	_rotate_button = Icons.plain_button("popup_secondary_button", Vector2(220, 84))
	Icons.button_text(_rotate_button, "Повернуть", 22)
	_rotate_button.pressed.connect(_on_rotate_button)
	_action_row.add_child(_rotate_button)

	_remove_button = Icons.plain_button("popup_danger_button", Vector2(220, 84))
	Icons.button_text(_remove_button, "Снять", 22)
	_remove_button.pressed.connect(_on_remove_pressed)
	_action_row.add_child(_remove_button)

	_bar_panel = Panel.new()
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Icons.skin_panel(_bar_panel, "cafe_top_bar"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("F6E7D8")
		style.border_color = Color("D8C4AE")
		style.border_width_top = 2
		style.corner_radius_top_left = 18
		style.corner_radius_top_right = 18
		_bar_panel.add_theme_stylebox_override("panel", style)
	_bar_panel.clip_contents = true
	add_child(_bar_panel)

	_bar_hint = Label.new()
	_bar_hint.text = "Инвентарь"
	_bar_hint.add_theme_font_size_override("font_size", 20)
	_bar_hint.add_theme_color_override("font_color", Color("6B5A48"))
	_bar_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_panel.add_child(_bar_hint)

	_zoom_hint = Label.new()
	_zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint.add_theme_font_size_override("font_size", 18)
	_zoom_hint.add_theme_color_override("font_color", Color("8A7566"))
	_zoom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zoom_hint.visible = false
	add_child(_zoom_hint)

	# Подсказка на карте: где ставить предметы из инвентаря.
	_map_hint = Label.new()
	_map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_hint.add_theme_font_size_override("font_size", 19)
	_map_hint.add_theme_color_override("font_color", Color(0.42, 0.34, 0.26, 0.85))
	_map_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_map_hint)

	# Интерфейс рисуется поверх сцены (предметы могут перекрыть панель).
	for control in [
		_back_button, _reset_button, _buy_button,
		_action_row, _bar_panel, _zoom_hint, _map_hint,
	]:
		control.z_index = UI_Z

	_build_catalog()


## Высота панели инвентаря с учётом нижней вставки (home-индикатор).
func _bar_height() -> float:
	return BAR_HEIGHT + SAFE.insets().w


## Верхняя граница сцены с учётом вставки сверху (чолка/статус-бар).
func _top_limit() -> float:
	return TOP_SAFE + SAFE.insets().y


func _layout() -> void:
	var size := _viewport_size()
	var w := size.x
	var h := size.y
	var ins := SAFE.insets()
	var left := ins.x + 16.0
	var right := ins.z + 16.0
	var top := ins.y + 16.0
	var bar_h := _bar_height()

	_back_button.position = Vector2(left, top)
	_back_button.size = Vector2(88, 88)

	_reset_button.position = Vector2(w - right - 160.0, top)
	_reset_button.size = Vector2(160, 88)

	_bar_panel.position = Vector2(0, h - bar_h)
	_bar_panel.size = Vector2(w, bar_h)

	_bar_hint.position = Vector2(left, 12)
	_bar_hint.size = Vector2(w - left - right, 30)

	_buy_button.position = Vector2(w - right - 96.0, h - bar_h - 108.0)
	_buy_button.size = Vector2(96, 96)

	_action_row.position = Vector2(w * 0.5 - 226.0, h - bar_h - 96.0)
	_action_row.size = Vector2(452, 84)

	_zoom_hint.position = Vector2(left, top + 128.0)
	_zoom_hint.size = Vector2(w - left - right, 26)

	_map_hint.position = Vector2(left, top + 96.0)
	_map_hint.size = Vector2(w - left - right, 26)

	_layout_catalog()
	_layout_chips()
	_clamp_view()
	_update_rotate_button()


func _layout_chips() -> void:
	var chip_size := Vector2(104, 92)
	var gap := 10.0
	var ins := SAFE.insets()
	var left := ins.x + 16.0
	var right := ins.z + 16.0
	var origin := Vector2(left, 46)
	var width := _viewport_size().x - left - right
	var per_row := maxi(1, int(width / (chip_size.x + gap)))
	var visible_count := per_row * 2

	for i in _chip_nodes.size():
		var chip := _chip_nodes[i]
		var col := i % per_row
		var row: int = floori(float(i) / float(per_row))
		chip.position = origin + Vector2(col * (chip_size.x + gap), row * (chip_size.y + gap))
		chip.size = chip_size
		chip.visible = i < visible_count

	if _bar_hint != null:
		_bar_hint.text = _bar_hint_text(mini(visible_count, _chip_nodes.size()))


# --- Инвентарь ------------------------------------------------------------

func _rebuild_bar() -> void:
	for node in _chip_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_chip_nodes.clear()
	_chips.clear()

	var items: Array = Meta.unplaced_decor()

	for item in items:
		var decor_id := String(item["id"])
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("FFFFFF")
		style.border_color = Color("D8C4AE")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		chip.add_theme_stylebox_override("panel", style)
		_bar_panel.add_child(chip)

		var label := Label.new()
		label.text = String(item.get("short", decor_id))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color("4A3A2E"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 6
		label.offset_right = -6
		chip.add_child(label)

		_chip_nodes.append(chip)
		_chips.append({"id": decor_id, "node": chip, "style": style})

	_layout_chips()
	_refresh_chips()


## Подсветка выбранного (тапом) предмета в панели.
func _refresh_chips() -> void:
	for i in _chips.size():
		var entry := _chips[i]
		var style: StyleBoxFlat = entry.get("style")
		if style == null:
			continue
		var picked := String(entry["id"]) == _pick_decor
		style.bg_color = Color("FFF3D6") if picked else Color("FFFFFF")
		style.border_color = Color("E0A63C") if picked else Color("D8C4AE")
		style.set_border_width_all(3 if picked else 1)


## Подпись панели: если чипов больше, чем помещается в два ряда, пишем «видно N».
func _bar_hint_text(shown: int) -> String:
	var total := _chip_nodes.size()
	if total <= shown:
		return "Инвентарь — перетащите в кофейню (%d)" % total
	return "Инвентарь — перетащите в кофейню (видно %d из %d)" % [shown, total]


## Тап по предмету в панели: выбрать/снять выбор. Тап по «+» поставит его.
func _pick(decor_id: String) -> void:
	_pick_decor = "" if _pick_decor == decor_id else decor_id
	_refresh_chips()
	_refresh_slot_marks()


func _chip_at(pos: Vector2) -> String:
	for i in _chip_nodes.size():
		var node := _chip_nodes[i]
		if is_instance_valid(node) and node.visible and node.get_global_rect().has_point(pos):
			return String(_chips[i]["id"])
	return ""


func _bar_rect() -> Rect2:
	var bar_h := _bar_height()
	return Rect2(0, _viewport_size().y - bar_h, _viewport_size().x, bar_h)


# --- Предметы -------------------------------------------------------------

func _rebuild_items() -> void:
	for child in _item_layer.get_children():
		child.queue_free()

	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		var decor_id := Meta.slot_decor(slot_id)
		if decor_id.is_empty():
			continue
		var item: Dictionary = DATA.decor(decor_id)
		if item.is_empty():
			continue
		_item_layer.add_child(_make_item(decor_id, item, slot, Meta.slot_rot(slot_id)))


func _make_item(decor_id: String, item: Dictionary, slot: Dictionary, rot: int) -> Node2D:
	var range_size: Vector2i = DATA.rotated_size(item, rot)
	var root := Node2D.new()
	var center: Vector2 = ISO.tile_center(slot["tx"], slot["ty"], slot["w"], slot["h"])
	root.position = center
	root.z_index = 100 + int(center.y)

	var shadow := Polygon2D.new()
	shadow.polygon = ISO.diamond(0, 0, range_size.x, range_size.y)
	shadow.position = Vector2(0, 4)
	shadow.color = COL_SHADOW
	root.add_child(shadow)

	var path: String = DATA.decor_sprite(decor_id, rot)
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = true
			sprite.position = Vector2(0, -texture.get_height() * 0.5 + 10.0)
			root.add_child(sprite)
			return root

	# Заглушка, пока нет арта: ромб цвета + короткое имя.
	var placeholder := Polygon2D.new()
	placeholder.polygon = ISO.diamond(0, 0, range_size.x, range_size.y)
	placeholder.position = Vector2(0, -26)
	placeholder.color = _placeholder_color(decor_id)
	root.add_child(placeholder)

	var label := Label.new()
	label.text = String(item.get("short", decor_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("4A3A2E"))
	label.size = Vector2(150, 60)
	label.position = Vector2(-75, -56)
	label.pivot_offset = Vector2(75, 30)
	label.scale = Vector2(0.9, 0.9)
	root.add_child(label)
	return root


func _placeholder_color(decor_id: String) -> Color:
	var hue := float(abs(decor_id.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.28, 0.92)


# --- Выделение слотов -----------------------------------------------------

func _refresh_slot_marks() -> void:
	var drag_item: Dictionary = {}
	var active_decor := _drag_decor
	var active_rot := _drag_rot
	if active_decor.is_empty():
		active_decor = _pick_decor
		active_rot = 0
	if not active_decor.is_empty():
		drag_item = DATA.decor(active_decor)

	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		var node: Polygon2D = _slot_nodes.get(slot_id)
		if node == null:
			continue

		var occupied := not Meta.slot_decor(slot_id).is_empty()
		var color := COL_SLOT
		var show_mark := true

		if not drag_item.is_empty():
			if DATA.fits(drag_item, slot, active_rot):
				color = COL_SLOT_OK
			else:
				color = COL_SLOT_BAD
				show_mark = false
		elif slot_id == _selected_slot:
			color = COL_SLOT_SELECT
		elif occupied:
			color = COL_SLOT_OCCUPIED
			show_mark = false

		node.color = color

		var line: Line2D = _slot_lines.get(slot_id)
		if line != null:
			line.default_color = COL_SLOT_LINE if show_mark else Color(0, 0, 0, 0)

		var mark: Node2D = _slot_marks.get(slot_id)
		if mark != null:
			mark.visible = show_mark

	if _map_hint == null:
		return
	if not _drag_decor.is_empty():
		_map_hint.text = "Отпустите предмет на зелёное место"
		return
	if not _pick_decor.is_empty():
		_map_hint.text = "Тапните по зелёному «+», чтобы поставить"
		return

	var free_count := 0
	for slot in DATA.SLOTS:
		if Meta.slot_decor(String(slot["id"])).is_empty():
			free_count += 1
	_map_hint.text = (
		"Свободных мест: %d — тяните предмет на «+»" % free_count if free_count > 0 else ""
	)


# --- Ввод -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Пока открыт каталог, мир не трогаем: клики должны доходить до кнопок.
	if _catalog_open:
		_catalog_input(event)
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var handled := false
		if touch.pressed:
			handled = _press(touch.index, touch.position)
		else:
			handled = _release(touch.index, touch.position)
		if handled:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		if _drag(event.index, event.position):
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var handled := false
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_down = mouse.pressed
				if mouse.pressed:
					handled = _press(0, mouse.position)
				else:
					handled = _release(0, mouse.position)
			MOUSE_BUTTON_WHEEL_UP:
				if mouse.pressed:
					_zoom_at(mouse.position, ZOOM_STEP)
					handled = true
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse.pressed:
					_zoom_at(mouse.position, 1.0 / ZOOM_STEP)
					handled = true
		if handled:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_down:
		if _drag(0, (event as InputEventMouseMotion).position):
			get_viewport().set_input_as_handled()


func _press(index: int, pos: Vector2) -> bool:
	if _over_control(pos):
		return false

	_touches[index] = pos

	if _touches.size() >= 2:
		_cancel_drag()
		_mode = "pinch"
		_pinch_dist = _touch_distance()
		_pinch_zoom = _zoom
		_pinch_focus = _world_from_screen(_touch_mid())
		return true

	if _touches.size() != 1:
		return true

	_press_pos = pos
	_drag_pos = pos
	_moved = false

	if _bar_rect().has_point(pos):
		var decor_id := _chip_at(pos)
		if not decor_id.is_empty():
			_begin_drag(decor_id, "", pos)
			_mode = "drag"
		else:
			_mode = "ignore"
		return true

	if pos.y < _top_limit():
		_mode = "ignore"
		return true

	var slot_id := _occupied_at(pos)
	if not slot_id.is_empty():
		_begin_drag(Meta.slot_decor(slot_id), slot_id, pos)
		_mode = "drag"
	else:
		_mode = "pan"
		_pan_start = _pan
	return true


func _drag(index: int, pos: Vector2) -> bool:
	if not _touches.has(index):
		return false
	_touches[index] = pos

	if _mode == "pinch":
		if _touches.size() < 2:
			_mode = "ignore"
			return true
		var distance := _touch_distance()
		if _pinch_dist > 1.0:
			_zoom = clampf(_pinch_zoom * (distance / _pinch_dist), ZOOM_MIN, ZOOM_MAX)
		_pan = _touch_mid() - _pinch_focus * _zoom
		_update_transform()
		return true

	if _mode == "pan":
		var delta := pos - _press_pos
		if delta.length() > TAP_SLOP:
			_moved = true
		_pan = _pan_start + delta
		_update_transform()
		return true

	if _mode == "drag":
		_drag_pos = pos
		if (pos - _press_pos).length() > TAP_SLOP:
			_moved = true
		if _ghost != null:
			_ghost.position = _world_from_screen(pos)
		_update_rotate_button()
		return true

	return false


func _release(index: int, pos: Vector2) -> bool:
	if not _touches.has(index):
		return false
	_touches.erase(index)

	if _mode == "pinch":
		if _touches.size() < 2:
			_mode = "ignore"
		return true

	if _mode == "drag":
		var from_slot := _drag_from_slot
		var tapped := _drag_decor
		if _moved:
			_drop(pos)
		else:
			_cancel_drag()
			if not from_slot.is_empty():
				_select(from_slot)
			else:
				# Тап по предмету в панели — выбрать его.
				_pick(tapped)
		_mode = ""
		return true

	if _mode == "pan":
		if not _moved:
			_tap_floor(pos)
		_mode = ""
		return true

	_mode = ""
	return true


## Тап по пустому месту: ставим выбранный предмет, а если выбора нет —
## первый подходящий из инвентаря. Так тап по «+» всегда что-то делает.
func _tap_floor(pos: Vector2) -> void:
	if not _pick_decor.is_empty():
		var target := _free_slot_at(pos, _pick_decor)
		if not target.is_empty():
			_place_here(_pick_decor, target)
			return

	for item in Meta.unplaced_decor():
		var decor_id := String(item["id"])
		var target := _free_slot_at(pos, decor_id)
		if not target.is_empty():
			_place_here(decor_id, target)
			return

	_deselect()


func _place_here(decor_id: String, slot_id: String) -> void:
	_pick_decor = ""
	_refresh_chips()
	_refresh_slot_marks()
	decor_place_requested.emit(decor_id, slot_id, 0)


## Ближайший свободный слот, в который влезает предмет (для тапа по «+»).
func _free_slot_at(pos: Vector2, decor_id: String) -> String:
	var item: Dictionary = DATA.decor(decor_id)
	if item.is_empty():
		return ""
	var best := ""
	var best_distance := DROP_RADIUS
	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		if not Meta.slot_decor(slot_id).is_empty():
			continue
		if not DATA.fits(item, slot, 0):
			continue
		var distance := _slot_screen_center(slot).distance_to(pos)
		if distance <= best_distance:
			best_distance = distance
			best = slot_id
	return best


func _over_control(pos: Vector2) -> bool:
	if _catalog_open:
		return true
	for control in [_back_button, _reset_button, _buy_button]:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(pos):
			return true
	if _action_row.visible and _action_row.get_global_rect().has_point(pos):
		return true
	return false


func _touch_distance() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _touch_mid() -> Vector2:
	var points: Array = _touches.values()
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0] as Vector2
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


# --- Перетаскивание -------------------------------------------------------

func _begin_drag(decor_id: String, from_slot: String, pos: Vector2) -> void:
	_cancel_drag()
	_drag_decor = decor_id
	_drag_rot = Meta.slot_rot(from_slot) if not from_slot.is_empty() else 0
	_drag_from_slot = from_slot
	_drag_pos = pos
	# LIGHT-тик в момент захвата декора: тот же отклик, что и на доске.
	Haptics.selection()
	_deselect()
	_rebuild_ghost()
	_refresh_slot_marks()
	_update_rotate_button()


func _rebuild_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if _drag_decor.is_empty():
		return
	var item: Dictionary = DATA.decor(_drag_decor)
	if item.is_empty():
		return
	var fake_slot := {
		"tx": 0.0, "ty": 0.0, "w": item.get("w", 1), "h": item.get("h", 1), "room": ""
	}
	_ghost = _make_item(_drag_decor, item, fake_slot, _drag_rot)
	_ghost.z_index = 2500
	_ghost.modulate = Color(1, 1, 1, 0.72)
	_ghost.position = _world_from_screen(_drag_pos)
	_world.add_child(_ghost)


func _cancel_drag() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_drag_decor = ""
	_drag_rot = 0
	_drag_from_slot = ""
	if is_instance_valid(_action_row):
		_remove_button.visible = true
		_action_row.visible = not _selected_slot.is_empty()
	_refresh_slot_marks()


## Кнопка «Повернуть» работает и во время перетаскивания: пока тащим
## вращаемый предмет, она показывается на своём обычном месте в ряду
## действий (см. _layout), а не плавающей кнопкой рядом с предметом.
func _update_rotate_button() -> void:
	if not is_instance_valid(_action_row):
		return
	if _drag_decor.is_empty():
		# Вне перетаскивания ряд управляется выделением (_select/_deselect).
		return
	var item: Dictionary = DATA.decor(_drag_decor)
	var rotatable: bool = not item.is_empty() and DATA.is_rotatable(item)
	_rotate_button.visible = true
	_remove_button.visible = false
	_action_row.visible = rotatable


func _on_rotate_button() -> void:
	if not _drag_decor.is_empty():
		_drag_rot = (_drag_rot + 1) % 4
		_rebuild_ghost()
		_refresh_slot_marks()
		return
	_on_rotate_pressed()


func _drop(pos: Vector2) -> void:
	var decor_id := _drag_decor
	var rot := _drag_rot
	var target := _slot_at(pos, decor_id, rot)
	_cancel_drag()
	if not target.is_empty():
		decor_place_requested.emit(decor_id, target, rot)


func _slot_at(pos: Vector2, decor_id: String, rot: int) -> String:
	var item: Dictionary = DATA.decor(decor_id)
	if item.is_empty():
		return ""
	var best := ""
	var best_distance := DROP_RADIUS
	for slot in DATA.SLOTS:
		if not DATA.fits(item, slot, rot):
			continue
		var distance := _slot_screen_center(slot).distance_to(pos)
		if distance <= best_distance:
			best_distance = distance
			best = String(slot["id"])
	return best


func _occupied_at(pos: Vector2) -> String:
	var best := ""
	var best_distance := SLOT_HIT_RADIUS
	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		if Meta.slot_decor(slot_id).is_empty():
			continue
		var distance := _slot_screen_center(slot).distance_to(pos)
		if distance <= best_distance:
			best_distance = distance
			best = slot_id
	return best


func _slot_screen_center(slot: Dictionary) -> Vector2:
	var center: Vector2 = ISO.tile_center(slot["tx"], slot["ty"], slot["w"], slot["h"])
	return center * _zoom + _pan


# --- Выбор предмета -------------------------------------------------------

func _select(slot_id: String) -> void:
	_selected_slot = slot_id
	var decor_id := Meta.slot_decor(slot_id)
	var item: Dictionary = DATA.decor(decor_id)
	var rotatable: bool = DATA.is_rotatable(item)

	_rotate_button.visible = rotatable
	_rotate_button.disabled = not rotatable
	_action_row.visible = true
	_layout()
	_refresh_slot_marks()


func _deselect() -> void:
	_selected_slot = ""
	if is_instance_valid(_action_row):
		_action_row.visible = false
	_refresh_slot_marks()


func _on_rotate_pressed() -> void:
	if _selected_slot.is_empty():
		return
	decor_rotate_requested.emit(_selected_slot)


func _on_remove_pressed() -> void:
	if _selected_slot.is_empty():
		return
	var slot_id := _selected_slot
	_deselect()
	decor_clear_requested.emit(slot_id)


# --- Камера ---------------------------------------------------------------

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _world_from_screen(pos: Vector2) -> Vector2:
	return (pos - _pan) / _zoom


func _update_transform() -> void:
	_world.position = _pan
	_world.scale = Vector2(_zoom, _zoom)
	_update_zoom_hint()


## Прямоугольник плана в мировых координатах (по всем комнатам).
func _plan_bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for room in DATA.ROOMS:
		var center: Vector2 = ISO.tile_center(room["tx"], room["ty"], room["w"], room["h"])
		var corners: PackedVector2Array = ISO.diamond(
			room["tx"], room["ty"], room["w"], room["h"]
		)
		for corner in corners:
			var point: Vector2 = center + corner
			min_point = min_point.min(point)
			max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _fit_view() -> void:
	var size := _viewport_size()
	if size.x <= 0 or size.y <= 0:
		return

	var bounds := _plan_bounds()
	var span := bounds.size
	if span.x <= 0 or span.y <= 0:
		_zoom = 1.0
		_pan = size * 0.5
		_update_transform()
		return

	var top_limit := _top_limit()
	var available := Vector2(size.x - 32.0, size.y - _bar_height() - top_limit - 32.0)
	var fit: float = minf(available.x / span.x, available.y / span.y)
	# Ограничиваем отдаление: по короткой стороне экрана должно влезать
	# не больше `_max_zoom_span` тайлов, иначе кофейня превращается в точку.
	var short_side: float = minf(size.x, size.y)
	var soft_max: float = short_side / (_max_zoom_span * float(ISO.TILE_W))
	_zoom = clampf(minf(fit, soft_max), ZOOM_MIN, ZOOM_MAX)
	var screen_center := Vector2(size.x * 0.5, top_limit + available.y * 0.5)
	_pan = screen_center - bounds.get_center() * _zoom
	_update_transform()


## Не даёт утащить план далеко за пределы экрана при сильном отдалении.
func _clamp_view() -> void:
	var size := _viewport_size()
	if size.x <= 0 or size.y <= 0:
		return
	var bounds := _plan_bounds()
	var ratio := _zoom / ZOOM_MIN
	var min_x := size.x - bounds.end.x * ratio
	var max_x := -bounds.position.x * ratio
	var min_y := size.y - bounds.end.y * ratio
	var max_y := -bounds.position.y * ratio
	_pan.x = clampf(_pan.x, min_x, max_x) if min_x < max_x else (min_x + max_x) * 0.5
	_pan.y = clampf(_pan.y, min_y, max_y) if min_y < max_y else (min_y + max_y) * 0.5
	_update_transform()


func _center_view() -> void:
	var size := _viewport_size()
	var bounds := _plan_bounds()
	var top_limit := _top_limit()
	var visible_height := size.y - _bar_height() - top_limit
	_pan = Vector2(size.x * 0.5, top_limit + visible_height * 0.5) - bounds.get_center() * _zoom
	_update_transform()


func _zoom_at(focal: Vector2, factor: float) -> void:
	var world_point := _world_from_screen(focal)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_pan = focal - world_point * _zoom
	_update_transform()


## Подсказка про отдаление: напоминает, что сдвигать можно двумя пальцами.
func _update_zoom_hint() -> void:
	if _zoom_hint == null:
		return
	var span_tiles: float = _viewport_size().x / (_zoom * float(ISO.TILE_W))
	if _zoom <= ZOOM_MIN + 0.02:
		_zoom_hint.text = "Максимально отдалено — сдвиньте двумя пальцами"
	elif span_tiles < 3.2:
		_zoom_hint.text = "Близко — сдвиньте двумя пальцами, чтобы отъехать"
	else:
		_zoom_hint.text = ""
	_zoom_hint.visible = not _zoom_hint.text.is_empty()


# --- Сигналы Meta ---------------------------------------------------------

func _on_placement_changed(_slot_id: String, _decor_id: String) -> void:
	_rebuild_items()
	_rebuild_bar()
	_refresh_slot_marks()


func _on_rotation_changed(_slot_id: String, _rot: int) -> void:
	_rebuild_items()


func _on_decor_changed(_item: Dictionary) -> void:
	_rebuild_bar()
	if _catalog_open:
		_rebuild_catalog()


# --- Каталог мебели: покупка только здесь, внутри кофейни ------------------

func _build_catalog() -> void:
	_catalog_root = Control.new()
	_catalog_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catalog_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_catalog_root.visible = false
	_catalog_root.z_index = CATALOG_Z
	add_child(_catalog_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_catalog_root.add_child(dim)

	_catalog_panel = Panel.new()
	if not Icons.skin_panel(_catalog_panel, "popup_panel"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("F6E7D8")
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		_catalog_panel.add_theme_stylebox_override("panel", style)
	_catalog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_catalog_root.add_child(_catalog_panel)

	var title := Label.new()
	title.text = "Магазин мебели"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("4A3A2E"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 56.0
	title.offset_right = -56.0
	title.offset_top = 16.0
	title.offset_bottom = 66.0
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_catalog_panel.add_child(title)

	# Монеты нужны игроку прямо во время покупки: плашка счётчика + крупное
	# число, а не мелкая серая подпись под заголовком.
	var counter := TextureRect.new()
	counter.texture = Icons.art("cafe_coin_counter")
	counter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	counter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if counter.texture == null:
		counter.texture = Icons.art("icon_coin_main", Vector2(45.0, 45.0))
		counter.offset_left = 56.0
		counter.offset_top = 64.0
		counter.offset_right = 88.0
		counter.offset_bottom = 96.0
	else:
		counter.offset_left = 56.0
		counter.offset_top = 72.0
		counter.offset_right = 281.0
		counter.offset_bottom = 117.0
	_catalog_panel.add_child(counter)

	_catalog_coins = Label.new()
	_catalog_coins.add_theme_font_size_override("font_size", 28)
	_catalog_coins.add_theme_color_override("font_color", Color("4A3A2E"))
	_catalog_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catalog_coins.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_catalog_coins.offset_left = 106.0
	_catalog_coins.offset_right = -56.0
	_catalog_coins.offset_top = 72.0
	_catalog_coins.offset_bottom = 117.0
	_catalog_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_catalog_panel.add_child(_catalog_coins)

	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_catalog_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catalog_scroll.offset_left = 56.0
	_catalog_scroll.offset_right = -56.0
	_catalog_scroll.offset_top = 148.0
	_catalog_scroll.offset_bottom = -152.0
	_catalog_panel.add_child(_catalog_scroll)

	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_list.add_theme_constant_override("separation", 10)
	_catalog_scroll.add_child(_catalog_list)

	var close_button := Icons.plain_button("popup_primary_button", Vector2(250, 84))
	Icons.button_text(close_button, "Закрыть", 26)
	close_button.pressed.connect(_close_catalog)
	close_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_button.offset_left = -125.0
	close_button.offset_right = 125.0
	close_button.offset_top = -140.0
	close_button.offset_bottom = -56.0
	_catalog_panel.add_child(close_button)


func _layout_catalog() -> void:
	if _catalog_panel == null:
		return
	var size := _viewport_size()
	var ins := SAFE.insets()
	var panel_w: float = minf(size.x - 24.0, 660.0)
	var panel_h: float = minf(size.y - 80.0 - ins.y - ins.w, 1040.0)
	_catalog_panel.size = Vector2(panel_w, panel_h)
	_catalog_panel.position = Vector2(
		(size.x - panel_w) * 0.5, (size.y - panel_h) * 0.5 + ins.y * 0.5
	)


func _open_catalog() -> void:
	if _catalog_root == null:
		return
	_cancel_drag()
	_deselect()
	_pick_decor = ""
	_rebuild_catalog()
	_catalog_root.visible = true
	_catalog_open = true


func _close_catalog() -> void:
	if not _catalog_open:
		return
	_catalog_open = false
	if _catalog_root != null:
		_catalog_root.visible = false


## Монеты в каталоге: обновляем при открытии, после покупки и на лету —
## баланс мог поменяться, пока окно магазина открыто.
func _refresh_catalog_coins(force := false) -> void:
	if _catalog_coins == null:
		return
	var coins := int(SaveManager.get_value("coins", 0))
	if not force and coins == _catalog_coins_value:
		return
	_catalog_coins_value = coins
	_catalog_coins.text = "%d" % coins


func _process(_delta: float) -> void:
	if _catalog_open:
		_refresh_catalog_coins()


func _rebuild_catalog() -> void:
	if _catalog_list == null:
		return
	for child in _catalog_list.get_children():
		_catalog_list.remove_child(child)
		child.queue_free()
	_refresh_catalog_coins(true)

	for item in DATA.DECOR:
		var decor: Dictionary = item
		var decor_id := String(decor.get("id", ""))
		var owned := Meta.owns_decor(decor_id)

		# Ряд: слева портретная арт-карточка 185x250 (пропорция арта),
		# справа текст и кнопка покупки — так карточка не растягивается.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_catalog_list.add_child(row)

		_catalog_card(row)

		# Текст держим в info, а не внутри узкой арт-карточки: в 185 px
		# название и XP ломались на три строки и вылезали за карточку.
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation", 8)
		row.add_child(info)

		var name_label := _catalog_line(info, String(decor.get("name", "")), 24,
			Color("4A3A2E") if owned else Color("8A7566"))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_catalog_line(info, "%s · +%d XP" % [
			String(decor.get("room", "")), int(decor.get("xp", 0)),
		], 18, Color("8A7566"))

		# Покупка — тоже чистый спрайт; подпись (и монета для цены) кладём поверх
		# отдельным оверлеем: у TextureButton нет ни текста, ни icon.
		var buy := Icons.plain_button("popup_primary_button", Vector2(250, 84))
		buy.disabled = owned
		if owned:
			Icons.button_text(buy, "Куплено", 24)
		else:
			var overlay := CenterContainer.new()
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buy.add_child(overlay)
			overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			var line := Icons.icon_label("coin", "Купить · %d" % int(decor.get("cost", 0)),
				24.0, Icons.DEFAULT_TINT, 24)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(line)
		buy.pressed.connect(func() -> void: decor_buy_requested.emit(decor_id))
		info.add_child(buy)


func _catalog_card(parent: Node) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(185, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not Icons.skin_panel(panel, "cafe_product_card"):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("FFFBF5")
		flat.set_corner_radius_all(16)
		panel.add_theme_stylebox_override("panel", flat)
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14.0
	column.offset_right = -14.0
	column.offset_top = 14.0
	column.offset_bottom = -14.0
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	return column


func _catalog_line(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## Каталог — обычный Control, поэтому _input должен сам крутить список
## свайпом: ScrollContainer левый драг не листает (как и в meta_popup).
func _catalog_input(event: InputEvent) -> void:
	if _catalog_scroll == null:
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _catalog_scroll.get_global_rect().has_point(drag.position):
			_catalog_scroll.scroll_vertical -= int(drag.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var on_scroll := _catalog_scroll.get_global_rect().has_point(motion.position)
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and on_scroll:
			_catalog_scroll.scroll_vertical -= int(motion.relative.y)
			get_viewport().set_input_as_handled()

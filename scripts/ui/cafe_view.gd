extends CanvasLayer

## Изометрическая кофейня (GDD §8): панорама, зум, инвентарь, расстановка.
##
## Экран собирается кодом, как и остальные попапы проекта. Мир — обычный
## Node2D-слой, к которому применяются `position` (пан) и `scale` (зум).
## Экранные координаты: `screen = world * zoom + pan`.
##
## Управление:
##   один палец по полу/пустому месту — панорама;
##   один палец по предмету — перенос (снап к тайлам, у края экрана план
##     едет сам; над панелью инвентаря — убрать предмет в инвентарь);
##   два пальца — панорама + пинч-зум;
##   колесо мыши (десктоп) — зум вокруг курсора;
##   тап по предмету — выбор (кнопки «Повернуть» / «В инвентарь»);
##   перетаскивание из нижней панели (или тап по чипу, потом по полу) —
##     поставить предмет. Расстановка свободная: куда угодно, где есть место.
##
## Сцена ничего не сохраняет: она только просит `game.gd`, а тот зовёт `Meta`
## и логирует аналитику. Ответ приходит обратно сигналами `Meta`.

signal closed
signal decor_place_requested(decor_id: String, tile: Vector2i, rot: int)
signal decor_remove_requested(decor_id: String)
signal decor_rotate_requested(decor_id: String)
## Кнопка магазина в кофейне открывает магазин мебели (покупка за монеты, game.gd).
signal shop_requested

const DATA := preload("res://scripts/data/meta.gd")
const ISO := preload("res://scripts/data/iso.gd")
const SAFE := preload("res://scripts/ui/safe_area.gd")
## Статичный мир (пол, стены, места) рисуется холстами, а не сотнями узлов.
const ISO_CANVAS := preload("res://scripts/ui/iso_canvas.gd")
## Интерфейс поверх мира (кнопки, подсказки, панель инвентаря) — сцена на
## контейнерах; каталог мебели — отдельный попап.
const CAFE_UI := preload("res://scenes/ui/cafe_ui.tscn")
## Отступ интерфейса от краёв экрана (поверх вставок safe area).
const SCREEN_MARGIN := 16.0
## Чип инвентаря и зазор между чипами; видно два ряда. В чипе — картинка
## предмета высотой CHIP_ICON_H и подпись под ней.
const CHIP_SIZE := Vector2(104, 92)
const CHIP_ICON_H := 52.0
const CHIP_GAP := 10.0
const TAP_SLOP := 16.0
## Предел отдаления — доля от «весь план в экране» (_fit_zoom): чуть дальше
## полного вида отъехать можно, но план не превращается в точку.
const ZOOM_MIN_OF_FIT := 0.9
const ZOOM_MAX := 2.6
const ZOOM_STEP := 1.12
## Предмет из панели при перетаскивании висит над пальцем на столько пикселей.
const DRAG_LIFT := 70.0
## Палец с предметом ближе EDGE_PAN_ZONE к краю видимой области — план едет.
const EDGE_PAN_ZONE := 56.0
const EDGE_PAN_SPEED := 560.0
## Тап по полу с выбранным предметом: если ровно сюда не влезает — пробуем
## соседние тайлы в этом порядке.
const NEAR_SHIFTS: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
]

## Задние стены высокие — на них вешаем окна и занавески.
const WALL_H := 74.0
## Передние стены низкие: не закрывают мебель.
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
## Подсветка области на полу: куда встанет предмет / выбранный предмет.
const COL_AREA_OK := Color(0.32, 0.78, 0.42, 0.40)
const COL_AREA_OK_LINE := Color(0.22, 0.60, 0.30, 0.95)
const COL_AREA_BAD := Color(0.88, 0.30, 0.25, 0.32)
const COL_AREA_BAD_LINE := Color(0.75, 0.22, 0.18, 0.95)
const COL_AREA_SELECT := Color(1.0, 0.80, 0.30, 0.30)
const COL_AREA_SELECT_LINE := Color(0.90, 0.62, 0.12, 1.0)
const COL_GHOST_OK := Color(1, 1, 1, 0.85)
const COL_GHOST_BAD := Color(1.0, 0.6, 0.55, 0.7)
const COL_SELECTED_TINT := Color(1.12, 1.08, 0.96)
const COL_SHADOW := Color(0, 0, 0, 0.12)
## Масштаб спрайтов декора относительно PNG (см. _fit_sprite).
const DECOR_SCALE := 0.65

## У предметов z_index = 100 + мировая Y (до ~1124): интерфейс (cafe_ui.tscn)
## стоит на z 3000, каталог — на своём CanvasLayer выше кофейни.

var _world: Node2D
var _floor_layer: ISO_CANVAS
var _mark_layer: ISO_CANVAS
## Масштаб «весь план в экране»: от него считается предел отдаления.
var _fit_zoom := 1.0
## Последняя нарисованная подсветка (см. _refresh_marks).
var _marks_state := {}
var _item_layer: Node2D
var _bg: ColorRect

var _ui: Control
var _top: Control
var _bar: Control
var _bar_safe: MarginContainer
var _chips_grid: GridContainer
var _bar_hint: Label
var _chips: Array[Dictionary] = []
var _chip_nodes: Array[Control] = []
## Ромбы-заглушки для чипов предметов без арта: decor_id → текстура.
var _placeholder_icons := {}

var _back_button: BaseButton
var _reset_button: BaseButton
var _buy_button: BaseButton
var _action_row: Control
var _rotate_button: BaseButton
var _remove_button: BaseButton
var _map_hint: Label

## Попапы поверх кофейни (задаёт game.gd): пока любой открыт, мир не
## реагирует на касания.
var overlays: Array = []

var _zoom := 1.0
var _pan := Vector2.ZERO
var _needs_fit := true

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
## Тащим уже стоящий предмет (а не из панели).
var _drag_moving := false
var _drag_pos := Vector2.ZERO
## Куда встанет предмет: левый верхний тайл, можно ли, почему нельзя.
var _drag_tile := Vector2i.ZERO
var _drag_ok := false
var _drag_reason := ""
var _drag_over_world := false
var _drag_to_inventory := false
## Смещение центра предмета от пальца (в мире) — держим за точку захвата.
var _grab_offset := Vector2.ZERO
var _ghost: Node2D

## Предмет, выбранный тапом в панели: тап по «+» ставит его.
var _pick_decor := ""

var _selected_decor := ""
var _rebuild_queued := false
## Узлы поставленных предметов: decor_id → {node, rot} (см. _rebuild_items).
var _item_nodes := {}


func _ready() -> void:
	layer = 4
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_background()
	_build_world()
	_build_ui()

	Meta.placement_changed.connect(_on_placement_changed)
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
	_rebuild_items()
	_rebuild_bar()
	_refresh_marks()
	visible = true


func close() -> void:
	_deselect()
	_cancel_drag()
	_pick_decor = ""
	visible = false
	closed.emit()


# --- Сборка ---------------------------------------------------------------

func _build_background() -> void:
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Color("F3EDE4")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Фон обязан уйти под пол: слои мира живут в отрицательном z.
	# Без этого непрозрачный ColorRect на z=0 перекрывает пол и слоты.
	_bg.z_index = -2000
	add_child(_bg)


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	# Мир зумится (0.9×fit … 2.6): спрайты декора — с мипмапами, иначе рябят
	# при отдалении. Работает для текстур, импортированных с мипмапами.
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_world)

	# Пол, стены, окна, подписи комнат — статичны: один холст, рисуется один раз.
	_floor_layer = ISO_CANVAS.new()
	_floor_layer.name = "Floor"
	_floor_layer.z_index = -1000
	_world.add_child(_floor_layer)

	# Подсветка области под предметом: один холст, перерисовывается при смене.
	_mark_layer = ISO_CANVAS.new()
	_mark_layer.name = "Marks"
	_mark_layer.z_index = -50
	_world.add_child(_mark_layer)

	_item_layer = Node2D.new()
	_item_layer.name = "Items"
	_world.add_child(_item_layer)

	_build_floor()


func _build_floor() -> void:
	var canvas := _floor_layer
	_build_ground()

	for room in DATA.ROOMS:
		var center: Vector2 = ISO.tile_center(room["tx"], room["ty"], room["w"], room["h"])
		var polygon: PackedVector2Array = ISO.diamond(
			room["tx"], room["ty"], room["w"], room["h"]
		)
		canvas.poly(polygon, Color(room["floor"]), center)
		# Контур комнаты — читается как стена пола и отделяет Зал/Кухню/Террасу/Сад.
		canvas.line(polygon, COL_FLOOR_BORDER, 4.0, center, true)
		canvas.text(String(room["name"]), center + Vector2(0, -ISO.TILE_H * 0.5), 26,
			Color(0.35, 0.28, 0.20, 0.65))

	_build_grid()
	_build_walls()


## Тайловая сетка поверх пола: помогает глазами понять масштаб места.
func _build_grid() -> void:
	var canvas := _floor_layer
	var min_t := Vector2i(9999, 9999)
	var max_t := Vector2i(-9999, -9999)
	for room in DATA.ROOMS:
		min_t.x = mini(min_t.x, int(room["tx"]))
		min_t.y = mini(min_t.y, int(room["ty"]))
		max_t.x = maxi(max_t.x, int(room["tx"]) + int(room["w"]))
		max_t.y = maxi(max_t.y, int(room["ty"]) + int(room["h"]))

	var grid_color := Color(0, 0, 0, 0.07)
	for tx in range(min_t.x, max_t.x + 1):
		canvas.line(PackedVector2Array([
			ISO.tile_to_screen(float(tx), float(min_t.y)),
			ISO.tile_to_screen(float(tx), float(max_t.y)),
		]), grid_color, 1.5)
	for ty in range(min_t.y, max_t.y + 1):
		canvas.line(PackedVector2Array([
			ISO.tile_to_screen(float(min_t.x), float(ty)),
			ISO.tile_to_screen(float(max_t.x), float(ty)),
		]), grid_color, 1.5)


## Общая плита под всем планом — читается как пол зала.
func _build_ground() -> void:
	var canvas := _floor_layer
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
	var plate := ISO.diamond(min_tx - pad, min_ty - pad, w, h)
	var center: Vector2 = ISO.tile_center(min_tx - pad, min_ty - pad, w, h)
	# Мягкая тень под всей плитой — план перестаёт «плавать» на фоне.
	canvas.poly(plate, Color(0, 0, 0, 0.08), center + Vector2(6, 12))
	canvas.poly(plate, COL_GROUND, center)
	canvas.line(plate, COL_FLOOR_BORDER, 5.0, center, true)


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
	var canvas := _floor_layer
	var height := WALL_H if back else WALL_FRONT_H
	var lift := Vector2(0.0, -height)
	canvas.poly(PackedVector2Array([a, b, b + lift, a + lift]), COL_WALL if back else COL_WALL_FRONT)
	canvas.line(PackedVector2Array([a + lift, b + lift]), COL_WALL_TOP, 5.0)


## Плинтус по низу задней стены — объём без спрайтов.
func _build_baseboard(a: Vector2, b: Vector2) -> void:
	var lift := Vector2(0.0, -WALL_H * 0.09)
	_floor_layer.poly(PackedVector2Array([a, b, b + lift, a + lift]), COL_SKIRT)


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
	var canvas := _floor_layer
	var dir := b - a
	var p0 := a + dir * t0
	var p1 := a + dir * t1
	var lift := Vector2(0.0, -WALL_H)
	var lo := 0.16
	var hi := 0.76
	var pane := PackedVector2Array([p0 + lift * lo, p1 + lift * lo, p1 + lift * hi, p0 + lift * hi])

	canvas.poly(pane, COL_WINDOW)
	canvas.line(pane, COL_WINDOW_FRAME, 4.0, Vector2.ZERO, true)
	var mid := p0.lerp(p1, 0.5)
	canvas.line(PackedVector2Array([mid + lift * lo, mid + lift * hi]), COL_WINDOW_FRAME, 3.0)
	var cross_y := (lo + hi) * 0.5
	canvas.line(PackedVector2Array([p0 + lift * cross_y, p1 + lift * cross_y]), COL_WINDOW_FRAME, 3.0)
	canvas.line(PackedVector2Array([p0 + lift * lo, p1 + lift * lo]), COL_WINDOW_FRAME, 6.0)

	var drape_width := dir.length() * 0.10
	_build_drape(p0, dir, drape_width, lo, hi)
	_build_drape(p1, -dir, drape_width, lo, hi)

	canvas.poly(PackedVector2Array([
		p0 + lift * (hi + 0.02), p1 + lift * (hi + 0.02),
		p1 + lift * (hi + 0.16), p0 + lift * (hi + 0.16),
	]), COL_CURTAIN_DARK)


## Драпировка занавески у края окна. `dir` — внутрь окна.
func _build_drape(anchor: Vector2, dir: Vector2, width: float, lo: float, hi: float) -> void:
	var lift := Vector2(0.0, -WALL_H)
	var inward := dir.normalized() * width
	_floor_layer.poly(PackedVector2Array([
		anchor + lift * (lo - 0.04), anchor + inward + lift * (lo - 0.04),
		anchor + inward + lift * (hi + 0.14), anchor + lift * (hi + 0.14),
	]), COL_CURTAIN)


## Подсветка на полу рисуется холстом _mark_layer (см. _draw_marks): область,
## куда встанет перетаскиваемый предмет (зелёная — можно, красная — нельзя),
## или рамка выбранного предмета. Одна область за раз.
func _draw_marks(state: Dictionary) -> void:
	var canvas := _mark_layer
	canvas.clear()
	if state.is_empty():
		return
	var area: Rect2i = state["area"]
	var center: Vector2 = ISO.tile_center(area.position.x, area.position.y, area.size.x, area.size.y)
	var corners: PackedVector2Array = ISO.diamond(0, 0, area.size.x, area.size.y)
	canvas.poly(corners, state["fill"], center)
	canvas.line(corners, state["line"], 4.0, center, true)


func _build_ui() -> void:
	_ui = CAFE_UI.instantiate()
	add_child(_ui)
	_top = _ui.get_node("%Top")
	_bar = _ui.get_node("%Bar")
	_bar_safe = _ui.get_node("%BarSafe")
	_chips_grid = _ui.get_node("%Chips")
	_bar_hint = _ui.get_node("%BarHint")
	_back_button = _ui.get_node("%Back")
	_reset_button = _ui.get_node("%Reset")
	_buy_button = _ui.get_node("%Shop")
	_action_row = _ui.get_node("%ActionRow")
	_rotate_button = _ui.get_node("%Rotate")
	_remove_button = _ui.get_node("%Remove")
	_map_hint = _ui.get_node("%MapHint")

	_back_button.pressed.connect(close)
	_reset_button.pressed.connect(_fit_view)
	_buy_button.pressed.connect(func() -> void: shop_requested.emit())
	_rotate_button.pressed.connect(_on_rotate_button)
	_remove_button.pressed.connect(_on_remove_pressed)


## Высота панели инвентаря (вместе с нижней вставкой home-индикатора).
func _bar_height() -> float:
	return _bar.size.y if _bar.size.y > 0.0 else 300.0 + SAFE.insets().w


## Нижняя граница верхнего ряда кнопок: выше — не мир, а интерфейс.
func _top_limit() -> float:
	if _top.size.y > 0.0:
		return _top.get_global_rect().end.y
	return 104.0 + SAFE.insets().y


## Раскладку делают контейнеры сцены; здесь — только safe area и число
## колонок инвентаря (зависит от ширины экрана).
func _layout() -> void:
	SAFE.apply_margins(_ui.get_node("%Safe") as MarginContainer, SCREEN_MARGIN)
	var ins := SAFE.insets()
	_bar_safe.add_theme_constant_override("margin_left", roundi(ins.x))
	_bar_safe.add_theme_constant_override("margin_right", roundi(ins.z))
	_bar_safe.add_theme_constant_override("margin_bottom", roundi(ins.w))
	_layout_chips()
	_fit_zoom = _compute_fit_zoom()
	_zoom = maxf(_zoom, _zoom_min())
	_clamp_view()
	_update_rotate_button()


## Сетка инвентаря: колонок столько, сколько влезает по ширине, рядов — два.
func _layout_chips() -> void:
	var ins := SAFE.insets()
	var bar_style := _bar.get_theme_stylebox("panel")
	var inner := _viewport_size().x - ins.x - ins.z
	if bar_style != null:
		inner -= bar_style.get_margin(SIDE_LEFT) + bar_style.get_margin(SIDE_RIGHT)
	var per_row := maxi(1, int((inner + CHIP_GAP) / (CHIP_SIZE.x + CHIP_GAP)))
	_chips_grid.columns = per_row
	var visible_count := per_row * 2
	for i in _chip_nodes.size():
		_chip_nodes[i].visible = i < visible_count
	_refresh_bar_hint()


# --- Инвентарь ------------------------------------------------------------

## Чип инвентаря: картинка предмета (ракурс «лицом к игроку») и подпись.
## Пока арта нет — цветной ромб-заглушка того же цвета, что и на полу.
func _rebuild_bar() -> void:
	for node in _chip_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_chip_nodes.clear()
	_chips.clear()

	for item in Meta.unplaced_decor():
		var decor_id := String(item["id"])
		var chip := PanelContainer.new()
		chip.name = "Chip_" + decor_id
		chip.theme_type_variation = &"Chip"
		chip.custom_minimum_size = CHIP_SIZE
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips_grid.add_child(chip)

		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		chip.add_child(box)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(0, CHIP_ICON_H)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.texture = _decor_texture(decor_id, 0)
		if icon.texture == null:
			icon.texture = _placeholder_icon(decor_id)
		box.add_child(icon)

		var label := Label.new()
		label.theme_type_variation = &"BodyLabel"
		label.add_theme_font_size_override("font_size", 15)
		label.text = String(item.get("short", decor_id))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		box.add_child(label)

		_chip_nodes.append(chip)
		_chips.append({"id": decor_id, "node": chip})

	_layout_chips()
	_refresh_chips()


## Заглушка для чипа: ромб цвета предмета (как на полу), один на предмет.
func _placeholder_icon(decor_id: String) -> Texture2D:
	if _placeholder_icons.has(decor_id):
		return _placeholder_icons[decor_id]
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color := _placeholder_color(decor_id)
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


## Чипы: выбранный тапом — подсвечен, перетаскиваемый — полупрозрачный.
func _refresh_chips() -> void:
	for entry in _chips:
		var chip: Control = entry["node"]
		if not is_instance_valid(chip):
			continue
		var decor_id := String(entry["id"])
		chip.theme_type_variation = &"ChipSelected" if decor_id == _pick_decor else &"Chip"
		var dragged := decor_id == _drag_decor and not _drag_moving and _moved
		chip.modulate = Color(1, 1, 1, 0.4) if dragged else Color.WHITE


## Подпись панели: что с ней делать сейчас, сколько предметов, сколько видно.
func _refresh_bar_hint() -> void:
	if _bar_hint == null:
		return
	var total := _chip_nodes.size()
	var shown := mini(total, _chips_grid.columns * 2)
	if _drag_moving and _moved:
		_bar_hint.text = "Отпустите — уберём в инвентарь" if _drag_to_inventory \
			else "Сюда — убрать в инвентарь"
	elif total == 0:
		_bar_hint.text = "Инвентарь пуст — новая мебель в магазине"
	elif total <= shown:
		_bar_hint.text = "Инвентарь (%d) — тяните на пол или тапните" % total
	else:
		_bar_hint.text = "Инвентарь (видно %d из %d) — тяните на пол" % [shown, total]
	# Над панелью тащат поставленный предмет — подсвечиваем её как цель.
	_bar.modulate = Color(1.12, 1.06, 0.92) if _drag_to_inventory else Color.WHITE


## Тап по предмету в панели: выбрать/снять выбор. Тап по полу поставит его.
func _pick(decor_id: String) -> void:
	_pick_decor = "" if _pick_decor == decor_id else decor_id
	_deselect()
	_refresh_chips()
	_refresh_marks()


func _chip_at(pos: Vector2) -> String:
	for i in _chip_nodes.size():
		var node := _chip_nodes[i]
		if is_instance_valid(node) and node.visible and node.get_global_rect().has_point(pos):
			return String(_chips[i]["id"])
	return ""


func _bar_rect() -> Rect2:
	return _bar.get_global_rect()


# --- Предметы -------------------------------------------------------------

## Узлы предметов не пересобираются целиком: держим их по decor_id и трогаем
## только изменившиеся (переезд — та же нода на новом месте, поворот — та же
## нода с другой текстурой и тенью, убранный предмет — нода удаляется).
func _rebuild_items() -> void:
	var seen := {}
	for key in Meta.placed:
		var decor_id := String(key)
		var item: Dictionary = DATA.decor(decor_id)
		if item.is_empty():
			continue
		seen[decor_id] = true
		var rot := Meta.decor_rot(decor_id)
		var entry: Dictionary = _item_nodes.get(decor_id, {})
		# Без типа: освобождённый узел в типизированную переменную не присвоить.
		var node: Variant = entry.get("node")
		if is_instance_valid(node) and int(entry["rot"]) != rot \
				and not _apply_rot(node as Node2D, decor_id, item, rot):
			_free_node(node as Node)
			node = null
		if not is_instance_valid(node):
			node = _make_item(decor_id, item, rot)
			(node as Node2D).name = "Decor_" + decor_id
			_item_layer.add_child(node as Node2D)
		_item_nodes[decor_id] = {"node": node, "rot": rot}
		_place_node(node as Node2D, Meta.decor_area(decor_id))
		# Пока предмет переносят, на старом месте его нет — виден «призрак».
		(node as Node2D).visible = not (_drag_moving and _drag_decor == decor_id and _moved)

	for decor_id in _item_nodes.keys():
		if seen.has(decor_id):
			continue
		var stale: Variant = _item_nodes[decor_id].get("node")
		if is_instance_valid(stale):
			_free_node(stale as Node)
		_item_nodes.erase(decor_id)
	_refresh_item_highlight()


## Нода предмета — в центр его области; z по экранной Y: кто ниже на экране,
## тот ближе к зрителю и рисуется поверх.
func _place_node(root: Node2D, area: Rect2i) -> void:
	root.position = ISO.tile_center(area.position.x, area.position.y, area.size.x, area.size.y)
	root.z_index = 100 + int(root.position.y)


## Выбранный предмет чуть светлее остальных (плюс рамка на полу).
func _refresh_item_highlight() -> void:
	for decor_id in _item_nodes:
		var node: Variant = _item_nodes[decor_id].get("node")
		if is_instance_valid(node):
			(node as Node2D).modulate = COL_SELECTED_TINT if decor_id == _selected_decor else Color.WHITE


## Поворот на месте: тень и спрайт/заглушка того же узла. false — вид узла
## меняется (арт появился или пропал), его проще собрать заново.
func _apply_rot(root: Node2D, decor_id: String, item: Dictionary, rot: int) -> bool:
	var range_size: Vector2i = DATA.rotated_size(item, rot)
	var texture := _decor_texture(decor_id, rot)
	var sprite := root.get_node_or_null("Sprite") as Sprite2D
	var placeholder := root.get_node_or_null("Placeholder") as Polygon2D
	if (texture != null) != (sprite != null):
		return false
	if texture != null:
		_fit_sprite(sprite, texture)
	elif placeholder != null:
		placeholder.polygon = ISO.diamond(0, 0, range_size.x, range_size.y)
	else:
		return false
	var shadow := root.get_node_or_null("Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = ISO.diamond(0, 0, range_size.x, range_size.y)
	return true


## Спрайт предмета для поворота или null, если арта нет.
func _decor_texture(decor_id: String, rot: int) -> Texture2D:
	var path: String = DATA.decor_sprite(decor_id, rot)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Спрайт стоит низом на центре места. Арт декора нарисован крупнее тайла
## (стул выше двух клеток) — ужимаем общим масштабом, пропорции между
## предметами сохраняются.
func _fit_sprite(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.scale = Vector2.ONE * DECOR_SCALE
	sprite.position = Vector2(0, (-texture.get_height() * 0.5 + 10.0) * DECOR_SCALE)


## queue_free отработает в конце кадра: имя освобождаем сразу, его ждёт
## новый узел того же предмета.
static func _free_node(node: Node) -> void:
	node.name = "Freed_%d" % node.get_instance_id()
	node.queue_free()


## Нода предмета с центром в (0, 0) — ставит её на место _place_node.
func _make_item(decor_id: String, item: Dictionary, rot: int) -> Node2D:
	var range_size: Vector2i = DATA.rotated_size(item, rot)
	var root := Node2D.new()

	# Имена детей нужны _apply_rot (поворот без пересборки узла).
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.polygon = ISO.diamond(0, 0, range_size.x, range_size.y)
	shadow.position = Vector2(0, 4)
	shadow.color = COL_SHADOW
	root.add_child(shadow)

	var texture := _decor_texture(decor_id, rot)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = true
		_fit_sprite(sprite, texture)
		root.add_child(sprite)
		return root

	# Заглушка, пока нет арта: ромб цвета + короткое имя.
	var placeholder := Polygon2D.new()
	placeholder.name = "Placeholder"
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


func _decor_name(decor_id: String) -> String:
	return DATA.decor_short(DATA.decor(decor_id))


## Предмет под пальцем: сначала по картинке (верх шкафа тоже «он»), из
## перекрывающихся — ближний к зрителю; мимо картинок — по тайлу на полу.
func _item_at(pos: Vector2) -> String:
	var best := ""
	var best_z := -1
	for decor_id in _item_nodes:
		var node: Variant = _item_nodes[decor_id].get("node")
		if not is_instance_valid(node):
			continue
		var root := node as Node2D
		if not root.visible or root.z_index <= best_z:
			continue
		var sprite := root.get_node_or_null("Sprite") as Sprite2D
		if sprite == null:
			continue
		var rect: Rect2 = sprite.get_global_transform() * sprite.get_rect()
		if rect.grow(-4.0).has_point(pos):
			best = String(decor_id)
			best_z = root.z_index
	if best.is_empty():
		best = Meta.decor_at(_tile_at(pos))
	return best


## Тайл под экранной точкой.
func _tile_at(pos: Vector2) -> Vector2i:
	var tile := ISO.screen_to_tile(_world_from_screen(pos))
	return Vector2i(floori(tile.x), floori(tile.y))


## Левый верхний тайл области `size`, центр которой ближе всего к точке мира.
func _anchor_for(world: Vector2, size: Vector2i) -> Vector2i:
	var tile := ISO.screen_to_tile(world)
	return Vector2i(roundi(tile.x - size.x * 0.5), roundi(tile.y - size.y * 0.5))


# --- Подсветка и подсказки ------------------------------------------------

func _refresh_marks() -> void:
	var state := {}
	if not _drag_decor.is_empty() and _moved and _drag_over_world:
		var size := DATA.rotated_size(DATA.decor(_drag_decor), _drag_rot)
		state = {
			"area": Rect2i(_drag_tile, size),
			"fill": COL_AREA_OK if _drag_ok else COL_AREA_BAD,
			"line": COL_AREA_OK_LINE if _drag_ok else COL_AREA_BAD_LINE,
		}
	elif not _selected_decor.is_empty() and Meta.is_placed(_selected_decor):
		state = {
			"area": Meta.decor_area(_selected_decor),
			"fill": COL_AREA_SELECT,
			"line": COL_AREA_SELECT_LINE,
		}
	# Холст перерисовывается, только если подсветка реально поменялась.
	if state != _marks_state:
		_marks_state = state
		_draw_marks(state)
	_refresh_hint()


## Подсказка сверху — всегда про то, что игрок может сделать прямо сейчас.
func _refresh_hint() -> void:
	if _map_hint == null:
		return
	var text := ""
	if not _drag_decor.is_empty() and _moved:
		if _drag_to_inventory:
			text = "Отпустите — предмет вернётся в инвентарь"
		elif not _drag_over_world:
			text = "Тяните на пол кофейни"
		elif _drag_ok:
			text = "Отпустите, чтобы поставить"
		else:
			text = _drag_reason
	elif not _pick_decor.is_empty():
		text = "Тапните по полу — поставим «%s»" % _decor_name(_pick_decor)
	elif not _selected_decor.is_empty():
		text = "«%s»: тяните, чтобы передвинуть" % _decor_name(_selected_decor)
	elif not Meta.unplaced_decor().is_empty():
		text = "Тяните мебель из инвентаря на любое свободное место"
	elif Meta.placed_count() > 0:
		text = "Нажмите на мебель, чтобы передвинуть, повернуть или убрать"
	_map_hint.text = text
	_map_hint.visible = not text.is_empty()


# --- Ввод -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Пока поверх открыт попап (магазин), мир не трогаем: клики — его кнопкам.
	if _overlay_open():
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

	# Палец уже пришёл как ScreenTouch/ScreenDrag; его эмулированную копию-мышь
	# пропускаем, иначе каждое касание обрабатывалось дважды (захват, вибрация,
	# пересборка «призрака» предмета).
	if (event is InputEventMouseButton or event is InputEventMouseMotion) \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
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
			_begin_drag(decor_id, false, pos)
			_mode = "drag"
		else:
			_mode = "ignore"
		return true

	if pos.y < _top_limit():
		_mode = "ignore"
		return true

	var hit := _item_at(pos)
	if not hit.is_empty():
		_begin_drag(hit, true, pos)
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
			_zoom = clampf(_pinch_zoom * (distance / _pinch_dist), _zoom_min(), ZOOM_MAX)
		_pan = _touch_mid() - _pinch_focus * _zoom
		_clamp_view()
		return true

	if _mode == "pan":
		var delta := pos - _press_pos
		if delta.length() > TAP_SLOP:
			_moved = true
		_pan = _pan_start + delta
		_clamp_view()
		return true

	if _mode == "drag":
		_drag_pos = pos
		if not _moved and (pos - _press_pos).length() > TAP_SLOP:
			_moved = true
			_start_drag_visuals()
		if _moved:
			_update_drag()
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
		var decor_id := _drag_decor
		var moving := _drag_moving
		if _moved:
			_drop()
		else:
			_cancel_drag()
			if moving:
				_select(decor_id)
			else:
				# Тап по предмету в панели — выбрать его.
				_pick(decor_id)
		_mode = ""
		return true

	if _mode == "pan":
		if not _moved:
			_tap_floor(pos)
		_mode = ""
		return true

	_mode = ""
	return true


## Тап по полу: если в панели выбран предмет — ставим его сюда (или на
## ближайший свободный тайл рядом), иначе снимаем выбор.
func _tap_floor(pos: Vector2) -> void:
	if _pick_decor.is_empty():
		_deselect()
		return
	var decor_id := _pick_decor
	var size := DATA.rotated_size(DATA.decor(decor_id), 0)
	var base := _anchor_for(_world_from_screen(pos), size)
	var target := base
	for shift in NEAR_SHIFTS:
		if bool(Meta.can_place(decor_id, base + shift, 0).get("ok", false)):
			target = base + shift
			break
	_pick_decor = ""
	_refresh_chips()
	# Не влезло нигде рядом — game.gd покажет причину тостом.
	decor_place_requested.emit(decor_id, target, 0)
	if Meta.is_placed(decor_id):
		_select(decor_id)
	else:
		_refresh_marks()


func _over_control(pos: Vector2) -> bool:
	if _overlay_open():
		return true
	for control: Control in [_back_button, _reset_button, _buy_button, _action_row]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(pos):
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

## Захват предмета: из панели (moving = false) или уже стоящего на полу.
## Визуально перетаскивание начинается только когда палец сдвинулся
## (_start_drag_visuals) — простой тап остаётся тапом.
func _begin_drag(decor_id: String, moving: bool, pos: Vector2) -> void:
	_cancel_drag()
	_drag_decor = decor_id
	_drag_moving = moving
	_drag_rot = Meta.decor_rot(decor_id) if moving else 0
	_drag_pos = pos
	_drag_ok = false
	_drag_over_world = false
	_drag_to_inventory = false
	_drag_reason = ""
	_grab_offset = Vector2.ZERO
	if moving:
		# Предмет не «прыгает» центром под палец: держим его за ту точку,
		# за которую взяли.
		var area := Meta.decor_area(decor_id)
		_drag_tile = area.position
		var center: Vector2 = ISO.tile_center(area.position.x, area.position.y, area.size.x, area.size.y)
		_grab_offset = center - _world_from_screen(pos)
	# LIGHT-тик в момент захвата декора: тот же отклик, что и на доске.
	Haptics.selection()


func _start_drag_visuals() -> void:
	_pick_decor = ""
	_deselect()
	_rebuild_ghost()
	if _drag_moving:
		var entry: Dictionary = _item_nodes.get(_drag_decor, {})
		var node: Variant = entry.get("node")
		if is_instance_valid(node):
			(node as Node2D).visible = false
	_refresh_chips()
	_update_rotate_button()


## Пересчитать, куда встанет предмет под пальцем: тайл со снапом к сетке,
## можно ли туда, над панелью ли палец (убрать в инвентарь).
func _update_drag() -> void:
	if _drag_decor.is_empty():
		return
	var size := DATA.rotated_size(DATA.decor(_drag_decor), _drag_rot)
	var over_bar := _bar_rect().has_point(_drag_pos)
	_drag_to_inventory = _drag_moving and over_bar
	_drag_over_world = not over_bar and _drag_pos.y >= _top_limit()
	if _drag_over_world:
		# Из панели предмет «висит» над пальцем: иначе его не видно под ним.
		var lift := Vector2.ZERO if _drag_moving else Vector2(0.0, -DRAG_LIFT)
		var tile := _anchor_for(_world_from_screen(_drag_pos + lift) + _grab_offset, size)
		_drag_tile = tile
		var check := Meta.can_place(_drag_decor, tile, _drag_rot)
		_drag_ok = bool(check.get("ok", false))
		_drag_reason = String(check.get("reason", ""))
	if _ghost != null:
		_ghost.visible = _drag_over_world
		_ghost.position = ISO.tile_center(_drag_tile.x, _drag_tile.y, size.x, size.y)
		_ghost.z_index = 100 + int(_ghost.position.y)
		_ghost.modulate = COL_GHOST_OK if _drag_ok else COL_GHOST_BAD
	_refresh_marks()
	_refresh_bar_hint()


## Призрак — предмет «в руке»: стоит на тайлах, куда встанет, поверх соседей
## по глубине, полупрозрачный; красноватый, если туда нельзя.
func _rebuild_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_free_node(_ghost)
	_ghost = null
	if _drag_decor.is_empty():
		return
	var item: Dictionary = DATA.decor(_drag_decor)
	if item.is_empty():
		return
	_ghost = _make_item(_drag_decor, item, _drag_rot)
	_ghost.visible = false
	_ghost.name = "Ghost"
	_item_layer.add_child(_ghost)


func _cancel_drag() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_free_node(_ghost)
	_ghost = null
	var decor_id := _drag_decor
	var was_moving := _drag_moving
	_drag_decor = ""
	_drag_rot = 0
	_drag_moving = false
	_drag_ok = false
	_drag_over_world = false
	_drag_to_inventory = false
	_drag_reason = ""
	_moved = false
	if was_moving:
		var entry: Dictionary = _item_nodes.get(decor_id, {})
		var node: Variant = entry.get("node")
		if is_instance_valid(node):
			(node as Node2D).visible = true
	if is_instance_valid(_action_row):
		_remove_button.visible = true
		_action_row.visible = not _selected_decor.is_empty()
	_refresh_chips()
	_refresh_marks()
	if _bar_hint != null:
		_refresh_bar_hint()


## Кнопка «Повернуть» работает и во время перетаскивания: пока тащим
## вращаемый предмет, она показывается на своём обычном месте в ряду
## действий, а не плавающей кнопкой рядом с предметом.
func _update_rotate_button() -> void:
	if not is_instance_valid(_action_row):
		return
	if _drag_decor.is_empty() or not _moved:
		# Вне перетаскивания ряд управляется выделением (_select/_deselect).
		return
	var item: Dictionary = DATA.decor(_drag_decor)
	var rotatable: bool = not item.is_empty() and DATA.is_rotatable(item)
	_rotate_button.visible = true
	_rotate_button.disabled = false
	_remove_button.visible = false
	_action_row.visible = rotatable


func _on_rotate_button() -> void:
	if not _drag_decor.is_empty():
		_drag_rot = (_drag_rot + 1) % 4
		_rebuild_ghost()
		_update_drag()
		return
	_on_rotate_pressed()


## Отпустили: над панелью — убрать в инвентарь, над полом — поставить
## (если нельзя, game.gd скажет почему, а предмет останется где был).
func _drop() -> void:
	var decor_id := _drag_decor
	var rot := _drag_rot
	var tile := _drag_tile
	var moving := _drag_moving
	var to_inventory := _drag_to_inventory
	var over_world := _drag_over_world
	var unchanged := moving and Meta.decor_area(decor_id).position == tile \
		and Meta.decor_rot(decor_id) == rot
	_cancel_drag()
	if to_inventory:
		decor_remove_requested.emit(decor_id)
		return
	if not over_world:
		return
	if unchanged:
		_select(decor_id)
		return
	decor_place_requested.emit(decor_id, tile, rot)
	if Meta.is_placed(decor_id):
		_select(decor_id)


## Палец с предметом у края видимой области — план сам едет навстречу:
## можно дотащить мебель в дальнюю комнату без отдельной панорамы.
func _process(delta: float) -> void:
	if not visible or _mode != "drag" or _drag_decor.is_empty() or not _moved:
		return
	if _bar_rect().has_point(_drag_pos):
		return
	var view := _view_rect()
	var push := Vector2.ZERO
	if _drag_pos.x < view.position.x + EDGE_PAN_ZONE:
		push.x = 1.0
	elif _drag_pos.x > view.end.x - EDGE_PAN_ZONE:
		push.x = -1.0
	if _drag_pos.y < view.position.y + EDGE_PAN_ZONE:
		push.y = 1.0
	elif _drag_pos.y > view.end.y - EDGE_PAN_ZONE:
		push.y = -1.0
	if push == Vector2.ZERO:
		return
	var before := _pan
	_pan += push * EDGE_PAN_SPEED * delta
	_clamp_view()
	if _pan != before:
		_update_drag()


# --- Выбор предмета -------------------------------------------------------

func _select(decor_id: String) -> void:
	_selected_decor = decor_id
	var rotatable: bool = DATA.is_rotatable(DATA.decor(decor_id))
	_rotate_button.visible = rotatable
	_rotate_button.disabled = not rotatable
	_remove_button.visible = true
	_action_row.visible = true
	_refresh_item_highlight()
	_refresh_marks()


func _deselect() -> void:
	_selected_decor = ""
	if is_instance_valid(_action_row):
		_action_row.visible = false
	_refresh_item_highlight()
	_refresh_marks()


func _on_rotate_pressed() -> void:
	if _selected_decor.is_empty():
		return
	decor_rotate_requested.emit(_selected_decor)


func _on_remove_pressed() -> void:
	if _selected_decor.is_empty():
		return
	var decor_id := _selected_decor
	_deselect()
	decor_remove_requested.emit(decor_id)


# --- Камера ---------------------------------------------------------------

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _world_from_screen(pos: Vector2) -> Vector2:
	return (pos - _pan) / _zoom


func _update_transform() -> void:
	_world.position = _pan
	_world.scale = Vector2(_zoom, _zoom)


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
	# Плюс то, что выступает за комнаты: плита пола под планом (~0.9 тайла)
	# по краям и задние стены высотой WALL_H сверху.
	var rect := Rect2(min_point, max_point - min_point)
	return rect.grow_individual(ISO.TILE_W * 0.5, WALL_H + ISO.TILE_H * 0.5,
		ISO.TILE_W * 0.5, ISO.TILE_H * 0.5 + 12.0)


## Видимая область мира на экране: между верхним рядом кнопок и панелью
## инвентаря, с полями по краям.
func _view_rect() -> Rect2:
	var size := _viewport_size()
	var top := _top_limit() + 16.0
	var bottom := size.y - _bar_height() - 16.0
	return Rect2(16.0, top, size.x - 32.0, maxf(1.0, bottom - top))


## Масштаб «весь план в видимой области».
func _compute_fit_zoom() -> float:
	var span := _plan_bounds().size
	var view := _view_rect().size
	if span.x <= 0.0 or span.y <= 0.0:
		return 1.0
	return clampf(minf(view.x / span.x, view.y / span.y), 0.05, ZOOM_MAX)


## Предел отдаления: чуть дальше полного вида плана.
func _zoom_min() -> float:
	return _fit_zoom * ZOOM_MIN_OF_FIT


## Показать весь план по центру видимой области (открытие, кнопка «Сброс»).
func _fit_view() -> void:
	if _viewport_size().x <= 0.0:
		return
	_fit_zoom = _compute_fit_zoom()
	_zoom = _fit_zoom
	_pan = _view_rect().get_center() - _plan_bounds().get_center() * _zoom
	_update_transform()


## План нельзя увести за видимую область: больше неё — край плана не
## заходит внутрь области, меньше — план стоит по центру.
func _clamp_view() -> void:
	if _viewport_size().x <= 0.0:
		return
	var view := _view_rect()
	var bounds := _plan_bounds()
	var lo := view.end - bounds.end * _zoom
	var hi := view.position - bounds.position * _zoom
	_pan.x = clampf(_pan.x, lo.x, hi.x) if lo.x < hi.x else (lo.x + hi.x) * 0.5
	_pan.y = clampf(_pan.y, lo.y, hi.y) if lo.y < hi.y else (lo.y + hi.y) * 0.5
	_update_transform()


func _zoom_at(focal: Vector2, factor: float) -> void:
	var world_point := _world_from_screen(focal)
	_zoom = clampf(_zoom * factor, _zoom_min(), ZOOM_MAX)
	_pan = focal - world_point * _zoom
	_clamp_view()



# --- Сигналы Meta ---------------------------------------------------------

## Перенос шлёт один сигнал, но поворот со сдвигом и пачка изменений из
## магазина — несколько подряд: обновляем один раз в конце кадра. Пока
## кофейня закрыта — не обновляем вовсе: open() сверит предметы с Meta сам.
func _on_placement_changed(_decor_id: String) -> void:
	_queue_rebuild()


func _on_decor_changed(_item: Dictionary) -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not visible or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_now.call_deferred()


func _rebuild_now() -> void:
	_rebuild_queued = false
	if not visible:
		return
	if not _selected_decor.is_empty() and not Meta.is_placed(_selected_decor):
		_deselect()
	_rebuild_items()
	_rebuild_bar()
	_refresh_marks()


func _overlay_open() -> bool:
	for layer in overlays:
		if layer != null and (layer as CanvasLayer).visible:
			return true
	return false

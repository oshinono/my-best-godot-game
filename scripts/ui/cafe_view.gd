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
## Кнопка магазина в кофейне открывает «Ремонт» (задания за звёзды, game.gd).
signal tasks_requested

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
## Чип инвентаря и зазор между чипами; видно два ряда.
const CHIP_SIZE := Vector2(104, 92)
const CHIP_GAP := 10.0
const TAP_SLOP := 16.0
## Предел отдаления — доля от «весь план в экране» (_fit_zoom): чуть дальше
## полного вида отъехать можно, но план не превращается в точку.
const ZOOM_MIN_OF_FIT := 0.9
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

## У предметов z_index = 100 + мировая Y (до ~1124): интерфейс (cafe_ui.tscn)
## стоит на z 3000, каталог — на своём CanvasLayer выше кофейни.

var _world: Node2D
var _floor_layer: ISO_CANVAS
var _slot_layer: ISO_CANVAS
## Масштаб «весь план в экране»: от него считается предел отдаления.
var _fit_zoom := 1.0
## Последняя нарисованная подсветка мест: slot_id → [цвет, контур виден].
var _slot_states := {}
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
	_rebuild_items()
	_rebuild_bar()
	_refresh_slot_marks()
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

	# Пол, стены, окна, подписи комнат — статичны: один холст, рисуется один раз.
	_floor_layer = ISO_CANVAS.new()
	_floor_layer.z_index = -1000
	_world.add_child(_floor_layer)

	# Места под мебель: тоже один холст, перерисовывается при смене подсветки.
	_slot_layer = ISO_CANVAS.new()
	_slot_layer.z_index = -50
	_world.add_child(_slot_layer)

	_item_layer = Node2D.new()
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


## Места под мебель рисуются холстом _slot_layer (см. _draw_slots): ромб,
## контур и «плюс» в центре, цвет — по состоянию (свободно / подходит / нет).
## Плюс места: две перекладины полутолщиной SLOT_MARK_T и полудлиной SLOT_MARK_HALF.
const SLOT_MARK_HALF := 13.0
const SLOT_MARK_T := 5.0


## Перерисовать все места. states: slot_id → [цвет заливки, контур и плюс видны].
func _draw_slots(states: Dictionary) -> void:
	var canvas := _slot_layer
	canvas.clear()
	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
		var state: Array = states.get(slot_id, [COL_SLOT, true])
		var center: Vector2 = ISO.tile_center(slot["tx"], slot["ty"], slot["w"], slot["h"])
		var corners: PackedVector2Array = ISO.diamond(0, 0, slot["w"], slot["h"])
		canvas.poly(corners, state[0], center)
		if not bool(state[1]):
			continue
		canvas.line(corners, COL_SLOT_LINE, 3.0, center, true)
		var h := SLOT_MARK_HALF
		var t := SLOT_MARK_T
		canvas.poly(PackedVector2Array([Vector2(-h, -t), Vector2(h, -t), Vector2(h, t), Vector2(-h, t)]),
			COL_SLOT_LINE, center)
		canvas.poly(PackedVector2Array([Vector2(-t, -h), Vector2(t, -h), Vector2(t, h), Vector2(-t, h)]),
			COL_SLOT_LINE, center)


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
	_buy_button.pressed.connect(func() -> void: tasks_requested.emit())
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
		# Чип — PanelContainer с вариацией темы Chip / ChipSelected.
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"Chip"
		chip.custom_minimum_size = CHIP_SIZE
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips_grid.add_child(chip)

		var label := Label.new()
		label.theme_type_variation = &"BodyLabel"
		label.add_theme_font_size_override("font_size", 17)
		label.text = String(item.get("short", decor_id))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.add_child(label)

		_chip_nodes.append(chip)
		_chips.append({"id": decor_id, "node": chip})

	_layout_chips()
	_refresh_chips()


## Подсветка выбранного (тапом) предмета в панели.
func _refresh_chips() -> void:
	for entry in _chips:
		var chip: Control = entry["node"]
		if is_instance_valid(chip):
			var picked := String(entry["id"]) == _pick_decor
			chip.theme_type_variation = &"ChipSelected" if picked else &"Chip"


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
	return _bar.get_global_rect()


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

	var states := {}
	for slot in DATA.SLOTS:
		var slot_id := String(slot["id"])
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
		states[slot_id] = [color, show_mark]

	# Холст перерисовывается, только если подсветка реально поменялась.
	if states != _slot_states:
		_slot_states = states
		_draw_slots(states)

	if _map_hint == null:
		return
	if not _drag_decor.is_empty():
		_map_hint.text = "Отпустите предмет на зелёное место"
		return
	if not _pick_decor.is_empty():
		_map_hint.text = "Тапните по зелёному «+», чтобы поставить"
		return

	# Подсказка про места — только когда есть что ставить из инвентаря.
	var free_count := 0
	for slot in DATA.SLOTS:
		if Meta.slot_decor(String(slot["id"])).is_empty():
			free_count += 1
	var has_items := not Meta.unplaced_decor().is_empty()
	_map_hint.text = (
		"Свободных мест: %d — тяните предмет на «+»" % free_count
		if free_count > 0 and has_items else ""
	)
	_map_hint.visible = not _map_hint.text.is_empty()


# --- Ввод -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Пока поверх открыт попап (ремонт), мир не трогаем: клики — его кнопкам.
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

func _on_placement_changed(_slot_id: String, _decor_id: String) -> void:
	_rebuild_items()
	_rebuild_bar()
	_refresh_slot_marks()


func _on_rotation_changed(_slot_id: String, _rot: int) -> void:
	_rebuild_items()


func _on_decor_changed(_item: Dictionary) -> void:
	_rebuild_bar()


func _overlay_open() -> bool:
	for layer in overlays:
		if layer != null and (layer as CanvasLayer).visible:
			return true
	return false

class_name Board
extends Node2D

## Поле: сетка columns×rows, перемещение и слияние предметов.
##
## Живёт на Node2D: клетки рисуются в _draw(), предметы — дочерние Item.
## Состояние сохраняется как [{cell, chain, level}] (см. serialize/load_from).
## Координаты: локальные, origin — левый верхний угол сетки.

signal item_placed(cell: int, data: ItemData)
signal item_moved(from_cell: int, to_cell: int)
signal items_merged(from_cell: int, to_cell: int, chain: StringName, level: int)
signal board_filled
signal invalid_drop(from_cell: int, to_cell: int)
signal item_sold(cell: int, data: ItemData)
signal booster_target_picked(cell: int)
## Короткий тап по предмету (палец почти не двинулся) — HUD открывает меню действий.
signal item_tapped(cell: int)

const ITEM_SCENE_PATH := "res://scenes/item.tscn"
## Безопасные зоны iPhone (вырез сверху, home-индикатор снизу) — через preload,
## чтобы не зависеть от global_script_class_cache.
const SAFE_AREA := preload("res://scripts/ui/safe_area.gd")

@export var columns: int = 7
@export var rows: int = 8
@export var tile_gap: float = 6.0

var cell_size: float = 96.0
var origin: Vector2 = Vector2.ZERO
var cells: Array = []  # Item | null, длина columns * rows

var _item_scene: PackedScene
var _drag_item: Item = null
var _drag_from: int = -1

## Максимальное смещение пальца в пикселях, при котором жест считается тапом,
## а не перетаскиванием: иначе меню открывалось бы при каждом drag.
const TAP_SLOP := 14.0

## Экранная позиция нажатия — по ней в _end_drag отличаем тап от перетаскивания.
var _press_global: Vector2 = Vector2.ZERO

## Режим «выбери предмет» (бустер «хаммер»): следующий тап не тащит, а сообщает клетку.
var take_target: bool = false


func _ready() -> void:
	_item_scene = load(ITEM_SCENE_PATH)
	columns = maxi(1, _cfg_int("board_width", 7))
	rows = maxi(1, _cfg_int("board_height", 8))
	_reset_cells()
	_recompute_layout()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


# --- Раскладка ---------------------------------------------------------------

func _recompute_layout() -> void:
	var viewport := get_viewport_rect().size
	var safe := SAFE_AREA.insets()
	# Портрет, сверху вниз: шапка (чипы + статус), панель заказов, поле,
	# полоса продажи, бустеры, генераторы (полосы HUD — см. game.gd _setup_hud).
	# Плюс безопасные зоны iPhone: вырез сверху, home-индикатор снизу.
	# По бокам — обязательный отступ, чтобы клетки не липли к кромке экрана.
	var margin_x := viewport.x * 0.04 + maxf(safe.x, safe.z)
	# top/bottom — границы полосы поля; должны совпадать с раскладкой HUD в game.gd.
	var top := viewport.y * 0.181 + safe.y
	var bottom := viewport.y * 0.766 - safe.w
	# Если вставки съели полосу — не даём полю схлопнуться.
	if bottom - top < viewport.y * 0.25:
		top = viewport.y * 0.25
		bottom = viewport.y * 0.75

	var by_width := (viewport.x - margin_x * 2.0) / float(columns)
	var by_height := (bottom - top) / float(rows)
	cell_size = floor(minf(by_width, by_height))

	var grid := Vector2(cell_size * columns, cell_size * rows)
	origin = Vector2(
		floor((viewport.x - grid.x) * 0.5),
		floor(top + (bottom - top - grid.y) * 0.5)
	)
	_relayout_items()


func _relayout_items() -> void:
	for i in cells.size():
		var item := item_at(i)
		if item != null:
			item.position = cell_center(i)
			item.resize(cell_size)


func _on_viewport_resized() -> void:
	_recompute_layout()
	queue_redraw()


# --- Геометрия ---------------------------------------------------------------

func cell_count() -> int:
	return columns * rows


func is_inside(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < columns and row < rows


func cell_of(col: int, row: int) -> int:
	return row * columns + col


func cell_center(cell: int) -> Vector2:
	var col := cell % columns
	var row := floori(float(cell) / float(columns))
	return origin + Vector2(
		col * cell_size + cell_size * 0.5,
		row * cell_size + cell_size * 0.5
	)


func position_to_cell(local_pos: Vector2) -> int:
	var rel := local_pos - origin
	if rel.x < 0.0 or rel.y < 0.0:
		return -1
	var col := floori(rel.x / cell_size)
	var row := floori(rel.y / cell_size)
	if not is_inside(col, row):
		return -1
	return cell_of(col, row)


# --- Клетки ------------------------------------------------------------------

func item_at(cell: int) -> Item:
	if cell < 0 or cell >= cells.size():
		return null
	return cells[cell]


func has_item(cell: int) -> bool:
	return item_at(cell) != null


func is_full() -> bool:
	for c in cells:
		if c == null:
			return false
	return true


func free_cells() -> Array:
	var result: Array = []
	for i in cells.size():
		if cells[i] == null:
			result.append(i)
	return result


func can_merge(from_cell: int, to_cell: int) -> bool:
	if from_cell == to_cell:
		return false
	var a := item_at(from_cell)
	var b := item_at(to_cell)
	if a == null or b == null:
		return false
	if a.data.chain != b.data.chain or a.data.level != b.data.level:
		return false
	return a.data.level < Chains.max_level(a.data.chain)


# --- Операции ----------------------------------------------------------------

## Поставить предмет в случайную свободную клетку. false — если места нет.
func spawn(chain: StringName, level: int) -> bool:
	var free := free_cells()
	if free.is_empty():
		board_filled.emit()
		return false
	var cell: int = free[randi() % free.size()]
	_place_item(Chains.make(chain, level), cell)
	return true


func try_move(from_cell: int, to_cell: int) -> bool:
	var item := item_at(from_cell)
	if item == null or from_cell == to_cell:
		return false
	if to_cell < 0 or has_item(to_cell):
		return false
	cells[from_cell] = null
	cells[to_cell] = item
	item.set_cell_index(to_cell, cell_center(to_cell))
	item_moved.emit(from_cell, to_cell)
	return true


func merge(from_cell: int, to_cell: int) -> bool:
	if not can_merge(from_cell, to_cell):
		return false
	var source := item_at(from_cell)
	var target := item_at(to_cell)
	var chain := source.data.chain
	var new_level := target.data.level + 1

	_remove_at(from_cell)
	_remove_at(to_cell)
	_place_item(Chains.make(chain, new_level), to_cell)
	items_merged.emit(from_cell, to_cell, chain, new_level)
	return true


func clear() -> void:
	for i in cells.size():
		var item := item_at(i)
		if item != null:
			item.queue_free()
		cells[i] = null


## Забрать предмет с поля (используется заказами). Экономику считает вызывающий.
func remove_at_cell(cell: int) -> void:
	_remove_at(cell)


## Продать предмет из клетки: убрать с поля и сообщить наружу (item_sold).
func sell_at(cell: int) -> bool:
	var item := item_at(cell)
	if item == null:
		return false
	var data := item.data
	_remove_at(cell)
	item_sold.emit(cell, data)
	return true


## Перемешать предметы поля (бустер «шафл»). Занятые клетки остаются теми же.
func shuffle() -> bool:
	var occupied: Array = []
	for i in cells.size():
		if cells[i] != null:
			occupied.append(i)
	if occupied.size() < 2:
		return false

	var items: Array = []
	for i in occupied:
		items.append(cells[i])
	for i in range(items.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

	for k in occupied.size():
		var cell: int = occupied[k]
		var item: Item = items[k]
		cells[cell] = item
		item.set_cell_index(cell, cell_center(cell))
	return true


# --- Сохранение --------------------------------------------------------------

func serialize() -> Array:
	var result: Array = []
	for i in cells.size():
		var item := item_at(i)
		if item == null:
			continue
		result.append({"cell": i, "chain": String(item.data.chain), "level": item.data.level})
	return result


func load_from(data: Array) -> void:
	clear()
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var cell := int(e.get("cell", -1))
		if cell < 0 or cell >= cells.size() or cells[cell] != null:
			continue
		_place_item(Chains.make(StringName(e.get("chain", "")), int(e.get("level", 1))), cell)


# --- Ввод (drag & drop) ------------------------------------------------------
# На мобильных тач → mouse-события (проект держит emulate_mouse_from_touch=true).

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(_local_mouse())
		else:
			_end_drag(_local_mouse())
	elif event is InputEventMouseMotion and _drag_item != null:
		_move_drag(_local_mouse())


func _local_mouse() -> Vector2:
	return to_local(get_global_mouse_position())


func _begin_drag(local_pos: Vector2) -> void:
	var cell := position_to_cell(local_pos)
	if take_target:
		take_target = false
		booster_target_picked.emit(cell if has_item(cell) else -1)
		return
	var item := item_at(cell)
	if item == null:
		return
	_drag_item = item
	_drag_from = cell
	item.position = local_pos
	item.set_dragging(true)
	_press_global = get_global_mouse_position()


func _move_drag(local_pos: Vector2) -> void:
	if _drag_item != null:
		_drag_item.position = local_pos


func _end_drag(local_pos: Vector2) -> void:
	if _drag_item == null:
		return

	var item := _drag_item
	var from_cell := _drag_from
	_drag_item = null
	_drag_from = -1
	item.set_dragging(false)

	var to_cell := position_to_cell(local_pos)

	if to_cell < 0:
		# Бросили мимо клеток: предмет возвращается, ничего не продаём —
		# продажа теперь только тапом по предмету (docs/GDD.md §18).
		item.position = cell_center(from_cell)
		invalid_drop.emit(from_cell, -1)
		return
	if to_cell == from_cell:
		item.position = cell_center(from_cell)
		# Палец почти не сместился — это тап: открываем меню действий.
		if get_global_mouse_position().distance_to(_press_global) <= TAP_SLOP:
			item_tapped.emit(from_cell)
		return
	if can_merge(from_cell, to_cell):
		merge(from_cell, to_cell)
		return
	if try_move(from_cell, to_cell):
		return

	item.position = cell_center(from_cell)
	invalid_drop.emit(from_cell, to_cell)


# --- Внутреннее --------------------------------------------------------------

func _reset_cells() -> void:
	cells.clear()
	cells.resize(columns * rows)
	for i in cells.size():
		cells[i] = null


func _place_item(data: ItemData, cell: int) -> Item:
	var item: Item = _item_scene.instantiate()
	add_child(item)
	item.setup(data, cell, cell_size)
	item.position = cell_center(cell)
	cells[cell] = item
	item_placed.emit(cell, data)
	return item


func _remove_at(cell: int) -> void:
	var item := item_at(cell)
	if item == null:
		return
	cells[cell] = null
	item.queue_free()


func _cfg_int(key: String, fallback: int) -> int:
	var value = Config.get_value(key)
	return int(value) if value != null else fallback


func _draw() -> void:
	for row in rows:
		for col in columns:
			var pos := origin + Vector2(col, row) * cell_size
			var rect := Rect2(pos, Vector2.ONE * (cell_size - tile_gap))
			var shade := Color("E8C39E", 0.45) if ((col + row) % 2 == 0) else Color("C98A5E", 0.38)
			draw_rect(rect, shade, true)
			draw_rect(rect, Color("4A3226", 0.30), false, 2.0)

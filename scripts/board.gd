class_name Board
extends Node2D

## Поле: сетка columns×rows, перемещение и слияние предметов.
##
## Живёт на Node2D: клетки рисуются в _draw(), предметы — дочерние Item.
## Состояние сохраняется как [{cell, chain, level, [charges, recharge_at]}]
## (см. serialize/load_from); генераторы — предметы цепочек «gen_*».
## Координаты: локальные, origin — левый верхний угол сетки.
## Фильтр текстур — LINEAR_WITH_MIPMAPS (scenes/game.tscn): столешница 512 px
## рисуется в масштабе 0.5, предметы и генераторы (дочерние Item, фильтр
## наследуют) ужаты до клетки — без мипмапов они рябят.

signal item_placed(cell: int, data: ItemData)
signal item_moved(from_cell: int, to_cell: int)
signal items_merged(from_cell: int, to_cell: int, chain: StringName, level: int)
signal board_filled
signal invalid_drop(from_cell: int, to_cell: int)
signal item_sold(cell: int, data: ItemData)
signal booster_target_picked(cell: int)
## Короткий тап по предмету (палец почти не двинулся) — HUD открывает меню действий.
signal item_tapped(cell: int)
## Короткий тап по генератору — выдать предмет его цепочки.
signal generator_tapped(cell: int)
## Пузырь не забрали вовремя — он лопнул и исчез с поля.
signal bubble_popped(cell: int, data: ItemData)
## Набор предметов на поле изменился (появился/исчез предмет): game.gd
## пересчитывает, какие заказы уже можно сдать.
signal contents_changed

const ITEM_SCENE_PATH := "res://scenes/item.tscn"

@export var columns: int = 7
@export var rows: int = 8
@export_range(0.0, 8.0) var tile_gap: float = 3.0

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

## Экранный прямоугольник, в который вписывается поле: область %BoardArea
## сцены HUD (scenes/ui/game_hud.tscn). Задаёт game.gd через set_area().
## Пустой — поле занимает средние 60% экрана (до первой раскладки HUD).
var area := Rect2()

const TOP_GAP := 6.0
const BOTTOM_GAP := 10.0
var _start_cells: int
var _cells_per_level: int
var _locked_tile := StyleBoxFlat.new()
var _tray := StyleBoxFlat.new()
var _tiles: Array[StyleBoxFlat] = []
var _targets: Array[StyleBoxFlat] = []

## Клетка под перетаскиваемым предметом (подсветка), -1 — нет.
var _drag_cell: int = -1
## Кайма рамки в пикселях (X — бока, Y — верх/низ): сетка сжимается, чтобы
## рамка влезла (см. _recompute_layout).
var _frame_border: float = 0.0


func _ready() -> void:
	_item_scene = load(ITEM_SCENE_PATH)
	_setup_board_styles()
	columns = maxi(1, _cfg_int("board_width", 7))
	rows = maxi(1, _cfg_int("board_height", 8))
	_start_cells = maxi(1, _cfg_int("board_start_cells", 12))
	_cells_per_level = maxi(1, _cfg_int("board_cells_per_level", 2))
	Progress.level_changed.connect(queue_redraw.unbind(2))
	_reset_cells()
	_recompute_layout()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()


# --- Раскладка ---------------------------------------------------------------

func _recompute_layout() -> void:
	var viewport := get_viewport_rect().size
	var box := area
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		box = Rect2(0.0, viewport.y * 0.2, viewport.x, viewport.y * 0.6)
	# Рамка лежит вокруг сетки: её кайма отнимается у клеток, иначе поле вылезет.
	_frame_border = clampf(minf(box.size.x, box.size.y) * 0.016, 4.0, 12.0)
	var inset := _frame_border
	var avail_h := box.size.y - TOP_GAP - BOTTOM_GAP - inset * 2.0
	var by_width := (box.size.x - inset * 2.0) / float(columns)
	var by_height := avail_h / float(rows)
	cell_size = maxf(1.0, floor(minf(by_width, by_height)))

	var grid := Vector2(cell_size * columns, cell_size * rows)
	origin = box.get_center() - grid * 0.5
	_relayout_items()


## Вписать поле в экранный прямоугольник (область поля в HUD).
func set_area(rect: Rect2) -> void:
	if rect == area:
		return
	area = rect
	_recompute_layout()
	queue_redraw()


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


func _unlock_level(cell: int) -> int:
	return 1 + ceili(float(maxi(0, cell + 1 - _start_cells)) / _cells_per_level)

func _can_place(cell: int) -> bool:
	return cell >= 0 and cell < cells.size() and not has_item(cell) and Progress.level >= _unlock_level(cell)

func is_full() -> bool:
	return free_cells().is_empty()


func free_cells() -> Array:
	var result: Array = []
	for i in cells.size():
		if _can_place(i):
			result.append(i)
	return result


func can_merge(from_cell: int, to_cell: int) -> bool:
	if from_cell == to_cell:
		return false
	var a := item_at(from_cell)
	var b := item_at(to_cell)
	if a == null or b == null:
		return false
	if a.is_bubble() or b.is_bubble():
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


## Поставить готовые данные (подарок-генератор, пузырь) в свободную клетку
## поближе к `near` (-1 — в случайную). Возвращает клетку или -1, если места нет.
func place_data(data: ItemData, near := -1) -> int:
	var cell := free_cell_near(near)
	if cell < 0:
		board_filled.emit()
		return -1
	_place_item(data, cell)
	return cell


## Свободная клетка, ближайшая к `near` (-1 — случайная свободная).
func free_cell_near(near: int) -> int:
	var free := free_cells()
	if free.is_empty():
		return -1
	if near < 0 or near >= cells.size():
		return free[randi() % free.size()]
	var best := -1
	var best_d := INF
	var from := Vector2(near % columns, floori(float(near) / columns))
	for cell: int in free:
		var d := from.distance_squared_to(Vector2(cell % columns, floori(float(cell) / columns)))
		if d < best_d:
			best_d = d
			best = cell
	return best


## Раз в секунду (game.gd): генераторы подзаряжаются, пузыри лопаются.
func tick() -> void:
	var now := int(Time.get_unix_time_from_system())
	var now_ms := Time.get_ticks_msec()
	for i in cells.size():
		var item := item_at(i)
		if item == null:
			continue
		if item.is_bubble():
			if now_ms >= item.bubble_until:
				var data := item.data
				_remove_at(i)
				bubble_popped.emit(i, data)
			else:
				item.refresh_overlay()
		elif item.is_generator():
			if item.data.charges <= 0 and item.data.recharge_at > 0:
				if now >= item.data.recharge_at:
					item.data.charges = int(Chains.gen_param("gen_charges", item.data.level, 6.0))
					item.data.recharge_at = 0
				item.refresh_overlay()


## Пара предметов, которые можно слить прямо сейчас (для подсказки):
## Vector2i(a, b) или (-1, -1).
func find_merge_pair() -> Vector2i:
	var seen := {}
	for i in cells.size():
		var item := item_at(i)
		if item == null or item.is_bubble():
			continue
		if item.data.level >= Chains.max_level(item.data.chain):
			continue
		var key := "%s:%d" % [item.data.chain, item.data.level]
		if seen.has(key):
			return Vector2i(int(seen[key]), i)
		seen[key] = i
	return Vector2i(-1, -1)


func hint_pair(pair: Vector2i) -> void:
	for cell in [pair.x, pair.y]:
		var item := item_at(cell)
		if item != null:
			item.wiggle()


func stop_hint() -> void:
	for i in cells.size():
		var item := item_at(i)
		if item != null:
			item.stop_wiggle()


func try_move(from_cell: int, to_cell: int) -> bool:
	var item := item_at(from_cell)
	if item == null or from_cell == to_cell:
		return false
	if not _can_place(to_cell):
		return false
	cells[from_cell] = null
	cells[to_cell] = item
	item.name = _item_name(to_cell)
	item.set_cell_index(to_cell, cell_center(to_cell))
	queue_redraw()
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
	queue_redraw()
	_drag_item = null
	_drag_from = -1
	_drag_cell = -1
	for i in cells.size():
		var item := item_at(i)
		if item != null:
			_free_item(item)
		cells[i] = null
	contents_changed.emit()


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

	# Имена «Item_<клетка>» меняются местами: сперва временные, иначе
	# переименование столкнётся с ещё не переехавшим соседом.
	for k in items.size():
		(items[k] as Item).name = "Shuffling_%d" % k
	for k in occupied.size():
		var cell: int = occupied[k]
		var item: Item = items[k]
		cells[cell] = item
		item.name = _item_name(cell)
		item.set_cell_index(cell, cell_center(cell))
	return true


# --- Сохранение --------------------------------------------------------------

func serialize() -> Array:
	var result: Array = []
	for i in cells.size():
		var item := item_at(i)
		if item == null:
			continue
		# Пузыри не сохраняются: после перезапуска их уже нет.
		if item.is_bubble():
			continue
		var entry := item.data.to_dict()
		entry["cell"] = i
		result.append(entry)
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
		_place_item(ItemData.from_dict(e), cell)


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


## Снять режим выбора цели бустера (например, при открытии попапа).
func cancel_take_target() -> void:
	take_target = false


func _begin_drag(local_pos: Vector2) -> void:
	# Прицел бустера главнее: тап по генератору/клетке должен сначала
	# завершить выбор цели, иначе хаммер остаётся взведённым.
	if take_target:
		take_target = false
		var target_cell := position_to_cell(local_pos)
		booster_target_picked.emit(target_cell if has_item(target_cell) else -1)
		return
	var cell := position_to_cell(local_pos)
	var item := item_at(cell)
	if item == null:
		return
	_drag_item = item
	_drag_from = cell
	_press_global = get_global_mouse_position()
	if item.is_bubble():
		# Пузырь не берётся в руку: ждём отпускания, чтобы отличить тап.
		return
	_drag_cell = cell
	item.position = local_pos
	item.set_dragging(true)
	_set_match_hints(cell)
	# LIGHT-тик в момент захвата: подтверждает, что предмет «взят».
	Haptics.selection()


func _move_drag(local_pos: Vector2) -> void:
	if _drag_item != null and _drag_item.is_bubble():
		return
	if _drag_item != null:
		_drag_item.position = local_pos
		# Подсветка клетки под пальцем: перерисовываем только при смене клетки.
		var cell := position_to_cell(local_pos)
		if cell != _drag_cell:
			_drag_cell = cell
			queue_redraw()


func _end_drag(local_pos: Vector2) -> void:
	if _drag_item == null:
		return

	var item := _drag_item
	var from_cell := _drag_from
	_drag_item = null
	_drag_from = -1
	item.set_dragging(false)
	_set_match_hints(-1)
	if _drag_cell != -1:
		_drag_cell = -1
		queue_redraw()

	var to_cell := position_to_cell(local_pos)

	if to_cell < 0:
		# Бросили мимо клеток: предмет возвращается, ничего не продаём —
		# продажа теперь только тапом по предмету (docs/GDD.md §18).
		item.position = cell_center(from_cell)
		invalid_drop.emit(from_cell, -1)
		return
	var is_tap := get_global_mouse_position().distance_to(_press_global) <= TAP_SLOP
	# Пузырь не двигается и не сливается: его можно только забрать тапом.
	if item.is_bubble():
		item.position = cell_center(from_cell)
		if is_tap:
			item_tapped.emit(from_cell)
		return
	if to_cell == from_cell:
		item.position = cell_center(from_cell)
		# Палец почти не сместился — это тап: генератор выдаёт предмет,
		# обычный предмет открывает меню действий.
		if is_tap:
			if item.is_generator():
				generator_tapped.emit(from_cell)
			else:
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
	item.name = _item_name(cell)
	add_child(item)
	item.setup(data, cell, cell_size)
	item.position = cell_center(cell)
	cells[cell] = item
	item_placed.emit(cell, data)
	contents_changed.emit()
	return item


## Пока предмет в руке, такие же (с которыми он сольётся) обводятся.
## from_cell < 0 — снять обводку со всех.
func _set_match_hints(from_cell: int) -> void:
	for i in cells.size():
		var other := item_at(i)
		if other != null:
			other.set_match_hint(from_cell >= 0 and can_merge(from_cell, i))


func _remove_at(cell: int) -> void:
	var item := item_at(cell)
	if item == null:
		return
	# Предмет мог уйти из-под пальца (пузырь лопнул, заказ забрал вторым
	# пальцем): бросаем перетаскивание, иначе _end_drag тронет удалённый узел.
	if item == _drag_item:
		_drag_item = null
		_drag_from = -1
		_set_match_hints(-1)
		if _drag_cell != -1:
			_drag_cell = -1
			queue_redraw()
	cells[cell] = null
	queue_redraw()
	_free_item(item)
	contents_changed.emit()


## Имя узла предмета — по клетке: в дереве видно, что где лежит.
static func _item_name(cell: int) -> String:
	return "Item_%d" % cell


## Удалить узел предмета. Имя освобождаем сразу: queue_free отработает в конце
## кадра, а новый предмет в той же клетке (слияние) хочет то же имя.
func _free_item(item: Item) -> void:
	item.name = "Freed_%d" % item.get_instance_id()
	item.queue_free()


func _cfg_int(key: String, fallback: int) -> int:
	var value = Config.get_value(key)
	return int(value) if value != null else fallback


func _setup_board_styles() -> void:
	_locked_tile.bg_color = Color("927763")
	_locked_tile.set_corner_radius_all(8)
	_tray.bg_color = Color("ad8064")
	_tray.border_color = Color("8e6651")
	_tray.set_border_width_all(2)
	_tray.set_corner_radius_all(18)
	_tray.shadow_color = Color("50372844")
	_tray.shadow_size = 4
	_tray.shadow_offset = Vector2(0, 3)
	for shade: Color in [Color("f5e3ca"), Color("ecd4b6")]:
		var tile := StyleBoxFlat.new()
		tile.bg_color = shade
		tile.set_corner_radius_all(8)
		tile.border_width_bottom = 2
		tile.border_color = shade.darkened(0.12)
		_tiles.append(tile)
	for tint: Color in [Color("b45a4f"), Color("64845b"), Color("b97619")]:
		var target := StyleBoxFlat.new()
		target.draw_center = false
		target.border_color = tint
		target.set_border_width_all(4)
		target.set_corner_radius_all(8)
		_targets.append(target)

func _draw() -> void:
	if _tiles.is_empty():
		return
	var grid := Rect2(origin, Vector2(columns, rows) * cell_size)
	draw_style_box(_tray, grid.grow(_frame_border))
	for row in rows:
		for col in columns:
			var cell := cell_of(col, row)
			var rect := _cell_rect(col, row)
			# Старые предметы остаются доступны, пока игрок не освободит клетку.
			if not has_item(cell) and Progress.level < _unlock_level(cell):
				draw_style_box(_locked_tile, rect)
				var font_size := maxi(1, roundi(cell_size * 0.23))
				var pos := Vector2(rect.position.x, rect.get_center().y + font_size * 0.34)
				draw_string(ThemeDB.fallback_font, pos, tr("Уровень кофейни %d") % _unlock_level(cell), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(1, roundi(font_size * 0.6)), Color.WHITE)
			else:
				draw_style_box(_tiles[(row + col) % 2], rect)
	if _drag_cell >= 0 and _drag_cell < cell_count():
		var state := 0
		if _drag_cell == _drag_from or _can_place(_drag_cell):
			state = 1
		elif can_merge(_drag_from, _drag_cell):
			state = 2
		draw_style_box(_targets[state], _cell_rect(_drag_cell % columns, floori(float(_drag_cell) / columns)))

func _cell_rect(col: int, row: int) -> Rect2:
	var rect := Rect2(origin + Vector2(col, row) * cell_size, Vector2.ONE * cell_size)
	return rect.grow(-minf(tile_gap * 0.5, cell_size * 0.1))

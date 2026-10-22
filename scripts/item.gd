class_name Item
extends Node2D

## Резолвер реального арта берём через preload: class_name попадает в
## global_script_class_cache.cfg только после импорта проекта.
const ART := preload("res://scripts/data/art.gd")

## Предмет на поле: данные (ItemData) + визуал (Sprite2D). Номер уровня не
## показываем: у места в цепочке есть собственный арт, а у плейсхолдера
## уровень нарисован пипсами.
##
## Спрайт занимает 2/3 клетки: вплотную к краям соседние предметы слипались бы
## в одно пятно, а обводка соседей — соприкасалась.
const SPRITE_FILL := 2.0 / 3.0
## У генератора иконка его цепочки меньше: вокруг — подложка «станции».
const GEN_SPRITE_FILL := 0.5
const GEN_GOLD := Color("F2B01E")
const GEN_DARK := Color("4A3226")

var data: ItemData
var cell: int = -1
## «Пузырь»: копия после слияния, которую можно забрать за гемы до этого
## момента (Time.get_ticks_msec). 0 — обычный предмет.
var bubble_until := 0

var _cell_size: float = 96.0
var _dragging: bool = false
var _wiggle: Tween
## Подложка генератора рисуется под спрайтом (_draw), а заряды, таймер отдыха
## и кольцо пузыря — над ним, отдельным узлом поверх спрайта.
var _overlay: Node2D

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_overlay = Node2D.new()
	_overlay.z_index = 1
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func is_generator() -> bool:
	return data != null and Chains.is_generator(data.chain)


func is_bubble() -> bool:
	return bubble_until > 0


## Сделать предмет пузырём на `seconds` секунд.
func set_bubble(seconds: float) -> void:
	bubble_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_sprite.modulate = Color(1, 1, 1, 0.7)
	refresh_overlay()


## Перерисовать заряды/таймеры (раз в секунду из Board.tick).
func refresh_overlay() -> void:
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


## Подсказка «эти можно слить»: несколько покачиваний.
func wiggle() -> void:
	stop_wiggle()
	_wiggle = create_tween()
	for angle in [0.14, -0.12, 0.1, -0.08, 0.05, 0.0]:
		_wiggle.tween_property(_sprite, "rotation", angle, 0.09)


func stop_wiggle() -> void:
	if _wiggle != null and _wiggle.is_valid():
		_wiggle.kill()
	if _sprite != null:
		_sprite.rotation = 0.0


func setup(item_data: ItemData, cell_index: int, cell_size: float) -> void:
	data = item_data
	cell = cell_index
	_cell_size = cell_size
	_refresh()


func resize(cell_size: float) -> void:
	_cell_size = cell_size
	_refresh()


func set_cell_index(index: int, target: Vector2) -> void:
	cell = index
	position = target


func set_dragging(value: bool) -> void:
	_dragging = value
	z_index = 20 if value else 0
	_refresh()


## Слияние: новый предмет «выпрыгивает» — из маленького в больше нормы
## и обратно, с лёгким покачиванием.
func merge_pop() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var final_scale := _sprite.scale
	_sprite.scale = final_scale * 0.3
	_sprite.rotation = -0.25
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", final_scale * 1.3, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "rotation", 0.12, 0.12)
	tween.tween_property(_sprite, "scale", final_scale, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Короткий «тычок» (тап по предмету).
func punch() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var final_scale := _sprite.scale
	_sprite.scale = final_scale * 0.6
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", final_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	if data == null or _sprite == null:
		return
	# Генератор показывает первый предмет своей цепочки на подложке «станции».
	var chain := Chains.generator_target(data.chain) if is_generator() else data.chain
	var level := 1 if is_generator() else data.level
	var art := ART.item_texture(chain, level)
	var tex: Texture2D = data.icon
	if tex == null:
		tex = art if art != null else Placeholders.item_texture(chain, level)
	_sprite.texture = tex

	var size := tex.get_size()
	var fill := GEN_SPRITE_FILL if is_generator() else SPRITE_FILL
	var factor := (_cell_size * fill) / maxf(1.0, maxf(size.x, size.y))
	if _dragging:
		factor *= 1.12
	_sprite.scale = Vector2.ONE * factor
	refresh_overlay()


## Подложка генератора: скруглённая «станция» цвета цепочки с золотой
## кромкой (толще с уровнем) и точками уровня сверху.
func _draw() -> void:
	if not is_generator():
		return
	var side := _cell_size * 0.84
	var rect := Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side)
	var target := Chains.generator_target(data.chain)
	var body := StyleBoxFlat.new()
	body.bg_color = Placeholders.chain_color(target).lightened(0.45)
	body.border_color = GEN_GOLD
	body.set_border_width_all(3 + data.level)
	body.set_corner_radius_all(int(side * 0.22))
	body.shadow_color = Color(0, 0, 0, 0.2)
	body.shadow_size = 4
	draw_style_box(body, rect)
	var dot := side * 0.06
	var gap := dot * 2.6
	var start := -gap * (data.level - 1) * 0.5
	for i in data.level:
		draw_circle(Vector2(start + gap * i, rect.position.y + dot * 2.2), dot, GEN_GOLD)


## Над спрайтом: у генератора — заряды (или затемнение и таймер отдыха),
## у пузыря — кольцо и таймер до «лопания».
func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	var side := _cell_size * 0.84
	if is_generator():
		var now := int(Time.get_unix_time_from_system())
		if data.charges <= 0 and data.recharge_at > now:
			var rect := Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side)
			var shade := StyleBoxFlat.new()
			shade.bg_color = Color(0.15, 0.1, 0.08, 0.55)
			shade.set_corner_radius_all(int(side * 0.22))
			_overlay.draw_style_box(shade, rect)
			var left := data.recharge_at - now
			var text := "%d:%02d" % [floori(left / 60.0), left % 60]
			var fs := int(_cell_size * 0.2)
			_overlay.draw_string_outline(font, Vector2(-side * 0.5, fs * 0.35), text,
				HORIZONTAL_ALIGNMENT_CENTER, side, fs, 6, GEN_DARK)
			_overlay.draw_string(font, Vector2(-side * 0.5, fs * 0.35), text,
				HORIZONTAL_ALIGNMENT_CENTER, side, fs, Color.WHITE)
		else:
			var r := _cell_size * 0.13
			var c := Vector2(side * 0.5 - r * 0.7, side * 0.5 - r * 0.7)
			_overlay.draw_circle(c, r, GEN_DARK)
			_overlay.draw_circle(c, r * 0.82, Color("7CC35A"))
			var fs := int(r * 1.15)
			_overlay.draw_string(font, c + Vector2(-r, fs * 0.36), str(maxi(data.charges, 0)),
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
	elif is_bubble():
		var radius := _cell_size * 0.44
		_overlay.draw_circle(Vector2.ZERO, radius, Color(0.75, 0.9, 1.0, 0.18))
		_overlay.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0, true)
		var left_s := maxi(0, ceili((bubble_until - Time.get_ticks_msec()) / 1000.0))
		var fs := int(_cell_size * 0.16)
		var pos := Vector2(-radius, radius - fs * 0.3)
		_overlay.draw_string_outline(font, pos, "%d с" % left_s, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, fs, 5, Color("2E6E9E"))
		_overlay.draw_string(font, pos, "%d с" % left_s, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, fs, Color.WHITE)

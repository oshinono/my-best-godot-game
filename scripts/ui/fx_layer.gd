extends CanvasLayer

## Слой эффектов поверх HUD: полёты иконок по дуге (монеты к счётчику,
## предметы в заказ), вспышки частиц на слиянии.
##
## Всё здесь — короткоживущие узлы: создаются под эффект и сами удаляются.
## Ввод слой не ловит (mouse_filter = IGNORE), координаты — экранные (viewport),
## те же, что у HUD и у поля (Board — Node2D без сдвига камеры).

## Длительность полёта одной иконки и шаг между монетами в «струйке».
const FLY_TIME := 0.55
const COIN_STAGGER := 0.06
## false — эффекты не показываются (самопроверка при запуске гоняет
## слияния, заказы и продажи — игрок не должен их видеть).
var enabled := true

var _spark: Texture2D
## Градиенты затухания частиц по цвету (цветов — по числу цепочек).
var _ramps := {}


func _ready() -> void:
	layer = 10
	_spark = _make_spark()

## Полёт иконки по дуге из `from` в `to` (экранные координаты).
## Возвращает сигнал окончания полёта — по нему удобно «пружинить» цель.
## `visual` — текстура иконки.
func fly(visual: Variant, from: Vector2, to: Vector2, size := 44.0,
		duration := FLY_TIME, delay := 0.0) -> Signal:
	if not enabled:
		return get_tree().process_frame
	var icon := _fly_node(visual, size)
	icon.position = from - icon.size * 0.5
	icon.visible = delay <= 0.0
	add_child(icon)

	# Контрольная точка дуги: выше середины пути и чуть в сторону — монеты
	# в «струйке» летят веером, а не одной линией.
	var control := from.lerp(to, 0.5) + Vector2(randf_range(-90.0, 90.0), -randf_range(120.0, 200.0))
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: icon.visible = true)
	tween.tween_method(func(t: float) -> void:
		var a := from.lerp(control, t)
		var b := control.lerp(to, t)
		icon.position = a.lerp(b, t) - icon.size * 0.5
		# Растёт к середине пути и сжимается у цели — «влетает» в счётчик.
		icon.scale = Vector2.ONE * (0.7 + sin(t * PI) * 0.5 - t * 0.2)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(icon.queue_free)
	return tween.finished


## Иконка для полёта монет или предмета.
func _fly_node(visual: Texture2D, size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = visual
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2.ONE * size
	icon.pivot_offset = icon.size * 0.5
	return icon

## «Струйка» из `count` иконок. `on_each` зовётся на прилёте каждой
## (пружина счётчика), возвращает время до прилёта последней.
func fly_many(texture: Variant, from: Vector2, to: Vector2, count: int,
		on_each: Callable = Callable(), size := 40.0) -> float:
	if not enabled:
		return 0.0
	count = maxi(1, count)
	for i in count:
		var scatter := Vector2(randf_range(-28.0, 28.0), randf_range(-20.0, 20.0))
		var done := fly(texture, from + scatter, to, size, FLY_TIME, i * COIN_STAGGER)
		if on_each.is_valid():
			done.connect(on_each)
	return FLY_TIME + (count - 1) * COIN_STAGGER


## Мягкая вспышка под предметом, затем разлёт отдельных гранёных искр.
func burst(pos: Vector2, color: Color, power := 1.0) -> void:
	if not enabled:
		return
	var glow := Sprite2D.new()
	glow.texture = _spark
	glow.position = pos
	glow.modulate = color.lightened(0.45)
	glow.scale = Vector2.ONE * 1.5
	add_child(glow)
	var fade := glow.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(glow, "scale", Vector2.ONE * 6.0, 0.24)
	fade.tween_property(glow, "modulate:a", 0.0, 0.24)
	fade.chain().tween_callback(glow.queue_free)

	var stars := CPUParticles2D.new()
	stars.emitting = false
	stars.position = pos
	stars.texture = preload("res://assets/vfx/merge_glint.svg")
	stars.one_shot = true
	stars.explosiveness = 0.94
	stars.amount = clampi(roundi(6 + 3 * power), 7, 14)
	stars.lifetime = 0.62
	stars.direction = Vector2.UP
	stars.spread = 180.0
	stars.gravity = Vector2(0, 105)
	stars.initial_velocity_min = 85.0
	stars.initial_velocity_max = 180.0
	stars.damping_min = 75.0
	stars.damping_max = 115.0
	stars.angular_velocity_min = -95.0
	stars.angular_velocity_max = 95.0
	stars.scale_amount_min = 0.22
	stars.scale_amount_max = 0.58
	if not _ramps.has(color):
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.add_point(0.52, color.lightened(0.45))
		ramp.set_color(2, Color(color, 0.0))
		_ramps[color] = ramp
	stars.color_ramp = _ramps[color]
	add_child(stars)
	stars.finished.connect(stars.queue_free)
	stars.emitting = true

## Мягкая круглая искра для частиц (без файла арта).
func _make_spark() -> Texture2D:
	var side := 24
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side, side) * 0.5
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / (side * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

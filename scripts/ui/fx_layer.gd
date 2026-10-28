extends CanvasLayer

## Слой эффектов поверх HUD: полёты иконок по дуге (монеты к счётчику,
## предметы в заказ), вспышки частиц на слиянии и очередь тостов.
##
## Всё здесь — короткоживущие узлы: создаются под эффект и сами удаляются.
## Ввод слой не ловит (mouse_filter = IGNORE), координаты — экранные (viewport),
## те же, что у HUD и у поля (Board — Node2D без сдвига камеры).

const TOAST := preload("res://scenes/ui/toast.tscn")
## Вид тоста → вариация темы: обычный, ошибка, успех.
const TOAST_STYLES := {
	"info": &"Toast",
	"error": &"ToastError",
	"success": &"ToastSuccess",
}
## Сколько висит тост и сколько их максимум на экране одновременно.
const TOAST_TIME := 2.4
const TOAST_MAX := 3
## Длительность полёта одной иконки и шаг между монетами в «струйке».
const FLY_TIME := 0.55
const COIN_STAGGER := 0.06
## Покадровые эффекты из assets/vfx/<имя>_<N>.png (нарезка листа
## tools/split_sheet.gd --rows): burst, ring, coins, smoke, check, sparkle.
const VFX_DIR := "res://assets/vfx/"
const VFX_FPS := 18.0
## Что грузим заранее (имя → зациклено ли): иначе первое слияние/продажа
## подвисает на чтении кадров с диска.
const VFX_WARMUP := {
	"burst": false, "ring": false, "smoke": false, "check": false,
	"sparkle": false, "coins": true,
}
## Отступ тостов от низа экрана, когда они внизу (над нижним рядом кнопок).
const TOAST_BOTTOM_GAP := 130.0

## false — эффекты не показываются (самопроверка при запуске гоняет
## слияния, заказы и продажи — игрок не должен их видеть).
var enabled := true

var _toasts: VBoxContainer
var _toast_top := 200.0
var _toasts_bottom := false
var _spark: Texture2D
## Кэш SpriteFrames по имени анимации.
var _frames := {}
## Градиенты затухания частиц по цвету (цветов — по числу цепочек).
var _ramps := {}


func _ready() -> void:
	# Над попапами и кофейней: ошибка «не хватает гемов» должна быть видна везде.
	layer = 10
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 8)
	add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 200.0
	_spark = _make_spark()
	_warm_up.call_deferred()


func _warm_up() -> void:
	for anim: String in VFX_WARMUP:
		_sprite_frames(anim, VFX_FPS, bool(VFX_WARMUP[anim]))


## Верх зоны тостов (экранная Y): game.gd ставит её под ряд заказов.
func set_toast_top(y: float) -> void:
	_toast_top = y
	if not _toasts_bottom:
		_toasts.offset_top = y


## Пока открыт попап, тосты уходят вниз экрана: сверху они закрывали бы
## его заголовок.
func set_toasts_bottom(on: bool) -> void:
	if on == _toasts_bottom:
		return
	_toasts_bottom = on
	if on:
		_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_toasts.alignment = BoxContainer.ALIGNMENT_END
		_toasts.offset_bottom = -TOAST_BOTTOM_GAP
	else:
		_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_toasts.grow_vertical = Control.GROW_DIRECTION_END
		_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
		_toasts.offset_top = _toast_top


## Полёт иконки по дуге из `from` в `to` (экранные координаты).
## Возвращает сигнал окончания полёта — по нему удобно «пружинить» цель.
## `visual` — Texture2D (иконка) или имя анимации VFX ("coins"): тогда
## летит зацикленная покадровая анимация.
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


## Вспышка слияния: покадровый burst (на крупном слиянии ещё и ring) плюс
## частицы цвета цепочки. `power` 1..3 — больше частиц и шире разлёт.
func burst(pos: Vector2, color: Color, power := 1.0) -> void:
	if not enabled:
		return
	play("burst", pos, 150.0 + 40.0 * power)
	# Кольцо — на крупных слияниях (уровень 4+, power от 1.7).
	if power >= 1.6:
		play("ring", pos, 180.0 + 40.0 * power)
	_spawn_particles(pos, color, power, 1.0)
	# Белые блёстки поверх цветных: на кремовом поле цветные искры теряются.
	_spawn_particles(pos, Color(1, 1, 0.92), power * 0.6, 0.7)


func _spawn_particles(pos: Vector2, color: Color, power: float, size_k: float) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.texture = _spark
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(10 + 8 * power)
	particles.lifetime = 0.55
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 520)
	particles.initial_velocity_min = 140.0 * (0.8 + power * 0.2)
	particles.initial_velocity_max = 300.0 * (0.8 + power * 0.2)
	particles.scale_amount_min = 1.0 * size_k
	particles.scale_amount_max = 2.0 * size_k
	if not _ramps.has(color):
		var ramp := Gradient.new()
		ramp.set_color(0, Color(color, 1.0))
		ramp.set_color(1, Color(color, 0.0))
		_ramps[color] = ramp
	particles.color_ramp = _ramps[color]
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


## Проиграть покадровый эффект один раз в точке `pos` (центр), размер —
## по большей стороне кадра. Возвращает сигнал окончания.
func play(anim: String, pos: Vector2, size := 160.0, fps := VFX_FPS) -> Signal:
	if not enabled:
		return get_tree().process_frame
	var frames := _sprite_frames(anim, fps, false)
	if frames == null:
		return get_tree().process_frame
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = pos
	sprite.scale = Vector2.ONE * (size / _frame_side(frames))
	add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"default")
	return sprite.animation_finished


## Узел для полёта: TextureRect с иконкой либо Control с зацикленной анимацией.
func _fly_node(visual: Variant, size: float) -> Control:
	var node: Control
	if visual is String:
		node = Control.new()
		var frames := _sprite_frames(String(visual), VFX_FPS, true)
		if frames != null:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.position = Vector2.ONE * size * 0.5
			sprite.scale = Vector2.ONE * (size / _frame_side(frames))
			# Струйка монет не крутится в такт: каждая со своего кадра.
			sprite.frame = randi() % frames.get_frame_count(&"default")
			node.add_child(sprite)
			sprite.play(&"default")
	else:
		var icon := TextureRect.new()
		icon.texture = visual
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node = icon
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = Vector2.ONE * size
	node.pivot_offset = node.size * 0.5
	return node


## SpriteFrames из <имя>_1.png, <имя>_2.png… (кэш). null — кадров нет.
func _sprite_frames(anim: String, fps: float, loop: bool) -> SpriteFrames:
	var key := "%s|%s" % [anim, loop]
	if _frames.has(key):
		return _frames[key]
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", loop)
	var i := 1
	while ResourceLoader.exists("%s%s_%d.png" % [VFX_DIR, anim, i]):
		frames.add_frame(&"default", load("%s%s_%d.png" % [VFX_DIR, anim, i]))
		i += 1
	var result: SpriteFrames = frames if i > 1 else null
	_frames[key] = result
	return result


## Большая сторона первого кадра — к ней приводим заданный размер.
static func _frame_side(frames: SpriteFrames) -> float:
	var tex := frames.get_frame_texture(&"default", 0)
	return maxf(1.0, maxf(tex.get_width(), tex.get_height()))


## Тост: короткое сообщение с иконкой под рядом заказов. Сам исчезает;
## старые выталкиваются, если их больше TOAST_MAX. `kind` — "info" | "error" |
## "success". Такой же тост уже на экране — он «встряхивается», а не дублируется.
func toast(text: String, icon: Texture2D = null, kind := "info") -> void:
	if not enabled or text.is_empty():
		return
	for existing in _toasts.get_children():
		if existing.has_meta("text") and existing.get_meta("text") == text \
				and not existing.is_queued_for_deletion():
			_restart_toast(existing as Control)
			return
	while _toasts.get_child_count() >= TOAST_MAX:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var item := TOAST.instantiate() as Control
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(item)
	item.set_meta("text", text)
	item.theme_type_variation = TOAST_STYLES.get(kind, &"Toast")
	(item.get_node("%Text") as Label).text = text
	var icon_rect := item.get_node("%Icon") as TextureRect
	icon_rect.texture = icon
	icon_rect.visible = icon != null

	# Появление: из прозрачного и чуть меньше, исчезновение — растворение.
	# Контейнер владеет position/size, поэтому анимируем только scale и modulate.
	item.modulate.a = 0.0
	item.resized.connect(func() -> void: item.pivot_offset = item.size * 0.5)
	item.scale = Vector2.ONE * 0.85
	_restart_toast(item)


## (Пере)запустить жизнь тоста: появление, пауза, растворение.
func _restart_toast(item: Control) -> void:
	if item.has_meta("tween"):
		var old: Tween = item.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
		# Повтор того же сообщения — короткий «пульс».
		item.scale = Vector2.ONE * 1.08
	var tween := item.create_tween()
	item.set_meta("tween", tween)
	tween.tween_property(item, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(item, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(item, "modulate:a", 0.0, 0.3)
	tween.tween_callback(item.queue_free)


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

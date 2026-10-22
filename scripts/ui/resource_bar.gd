extends Control

## Плашка ресурса HUD (scenes/ui/resource_bar.tscn): фон с «+» в арте,
## иконка слева, число по центру. Иконку и «+» задаёт сцена-владелец.
##
## Число не прыгает, а «докручивается» до нового значения. Пока к плашке летят
## монеты (fx_layer.gd), её можно придержать — hold(): значение запомнится и
## начнёт докручиваться, когда монеты долетят.

signal plus_pressed

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			(%Icon as TextureRect).texture = value
## false — «+» не нажимается (у монет покупки нет).
@export var show_plus := true

var value: int:
	set(v):
		value = v
		if not is_node_ready():
			return
		if not _initialized:
			# Первое значение (загрузка сейва) — сразу, без докрутки.
			_initialized = true
			_set_shown(float(v))
		elif Time.get_ticks_msec() >= _hold_until:
			_animate()

var _initialized := false
var _shown := 0
var _hold_until := 0
var _tween: Tween
var _punch: Tween


func _ready() -> void:
	(%Icon as TextureRect).texture = icon
	_set_shown(float(value))
	var plus := %Plus as TextureButton
	plus.visible = show_plus
	plus.pressed.connect(func() -> void: plus_pressed.emit())
	var icon_rect := %Icon as Control
	icon_rect.resized.connect(func() -> void: icon_rect.pivot_offset = icon_rect.size * 0.5)


## Придержать число на `seconds`: потом оно докрутится до последнего value.
func hold(seconds: float) -> void:
	_hold_until = maxi(_hold_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _hold_until:
			_animate())


## «Пружина» иконки — на прилёт монеты.
func punch() -> void:
	var icon_rect := %Icon as Control
	if _punch != null and _punch.is_valid():
		_punch.kill()
	icon_rect.scale = Vector2.ONE * 1.25
	_punch = create_tween()
	_punch.tween_property(icon_rect, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Экранный центр иконки — цель для летящих монет.
func icon_center() -> Vector2:
	return (%Icon as Control).get_global_rect().get_center()


func _animate() -> void:
	if _shown == value:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var duration := clampf(absf(value - _shown) / 400.0, 0.25, 0.7)
	_tween = create_tween()
	_tween.tween_method(_set_shown, float(_shown), float(value), duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _set_shown(v: float) -> void:
	_shown = roundi(v)
	(%Value as Label).text = format_number(_shown)


## 1279 → «1 279» (узкий неразрывный пробел между тысячами).
static func format_number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out

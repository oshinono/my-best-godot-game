extends RefCounted

## Безопасные зоны экрана (адаптация под iPhone: вырез/чёлка сверху,
## home-индикатор снизу, скруглённые углы по бокам).
##
## DisplayServer отдаёт зону в ФИЗИЧЕСКИХ пикселях экрана, а игра считает
## координаты в логических единицах viewport (stretch canvas_items + expand).
## Поэтому вставки делим на масштаб окна. На десктопе и Android вставки нулевые.
##
## Использование:
##   SAFE_AREA.apply_margins(%Safe, 16.0)    # корневой MarginContainer экрана
##   SAFE_AREA.apply_offsets(_hud_root)      # HUD (Control с FULL_RECT)
##   var i := SAFE_AREA.insets()             # ручная раскладка (поле, попапы)

const BASE_WIDTH_KEY := "display/window/size/viewport_width"
const BASE_HEIGHT_KEY := "display/window/size/viewport_height"

## Отладочные вставки: на десктопе DisplayServer всегда отдаёт нули, поэтому
## проблемы под чёлкой/индикатором не видно. Выставьте значение один раз при
## старте (например, в `main.gd`) и проверьте все экраны:
##   SafeArea.debug_insets = Vector4(0, 108, 0, 62)   # как на iPhone с чёлкой
## Ноль (по умолчанию) — режим выключен, работают настоящие вставки.
static var debug_insets := Vector4.ZERO


## Вставки в логических единицах: (left, top, right, bottom). Всё ≥ 0.
## Корень HUD — обычный Control с якорями FULL_RECT: подставляем вставки в его
## offset_* (Container для этого не годится — он растянул бы детей на всю панель).
static func insets() -> Vector4:
	if debug_insets != Vector4.ZERO:
		return debug_insets
	if not is_mobile():
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4.ZERO
	var area_rect := DisplayServer.get_display_safe_area()
	var area := Rect2(Vector2(area_rect.position), Vector2(area_rect.size))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return Vector4.ZERO
	# Зона больше окна — значит окно не на весь экран (или данные не про мобильный).
	# В этом случае ориентируемся на весь экран, а не на «обрезки».
	if area.size.x > window.x + 1.0 or area.size.y > window.y + 1.0:
		return Vector4.ZERO

	var scale := _scale(window)
	if scale <= 0.0:
		return Vector4.ZERO
	var left := maxf(0.0, area.position.x / scale)
	var top := maxf(0.0, area.position.y / scale)
	var right := maxf(0.0, (window.x - area.position.x - area.size.x) / scale)
	var bottom := maxf(0.0, (window.y - area.position.y - area.size.y) / scale)
	return Vector4(left, top, right, bottom)


## Применить вставки к Control с якорями FULL_RECT (корень HUD):
## сдвигает его края внутрь, дети наследуют сдвиг через свои якоря.
static func apply_offsets(control: Control) -> void:
	if control == null:
		return
	var i := insets()
	control.offset_left = i.x
	control.offset_top = i.y
	control.offset_right = -i.z
	control.offset_bottom = -i.w


## Корневой MarginContainer экрана: вставки safe area + общий отступ `extra`.
## Звать при старте и на `size_changed` вьюпорта (поворот, смена окна).
static func apply_margins(container: MarginContainer, extra := 0.0) -> void:
	if container == null:
		return
	var i := insets()
	container.add_theme_constant_override("margin_left", roundi(i.x + extra))
	container.add_theme_constant_override("margin_top", roundi(i.y + extra))
	container.add_theme_constant_override("margin_right", roundi(i.z + extra))
	container.add_theme_constant_override("margin_bottom", roundi(i.w + extra))


static func is_mobile() -> bool:
	var name := OS.get_name()
	return name == "iOS" or name == "Android"


## Масштаб stretch canvas_items + expand: min(окно / базовый размер).
static func _scale(window: Vector2) -> float:
	var base := Vector2(
		float(ProjectSettings.get_setting(BASE_WIDTH_KEY, 720)),
		float(ProjectSettings.get_setting(BASE_HEIGHT_KEY, 1280))
	)
	if base.x <= 0.0 or base.y <= 0.0:
		return 0.0
	return minf(window.x / base.x, window.y / base.y)

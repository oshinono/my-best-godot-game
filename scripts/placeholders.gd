class_name Placeholders
extends RefCounted

## Плейсхолдер-текстуры: пока нет арта, предметы рисуются в коде.
## Цвет = цепочка, яркость = уровень, пипсы внизу = уровень.
## Когда появится настоящий арт — он подключается через ItemData.icon,
## и этот файл перестаёт использоваться (оставляем для отладки/фолбэка).

const SIZE := 64
const BORDER := Color("4A3226")
const DEFAULT_FILL := Color("C98A5E")

const COLORS := {
	Chains.COFFEE: Color("8A5A3B"),
	Chains.PASTRY: Color("E2946B"),
	Chains.FLOWERS: Color("A8C0A0"),
	&"energy": Color("F2C14E"),
	&"coin": Color("F2C14E"),
	&"gem": Color("7C6A8A"),
}

static var _cache: Dictionary = {}


static func chain_color(chain: StringName) -> Color:
	return COLORS.get(chain, DEFAULT_FILL)


static func item_texture(chain: StringName, level: int) -> Texture2D:
	var key := "%s_%d" % [chain, level]
	if _cache.has(key):
		return _cache[key]
	var texture := _make_item_texture(chain, level)
	_cache[key] = texture
	return texture


static func _make_item_texture(chain: StringName, level: int) -> Texture2D:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var fill := chain_color(chain).lightened(clampf(0.055 * float(level - 1), 0.0, 0.42))

	for y in SIZE:
		for x in SIZE:
			if _outside_round_rect(x, y, 1, 1, SIZE - 2, SIZE - 2, 12):
				continue
			var is_border := _outside_round_rect(x, y, 4, 4, SIZE - 5, SIZE - 5, 10)
			image.set_pixel(x, y, BORDER if is_border else fill)

	_draw_pips(image, level)
	return ImageTexture.create_from_image(image)


## Пипсы уровня: до 10 штук в ряд снизу (4 px + 2 px зазор => 58 px на 10).
static func _draw_pips(image: Image, level: int) -> void:
	var pips := clampi(level, 1, 10)
	var pip := 4
	var gap := 2
	var total := pips * pip + (pips - 1) * gap
	var start_x := int(floor(float(SIZE - total) / 2.0))
	var pip_y := SIZE - 13
	for i in pips:
		var px := start_x + i * (pip + gap)
		for y in range(pip_y, pip_y + pip):
			for x in range(px, px + pip):
				image.set_pixel(x, y, BORDER)


static func _outside_round_rect(x: int, y: int, x0: int, y0: int, x1: int, y1: int, radius: int) -> bool:
	if x < x0 or y < y0 or x > x1 or y > y1:
		return true
	var cx := clampi(x, x0 + radius, x1 - radius)
	var cy := clampi(y, y0 + radius, y1 - radius)
	var dx := float(x - cx)
	var dy := float(y - cy)
	return dx * dx + dy * dy > float(radius * radius)

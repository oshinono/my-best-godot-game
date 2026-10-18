class_name Iso
extends RefCounted

## Изо-проекция 2:1 (docs/GDD.md §8.1): тайл ↔ экран.
## Тайл — ромб 128×64 px. Прямая проекция:
##   screen.x = (tx - ty) * TILE_W/2
##   screen.y = (tx + ty) * TILE_H/2
## Обратная — та же система, решается алгебраически (см. screen_to_tile).
## Чистая математика без состояния: используется и рендером (cafe_view.gd),
## и самопроверкой (game.gd).

const TILE_W := 128.0
const TILE_H := 64.0


## Тайловые координаты → экранные (пиксели изо-мира, до зума/пана).
static func tile_to_screen(tx: float, ty: float) -> Vector2:
	return Vector2((tx - ty) * (TILE_W * 0.5), (tx + ty) * (TILE_H * 0.5))


## Экранные → тайловые (обратная проекция).
static func screen_to_tile(pos: Vector2) -> Vector2:
	var u := pos.x / (TILE_W * 0.5)
	var v := pos.y / (TILE_H * 0.5)
	return Vector2((u + v) * 0.5, (v - u) * 0.5)


## Центр прямоугольной области (tx, ty, w, h) в экранных пикселях.
static func tile_center(tx: float, ty: float, w: float, h: float) -> Vector2:
	return tile_to_screen(tx + w * 0.5, ty + h * 0.5)


## Ромб области (tx, ty, w, h), координаты — относительно центра области
## (для Polygon2D: узел ставим в tile_center, точки — локальные).
static func diamond(tx: float, ty: float, w: float, h: float) -> PackedVector2Array:
	var c := tile_center(tx, ty, w, h)
	return PackedVector2Array([
		tile_to_screen(tx, ty) - c,
		tile_to_screen(tx + w, ty) - c,
		tile_to_screen(tx + w, ty + h) - c,
		tile_to_screen(tx, ty + h) - c,
	])

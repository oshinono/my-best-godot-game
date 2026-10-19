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

var data: ItemData
var cell: int = -1

var _cell_size: float = 96.0
var _dragging: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


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


## Короткий «тычок» после слияния.
func punch() -> void:
	if _sprite == null:
		return
	var target := (_cell_size * SPRITE_FILL) / maxf(1.0, maxf(_sprite.texture.get_size().x, _sprite.texture.get_size().y))
	var final_scale := Vector2.ONE * target
	_sprite.scale = final_scale * 0.6
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", final_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	if data == null or _sprite == null:
		return
	var art := ART.item_texture(data.chain, data.level)
	var tex: Texture2D = data.icon
	if tex == null:
		tex = art if art != null else Placeholders.item_texture(data.chain, data.level)
	_sprite.texture = tex

	var size := tex.get_size()
	var factor := (_cell_size * SPRITE_FILL) / maxf(1.0, maxf(size.x, size.y))
	if _dragging:
		factor *= 1.12
	_sprite.scale = Vector2.ONE * factor

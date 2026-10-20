extends Control

## Плашка ресурса HUD (scenes/ui/resource_bar.tscn): фон с «+» в арте,
## иконка слева, число по центру. Иконку и «+» задаёт сцена-владелец.

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
		if is_node_ready():
			(%Value as Label).text = str(v)


func _ready() -> void:
	(%Icon as TextureRect).texture = icon
	(%Value as Label).text = str(value)
	var plus := %Plus as TextureButton
	plus.visible = show_plus
	plus.pressed.connect(func() -> void: plus_pressed.emit())

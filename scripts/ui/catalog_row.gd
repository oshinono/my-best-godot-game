extends HBoxContainer

## Строка каталога мебели (scenes/ui/catalog_row.tscn): карточка арта
## (спрайт предмета или его короткое имя, XP на плашке), название, комната
## и кнопка покупки с ценой.

signal buy_pressed(decor_id: String)

const DATA := preload("res://scripts/data/meta.gd")


func setup(decor: Dictionary, owned: bool) -> void:
	var decor_id := String(decor.get("id", ""))
	var path: String = DATA.decor_sprite(decor_id, 0)
	var sprite := %Sprite as TextureRect
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	sprite.visible = sprite.texture != null
	var short := %Short as Label
	short.text = String(decor.get("short", decor_id))
	short.visible = not sprite.visible
	(%Xp as Label).text = "+%d XP" % int(decor.get("xp", 0))
	(%Name as Label).text = String(decor.get("name", ""))
	(%Room as Label).text = String(decor.get("room", ""))

	var buy := %Buy as Button
	buy.disabled = owned
	if owned:
		buy.text = "Куплено"
		buy.icon = null
	else:
		buy.text = "%d" % int(decor.get("cost", 0))
	buy.pressed.connect(func() -> void: buy_pressed.emit(decor_id))

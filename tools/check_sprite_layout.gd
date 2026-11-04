extends SceneTree

func _initialize() -> void:
	var card := load("res://scenes/ui/cat_card.tscn").instantiate() as Control
	root.add_child(card)
	card.size = Vector2(500, 144)
	await process_frame
	await process_frame
	var portrait := card.get_node("Slot/Portrait") as Control
	assert(portrait.size.x >= 90.0)
	assert(absf(portrait.get_global_rect().get_center().y - card.get_global_rect().get_center().y) < 12.0)
	var cafe := load("res://scripts/ui/cafe_view.gd").new() as CanvasLayer
	var sprite := Sprite2D.new()
	var image := Image.create(314, 345, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	cafe._fit_sprite(sprite, texture, Vector2i.ONE)
	assert(sprite.scale.x * texture.get_width() <= 128.0)
	assert(is_equal_approx(sprite.position.y + texture.get_height() * sprite.scale.y * 0.5, 32.0))
	sprite.free()
	var data := load("res://scripts/data/meta.gd")
	var mount: Dictionary = data.wall_mount(Vector2i(1, 8), Vector2i.ONE)
	assert(not mount.is_empty())
	var anchor: Vector2i = mount["tile"]
	var outward := Vector2i(0, -1) if int(mount["axis"]) == 0 else Vector2i(-1, 0)
	assert(data.room_at(anchor + outward).is_empty())
	cafe.free()
	card.queue_free()
	print("[sprite_layout] OK")
	quit()

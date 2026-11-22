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
	var bounds := Rect2i(36, 50, 205, 224)
	image.fill_rect(bounds, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	cafe._fit_sprite(sprite, texture, Vector2i.ONE)
	assert(is_equal_approx(sprite.scale.x * bounds.size.y, 128.0 * 0.63))
	assert(is_equal_approx(sprite.position.y + bounds.size.y * sprite.scale.y * 0.5, 64.0 * 0.28))
	assert(absf(sprite.get_rect().position.x + Rect2(bounds).get_center().x) <= 0.5)
	sprite.free()
	var data := load("res://scripts/data/meta.gd")
	# Длинная кромка дивана совпадает с направлением двух клеток во всех ракурсах.
	for rot in 4:
		var sofa: Dictionary = data.decor("sofa")
		var node: Node2D = cafe._make_item("sofa", sofa, rot)
		var art := node.get_node("Sprite") as Sprite2D
		var edge: float = cafe.DECOR_EDGE["sofa"][rot]
		var axis := art.transform.basis_xform(Vector2(1, edge))
		assert(is_equal_approx(axis.y / axis.x, 0.5 if rot % 2 == 0 else -0.5))
		node.free()
	var mount: Dictionary = data.wall_mount(Vector2i(1, 8), Vector2i.ONE)
	assert(not mount.is_empty())
	var anchor: Vector2i = mount["tile"]
	var outward := Vector2i(0, -1) if int(mount["axis"]) == 0 else Vector2i(-1, 0)
	assert(data.room_at(anchor + outward).is_empty())
	cafe.free()
	card.queue_free()
	var ui := load("res://scenes/ui/cafe_ui.tscn").instantiate() as Control
	root.add_child(ui)
	var scroll := ui.get_node("%InventoryScroll") as ScrollContainer
	var row := ui.get_node("%Chips") as HBoxContainer
	for i in 24:
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(104, 92)
		row.add_child(chip)
	await process_frame
	await process_frame
	assert(is_equal_approx(scroll.size.y, 92.0))
	scroll.scroll_horizontal = 104
	assert(scroll.scroll_horizontal == 104)
	ui.queue_free()
	print("[sprite_layout] OK")
	quit()

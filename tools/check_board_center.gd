extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud = load("res://scenes/ui/game_hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var initial: Rect2 = hud.board_rect()
	for count in [1, 4, 0, 2]:
		hud.ensure_order_cards(count, func(_index): pass, func(_index): pass)
		await process_frame
		if hud.board_rect() != initial or not initial.get_center().is_equal_approx(root.get_visible_rect().get_center()):
			push_error("Order count changed board geometry or board is off-center")
			quit(1)
			return
	print("[board_center] OK")
	quit()

extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var popup = load("res://scenes/ui/choice_popup.tscn").instantiate()
	root.add_child(popup)
	popup.open_baristas("mocha", ["mocha", "latte"])
	assert(popup.visible and popup.get_node("%List").get_child_count() == 2)
	assert(popup.get_node("%List").get_child(0).text.begins_with("✓"))
	for kind in ["coins", "gems"]:
		popup.open_shop(kind)
		var offers := popup.get_node("%List") as VBoxContainer
		assert(offers.get_child_count() > 0)
		assert((offers.get_child(0) as Button).disabled)
	popup.close()
	assert(not popup.visible)
	await process_frame
	print("[choice_popup] OK")
	quit()

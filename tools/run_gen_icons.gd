extends SceneTree

func _initialize() -> void:
	var script := load("res://tools/gen_icons.gd")
	var runner := Node.new()
	runner.set_script(script)
	root.add_child(runner)
	await runner.ready
	quit()

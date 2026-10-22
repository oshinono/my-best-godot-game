extends "res://scripts/ui/popup_base.gd"

## Ивент (scenes/ui/event_popup.tscn): таймер, полоса очков и шкала наград.
## Очки и выдачу наград считает game.gd (scripts/event_state.gd).

signal claim_requested(index: int)

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)


## milestones — [{points, text, state}], state: "claimed" | "ready" | "locked".
func show_event(title: String, time_left: String, points: int, goal: int,
		milestones: Array, hint: String) -> void:
	(%Title as Label).text = title
	(%Timer as Label).text = "Осталось: %s" % time_left
	var bar := %Bar as ProgressBar
	bar.max_value = maxf(1.0, goal)
	bar.value = mini(points, goal)
	(%Points as Label).text = "%d / %d" % [mini(points, goal), goal]
	(%Hint as Label).text = hint
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for i in milestones.size():
		_list.add_child(_row(i, milestones[i]))
	if visible:
		_relayout.call_deferred()


func _row(index: int, m: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ChipSelected" if m.get("state") == "ready" else &"Chip"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var points := Label.new()
	points.theme_type_variation = &"HeaderLabel"
	points.custom_minimum_size = Vector2(70, 0)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points.text = str(int(m.get("points", 0)))
	row.add_child(points)
	var reward := Label.new()
	reward.theme_type_variation = &"BodyLabel"
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward.text = String(m.get("text", ""))
	row.add_child(reward)
	match String(m.get("state", "locked")):
		"ready":
			var claim := Button.new()
			claim.theme_type_variation = &"PrimaryButton"
			claim.custom_minimum_size = Vector2(170, 64)
			claim.text = "Забрать"
			claim.pressed.connect(func() -> void: claim_requested.emit(index))
			row.add_child(claim)
		"claimed":
			var done := Label.new()
			done.theme_type_variation = &"BodyLabel"
			done.add_theme_color_override("font_color", Color("4F8F2F"))
			done.custom_minimum_size = Vector2(170, 64)
			done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			done.text = "Получено"
			row.add_child(done)
		_:
			var lock := Label.new()
			lock.theme_type_variation = &"HintLabel"
			lock.custom_minimum_size = Vector2(170, 64)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock.text = "ещё %d" % int(m.get("missing", 0))
			row.add_child(lock)
	return card

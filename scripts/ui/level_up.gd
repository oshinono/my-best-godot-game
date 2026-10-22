extends CanvasLayer

## Окно «Новый уровень!» (scenes/ui/level_up.tscn): значок с номером уровня
## и что открылось. Появляется «пружиной», закрывается кнопкой, тапом мимо
## или само через AUTO_CLOSE секунд.

signal closed

const AUTO_CLOSE := 3.5

@onready var _panel: Control = %Panel
var _shown_at := 0


func _ready() -> void:
	visible = false
	(%Ok as BaseButton).pressed.connect(close)
	(%Dim as Control).gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			close())


func show_level(level: int, note: String) -> void:
	(%Level as Label).text = str(level)
	var note_label := %Note as Label
	note_label.text = note
	note_label.visible = not note.is_empty()
	visible = true
	var stamp := Time.get_ticks_msec()
	_shown_at = stamp

	# Pivot — по центру панели: её размер известен только после раскладки.
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.6
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Автозакрытие — только если за это время окно не открыли заново.
	await get_tree().create_timer(AUTO_CLOSE).timeout
	if visible and _shown_at == stamp:
		close()


func close() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		visible = false
		closed.emit())

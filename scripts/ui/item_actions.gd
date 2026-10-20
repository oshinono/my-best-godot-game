extends CanvasLayer

## Меню действий по тапу на предмет (docs/GDD.md §18), scenes/ui/item_actions.tscn:
## затемнение + карточка «название, подсказка, Продать / Отмена».
## Карточка — контейнеры + Theme (ActionFrame); единственное, что считает код, —
## куда её поставить: рядом с предметом, но целиком в safe area.

signal sell_pressed
signal closed

const SAFE := preload("res://scripts/ui/safe_area.gd")
const SCREEN_MARGIN := 16.0

@onready var _card: Control = %Card


func _ready() -> void:
	visible = false
	(%Sell as BaseButton).pressed.connect(func() -> void: sell_pressed.emit())
	(%Cancel as BaseButton).pressed.connect(close)
	(%Scrim as Control).gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			close())


## anchor — прямоугольник предмета на экране: карточка встаёт под ним
## (или над ним, если снизу не влезает).
func open(title: String, hint: String, price: int, anchor: Rect2) -> void:
	(%Title as Label).text = title
	var hint_label := %Hint as Label
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()
	(%Sell as Button).text = "Продать за %d" % price
	visible = true
	_card.reset_size()
	_place.call_deferred(anchor)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _place(anchor: Rect2) -> void:
	# Ширина карточки уже известна — пересчитываем высоту по контенту.
	_card.reset_size()
	var card := _card.size
	var view := get_viewport().get_visible_rect().size
	var ins := SAFE.insets()
	var min_pos := Vector2(ins.x, ins.y) + Vector2.ONE * SCREEN_MARGIN
	var max_pos := view - Vector2(ins.z, ins.w) - card - Vector2.ONE * SCREEN_MARGIN
	var pos := Vector2(anchor.get_center().x - card.x * 0.5, anchor.end.y + SCREEN_MARGIN)
	if pos.y > max_pos.y:
		pos.y = anchor.position.y - SCREEN_MARGIN - card.y
	_card.position = pos.clamp(min_pos, max_pos.max(min_pos))

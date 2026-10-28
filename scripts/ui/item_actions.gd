extends CanvasLayer

## Меню действий по тапу на предмет (docs/GDD.md §18), scenes/ui/item_actions.tscn:
## затемнение + карточка «название, подсказка, Продать / Отмена, Цепочка».
## У пузыря вместо продажи — «Забрать за N гемов», второго ряда нет.
## Карточка — контейнеры + Theme (ActionFrame); единственное, что считает код, —
## куда её поставить: рядом с предметом, но целиком в safe area.

## Главная кнопка: продать (обычный предмет) или забрать (пузырь).
signal sell_pressed
signal chain_pressed
signal closed

const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
const GEM_ICON := preload("res://assets/ui/theme/icon_gem.png")

const SAFE := preload("res://scripts/ui/safe_area.gd")
const SCREEN_MARGIN := 16.0

@onready var _card: Control = %Card


func _ready() -> void:
	visible = false
	(%Sell as BaseButton).pressed.connect(func() -> void: sell_pressed.emit())
	(%Cancel as BaseButton).pressed.connect(close)
	(%Chain as BaseButton).pressed.connect(func() -> void: chain_pressed.emit())
	(%Scrim as Control).gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			close())


## anchor — прямоугольник предмета на экране: карточка встаёт под ним
## (или над ним, если снизу не влезает).
func open(title: String, hint: String, price: int, anchor: Rect2) -> void:
	var sell := %Sell as Button
	sell.text = "Продать за %d" % price
	sell.icon = COIN_ICON
	sell.disabled = false
	(%More as Control).visible = true
	_show(title, hint, anchor)


## Пузырь: «Забрать за N гемов»; кнопка выключена, если гемов не хватает.
func open_bubble(title: String, hint: String, gems: int, affordable: bool, anchor: Rect2) -> void:
	var sell := %Sell as Button
	sell.text = "Забрать за %d" % gems
	sell.icon = GEM_ICON
	sell.disabled = not affordable
	(%More as Control).visible = false
	_show(title, hint, anchor)


func _show(title: String, hint: String, anchor: Rect2) -> void:
	(%Title as Label).text = title
	var hint_label := %Hint as Label
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()
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

extends "res://scripts/ui/popup_base.gd"

## Ремонт кафе (scenes/ui/tasks_popup.tscn): ближайшие задания — поставить
## мебель. Цена задания — звёзды (за заказы) и монеты; готовое задание сразу
## ставит предмет в его комнату. Список и правила считает game.gd.

signal task_requested(decor_id: String)

const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
const COLOR_TEXT := Color("4A3A2E")

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)


## tasks — [{id, name, room, xp, stars, coins, ready}], ready — хватает ли
## звёзд и монет; done/total — сколько предметов кафе уже обустроено.
func show_tasks(stars: int, tasks: Array, done: int, total: int) -> void:
	(%Stars as Label).text = "★ %d" % stars
	(%Progress as Label).text = "Обустроено: %d из %d" % [done, total]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if tasks.is_empty():
		var all_done := Label.new()
		all_done.theme_type_variation = &"BodyLabel"
		all_done.text = "Кафе обустроено полностью!"
		all_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(all_done)
	for task: Dictionary in tasks:
		_list.add_child(_task_card(task))
	if visible:
		_relayout.call_deferred()


## Карточка задания на арте ListCard: в слоте — первая буква предмета.
func _task_card(task: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ListCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder)
	var letter := Label.new()
	letter.theme_type_variation = &"TitleLabel"
	letter.text = String(task.get("name", "?")).left(1)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(letter)
	# Слот арта 21..73 по X, контент начинается с 92 (см. ListCard в теме).
	letter.anchor_bottom = 1.0
	letter.offset_left = 21.0 - 92.0
	letter.offset_right = 73.0 - 92.0
	letter.offset_top = -16.0
	letter.offset_bottom = 16.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var title := Label.new()
	title.theme_type_variation = &"BodyLabel"
	title.text = String(task.get("name", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"HintLabel"
	sub.text = "%s · +%d XP" % [String(task.get("room", "")), int(task.get("xp", 0))]
	info.add_child(sub)

	var go := Button.new()
	go.theme_type_variation = &"PrimaryButton"
	go.custom_minimum_size = Vector2(200, 76)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 20)
	go.text = "★%d · %d" % [int(task.get("stars", 0)), int(task.get("coins", 0))]
	go.icon = COIN_ICON
	go.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	go.disabled = not bool(task.get("ready", false))
	var decor_id := String(task.get("id", ""))
	go.pressed.connect(func() -> void: task_requested.emit(decor_id))
	row.add_child(go)
	return card

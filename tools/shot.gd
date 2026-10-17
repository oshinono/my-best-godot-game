extends Node
## Отладочная проба вёрстки: печатает реальную геометрию попапа меты и
## прогоняет расстановку мебели, возвращая сейв в исходное состояние.
## dummy-рендер скриншот не даёт, но раскладка Control считается и в нём.
## Запуск: editor-run со сценой res://tools/shot.tscn (main scene не трогать).

const META_POPUP := preload("res://scripts/ui/meta_popup.gd")

var _popup: CanvasLayer
var _placed_backup: Dictionary = {}


func _ready() -> void:
	print("[probe] ready")
	_placed_backup = Meta.placed.duplicate()
	_popup = META_POPUP.new()
	add_child(_popup)
	_popup.open()
	await get_tree().process_frame
	await get_tree().process_frame

	var list: VBoxContainer = _popup._list
	print("[probe] daily: list=", list.size)
	for child in list.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				var tile: Control = sub
				print("[probe]   tile size=", tile.size, " min=", tile.get_combined_minimum_size())

	# In-memory: два предмета куплены, один поставлен в зал. Писать в сейв нельзя.
	Meta.owned_decor.append("sofa")
	Meta.owned_decor.append("fountain")
	Meta.placed["hall_1"] = "sofa"

	print("[probe] placed_count=", Meta.placed_count(), " unplaced=", Meta.unplaced_decor().size(),
		" slot(hall_1)=", Meta.slot_decor("hall_1"), " decor_slot(sofa)=", Meta.decor_slot("sofa"))
	var wrong: Dictionary = Meta.place_decor("fountain", "hall_2")
	print("[probe] wrong room -> ok=", wrong.get("ok"), " reason=", wrong.get("reason"))
	var unowned: Dictionary = Meta.place_decor("rug", "hall_2")
	print("[probe] unowned -> ok=", unowned.get("ok"), " reason=", unowned.get("reason"))

	_popup.place_requested.connect(func(decor_id: String, slot_id: String) -> void:
		print("[probe] signal place_requested ", decor_id, " -> ", slot_id))
	_popup.clear_slot_requested.connect(func(slot_id: String) -> void:
		print("[probe] signal clear_slot_requested ", slot_id))

	_popup._select_tab(3)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[probe] map: children=", list.get_child_count())
	for child in list.get_children():
		var control: Control = child
		print("[probe]   ", control.get_class(), " size=", control.size)
		if child is HBoxContainer:
			for chip in child.get_children():
				var button: Button = chip
				print("[probe]     chip \"", button.text, "\" pressed=", button.button_pressed, " size=", button.size)
		if child is PanelContainer:
			var body: Control = child.get_child(0)
			for slot in body.get_children():
				var slot_button: Button = slot
				print("[probe]     slot \"", slot_button.text, "\" pos=", slot_button.position, " size=", slot_button.size)

	_popup._select_placing("fountain")
	await get_tree().process_frame
	print("[probe] after select: placing=", _popup._placing, " hint=\"", _popup._hint, "\"")
	var seen := 0
	for child in list.get_children():
		if child is PanelContainer:
			var body: Control = child.get_child(0)
			for slot in body.get_children():
				var slot_button: Button = slot
				var color: Color = slot_button.get_theme_color("font_color")
				print("[probe]     slot \"", slot_button.text, "\" color=", color.to_html(false))
				seen += 1

	_popup._on_slot_pressed("garden_1")
	_popup._on_slot_pressed("hall_1")
	await get_tree().process_frame
	print("[probe] slots seen=", seen, " done")

	# Возвращаем сейв как было: проба вызывала place_decor, который пишет decor_placed.
	Meta.placed = _placed_backup
	SaveManager.set_value("decor_placed", Meta.placed)
	print("[probe] save restored: placed=", Meta.placed)
	get_tree().quit()

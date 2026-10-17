extends CanvasLayer

## Мета-прогрессия (docs/GDD.md §8): ежедневная награда, коты, декор кофейни.
##
## Строится кодом, как scripts/ui/settings_popup.gd. Состояние читает из автолоада
## Meta (scripts/autoload/meta.gd) и таблиц scripts/data/meta.gd, а награды/покупки
## выдаёт game.gd по сигналам наружу. Размеры — под портретный viewport 720x1280.

signal daily_claim_requested
signal decor_buy_requested(decor_id: String)
signal place_requested(decor_id: String, slot_id: String)
signal clear_slot_requested(slot_id: String)
signal closed

const DATA := preload("res://scripts/data/meta.gd")
const TABS := ["🎁 День", "🐱 Коты", "🛋 Декор", "🏠 Карта"]

## Слоты расстановки: половина ширины/высоты кнопки слота (px).
const SLOT_HALF := Vector2(70.0, 30.0)
const ROOM_HEIGHT := 150.0

var _list: VBoxContainer
var _tabs: Array[Button] = []
var _tab := 0
## Выбранный на полке предмет для расстановки ("" — ничего не выбрано).
var _placing := ""
var _hint := ""


func _ready() -> void:
	layer = 3
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color("F6E7D8")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -550.0
	panel.offset_bottom = 550.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "🏠 Кофейня", -520)
	_build_tabs(panel)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_top = 0.5
	scroll.anchor_bottom = 0.5
	scroll.offset_left = -316.0
	scroll.offset_right = 316.0
	scroll.offset_top = -352.0
	scroll.offset_bottom = 300.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	var close_button := _button(panel, "Закрыть", 348)
	close_button.pressed.connect(close)


## Открыть и пересобрать содержимое (состояние могло измениться).
func open() -> void:
	visible = true
	_rebuild()


## Пересобрать, если попап открыт (после выдачи награды или покупки).
func refresh() -> void:
	if visible:
		_rebuild()


func close() -> void:
	visible = false
	closed.emit()


# --- Вкладки -----------------------------------------------------------------

func _build_tabs(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -318.0
	row.offset_right = 318.0
	row.offset_top = -428.0
	row.offset_bottom = -360.0
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	for index in TABS.size():
		var tab := Button.new()
		tab.text = String(TABS[index])
		tab.toggle_mode = true
		tab.button_pressed = index == _tab
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(func() -> void: _select_tab(index))
		row.add_child(tab)
		_tabs.append(tab)


func _select_tab(index: int) -> void:
	_tab = index
	_hint = ""
	for i in _tabs.size():
		_tabs[i].button_pressed = i == index
	_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		1:
			_build_cats()
		2:
			_build_decor()
		3:
			_build_map()
		_:
			_build_daily()


# --- Ежедневная награда (GDD §8.3) -------------------------------------------

func _build_daily() -> void:
	var streak := Meta.daily_streak
	var day := Meta.next_day()
	_line(_list, "Стрик: %d / %d" % [streak, DATA.DAILY_DAYS], 26)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_list.add_child(row)
	for index in DATA.DAILY_REWARDS.size():
		var reward: Dictionary = DATA.DAILY_REWARDS[index]
		var tile := _card(row, true)
		var number := index + 1
		_line(tile, "Д%d" % number, 16, Color("8A7566") if number != day else Color("C05621"))
		_line(tile, _reward_text(reward), 16, Color("4A3A2E") if number != day else Color("C05621"))

	var claim := Button.new()
	claim.text = "Забрать" if Meta.can_claim() else "Уже получено"
	claim.disabled = not Meta.can_claim()
	claim.custom_minimum_size = Vector2(0, 76)
	claim.add_theme_font_size_override("font_size", 28)
	claim.pressed.connect(func() -> void: daily_claim_requested.emit())
	_list.add_child(claim)

	_line(_list, "Пропущенный день сбрасывает стрик на первый. На 7-й день — котовый сундук.", 18, Color("8A7566"))


# --- Коты (GDD §8.2) ---------------------------------------------------------

func _build_cats() -> void:
	_line(_list, "Открыто: %d / %d · бонус +%d%% 🪙 за заказ" % [
		Meta.cat_count(), DATA.CATS.size(), Meta.cat_bonus_percent(),
	], 24)

	for item in DATA.CATS:
		var cat: Dictionary = item
		var unlocked := Meta.is_cat_unlocked(String(cat.get("id", "")))
		var card := _card(_list)
		var rarity := String(cat.get("rarity", "common"))
		_line(card, "%s %s · %s" % [
			DATA.rarity_icon(rarity), String(cat.get("name", "")), String(cat.get("role", "")),
		], 26, Color("4A3A2E") if unlocked else Color("8A7566"))
		_line(card, "%s · %s" % [DATA.rarity_name(rarity), "✅ В кафе" if unlocked else Meta.cat_status(cat)], 20, Color("8A7566"))
		var story := String(cat.get("story", ""))
		if story != "":
			_line(card, story, 18, Color("8A7566"))


# --- Декор кофейни (GDD §8.1) ------------------------------------------------

func _build_decor() -> void:
	var coins := int(SaveManager.get_value("coins", 0))
	_line(_list, "Куплено: %d / %d · уровень кофейни %d · монет %d 🪙" % [
		Meta.decor_count(), DATA.DECOR.size(), Progress.level, coins,
	], 22)

	for item in DATA.DECOR:
		var decor: Dictionary = item
		var decor_id := String(decor.get("id", ""))
		var owned := Meta.owns_decor(decor_id)
		var card := _card(_list)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		card.add_child(head)

		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(column)
		_line(column, String(decor.get("name", "")), 26, Color("4A3A2E") if owned else Color("8A7566"))
		var slot_id := Meta.decor_slot(decor_id)
		var place_text := "Купите — поставите на вкладке «🏠 Карта»"
		if slot_id != "":
			place_text = "📍 %s" % String(DATA.slot(slot_id).get("room", ""))
		elif owned:
			place_text = "Куплено, стоит на полке"
		_line(column, "%s · +%d XP · %s" % [String(decor.get("room", "")), int(decor.get("xp", 0)), place_text], 18, Color("8A7566"))

		var cost := int(decor.get("cost", 0))
		var buy := Button.new()
		buy.text = "Куплено" if owned else "%d 🪙" % cost
		buy.disabled = owned
		buy.custom_minimum_size = Vector2(180, 68)
		buy.add_theme_font_size_override("font_size", 22)
		buy.pressed.connect(func() -> void: decor_buy_requested.emit(decor_id))
		head.add_child(buy)


# --- Карта кофейни: расстановка мебели (GDD §8.1) -----------------------------

func _build_map() -> void:
	_line(_list, "Расставлено: %d / %d · куплено %d / %d" % [
		Meta.placed_count(), DATA.SLOTS.size(), Meta.decor_count(), DATA.DECOR.size(),
	], 22)

	var pool: Array = Meta.unplaced_decor()
	if _placing != "" and Meta.decor_slot(_placing) != "":
		_placing = ""

	if Meta.decor_count() == 0:
		_line(_list, "Мебели нет: купите её на вкладке «🛋 Декор».", 20, Color("8A7566"))
		return

	if pool.is_empty():
		_line(_list, "Вся купленная мебель расставлена. Тап по занятому слоту — снять предмет.", 20, Color("8A7566"))
	else:
		_line(_list, "1) Выберите предмет. 2) Тапните слот в его комнате.", 20, Color("8A7566"))
		var shelf := HBoxContainer.new()
		shelf.add_theme_constant_override("separation", 8)
		_list.add_child(shelf)
		for item in pool:
			var decor: Dictionary = item
			var decor_id := String(decor.get("id", ""))
			var chip := Button.new()
			chip.text = DATA.decor_short(decor)
			chip.toggle_mode = true
			chip.button_pressed = _placing == decor_id
			chip.clip_text = true
			chip.custom_minimum_size = Vector2(0, 64)
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.add_theme_font_size_override("font_size", 20)
			chip.pressed.connect(func() -> void: _select_placing(decor_id))
			shelf.add_child(chip)

	if _hint != "":
		_line(_list, _hint, 20, Color("C05621"))

	for room in DATA.ROOMS:
		var room_name := String(room.get("name", ""))
		_line(_list, "%s · слотов %d" % [room_name, DATA.room_slots(room_name).size()], 24)
		var body := _room_body(DATA.room_floor(room_name))
		for slot in DATA.room_slots(room_name):
			_add_slot_button(body, slot)


## Пол комнаты: панель-подложка, внутри — Control для позиций слотов.
func _room_body(floor_hex: String) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(floor_hex)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.set_content_margin_all(8.0)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(0, ROOM_HEIGHT)
	_list.add_child(box)

	var body := Control.new()
	body.custom_minimum_size = Vector2(0, ROOM_HEIGHT - 16.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	return body


## Кнопка слота: пустой слот показывает 📍, занятый — короткое имя предмета.
func _add_slot_button(body: Control, slot: Dictionary) -> void:
	var slot_id := String(slot.get("id", ""))
	var decor_id := Meta.slot_decor(slot_id)
	var center := Vector2(float(slot.get("x", 0.5)), float(slot.get("y", 0.5)))

	var button := Button.new()
	button.anchor_left = center.x
	button.anchor_right = center.x
	button.anchor_top = center.y
	button.anchor_bottom = center.y
	button.offset_left = -SLOT_HALF.x
	button.offset_right = SLOT_HALF.x
	button.offset_top = -SLOT_HALF.y
	button.offset_bottom = SLOT_HALF.y
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 18)

	var color := Color("8A7566")
	if decor_id != "":
		button.text = DATA.decor_short(DATA.decor(decor_id))
		color = Color("4A3A2E")
	else:
		var fits := _placing != "" and String(DATA.decor(_placing).get("room", "")) == String(slot.get("room", ""))
		button.text = "📍" if not fits else "➕"
		if fits:
			color = Color("2F855A")
	button.add_theme_color_override("font_color", color)
	button.pressed.connect(func() -> void: _on_slot_pressed(slot_id))
	body.add_child(button)


func _select_placing(decor_id: String) -> void:
	_placing = "" if _placing == decor_id else decor_id
	_hint = "" if _placing != "" else "Предмет снят с выбора."
	_rebuild()


func _on_slot_pressed(slot_id: String) -> void:
	if _placing != "":
		place_requested.emit(_placing, slot_id)
		return
	if Meta.slot_decor(slot_id) != "":
		clear_slot_requested.emit(slot_id)
		return
	_hint = "Сначала выберите предмет из полки выше."
	_rebuild()


# --- Хелперы -----------------------------------------------------------------

func _reward_text(reward: Dictionary) -> String:
	if reward.has("chest"):
		return "🐱 Сундук"
	if reward.has("coins"):
		return "%d 🪙" % int(reward.get("coins", 0))
	if reward.has("gems"):
		return "%d 💎" % int(reward.get("gems", 0))
	if reward.has("energy"):
		return "%d ⚡" % int(reward.get("energy", 0))
	return ""


func _title(parent: Node, text: String, top: float) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = top
	label.offset_bottom = top + 80.0
	label.add_theme_font_size_override("font_size", 42)
	parent.add_child(label)


func _button(parent: Node, text: String, top: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -290.0
	button.offset_right = 290.0
	button.offset_top = top
	button.offset_bottom = top + 88.0
	button.add_theme_font_size_override("font_size", 28)
	parent.add_child(button)
	return button


## Карточка: белая панель со скруглением, внутрь кладём текст/кнопки.
## `expand` — растягивать карточку по ширине родителя (для плиток в ряду:
## флаг ставится на сам PanelContainer, а не на внутренний VBox).
func _card(parent: Node, expand := false) -> VBoxContainer:
	var box := PanelContainer.new()
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("FFFFFF")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.set_content_margin_all(8.0 if expand else 14.0)
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	box.add_child(column)
	return column


func _line(parent: Node, text: String, size: int, color := Color("4A3A2E")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

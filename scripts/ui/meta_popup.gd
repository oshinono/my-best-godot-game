extends CanvasLayer

## Мета-прогрессия (docs/GDD.md §8): ежедневная награда, коты, декор кофейни.
##
## Строится кодом, как scripts/ui/settings_popup.gd. Состояние читает из автолоада
## Meta (scripts/autoload/meta.gd) и таблиц scripts/data/meta.gd, а награды/покупки
## выдаёт game.gd по сигналам наружу. Размеры — под портретный viewport 720x1280.

signal daily_claim_requested
signal open_cafe_requested
signal closed

const DATA := preload("res://scripts/data/meta.gd")
## Вкладки: id — иконка из assets/ui/icons (docs/ui-icons.md), text — подпись.
const TABS := [
	{"id": "gift", "text": "День"},
	{"id": "cat", "text": "Коты"},
	{"id": "sofa", "text": "Декор"},
	{"id": "home", "text": "Карта"},
]

var _list: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _tab := 0


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

	_title(panel, "Кофейня", -520, "home")
	_build_tabs(panel)

	_scroll = ScrollContainer.new()
	_scroll.anchor_left = 0.5
	_scroll.anchor_right = 0.5
	_scroll.anchor_top = 0.5
	_scroll.anchor_bottom = 0.5
	_scroll.offset_left = -316.0
	_scroll.offset_right = 316.0
	_scroll.offset_top = -352.0
	_scroll.offset_bottom = 300.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)

	var close_button := _button(panel, "Закрыть", 348)
	close_button.pressed.connect(close)

	# Точки карты должны обновляться, когда мебель ставят/снимают в кофейне.
	Meta.placement_changed.connect(_on_placement_changed)


## Открыть и пересобрать содержимое (состояние могло измениться).
func open() -> void:
	visible = true
	_rebuild()


## Открыть сразу на нужной вкладке (0..TABS.size()-1).
func open_tab(index: int) -> void:
	_tab = clampi(index, 0, _tabs.size() - 1)
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _tab
	open()


## Пересобрать, если попап открыт (после выдачи награды или покупки).
func refresh() -> void:
	if visible:
		_rebuild()


func close() -> void:
	visible = false
	closed.emit()


## Свайп-скролл пальцем. ScrollContainer сам тач-драг не умеет: при
## emulate_mouse_from_touch свайп приходит мышью, а левый драг он не листает.
func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _scroll.get_global_rect().has_point(drag.position):
			_scroll.scroll_vertical -= int(drag.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var on_scroll := _scroll.get_global_rect().has_point(motion.position)
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and on_scroll:
			_scroll.scroll_vertical -= int(motion.relative.y)
			get_viewport().set_input_as_handled()


func _on_placement_changed(_slot_id: String, _decor_id: String) -> void:
	if visible and _tab == 3:
		_rebuild()


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
		var tab_data: Dictionary = TABS[index]
		tab.text = String(tab_data.get("text", ""))
		Icons.decorate(tab, String(tab_data.get("id", "")), 24.0)
		tab.toggle_mode = true
		tab.button_pressed = index == _tab
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
		tab.add_theme_font_size_override("font_size", 20)
		Icons.flat(tab, Color(0.78, 0.45, 0.16, 0.28), Vector2(8.0, 8.0))
		tab.pressed.connect(func() -> void: _select_tab(index))
		row.add_child(tab)
		_tabs.append(tab)


func _select_tab(index: int) -> void:
	_tab = index
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
		_reward_line(tile, reward, Color("4A3A2E") if number != day else Color("C05621"))

	var claim := Button.new()
	claim.text = "Забрать" if Meta.can_claim() else "Уже получено"
	claim.disabled = not Meta.can_claim()
	claim.custom_minimum_size = Vector2(0, 76)
	claim.add_theme_font_size_override("font_size", 28)
	Icons.flat(claim)
	claim.pressed.connect(func() -> void: daily_claim_requested.emit())
	_list.add_child(claim)

	_line(_list, "Пропущенный день сбрасывает стрик на первый. На 7-й день — котовый сундук.", 18, Color("8A7566"))


# --- Коты (GDD §8.2) ---------------------------------------------------------

func _build_cats() -> void:
	_line(_list, "Открыто: %d / %d · бонус +%d%% за заказ" % [
		Meta.cat_count(), DATA.CATS.size(), Meta.cat_bonus_percent(),
	], 24)

	for item in DATA.CATS:
		var cat: Dictionary = item
		var unlocked := Meta.is_cat_unlocked(String(cat.get("id", "")))
		var card := _card(_list)
		var rarity := String(cat.get("rarity", "common"))
		_line(card, "%s · %s" % [
			String(cat.get("name", "")), String(cat.get("role", "")),
		], 26, Color("4A3A2E") if unlocked else Color("8A7566"))
		card.add_child(Icons.stars(DATA.rarity_stars(rarity), 18.0))
		_line(card, "%s · %s" % [
			DATA.rarity_name(rarity),
			"В кафе" if unlocked else Meta.cat_status(cat),
		], 20, Color("8A7566"))
		var story := String(cat.get("story", ""))
		if story != "":
			_line(card, story, 18, Color("8A7566"))


# --- Декор кофейни (GDD §8.1) ------------------------------------------------

func _build_decor() -> void:
	var coins := int(SaveManager.get_value("coins", 0))
	_line(_list, "Куплено: %d / %d · уровень кофейни %d · монет %d" % [
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
		var place_text := "купить можно в кофейне"
		if slot_id != "":
			place_text = "в комнате «%s»" % String(DATA.slot(slot_id).get("room", ""))
		elif owned:
			place_text = "Куплено, стоит на полке"
		_line(column, "%s · +%d XP · %s" % [String(decor.get("room", "")), int(decor.get("xp", 0)), place_text], 18, Color("8A7566"))

		# Здесь только цена: покупка живёт исключительно в изо-кофейне.
		var cost := int(decor.get("cost", 0))
		if owned:
			column.add_child(Icons.icon_label("check", "Куплено", 20.0, Color("8A7566"), 18))
		else:
			column.add_child(Icons.icon_label(
				"coin", "%d · купить можно в кофейне" % cost, 20.0, Color("8A7566"), 18
			))


# --- Кофейня: переход в изометрический вид (GDD §8.1) ------------------------

func _build_map() -> void:
	var placed := Meta.placed_count()
	_line(_list, "Расставлено: %d / %d · куплено %d / %d" % [
		placed, DATA.SLOTS.size(), Meta.decor_count(), DATA.DECOR.size(),
	], 22)
	_line(_list, "Места под мебель видны прямо в кофейне: откройте её и "
		+ "перетащите предмет из инвентаря.", 20, Color("8A7566"))

	var open_cafe := Button.new()
	open_cafe.text = "Открыть кофейню"
	Icons.decorate(open_cafe, "home", 28.0)
	open_cafe.custom_minimum_size = Vector2(0, 96)
	open_cafe.add_theme_font_size_override("font_size", 30)
	Icons.flat(open_cafe, Color(0.78, 0.45, 0.16, 0.22), Vector2(12.0, 10.0))
	open_cafe.pressed.connect(func() -> void: open_cafe_requested.emit())
	_list.add_child(open_cafe)


# --- Хелперы -----------------------------------------------------------------

## Строка награды ежедневки: иконка + значение (иконки — docs/ui-icons.md).
func _reward_line(parent: Node, reward: Dictionary, color: Color) -> void:
	var icon_id := ""
	var value := ""
	if reward.has("chest"):
		icon_id = "cat"
		value = "Сундук"
	elif reward.has("coins"):
		icon_id = "coin"
		value = str(int(reward.get("coins", 0)))
	elif reward.has("gems"):
		icon_id = "gem"
		value = str(int(reward.get("gems", 0)))
	elif reward.has("energy"):
		icon_id = "energy"
		value = str(int(reward.get("energy", 0)))
	if icon_id == "":
		return
	parent.add_child(Icons.icon_label(icon_id, value, 18.0, color, 16))


func _title(parent: Node, text: String, top: float, icon_id := "") -> void:
	if icon_id != "":
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.anchor_left = 0.0
		row.anchor_right = 1.0
		row.anchor_top = 0.5
		row.anchor_bottom = 0.5
		row.offset_left = 24.0
		row.offset_right = -24.0
		row.offset_top = top
		row.offset_bottom = top + 80.0
		row.add_child(Icons.rect(icon_id, 34.0))
		var row_label := _plain_label(text, 42, Color("4A3A2E"))
		# В HBox ширина лейбла считается по минимальному размеру, а с
		# автопереносом минимум схлопывается → каждая буква уходит вниз.
		row_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(row_label)
		parent.add_child(row)
		return
	var label := _plain_label(text, 42, Color("4A3A2E"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = top
	label.offset_bottom = top + 80.0
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
	Icons.flat(button, Color(0.78, 0.45, 0.16, 0.22), Vector2(12.0, 10.0))
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


func _plain_label(text: String, size: int, color := Color("4A3A2E")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _line(parent: Node, text: String, size: int, color := Color("4A3A2E")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

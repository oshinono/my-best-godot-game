extends CanvasLayer

## Мета-прогрессия (docs/GDD.md §8): ежедневная награда, коты, декор кофейни.
##
## Строится кодом, как scripts/ui/settings_popup.gd. Состояние читает из автолоада
## Meta (scripts/autoload/meta.gd) и таблиц scripts/data/meta.gd, а награды/покупки
## выдаёт game.gd по сигналам наружу. Размеры — под портретный viewport 720x1280.

signal daily_claim_requested
signal closed

const DATA := preload("res://scripts/data/meta.gd")
const SAFE := preload("res://scripts/ui/safe_area.gd")
## Проектная высота панели: 680x1160 (отступы по краям 56, сверху 48).
const PANEL_H := 1160.0
## Вкладки: подпись — text; спрайт берётся из TAB_ART_* (активная/неактивная).
const TABS := [
	{"id": "gift", "text": "День"},
	{"id": "cat", "text": "Коты"},
]
const TAB_ART_ACTIVE := "tab_active"
const TAB_ART_INACTIVE := "tab_inactive"

var _panel: Panel
var _list: VBoxContainer
var _scroll: ScrollContainer
var _daily_strip: ScrollContainer
var _tabs: Array[BaseButton] = []
var _tab := 0


func _ready() -> void:
	layer = 3
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = Panel.new()
	var panel := _panel
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not Icons.skin_panel(panel, "popup_panel"):
		panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	# Раскладка — абсолютная сетка внутри панели 680x1160 (отступы по краям 56,
	# сверху 48): арт имеет свои пропорции (заголовок, вкладки 170x84,
	# карточки), и подгонять контейнеры под них проще координатами, чем якорями.
	_title(panel, "Кофейня", Vector2(56, 48))
	_build_tabs(panel)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(_scroll, Vector2(56, 224), Vector2(568, 770))
	panel.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)

	var close_button := _button(panel, "Закрыть", Vector2(215, 1016))
	close_button.pressed.connect(close)

	_apply_panel_size()
	get_viewport().size_changed.connect(_apply_panel_size)


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
		if _daily_strip != null and _daily_strip.visible \
				and _daily_strip.get_global_rect().has_point(drag.position):
			_daily_strip.scroll_horizontal -= int(drag.relative.x)
			get_viewport().set_input_as_handled()
		elif _scroll.get_global_rect().has_point(drag.position):
			_scroll.scroll_vertical -= int(drag.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var dragging := (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if _daily_strip != null and _daily_strip.visible and dragging \
				and _daily_strip.get_global_rect().has_point(motion.position):
			_daily_strip.scroll_horizontal -= int(motion.relative.x)
			get_viewport().set_input_as_handled()
			return
		var on_scroll := _scroll.get_global_rect().has_point(motion.position)
		if dragging and on_scroll:
			_scroll.scroll_vertical -= int(motion.relative.y)
			get_viewport().set_input_as_handled()


## Панель по высоте ограничена экраном: на низких экранах она не должна залезать
## под чёлку и home-индикатор (вставки safe area).
func _apply_panel_size() -> void:
	if _panel == null:
		return
	var ins := SAFE.insets()
	var avail := get_viewport().get_visible_rect().size.y - ins.y - ins.w - 32.0
	var h := minf(PANEL_H, maxf(420.0, avail))
	_panel.offset_top = -h * 0.5
	_panel.offset_bottom = h * 0.5


# --- Вкладки -----------------------------------------------------------------

func _build_tabs(parent: Node) -> void:
	var row := HBoxContainer.new()
	_place(row, Vector2(56, 128), Vector2(568, 76))
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	for index in TABS.size():
		var tab_data: Dictionary = TABS[index]
		var is_active := index == _tab
		# Вкладка — чистый спрайт (tab_active.png / tab_inactive.png) и подпись
		# поверх: никаких StyleBox и 9-slice.
		var tab := Icons.plain_button(TAB_ART_ACTIVE if is_active else TAB_ART_INACTIVE,
				Vector2(170, 84))
		Icons.button_text(tab, String(tab_data.get("text", "")), 20)
		tab.toggle_mode = true
		tab.button_pressed = is_active
		tab.toggled.connect(func(on: bool) -> void:
			tab.texture_normal = Icons.art(TAB_ART_ACTIVE if on else TAB_ART_INACTIVE,
					Vector2(170, 84))
			tab.texture_disabled = tab.texture_normal
		)
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
		_:
			_build_daily()


# --- Ежедневная награда (GDD §8.3) -------------------------------------------

func _build_daily() -> void:
	var streak := Meta.daily_streak
	var day := Meta.next_day()
	_line(_list, "Стрик: %d / %d" % [streak, DATA.DAILY_DAYS], 26)

	var strip := ScrollContainer.new()
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Скроллбар не показываем: горизонтальный свайп висит на _input().
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip.custom_minimum_size = Vector2(0, 164)
	_list.add_child(strip)
	_daily_strip = strip

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	strip.add_child(row)
	for index in DATA.DAILY_REWARDS.size():
		var reward: Dictionary = DATA.DAILY_REWARDS[index]
		var number := index + 1
		var tile := _card(row, false, Vector2(170, 144))
		_line(tile, "Д%d" % number, 16, Color("8A7566") if number != day else Color("C05621"))
		_reward_line(tile, reward, Color("4A3A2E") if number != day else Color("C05621"))

	var claim := Icons.plain_button("popup_primary_button", Vector2(0, 84))
	Icons.button_text(claim, "Забрать" if Meta.can_claim() else "Уже получено", 26)
	claim.disabled = not Meta.can_claim()
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


# --- Декор кофейни: покупка живёт в изо-кофейне (GDD §8.1), в попапе не дублируем ---

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
	var tex := Icons.texture(icon_id, 22.0)
	if tex == null:
		parent.add_child(Icons.icon_label(icon_id, value, 18.0, color, 16))
		return
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(22, 22)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = color
	row.add_child(rect)
	var label := _plain_label(value, 16, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	parent.add_child(row)


## Абсолютная сетка: все дети панели ставятся в её координатах (0..680 × 0..1080).
func _place(control: Control, pos: Vector2, size_px: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = pos
	control.size = size_px
	control.custom_minimum_size = size_px


func _title(parent: Node, text: String, pos: Vector2) -> void:
	var label := _plain_label(text, 34, Color("4A3A2E"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(label, pos, Vector2(568, 64))
	parent.add_child(label)


## Кнопка на чистом спрайте: TextureButton + подпись поверх (без StyleBox).
func _button(parent: Node, text: String, pos: Vector2,
		size_px := Vector2(250, 84), base := "popup_secondary_button",
		font_size := 26) -> TextureButton:
	var button := Icons.plain_button(base, size_px)
	Icons.button_text(button, text, font_size)
	_place(button, pos, size_px)
	parent.add_child(button)
	return button


## Запасная панель, если арта нет: тёплый прямоугольник со скруглением.
func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("F6E7D8")
	box.set_corner_radius_all(28)
	box.set_content_margin_all(16.0)
	return box


## Карточка: белая панель со скруглением, внутрь кладём текст/кнопки.
## `expand` — растягивать карточку по ширине родителя (для плиток в ряду:
## флаг ставится на сам PanelContainer, а не на внутренний VBox).
## Карточка: PanelContainer (высота растёт за контентом) + MarginContainer
## с отступами 28 по бокам и 14 сверху/снизу — у арта карточки углы 30.
## `expand` — растягивать по ширине родителя; `min_size` — минимальный размер.
func _card(parent: Node, expand := false, min_size := Vector2(0, 96)) -> VBoxContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = min_size
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not Icons.skin_panel(box, "popup_list_card"):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("FFFFFF")
		flat.set_corner_radius_all(16)
		box.add_theme_stylebox_override("panel", flat)
	else:
		# Отступы задаёт MarginContainer, поэтому у 9-slice стиля их обнуляем.
		var style := box.get_theme_stylebox("panel")
		if style != null:
			style.set_content_margin_all(0.0)
	parent.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	box.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
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

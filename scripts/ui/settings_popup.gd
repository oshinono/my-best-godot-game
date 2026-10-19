extends CanvasLayer

## Настройки прототипа (docs/GDD.md §20, §21): «продать всё поле» для тестов
## тупиков, «сбросить прогресс» (чистый save для плейтеста) и бустеры
## (docs/GDD.md §18) — они переехали сюда из нижней полосы HUD.
##
## Строится кодом. Логику делают обработчики в game.gd.
##
## Раскладка — PanelContainer + VBoxContainer + ScrollContainer, а не сетка
## абсолютных координат: панель тянется по экрану (с учётом safe area), высота
## контента считается сама, а длинный список прокручивается. Отступы от рамки
## 9-slice даёт `Icons.skin_panel` (content_margin = кромка popup_panel + 8).
## Кнопки — чистые PNG-спрайты (`Icons.plain_button`) без StyleBox и 9-slice,
## подпись кладётся оверлеем `Icons.button_text` (у TextureButton нет text).
##
## Эмодзи в текстах нет: стандартный шрифт Godot рисует их квадратами.
##
## Размеры рассчитаны на портретный viewport 720x1280.

signal sell_all_requested
signal reset_requested
## Бустер: "hammer" | "shuffle" | "magnet".
signal booster_requested(kind: String)
## Техспайк фазы 0 (docs/technspike.md): проверка рекламы, консента и покупок
## на живом устройстве. action: "rewarded" | "interstitial" | "consent" |
## "purchase" | "restore".
signal technospike_action(action: String)
signal closed

const SAFE := preload("res://scripts/ui/safe_area.gd")
## Воздух от края экрана и от вставок чёлки/home-индикатора.
const SCREEN_MARGIN := 16.0
## Минимальная высота кнопок: 84 при арте 250x84 (кромка 26) не сплющивает 9-slice.
const BUTTON_H := 84.0

var _hint: Label
var _panel: PanelContainer
## kind → Button, состояние обновляет game.gd через refresh_boosters().
var _booster_buttons: Dictionary = {}


func _ready() -> void:
	layer = 3
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not Icons.skin_panel(_panel, "popup_panel"):
		_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	box.add_child(_title("Настройки"))
	box.add_child(_caption("Техспайк: реклама и покупки"))

	# Тело в скролле: на маленьких экранах список целиком не влезает.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# --- Техспайк: две колонки, кнопки тянутся по ширине колонки ---
	var tech := [
		["Реклама: rewarded", "rewarded"],
		["Реклама: interstitial", "interstitial"],
		["Консент (UMP/ATT)", "consent"],
		["Тестовый SKU", "purchase"],
		["Восстановить покупки", "restore"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for entry in tech:
		var button := _button(String(entry[0]), "popup_secondary_button", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, BUTTON_H)
		var action := String(entry[1])
		button.pressed.connect(func() -> void: technospike_action.emit(action))
		grid.add_child(button)

	# --- Бустеры (GDD §18): три карточки 185x80 в один ряд ---
	body.add_child(_caption("Бустеры"))
	var boosters := HBoxContainer.new()
	boosters.add_theme_constant_override("separation", 12)
	boosters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(boosters)
	for kind in ["hammer", "shuffle", "magnet"]:
		var booster := _button("", "popup_booster_card", 20)
		booster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		booster.custom_minimum_size = Vector2(0, 80)
		booster.pressed.connect(func() -> void: booster_requested.emit(kind))
		_booster_buttons[kind] = booster
		boosters.add_child(booster)

	# --- Вибрация (GDD §15, docs/haptics.md) ---
	# Звука в прототипе нет: вся обратная связь — тактильная (iOS-плагин
	# HapticsIOS, на Android — Input.vibrate_handheld).
	var toggle := _button("", "popup_list_card", 24)
	toggle.custom_minimum_size = Vector2(0, BUTTON_H)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Icons.button_text(toggle, _toggle_text("Вибрация", Haptics.enabled), 24)
	toggle.toggle_mode = true
	toggle.button_pressed = Haptics.enabled
	toggle.toggled.connect(func(pressed: bool) -> void:
		Haptics.set_enabled(pressed)
		_set_button_text(toggle, _toggle_text("Вибрация", pressed), 24)
	)
	body.add_child(toggle)

	# --- Игровые тесты ---
	var danger := HBoxContainer.new()
	danger.add_theme_constant_override("separation", 12)
	danger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(danger)
	var sell := _button("Продать всё", "popup_danger_button", 26)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.custom_minimum_size = Vector2(0, BUTTON_H)
	sell.pressed.connect(func() -> void: sell_all_requested.emit())
	danger.add_child(sell)
	var reset := _button("Сброс", "popup_danger_button", 26)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.custom_minimum_size = Vector2(0, BUTTON_H)
	reset.pressed.connect(func() -> void: reset_requested.emit())
	danger.add_child(reset)

	_hint = Label.new()
	_hint.text = "Техспайк: rewarded/interstitial дадут статус, консент — UMP, покупки — тестовый SKU из Config. Сброс удаляет save."
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color("8A7566"))
	body.add_child(_hint)

	# Кнопка закрытия — вне скролла, всегда под рукой.
	var close_button := _button("Закрыть", "popup_primary_button", 26)
	close_button.custom_minimum_size = Vector2(250, BUTTON_H)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)

	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


## Состояние бустеров задаёт game.gd: цена, лимит сессии, хватает ли гемов.
## info: kind → {text: String, enabled: bool}
func refresh_boosters(info: Dictionary) -> void:
	for kind in _booster_buttons.keys():
		var button := _booster_buttons[kind] as BaseButton
		if button == null:
			continue
		var data: Dictionary = info.get(kind, {})
		_set_button_text(button, String(data.get("text", kind)))
		button.disabled = not bool(data.get("enabled", true))


## Панель занимает экран минус вставки (чёлка/home-индикатор) и воздух по краю —
## тогда она никогда не уезжает под системные элементы.
func _apply_safe_area() -> void:
	if _panel == null:
		return
	var ins := SAFE.insets()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = SCREEN_MARGIN + ins.x
	_panel.offset_top = SCREEN_MARGIN + ins.y
	_panel.offset_right = -(SCREEN_MARGIN + ins.z)
	_panel.offset_bottom = -(SCREEN_MARGIN + ins.w)


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("4A3A2E"))
	return label


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("8A7566"))
	return label


## Кнопка на чистом спрайте popup_*.png; подпись — оверлей с именем `__label`.
func _button(text: String, base: String, font_size: int) -> TextureButton:
	var button := Icons.plain_button(base, Vector2(250, 84))
	if text != "":
		Icons.button_text(button, text, font_size)
	return button


## Переписать подпись спрайт-кнопки (у TextureButton нет свойства text).
func _set_button_text(button: Control, text: String, font_size := 20) -> void:
	var label := button.get_node_or_null("__label") as Label
	if label == null:
		Icons.button_text(button, text, font_size)
		return
	label.text = text


func _toggle_text(label_text: String, value: bool) -> String:
	return "%s: %s" % [label_text, "Вкл" if value else "Выкл"]


## Запасная панель, если арта нет: тёплый прямоугольник со скруглением.
func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("F6E7D8")
	box.set_corner_radius_all(28)
	box.set_content_margin_all(56.0)
	return box

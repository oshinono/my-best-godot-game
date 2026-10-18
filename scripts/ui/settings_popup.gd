extends CanvasLayer

## Настройки прототипа (docs/GDD.md §20, §21): «продать всё поле» для тестов
## тупиков, «сбросить прогресс» (чистый save для плейтеста) и бустеры
## (docs/GDD.md §18) — они переехали сюда из нижней полосы HUD.
##
## Строится кодом. Логику делают обработчики в game.gd.
## Размеры рассчитаны на портретный viewport 720x1280.

signal sell_all_requested
signal reset_requested
## Бустер: "hammer" | "shuffle" | "magnet".
signal booster_requested(kind: String)
## Техспайк фазы 0 (docs/technspike.md): проверка рекламы, консента и покупок
## на живом устройстве. action: "rewarded" | "interstitial" | "consent" |
## "purchase" | "restore".
signal technospike_action(action: String)
## Кнопка «🎛 Тест вибрации»: открывает попап проверки всех видов отклика
## (scripts/ui/haptics_test_popup.gd, docs/haptics.md).
signal haptics_test_requested
signal closed

var _hint: Label
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

	var panel := ColorRect.new()
	panel.color = Color("F6E7D8")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -580.0
	panel.offset_bottom = 700.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	_title(panel, "⚙ Настройки прототипа", -540)

	# --- Техспайк фазы 0: реклама, консент, покупки (docs/technspike.md) ---
	_tech_button(panel, "🔎 Реклама: rewarded", "rewarded", -448)
	_tech_button(panel, "🎬 Реклама: interstitial", "interstitial", -344)
	_tech_button(panel, "🔒 Консент (UMP/ATT)", "consent", -240)
	_tech_button(panel, "🛒 Купить тестовый SKU", "purchase", -136)
	_tech_button(panel, "♻ Восстановить покупки", "restore", -32)

	# --- Бустеры (GDD §18): раньше жили в нижней полосе HUD ---
	_caption(panel, "Бустеры", 28)
	# Три бустера в один ряд: левая, центральная и правая ячейки панели.
	var rects := {
		"hammer": Vector4(-290.0, -105.0, 68.0, 148.0),
		"shuffle": Vector4(-92.0, 92.0, 68.0, 148.0),
		"magnet": Vector4(105.0, 290.0, 68.0, 148.0),
	}
	for kind in ["hammer", "shuffle", "magnet"]:
		var rect: Vector4 = rects[kind]
		var booster := _row_button(panel, "", rect.x, rect.y, rect.z, rect.w)
		Icons.decorate(booster, _booster_icon(kind), 26.0)
		Icons.flat(booster)
		booster.pressed.connect(func() -> void: booster_requested.emit(kind))
		_booster_buttons[kind] = booster

	# --- Игровые тесты ---
	var sell := _button(panel, "🪙 Продать всё поле", 162)
	sell.pressed.connect(func() -> void: sell_all_requested.emit())

	var reset := _button(panel, "♻ Сбросить прогресс", 258)
	reset.pressed.connect(func() -> void: reset_requested.emit())

	var close_button := _button(panel, "Закрыть", 350)
	close_button.pressed.connect(close)

	# --- Вибрация (GDD §15, docs/haptics.md) ---
	# Звука в прототипе нет: вся обратная связь — тактильная (iOS-плагин
	# HapticsIOS, на Android — Input.vibrate_handheld).
	_toggle(panel, "📳 Вибрация", Haptics.enabled, func(value: bool) -> void: Haptics.set_enabled(value))

	# --- Тест вибрации (docs/haptics.md): все виды отклика на одном стенде ---
	var haptics_test := _button(panel, "🎛 Тест вибрации", 524)
	haptics_test.pressed.connect(func() -> void: haptics_test_requested.emit())

	_hint = Label.new()
	_hint.text = "Техспайк: rewarded/interstitial дадут статус, консент — UMP, покупки — тестовый SKU из Config. Сброс удаляет save (поле, монеты, гемы, XP, котов)."
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = 24.0
	_hint.offset_right = -24.0
	_hint.offset_top = 616.0
	_hint.offset_bottom = 660.0
	_hint.add_theme_font_size_override("font_size", 18)
	panel.add_child(_hint)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


## Состояние бустеров задаёт game.gd: цена, лимит сессии, хватает ли гемов.
## info: kind → {text: String, enabled: bool}
func refresh_boosters(info: Dictionary) -> void:
	for kind in _booster_buttons.keys():
		var button: Button = _booster_buttons[kind]
		var data: Dictionary = info.get(kind, {})
		button.text = String(data.get("text", kind))
		button.disabled = not bool(data.get("enabled", true))


func _booster_icon(kind: String) -> String:
	match kind:
		"hammer":
			return "hammer"
		"shuffle":
			return "shuffle"
		"magnet":
			return "magnet"
	return "star"


func _caption(parent: Node, text: String, top: float) -> void:
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
	label.offset_bottom = top + 32.0
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)


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
	return _row_button(parent, text, -290.0, 290.0, top, top + 84.0)


## Кнопка с явным прямоугольником: нужна и на всю ширину, и в ряд по три.
func _row_button(parent: Node, text: String, left: float, right: float,
		top: float, bottom: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = left
	button.offset_right = right
	button.offset_top = top
	button.offset_bottom = bottom
	button.add_theme_font_size_override("font_size", 28)
	parent.add_child(button)
	return button


## Тумблер «вкл/выкл» на всю ширину панели: состояние применяет переданный Callable.
## Флаг вибрации живёт в сохранении (см. scripts/autoload/haptics.gd), так что
## переключатель просто читает текущее состояние автолоада Haptics.
func _toggle(parent: Node, label_text: String, value: bool, apply: Callable) -> void:
	var button := Button.new()
	button.text = _toggle_text(label_text, value)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = -290.0
	button.offset_right = 290.0
	button.offset_top = 444.0
	button.offset_bottom = 512.0
	button.toggle_mode = true
	button.button_pressed = value
	button.add_theme_font_size_override("font_size", 24)
	button.toggled.connect(func(pressed: bool) -> void:
		apply.call(pressed)
		button.text = _toggle_text(label_text, pressed)
	)
	parent.add_child(button)


func _toggle_text(label_text: String, value: bool) -> String:
	return "%s: %s" % [label_text, "Вкл" if value else "Выкл"]


## Кнопка техспайка: наружу уходит только имя действия.
func _tech_button(parent: Node, text: String, action: String, top: float) -> Button:
	var button := _button(parent, text, top)
	button.pressed.connect(func() -> void: technospike_action.emit(action))
	return button

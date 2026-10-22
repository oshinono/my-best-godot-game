extends SceneTree

## Сборка единой темы интерфейса: res://resources/ui_theme.tres.
##
## Арт в assets/ui/** — экспорт листа спрайтов в 4x с прозрачными полями
## (у popup_panel ~12% сверху и снизу, у popup_list_card — половина ширины).
## С полями 9-slice режет пустоту, поэтому генератор:
##   1) срезает поля и ужимает арт до проектного размера (база 720x1280),
##      кладёт PNG в assets/ui/theme/ (1x — для StyleBoxTexture, 2x — картинки);
##   2) собирает Theme с Type Variations (PrimaryButton, PopupFrame, ...).
## Тема подключена в Project Settings → GUI → Theme → Custom и задаёт ТОЛЬКО
## вариации: стандартные Button/Label/Panel не трогает.
##
## Запуск (два шага: между ними Godot импортирует новые PNG):
##   godot --headless --path . -s res://tools/build_ui_theme.gd -- art
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/build_ui_theme.gd -- theme

const SRC_DIRS := [
	"res://assets/ui/hud/",
	"res://assets/ui/buttons/",
	"res://assets/ui/panels/",
	"res://assets/ui/cafe/",
]
const OUT_DIR := "res://assets/ui/theme/"
const THEME_PATH := "res://resources/ui_theme.tres"

## Арт для StyleBoxTexture: рисуется 1:1 (кромки 9-slice в пикселях текстуры),
## поэтому ужимаем ровно до проектной высоты.
const BOX_ART := {
	"popup_panel": 550,
	"popup_primary_button": 76,
	"popup_secondary_button": 76,
	"popup_danger_button": 76,
	"tab_active": 80,
	"tab_inactive": 80,
	"popup_booster_card": 52,
	"popup_list_card": 80,
	"cafe_top_bar": 80,
	"btn_blue": 88,
}
## Тот же арт в другой высоте (вариации поменьше): имя файла → [арт, высота].
const BOX_ALIASES := {
	"button_small": ["popup_secondary_button", 64],
}
## Картинки (TextureRect / иконки кнопок): масштабируются при отрисовке,
## поэтому храним в 2x от проектной высоты — на ретине не мылятся.
## Кнопочный арт с толстой тёмно-коричневой обводкой (нарисована в PNG, снизу
## толще — «тень»). Её срезаем при экспорте (см. _strip_outline); у иллюстраций
## (магазин, значок уровня, предметы) обводка — стиль, их не трогаем.
const STRIP_OUTLINE := [
	"popup_primary_button", "popup_secondary_button", "popup_danger_button",
	"tab_active", "tab_inactive", "btn_blue", "btn_play",
	"popup_booster_card", "order_card", "bar_bg",
	# Карточки, на которые тоже тапают: плитки дней, карточки котов/заданий.
	"cafe_product_card", "popup_list_card",
]
## Порог «тёмного» пикселя обводки (яркость HSV) и второй, мягче, — для
## полупрозрачной каймы на стыке обводки и цвета кнопки.
const OUTLINE_DARK := 0.45
const OUTLINE_EDGE := 0.62

const IMAGE_ART := {
	"cafe_product_card": 191,
	"cafe_coin_counter": 60,
	"level_badge_main": 64,
	"bar_bg": 35,
	"icon_energy_main": 46,
	"icon_coin_main": 46,
	"icon_gem_main": 46,
	"icon_coin": 36,
	"icon_gem": 36,
	"icon_energy": 36,
	"plus_badge": 24,
	"icon_settings": 52,
	"icon_menu": 52,
	"btn_play": 70,
	"notif_dot": 22,
	"shop": 96,
	"order_card": 64,
	"icon_inventory": 52,
}

const TEXT := Color("4A3A2E")
const MUTED := Color("8A7566")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("art"):
		_build_art()
	elif args.has("theme"):
		_build_theme()
	else:
		push_error("build_ui_theme: укажите шаг: -- art | -- theme")
	quit()


# --- Шаг 1: арт ---------------------------------------------------------------

func _build_art() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for base in BOX_ART:
		_export(base, int(BOX_ART[base]), base)
	for out_name in BOX_ALIASES:
		var alias: Array = BOX_ALIASES[out_name]
		_export(String(alias[0]), int(alias[1]), out_name)
	_export_board_frame()
	for base in IMAGE_ART:
		_export(base, int(IMAGE_ART[base]) * 2, base)
	print("[ui_theme] арт готов: ", OUT_DIR)


func _export(base: String, height: int, out_name: String) -> void:
	var src := _find(base)
	if src == "":
		push_error("[ui_theme] нет арта " + base)
		return
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(src)) != OK:
		push_error("[ui_theme] не читается " + src)
		return
	img.convert(Image.FORMAT_RGBA8)
	if STRIP_OUTLINE.has(base):
		_strip_outline(img)
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	var k := float(height) / float(img.get_height())
	img.resize(maxi(1, roundi(img.get_width() * k)), height, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + out_name + ".png"))


## Срезать тёмную обводку кнопки: заливка от прозрачного края внутрь по
## тёмным пикселям (они становятся прозрачными) до цветного тела кнопки.
## Тёмные детали внутри (рисунок чашки на btn_play) снаружи недостижимы
## и остаются. Вторым проходом убираем тёмную кайму на стыке.
static func _strip_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var state := PackedByteArray()  # 0 — не тронут, 1 — снаружи/срезан
	state.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if state[i] == 1:
			continue
		var c := img.get_pixelv(p)
		if c.a > 0.05 and c.v >= OUTLINE_DARK:
			continue
		state[i] = 1
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	# Кайма: соседи срезанной области, всё ещё заметно тёмные.
	var edge: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if state[y * w + x] == 1:
				continue
			if state[y * w + x - 1] == 1 or state[y * w + x + 1] == 1 \
					or state[(y - 1) * w + x] == 1 or state[(y + 1) * w + x] == 1:
				if img.get_pixel(x, y).v < OUTLINE_EDGE:
					edge.append(Vector2i(x, y))
	for p in edge:
		img.set_pixelv(p, Color(0, 0, 0, 0))


## Рамка поля: в экспорте листа «прозрачный» центр — нарисованная шахматка
## (непрозрачные белые и серые клетки). Заливкой от центра делаем её
## по-настоящему прозрачной: заливка идёт по светлым ненасыщенным пикселям и
## останавливается на тёмной обводке рамки.
func _export_board_frame() -> void:
	var src := "res://assets/ui/board/field_frame_512.png"
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(src)) != OK:
		push_error("[ui_theme] нет арта " + src)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = [Vector2i(w / 2, h / 2)]
	var cleared := 0
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if seen[i] == 1:
			continue
		seen[i] = 1
		var c := img.get_pixelv(p)
		if c.s > 0.18 or c.v < 0.62:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		cleared += 1
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "field_frame.png"))
	print("[ui_theme] рамка поля: прозрачных пикселей ", cleared, " из ", w * h)


func _find(base: String) -> String:
	for dir in SRC_DIRS:
		var path: String = dir + base + ".png"
		if FileAccess.file_exists(path):
			return path
	return ""


# --- Шаг 2: тема --------------------------------------------------------------

func _build_theme() -> void:
	var theme := Theme.new()

	# Кнопки-пилюли: торцы (полвысоты) не тянутся, тянется прямая середина.
	_pill_button(theme, "PrimaryButton", "popup_primary_button")
	_pill_button(theme, "SecondaryButton", "popup_secondary_button")
	_pill_button(theme, "DangerButton", "popup_danger_button")

	# Вкладка: неактивная — tab_inactive, нажатая (toggle) — tab_active.
	theme.set_type_variation("TabButton", "Button")
	var inactive := _box("tab_inactive", Vector4(26, 26, 26, 26), Vector4(16, 8, 16, 8))
	var active := _box("tab_active", Vector4(26, 26, 26, 26), Vector4(16, 8, 16, 8))
	for state in ["normal", "hover", "disabled"]:
		theme.set_stylebox(state, "TabButton", inactive)
	for state in ["pressed", "hover_pressed"]:
		theme.set_stylebox(state, "TabButton", active)
	theme.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	_button_text(theme, "TabButton", 24)

	# Карточка бустера: слева в арте жёлтый слот под иконку — его закрывает
	# левая кромка 9-slice, иконка кнопки встаёт ровно в слот.
	theme.set_type_variation("BoosterButton", "Button")
	_states(theme, "BoosterButton",
		_box("popup_booster_card", Vector4(48, 14, 14, 14), Vector4(12, 6, 10, 6)))
	_button_text(theme, "BoosterButton", 18)
	theme.set_constant("h_separation", "BoosterButton", 16)
	theme.set_constant("icon_max_width", "BoosterButton", 26)

	# Квадратная синяя кнопка с иконкой (настройки, меню, «назад»).
	theme.set_type_variation("SquareButton", "Button")
	_states(theme, "SquareButton", _box("btn_blue", Vector4(26, 26, 26, 26), Vector4(14, 14, 14, 14)))
	_button_text(theme, "SquareButton", 32, Color.WHITE)
	theme.set_constant("icon_max_width", "SquareButton", 52)

	# Маленькая кнопка (реролл заказа): тот же арт, но высотой 64.
	theme.set_type_variation("SmallButton", "Button")
	_states(theme, "SmallButton", _box("button_small", Vector4(30, 26, 30, 26), Vector4(16, 6, 16, 8)))
	_button_text(theme, "SmallButton", 22)
	theme.set_constant("h_separation", "SmallButton", 4)
	theme.set_constant("icon_max_width", "SmallButton", 28)

	# Кнопка генератора на поле: зелёная пилюля, у закрытого — приглушённая.
	theme.set_type_variation("GeneratorButton", "Button")
	_states(theme, "GeneratorButton",
		_box("popup_secondary_button", Vector4(36, 30, 36, 30), Vector4(20, 6, 20, 8)))
	_button_text(theme, "GeneratorButton", 22)
	theme.set_constant("h_separation", "GeneratorButton", 6)
	theme.set_constant("icon_max_width", "GeneratorButton", 28)

	# Панели.
	# Меню действий с предметом: та же рамка, что у попапов, но поля меньше
	# (у арта item_action_panel справа лента — она налезала на кнопки).
	theme.set_type_variation("ActionFrame", "PanelContainer")
	theme.set_stylebox("panel", "ActionFrame",
		_box("popup_panel", Vector4(48, 48, 48, 48), Vector4(48, 40, 48, 40)))

	theme.set_type_variation("PopupFrame", "PanelContainer")
	theme.set_stylebox("panel", "PopupFrame",
		_box("popup_panel", Vector4(48, 48, 48, 48), Vector4(56, 52, 56, 52)))

	# Карточка списка: широкая левая кромка — слот под портрет не тянется по X.
	theme.set_type_variation("ListCard", "PanelContainer")
	theme.set_stylebox("panel", "ListCard",
		_box("popup_list_card", Vector4(80, 30, 30, 30), Vector4(92, 16, 26, 16)))

	theme.set_type_variation("BottomBar", "PanelContainer")
	theme.set_stylebox("panel", "BottomBar",
		_box("cafe_top_bar", Vector4(28, 28, 28, 28), Vector4(28, 22, 28, 22)))

	# Тост (заказ выполнен, продажа…): тёмная плашка, светлый текст.
	theme.set_type_variation("Toast", "PanelContainer")
	var toast := _flat(Color(0.29, 0.227, 0.18, 0.94), Color("C98A5E"), 2)
	toast.set_corner_radius_all(26)
	toast.content_margin_left = 22.0
	toast.content_margin_right = 26.0
	toast.content_margin_top = 10.0
	toast.content_margin_bottom = 12.0
	toast.shadow_color = Color(0, 0, 0, 0.25)
	toast.shadow_size = 8
	toast.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "Toast", toast)
	_label(theme, "ToastLabel", 24, Color("FFF4E6"))

	# Тосты по смыслу: ошибка (красная кромка) и успех (зелёная кромка).
	for kind in [["ToastError", Color("E0604A")], ["ToastSuccess", Color("7CC35A")]]:
		theme.set_type_variation(kind[0], "PanelContainer")
		var box := toast.duplicate() as StyleBoxFlat
		box.border_color = kind[1]
		box.set_border_width_all(3)
		theme.set_stylebox("panel", kind[0], box)

	# Значок смены заказа на углу карточки: зелёная пилюля, гем + цена.
	theme.set_type_variation("RerollBadge", "Button")
	var badge := _flat(Color("7CC35A"), Color("5E9E42"), 2)
	badge.set_corner_radius_all(22)
	badge.content_margin_left = 10.0
	badge.content_margin_right = 12.0
	badge.content_margin_top = 2.0
	badge.content_margin_bottom = 4.0
	theme.set_stylebox("normal", "RerollBadge", badge)
	var badge_hover := badge.duplicate() as StyleBoxFlat
	badge_hover.bg_color = Color("8BD067")
	theme.set_stylebox("hover", "RerollBadge", badge_hover)
	var badge_pressed := badge.duplicate() as StyleBoxFlat
	badge_pressed.bg_color = Color("5E9E42")
	theme.set_stylebox("pressed", "RerollBadge", badge_pressed)
	theme.set_stylebox("hover_pressed", "RerollBadge", badge_pressed)
	var badge_off := badge.duplicate() as StyleBoxFlat
	badge_off.bg_color = Color("B9B2A6")
	badge_off.border_color = Color("8A8276")
	theme.set_stylebox("disabled", "RerollBadge", badge_off)
	theme.set_stylebox("focus", "RerollBadge", StyleBoxEmpty.new())
	_button_text(theme, "RerollBadge", 20, Color.WHITE)
	theme.set_color("font_outline_color", "RerollBadge", Color("3F6B2A"))
	theme.set_constant("outline_size", "RerollBadge", 4)
	theme.set_constant("h_separation", "RerollBadge", 2)
	theme.set_constant("icon_max_width", "RerollBadge", 22)

	# Полоса прогресса ивента: кремовый жёлоб, тёплая заливка.
	theme.set_type_variation("EventBar", "ProgressBar")
	var trough := _flat(Color("E8D5BE"), Color("C9A27E"), 2)
	trough.set_corner_radius_all(14)
	theme.set_stylebox("background", "EventBar", trough)
	var fill := _flat(Color("F2A93B"), Color("C47A1E"), 2)
	fill.set_corner_radius_all(14)
	theme.set_stylebox("fill", "EventBar", fill)
	theme.set_font_size("font_size", "EventBar", 20)
	theme.set_color("font_color", "EventBar", TEXT)
	theme.set_color("font_outline_color", "EventBar", Color("FFF4E6"))
	theme.set_constant("outline_size", "EventBar", 4)

	# Ячейка склада: светлая карточка-кнопка (иконка сверху, подпись снизу).
	theme.set_type_variation("SlotButton", "Button")
	var slot := _flat(Color("FFFBF5"), Color("D8C4AE"), 2)
	slot.set_corner_radius_all(18)
	slot.set_content_margin_all(10.0)
	theme.set_stylebox("normal", "SlotButton", slot)
	var slot_hover := slot.duplicate() as StyleBoxFlat
	slot_hover.border_color = Color("E0A63C")
	theme.set_stylebox("hover", "SlotButton", slot_hover)
	var slot_pressed := slot.duplicate() as StyleBoxFlat
	slot_pressed.bg_color = Color("FFF3D6")
	slot_pressed.border_color = Color("E0A63C")
	theme.set_stylebox("pressed", "SlotButton", slot_pressed)
	theme.set_stylebox("hover_pressed", "SlotButton", slot_pressed)
	var slot_off := slot.duplicate() as StyleBoxFlat
	slot_off.bg_color = Color("EFE6DA")
	theme.set_stylebox("disabled", "SlotButton", slot_off)
	theme.set_stylebox("focus", "SlotButton", StyleBoxEmpty.new())
	_button_text(theme, "SlotButton", 18)
	theme.set_constant("icon_max_width", "SlotButton", 72)

	# Чип инвентаря кофейни: обычный и выбранный.
	theme.set_type_variation("Chip", "PanelContainer")
	theme.set_stylebox("panel", "Chip", _flat(Color("FFFFFF"), Color("D8C4AE"), 1))
	theme.set_type_variation("ChipSelected", "PanelContainer")
	theme.set_stylebox("panel", "ChipSelected", _flat(Color("FFF3D6"), Color("E0A63C"), 3))

	# Текст.
	_label(theme, "TitleLabel", 34, TEXT)
	_label(theme, "HeaderLabel", 26, TEXT)
	_label(theme, "BodyLabel", 22, TEXT)
	_label(theme, "CaptionLabel", 20, MUTED)
	_label(theme, "HintLabel", 18, MUTED)

	var err := ResourceSaver.save(theme, THEME_PATH)
	print("[ui_theme] тема: ", THEME_PATH, " err=", err)


func _pill_button(theme: Theme, variation: String, base: String) -> void:
	theme.set_type_variation(variation, "Button")
	# Высота арта 76: торцы-полукруги 38, по вертикали оставляем полосу в середине.
	_states(theme, variation, _box(base, Vector4(36, 30, 36, 30), Vector4(28, 8, 28, 10)))
	_button_text(theme, variation, 24)
	theme.set_constant("h_separation", variation, 10)
	theme.set_constant("icon_max_width", variation, 36)


## Один StyleBoxTexture на все состояния, состояния отличаются тоном.
func _states(theme: Theme, variation: String, box: StyleBoxTexture) -> void:
	theme.set_stylebox("normal", variation, box)
	var hover := box.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.05, 1.05, 1.05)
	theme.set_stylebox("hover", variation, hover)
	var pressed := box.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.88, 0.88, 0.88)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("hover_pressed", variation, pressed)
	var disabled := box.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(1, 1, 1, 0.55)
	theme.set_stylebox("disabled", variation, disabled)
	theme.set_stylebox("focus", variation, StyleBoxEmpty.new())


func _button_text(theme: Theme, variation: String, size: int, color := TEXT) -> void:
	theme.set_font_size("font_size", variation, size)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, variation, color)
	theme.set_color("font_disabled_color", variation, Color(color, 0.5))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(state, variation, Color.WHITE)
	theme.set_color("icon_disabled_color", variation, Color(1, 1, 1, 0.5))


## margins / content: (left, top, right, bottom).
func _box(base: String, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(OUT_DIR + base + ".png") as Texture2D
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


func _flat(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(6.0)
	return box


func _label(theme: Theme, variation: String, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)

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
	"button_small": ["popup_secondary_button", 52],
}
## Картинки (TextureRect / иконки кнопок): масштабируются при отрисовке,
## поэтому храним в 2x от проектной высоты — на ретине не мылятся.
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
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	var k := float(height) / float(img.get_height())
	img.resize(maxi(1, roundi(img.get_width() * k)), height, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + out_name + ".png"))


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

	# Маленькая кнопка (реролл заказа): тот же арт, но высотой 52.
	theme.set_type_variation("SmallButton", "Button")
	_states(theme, "SmallButton", _box("button_small", Vector4(24, 20, 24, 20), Vector4(14, 4, 14, 6)))
	_button_text(theme, "SmallButton", 20)
	theme.set_constant("h_separation", "SmallButton", 4)
	theme.set_constant("icon_max_width", "SmallButton", 24)

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

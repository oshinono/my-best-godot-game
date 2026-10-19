class_name GameHUD
extends Control
## HUD в стиле скриншота: значок уровня, три плашки ресурсов, кнопка магазина
## сверху и ряд кнопок снизу. Всё собирается кодом, карты на фоне нет.
##
## Спрайты назначаются в Инспекторе (группы Top/Bottom: textures). Пока спрайт
## не назначен — берётся PNG-арт из assets/ui (scripts/ui/icons.gd), а если и
## его нет — цветной квадрат-заглушка, чтобы раскладку было видно сразу.
##
## Размеры заданы для базового экрана 1080x1920 и умножаются на ui_scale:
## проект рисует в 720x1280, то есть ui_scale = 720/1080 ≈ 0.6667.

signal level_pressed
signal energy_plus_pressed
signal gems_plus_pressed
signal settings_pressed
signal menu_pressed
signal play_pressed

# ---------------------------------------------------------------- СПРАЙТЫ
@export_group("Top: textures")
@export var tex_level_badge: Texture2D   ## звезда/шестерёнка с уровнем
@export var tex_bar_bg: Texture2D        ## фон плашки (9-slice, растягивается)
@export var tex_icon_energy: Texture2D   ## молния
@export var tex_icon_coin: Texture2D     ## монета
@export var tex_icon_gem: Texture2D      ## кристалл
@export var tex_plus_badge: Texture2D    ## маленький зелёный "+"
@export var tex_shop: Texture2D          ## кнопка магазина (прилавок)

@export_group("Bottom: textures")
@export var tex_btn_blue: Texture2D      ## синяя скруглённая кнопка (подложка)
@export var tex_icon_settings: Texture2D ## шестерёнка
@export var tex_icon_menu: Texture2D     ## 4 квадрата
@export var tex_btn_play: Texture2D      ## кнопка-треугольник "играть"
@export var tex_notif_dot: Texture2D     ## красная точка уведомления

## Подмены из арта: PNG — папки из `Icons.ART_DIRS`.
## Пусто/недоступно — падаем на цветную заглушку.
const SAFE := preload("res://scripts/ui/safe_area.gd")

## PNG арта (экспорт 4x от авторских размеров, см. `assets/ui/README.txt`);
## путь резолвит `Icons.art_path()`. Слоты, заполненные в Инспекторе, не перетираются.
const UI_ART := {
	"tex_level_badge": "level_badge_main.png",
	"tex_bar_bg": "bar_bg.png",
	"tex_icon_energy": "icon_energy_main.png",
	"tex_icon_coin": "icon_coin_main.png",
	"tex_icon_gem": "icon_gem_main.png",
	"tex_plus_badge": "plus_badge.png",
	"tex_shop": "shop.png",
	"tex_btn_blue": "btn_blue.png",
	"tex_icon_settings": "icon_settings.png",
	"tex_icon_menu": "icon_menu.png",
	"tex_btn_play": "btn_play.png",
	"tex_notif_dot": "notif_dot.png",
}
## Авторские размеры (база 1080x1920) — дальше умножаются на ui_scale.
## Это ИЗОБРАЖЕНИЯ (текстуры), не геометрия: числа держим рядом, а сама
## геометрия плашек/кнопок живёт в группе «Sizes» ниже.
const UI_ART_SIZES := {
	"level_badge_main.png": Vector2(96, 96),
	"bar_bg.png": Vector2(240, 52),
	"icon_energy_main.png": Vector2(69, 69),
	"icon_coin_main.png": Vector2(69, 69),
	"icon_gem_main.png": Vector2(69, 69),
	"plus_badge.png": Vector2(33, 33),
	"shop.png": Vector2(81, 81),
	"btn_blue.png": Vector2(132, 132),
	"icon_settings.png": Vector2(132, 132),
	"icon_menu.png": Vector2(132, 132),
	"btn_play.png": Vector2(210, 183),
	"notif_dot.png": Vector2(33, 33),
}

# ---------------------------------------------------------------- СТИЛЬ
@export_group("Style")
@export var font: Font
@export var font_size_value: int = 38
@export var font_size_level: int = 48
@export var value_color: Color = Color("7a4a1e")
@export var value_outline_color: Color = Color(1, 1, 1, 0)
@export var value_outline_size: int = 0
@export var level_color: Color = Color.WHITE
@export var level_outline_color: Color = Color("1b3f7a")
@export var level_outline_size: int = 8

@export_group("Sizes (px, база 1080x1920)")
## Множитель к базе 1080x1920: проект рисует 720x1280 → 720/1080.
@export var ui_scale: float = 0.6667
@export var badge_size := Vector2(96, 96)
@export var bar_size := Vector2(240, 52)          ## сама плашка без иконки
@export var bar_icon_size := Vector2(69, 69)      ## иконка, торчит слева
@export var plus_size := Vector2(33, 33)
@export var shop_size := Vector2(81, 81)
## 132 при ui_scale 0.667 = 88 px ≈ 44 pt на iPhone — минимальный размер касания.
@export var bottom_btn_size := Vector2(132, 132)
@export var play_btn_size := Vector2(210, 183)
@export var notif_size := Vector2(33, 33)
@export var nine_patch_margin: int = 20           ## пиксели текстуры bar_bg
@export var screen_margin: int = 24
@export var top_separation: int = 15
@export var bottom_separation: int = 15
@export var bar_text_right_padding: int = 44

@export_group("Initial values")
@export var level: int = 29
@export var energy: int = 90
@export var coins: int = 545
@export var gems: int = 114
@export var menu_notification: bool = true

var _lbl_level: Label
var _lbl_energy: Label
var _lbl_coins: Label
var _lbl_gems: Label
var _notif: TextureRect
var _top_margin: MarginContainer
var _bottom_margin: MarginContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # карта под HUD остаётся кликабельной
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_ui()
	_build_top()
	_build_bottom()
	set_level(level)
	set_energy(energy)
	set_coins(coins)
	set_gems(gems)
	set_menu_notification(menu_notification)
	_apply_safe_area()
	# Вставки safe area меняются при повороте/смене окна — держим их актуальными.
	get_viewport().size_changed.connect(_apply_safe_area)


# ---------------------------------------------------------------- ПУБЛИЧНОЕ API
func set_level(v: int) -> void:
	level = v
	_lbl_level.text = str(v)


func set_energy(v: int) -> void:
	energy = v
	_lbl_energy.text = str(v)


func set_coins(v: int) -> void:
	coins = v
	_lbl_coins.text = str(v)


func set_gems(v: int) -> void:
	gems = v
	_lbl_gems.text = str(v)


func set_menu_notification(show_dot: bool) -> void:
	menu_notification = show_dot
	_notif.visible = show_dot


# ---------------------------------------------------------------- ВЕРХ
func _build_top() -> void:
	var inset := _safe_insets()
	var margin := _make_margin(inset.x, 0.0)
	_top_margin = margin
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", _i(top_separation))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(row)

	# Значок уровня: только отображение, цифра рисуется Label.
	var badge := Control.new()
	badge.custom_minimum_size = _s(badge_size)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_btn := TextureButton.new()
	badge_btn.texture_normal = _tex2(tex_level_badge, Color("3a7bd5"), _s(badge_size))
	badge_btn.ignore_texture_size = true
	badge_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	badge_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_btn.pressed.connect(func() -> void: level_pressed.emit())
	_bind_press(badge_btn)
	badge.add_child(badge_btn)
	_lbl_level = _make_label(font_size_level, level_color, level_outline_color, level_outline_size)
	_lbl_level.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_lbl_level)
	row.add_child(badge)

	# Плашки ресурсов.
	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", _i(top_separation))
	row.add_child(bars)

	var energy_bar := _make_bar(tex_icon_energy, Color("ffc933"), true)
	_lbl_energy = energy_bar.get_meta("label")
	(energy_bar.get_meta("plus") as TextureButton).pressed.connect(
		func() -> void: energy_plus_pressed.emit())
	bars.add_child(energy_bar)

	var coin_bar := _make_bar(tex_icon_coin, Color("f2b01e"), false)
	_lbl_coins = coin_bar.get_meta("label")
	bars.add_child(coin_bar)

	var gem_bar := _make_bar(tex_icon_gem, Color("e0489b"), true)
	_lbl_gems = gem_bar.get_meta("label")
	(gem_bar.get_meta("plus") as TextureButton).pressed.connect(
		func() -> void: gems_plus_pressed.emit())
	bars.add_child(gem_bar)

	# Магазин переехал в изо-кафе (кнопка с иконкой магазина вместо «Купить»).

	margin.name = "TopMargin"
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)


## Плашка: фон (9-slice) + иконка, торчащая слева + число + опциональный «+».
func _make_bar(icon_tex: Texture2D, icon_fallback: Color,
		with_plus: bool) -> Control:
	var bar := _s(bar_size)
	var icon_size := _s(bar_icon_size)
	var h: float = maxf(icon_size.y, bar.y)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(bar.x + icon_size.x * 0.5, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := NinePatchRect.new()
	bg.texture = _tex2(tex_bar_bg, Color("f3d9a8"), bar)
	var patch := _i(float(nine_patch_margin))
	bg.patch_margin_left = patch
	bg.patch_margin_right = patch
	bg.patch_margin_top = patch
	bg.patch_margin_bottom = patch
	bg.position = Vector2(icon_size.x * 0.5, (h - bar.y) * 0.5)
	bg.size = bar
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)

	var lbl := _make_label(font_size_value, value_color, value_outline_color, value_outline_size)
	lbl.position = bg.position
	lbl.size = Vector2(bar.x - _i(float(bar_text_right_padding)), bar.y)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(lbl)

	var icon := _tex_rect(_tex2(icon_tex, icon_fallback, icon_size), icon_size, icon_fallback)
	icon.position = Vector2(0.0, (h - icon_size.y) * 0.5)
	holder.add_child(icon)

	holder.set_meta("label", lbl)

	if with_plus:
		var plus_size_px := _s(plus_size)
		var plus := TextureButton.new()
		plus.texture_normal = _tex2(tex_plus_badge, Color("4cc94c"), plus_size_px)
		plus.ignore_texture_size = true
		plus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		plus.size = plus_size_px
		plus.position = icon.position + icon_size - plus_size_px * 0.8
		_bind_press(plus)
		holder.add_child(plus)
		holder.set_meta("plus", plus)

	return holder


# ---------------------------------------------------------------- НИЗ
func _build_bottom() -> void:
	var inset := _safe_insets()
	var margin := _make_margin(0.0, inset.y)
	_bottom_margin = margin
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", _i(bottom_separation))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(row)

	row.add_child(_icon_button(tex_btn_blue, tex_icon_settings, bottom_btn_size,
		Color("4aa3e8"), Color.WHITE, func() -> void: settings_pressed.emit()))

	# Меню (мета). Сюда же переехала красная точка: она висела на кнопке карточек,
	# а карточки и инвентарь убраны — слева остались только настройки и меню.
	var menu := _icon_button(tex_btn_blue, tex_icon_menu, bottom_btn_size,
		Color("4aa3e8"), Color.WHITE, func() -> void: menu_pressed.emit())
	var notif_size_px := _s(notif_size)
	_notif = _tex_rect(_tex2(tex_notif_dot, Color("e53935"), notif_size_px),
		notif_size_px, Color("e53935"))
	_notif.position = Vector2(menu.custom_minimum_size.x - notif_size_px.x * 0.7,
		-notif_size_px.y * 0.3)
	menu.add_child(_notif)
	row.add_child(menu)

	# Распорка.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Большая кнопка play (арт btn_play): ведёт в изо-кафе. Генераторы теперь
	# прямоугольниками на поле, попап «Генераторы» больше не открывается.
	# На btn_play арт уже нарисован целиком — второй глиф не накладываем.
	var play := _icon_button(tex_btn_play, null, play_btn_size,
		Color("3b9be0"), Color.WHITE, func() -> void: play_pressed.emit())
	play.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(play)

	margin.name = "BottomMargin"
	add_child(margin)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)


## Кнопка: подложка + (необязательно) иконка сверху.
func _icon_button(bg: Texture2D, icon: Texture2D, size_px: Vector2,
		bg_fallback: Color, icon_fallback: Color, on_pressed: Callable) -> TextureButton:
	var px := _s(size_px)
	var b := TextureButton.new()
	b.texture_normal = _tex2(bg, bg_fallback, px)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = px
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	# Пустой слот (icon == null) — кнопка только с подложкой:
	# так btn_play не получает вторую картинку поверх готового арта.
	if icon != null:
		var icon_size := px * 0.55
		var ir := _tex_rect(_tex2(icon, icon_fallback, icon_size), icon_size, icon_fallback)
		ir.position = (px - icon_size) * 0.5
		b.add_child(ir)
	b.pressed.connect(on_pressed)
	_bind_press(b)
	return b


# ---------------------------------------------------------------- УТИЛИТЫ
func _make_margin(top_inset: float, bottom_inset: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _i(float(screen_margin))
	m.add_theme_constant_override("margin_left", margin)
	m.add_theme_constant_override("margin_right", margin)
	m.add_theme_constant_override("margin_top", margin + maxi(0, _i(top_inset)))
	m.add_theme_constant_override("margin_bottom", margin + maxi(0, _i(bottom_inset)))
	return m


func _make_label(size_px: int, color: Color, outline: Color, outline_size: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", _i(float(size_px)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", _i(float(outline_size)))
	return l


func _tex_rect(t: Texture2D, size_px: Vector2, fallback: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t if t != null else _placeholder(fallback, size_px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = size_px
	r.size = size_px
	return r


## Подхватить PNG арта (`Icons.art`): только в пустые слоты, молча при отсутствии.
## Загрузку/масштабирование полностью держит `Icons.art` — он сохраняет пропорции
## арта, своего ресайза в HUD нет (растянуть картинку по одной оси нельзя).
func _load_ui() -> void:
	var loaded := 0
	for slot in UI_ART:
		if get(slot) != null:
			continue
		var art: String = UI_ART[slot]
		var target: Vector2 = _s(UI_ART_SIZES[art])
		var tex := Icons.art(art, target)
		if tex != null:
			set(slot, tex)
			loaded += 1
	print("[HUD] арт загружено: %d/%d" % [loaded, UI_ART.size()])


## Спрайт из Инспектора → PNG-арт по маппингу `Icons.ICON_ART` → цветная заглушка.
func _tex2(t: Texture2D, color: Color, size_px: Vector2) -> Texture2D:
	if t != null:
		return t
	return _placeholder(color, size_px)


func _placeholder(color: Color, size_px: Vector2) -> Texture2D:
	var img := Image.create(maxi(int(size_px.x), 8), maxi(int(size_px.y), 8), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _bind_press(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _scale_to(b, 0.92))
	b.button_up.connect(func() -> void: _scale_to(b, 1.0))


func _scale_to(node: Control, s: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * s, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Базовый размер 1080 → экранный (проект рисует 720).
func _i(v: float) -> int:
	return int(round(v * ui_scale))


func _s(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x * ui_scale), roundf(v.y * ui_scale))


## Отступы под чёлку / индикатор жестов (x = сверху, y = снизу), в координатах viewport.
## Только мобильные: на десктопе DisplayServer.get_display_safe_area() отдаёт зону
## всего монитора (часто выше окна игры), из-за чего низ уезжал за экран.
func _safe_insets() -> Vector2:
	var ins := SAFE.insets()
	return Vector2(ins.y, ins.w)


## Единая точка правки отступов HUD: поля по бокам учитывают вставки, чтобы
## ряд не вылезал под чёлку/скруглённые углы. Вызывается после сборки и на
## каждый `size_changed` вьюпорта.
func _apply_safe_area() -> void:
	var ins := SAFE.insets()
	var m := _i(float(screen_margin))
	for pair in [[_top_margin, ins.y, 0.0], [_bottom_margin, 0.0, ins.w]]:
		var c: MarginContainer = pair[0]
		if c == null:
			continue
		c.add_theme_constant_override("margin_left", m + int(ins.x))
		c.add_theme_constant_override("margin_right", m + int(ins.z))
		c.add_theme_constant_override("margin_top", m + int(pair[1]))
		c.add_theme_constant_override("margin_bottom", m + int(pair[2]))

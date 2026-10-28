extends CanvasLayer

## Общая часть попапов-сцен (energy_popup.tscn, settings_popup.tscn, ...).
##
## Структура сцены (раскладка — только контейнеры, оформление — Theme
## res://resources/ui_theme.tres через Type Variations):
##   CanvasLayer (этот скрипт)
##   ├─ Dim (ColorRect, Full Rect)        ← затемнение, ловит тапы
##   └─ %Safe (MarginContainer, Full Rect) ← safe area + SCREEN_MARGIN
##      └─ CenterContainer
##         └─ %Panel (PanelContainer «PopupFrame»)
##            └─ VBoxContainer: заголовок, [%Scroll], кнопки
##
## ScrollContainer не умеет «высота по контенту, но не выше экрана» — это
## единственное, что считается кодом (`_relayout`): высота %Scroll.

signal closed

const SAFE := preload("res://scripts/ui/safe_area.gd")
## Воздух от края экрана и от вставок чёлки/home-индикатора.
const SCREEN_MARGIN := 16.0
## Скролл не сжимается ниже этого, даже на очень низком экране.
const MIN_SCROLL_H := 160.0

## Фиксированная высота панели (0 — по контенту). Всегда не выше экрана.
@export var panel_height := 0.0

@onready var _safe: MarginContainer = %Safe
@onready var _panel: Control = %Panel
@onready var _scroll: ScrollContainer = get_node_or_null("%Scroll") as ScrollContainer


func _ready() -> void:
	visible = false
	# Свайп-скролл нужен только открытому попапу: закрытые не разбирают ввод.
	set_process_input(false)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func open() -> void:
	visible = true
	set_process_input(true)
	_relayout.call_deferred()
	_relayout_after_layout()


## Второй проход: переносы строк в списке знают свою ширину только после
## раскладки — без него высота скролла считалась по «узкому» контенту.
func _relayout_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if visible:
		_relayout()


func close() -> void:
	visible = false
	set_process_input(false)
	closed.emit()


## Safe area и высота скролла. Зовётся на открытии и при смене размера окна.
func _relayout() -> void:
	SAFE.apply_margins(_safe, SCREEN_MARGIN)
	if _scroll == null or _scroll.get_child_count() == 0:
		return
	var ins := SAFE.insets()
	var avail := get_viewport().get_visible_rect().size.y - ins.y - ins.w - SCREEN_MARGIN * 2.0
	if panel_height > 0.0:
		avail = minf(avail, panel_height)
	_scroll.custom_minimum_size.y = 0.0
	var chrome := _panel.get_combined_minimum_size().y
	var cap := maxf(MIN_SCROLL_H, avail - chrome)
	var content := (_scroll.get_child(0) as Control).get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = cap if panel_height > 0.0 else minf(content, cap)


## Свайп-скролл пальцем: тап по кнопке внутри списка съедает драг у
## ScrollContainer, поэтому листаем сами, пока палец над областью скролла.
func _input(event: InputEvent) -> void:
	if not visible or _scroll == null:
		return
	var delta := 0.0
	var pos := Vector2.ZERO
	if event is InputEventScreenDrag:
		delta = (event as InputEventScreenDrag).relative.y
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		# На таче тот же свайп приходит ещё и эмулированной мышью — не листаем дважды.
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		delta = motion.relative.y
		pos = motion.position
	else:
		return
	if _scroll.get_global_rect().has_point(pos):
		_scroll.scroll_vertical -= int(delta)
		get_viewport().set_input_as_handled()

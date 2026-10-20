extends "res://scripts/ui/popup_base.gd"

## Мета-прогрессия (docs/GDD.md §8): ежедневная награда и коты.
## Декор и его покупка живут в изо-кофейне (scripts/ui/cafe_view.gd).
##
## Вёрстка — scenes/ui/meta_popup.tscn (контейнеры + Theme), элементы списка —
## компоненты scenes/ui/daily_tile.tscn и scenes/ui/cat_card.tscn. Состояние
## читается из автолоада Meta, награды выдаёт game.gd по сигналу наружу.

signal daily_claim_requested

const DATA := preload("res://scripts/data/meta.gd")
const DAILY_TILE := preload("res://scenes/ui/daily_tile.tscn")
const CAT_CARD := preload("res://scenes/ui/cat_card.tscn")
## Все 7 дней видны сразу: сетка 4 + 3, без горизонтального скролла.
const DAILY_COLUMNS := 4

@onready var _list: VBoxContainer = %List
@onready var _tabs: Array[Button] = [%DayTab, %CatsTab]
var _tab := 0


func _ready() -> void:
	super()
	for index in _tabs.size():
		_tabs[index].pressed.connect(func() -> void: _select_tab(index))
	(%Close as Button).pressed.connect(close)


## Открыть и пересобрать содержимое (состояние могло измениться).
func open() -> void:
	_rebuild()
	super()


## Открыть сразу на нужной вкладке (0 — день, 1 — коты).
func open_tab(index: int) -> void:
	_tab = clampi(index, 0, _tabs.size() - 1)
	_tabs[_tab].button_pressed = true
	open()


## Пересобрать, если попап открыт (после выдачи награды или покупки).
func refresh() -> void:
	if visible:
		_rebuild()


func _select_tab(index: int) -> void:
	_tab = index
	_rebuild()
	_relayout()


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _tab == 1:
		_build_cats()
	else:
		_build_daily()


# --- Ежедневная награда (GDD §8.3) -------------------------------------------

func _build_daily() -> void:
	_label("Стрик: %d / %d" % [Meta.daily_streak, DATA.DAILY_DAYS], "HeaderLabel")

	var grid := GridContainer.new()
	grid.columns = DAILY_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_list.add_child(grid)
	var today := Meta.next_day()
	for index in DATA.DAILY_REWARDS.size():
		var tile := DAILY_TILE.instantiate()
		grid.add_child(tile)
		tile.setup(DATA.DAILY_REWARDS[index], index + 1, today)

	var claim := Button.new()
	claim.theme_type_variation = &"PrimaryButton"
	claim.text = "Забрать" if Meta.can_claim() else "Уже получено"
	claim.custom_minimum_size = Vector2(320, 80)
	claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim.disabled = not Meta.can_claim()
	claim.pressed.connect(func() -> void: daily_claim_requested.emit())
	_list.add_child(claim)

	_label("Пропущенный день сбрасывает стрик на первый. На 7-й день — котовый сундук.",
		"HintLabel")


# --- Коты (GDD §8.2) ---------------------------------------------------------

func _build_cats() -> void:
	_label("Открыто: %d / %d · бонус +%d%% за заказ" % [
		Meta.cat_count(), DATA.CATS.size(), Meta.cat_bonus_percent(),
	], "BodyLabel")
	for item in DATA.CATS:
		var cat: Dictionary = item
		var card := CAT_CARD.instantiate()
		_list.add_child(card)
		card.setup(cat, Meta.is_cat_unlocked(String(cat.get("id", ""))))


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)
	return label

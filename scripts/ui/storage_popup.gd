extends "res://scripts/ui/popup_base.gd"

## Склад (scenes/ui/storage_popup.tscn): ячейки вне поля. Тап по занятой
## ячейке — вернуть предмет на поле, по закрытой — купить слот за гемы.
## Правила (вместимость, цена слота) — в game.gd, здесь только отображение.

signal take_requested(index: int)
signal buy_slot_requested

const ART := preload("res://scripts/data/art.gd")
const GEM_ICON := preload("res://assets/ui/theme/icon_gem.png")
const SLOT_SIZE := Vector2(170, 150)

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)


## items — массив словарей ItemData.to_dict(); slots — открыто ячеек;
## can_buy/next_cost — можно ли докупить следующую и за сколько.
func show_storage(items: Array, slots: int, can_buy: bool, next_cost: int) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for i in slots:
		var slot := _slot_button()
		if i < items.size():
			var data := ItemData.from_dict(items[i])
			slot.icon = _icon(data)
			slot.text = data.display_name
			slot.pressed.connect(func() -> void: take_requested.emit(i))
		else:
			slot.text = "Пусто"
			slot.disabled = true
		_grid.add_child(slot)
	if can_buy:
		var buy := _slot_button()
		buy.icon = GEM_ICON
		buy.text = "+1 ячейка · %d" % next_cost
		buy.pressed.connect(func() -> void: buy_slot_requested.emit())
		_grid.add_child(buy)
	if visible:
		_relayout.call_deferred()


func _slot_button() -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SlotButton"
	b.custom_minimum_size = SLOT_SIZE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


static func _icon(data: ItemData) -> Texture2D:
	var chain := Chains.generator_target(data.chain) if Chains.is_generator(data.chain) else data.chain
	var level := 1 if Chains.is_generator(data.chain) else data.level
	var tex: Texture2D = ART.item_texture(chain, level)
	return tex if tex != null else Placeholders.item_texture(chain, level)

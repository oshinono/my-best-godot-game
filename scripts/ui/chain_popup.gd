extends "res://scripts/ui/popup_base.gd"

## Цепочка предмета (scenes/ui/chain_popup.tscn): все уровни цепочки по
## порядку; текущий подсвечен, ещё не открытые — силуэтом и «???».

const ART := preload("res://scripts/data/art.gd")
const COLUMNS := 4
const TILE := Vector2(120, 120)

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)


## discovered — максимальный уровень, который игрок уже получал в этой цепочке.
func show_chain(chain: StringName, current: int, discovered: int) -> void:
	(%Title as Label).text = Chains.title(chain)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	_list.add_child(grid)
	for level in range(1, Chains.max_level(chain) + 1):
		grid.add_child(_tile(chain, level, level == current, level <= discovered))
	open()


func _tile(chain: StringName, level: int, is_current: bool, known: bool) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"ChipSelected" if is_current else &"Chip"
	frame.custom_minimum_size = TILE
	column.add_child(frame)
	var icon := TextureRect.new()
	var tex: Texture2D = ART.item_texture(chain, level)
	icon.texture = tex if tex != null else Placeholders.item_texture(chain, level)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Арт предмета ~512 px ужат до плитки: с мипмапами без ряби.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not known:
		# Силуэт: форма видна, сам предмет — сюрприз.
		icon.modulate = Color(0.25, 0.18, 0.12, 0.45)
	frame.add_child(icon)
	var name_label := Label.new()
	name_label.theme_type_variation = &"HintLabel"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.text = "%d. %s" % [level, Chains.item_name(chain, level) if known else "???"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(TILE.x, 0)
	column.add_child(name_label)
	return column

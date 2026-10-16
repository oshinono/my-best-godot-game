class_name ItemData
extends Resource

## Данные одного предмета на поле.
## chain — идентификатор цепочки ("coffee"/"pastry"/"flowers"),
## level — уровень внутри цепочки (1..Chains.max_level(chain)).
##
## Это «сохранённые» данные: визуал берётся из icon, а пока арта нет —
## из Placeholders.item_texture(chain, level).

@export var chain: StringName = &""
@export var level: int = 1
@export var display_name: String = ""
@export var icon: Texture2D


func duplicate_data() -> ItemData:
	var copy := ItemData.new()
	copy.chain = chain
	copy.level = level
	copy.display_name = display_name
	copy.icon = icon
	return copy


func to_dict() -> Dictionary:
	return {"chain": String(chain), "level": level}


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.chain = StringName(data.get("chain", ""))
	item.level = int(data.get("level", 1))
	return item

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
## Только у генераторов: сколько тапов осталось до отдыха (-1 — не генератор)
## и когда отдых закончится (unix-секунды, 0 — не отдыхает).
@export var charges: int = -1
@export var recharge_at: int = 0


func duplicate_data() -> ItemData:
	var copy := ItemData.new()
	copy.chain = chain
	copy.level = level
	copy.display_name = display_name
	copy.icon = icon
	copy.charges = charges
	copy.recharge_at = recharge_at
	return copy


func to_dict() -> Dictionary:
	var out := {"chain": String(chain), "level": level}
	if charges >= 0:
		out["charges"] = charges
		out["recharge_at"] = recharge_at
	return out


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.chain = StringName(data.get("chain", ""))
	item.level = int(data.get("level", 1))
	item.display_name = Chains.item_name(item.chain, item.level)
	if data.has("charges"):
		item.charges = int(data.get("charges", -1))
		item.recharge_at = int(data.get("recharge_at", 0))
	elif Chains.is_generator(item.chain):
		item.charges = int(Chains.gen_param("gen_charges", item.level, 6.0))
	return item

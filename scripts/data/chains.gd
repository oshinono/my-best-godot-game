class_name Chains
extends RefCounted

## Цепочки предметов. Последний уровень цепочки — тот, что просят коты в заказах.
## Источник правды по названиям/длинам: docs/GDD.md §5, docs/economy.md.

const COFFEE := &"coffee"
const PASTRY := &"pastry"
const FLOWERS := &"flowers"

const DATA := {
	COFFEE: {
		"title": "Кофе",
		"levels": [
			"Зелёное зерно",
			"Обжаренное зерно",
			"Смолотый кофе",
			"Таблетка",
			"Эспрессо",
			"Капучино",
			"Латте",
			"Флэт-уайт",
			"Кофейный сет",
			"Сигнатурный напиток",
		],
	},
	PASTRY: {
		"title": "Выпечка",
		"levels": [
			"Тесто",
			"Заготовка круассана",
			"Круассан",
			"Маффин",
			"Чизкейк",
			"Слоёный торт",
			"Многоярусный торт",
		],
	},
	FLOWERS: {
		"title": "Цветы",
		"levels": [
			"Росток",
			"Бутон",
			"Цветок",
			"Букет",
			"Композиция",
		],
	},
}


## Генераторы — тоже предметы поля: цепочка «gen_<цепочка>», уровни 1..3.
## Тап по генератору выдаёт L1 своей цепочки; два одинаковых сливаются.
const GEN_PREFIX := "gen_"
const GEN_MAX_LEVEL := 3
const GEN_TITLES := {
	COFFEE: "Кофемашина",
	PASTRY: "Печь",
	FLOWERS: "Теплица",
}


static func all_chains() -> Array:
	return [COFFEE, PASTRY, FLOWERS]


static func is_generator(chain: StringName) -> bool:
	return String(chain).begins_with(GEN_PREFIX)


## Цепочка генератора для цепочки предметов: coffee → gen_coffee.
static func generator_for(target: StringName) -> StringName:
	return StringName(GEN_PREFIX + String(target))


## Какую цепочку выдаёт генератор: gen_coffee → coffee.
static func generator_target(chain: StringName) -> StringName:
	return StringName(String(chain).trim_prefix(GEN_PREFIX))


## Параметр генератора по уровню из Config (массив по уровням 1..3).
static func gen_param(key: String, level: int, fallback: float) -> float:
	var values = Config.get_value(key)
	if typeof(values) != TYPE_ARRAY or (values as Array).is_empty():
		return fallback
	var list: Array = values
	return float(list[clampi(level - 1, 0, list.size() - 1)])


static func max_level(chain: StringName) -> int:
	if is_generator(chain):
		return GEN_MAX_LEVEL
	var info: Dictionary = DATA.get(chain, {})
	return (info.get("levels", []) as Array).size()


static func title(chain: StringName) -> String:
	if is_generator(chain):
		return String(GEN_TITLES.get(generator_target(chain), "Генератор"))
	var info: Dictionary = DATA.get(chain, {})
	return String(info.get("title", String(chain)))


static func item_name(chain: StringName, level: int) -> String:
	if is_generator(chain):
		return "%s · ур. %d" % [title(chain), level]
	var info: Dictionary = DATA.get(chain, {})
	var levels: Array = info.get("levels", [])
	if level < 1 or level > levels.size():
		return "%s L%d" % [title(chain), level]
	return String(levels[level - 1])


## Стоимость продажи одного предмета: round(base * growth^(level-1)).
## base/growth приходят из Config (item_value_base / item_value_growth).
static func sell_value(level: int, base: float, growth: float) -> int:
	return int(round(base * pow(growth, level - 1)))


## Данные предмета для сцены.
static func make(chain: StringName, level: int) -> ItemData:
	var item := ItemData.new()
	item.chain = chain
	item.level = level
	item.display_name = item_name(chain, level)
	if is_generator(chain):
		item.charges = int(gen_param("gen_charges", level, 6.0))
	return item

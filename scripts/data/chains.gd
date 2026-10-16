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


static func all_chains() -> Array:
	return [COFFEE, PASTRY, FLOWERS]


static func max_level(chain: StringName) -> int:
	var info: Dictionary = DATA.get(chain, {})
	return (info.get("levels", []) as Array).size()


static func title(chain: StringName) -> String:
	var info: Dictionary = DATA.get(chain, {})
	return String(info.get("title", String(chain)))


static func item_name(chain: StringName, level: int) -> String:
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
	return item

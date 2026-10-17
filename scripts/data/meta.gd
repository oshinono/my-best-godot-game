extends RefCounted
## Таблицы мета-прогрессии (GDD §8): ежедневная награда, коты, декор.
## Здесь только данные и хелперы, без состояния — состояние живёт
## в автолоаде scripts/autoload/meta.gd (ключи сейва cats / decor / daily_*).

## Длина стрика ежедневной награды (GDD §8.3).
const DAILY_DAYS := 7

## 7-дневный стрик: монеты / гемы / энергия, 7-й день — «котовый сундук».
const DAILY_REWARDS: Array = [
	{"day": 1, "coins": 150},
	{"day": 2, "energy": 10},
	{"day": 3, "coins": 300},
	{"day": 4, "gems": 5},
	{"day": 5, "coins": 600},
	{"day": 6, "energy": 20},
	{"day": 7, "chest": "cat"},
]

const RARITY_NAMES := {
	"common": "Обычный",
	"rare": "Редкий",
	"epic": "Эпический",
}

const RARITY_ICONS := {
	"common": "⭐",
	"rare": "⭐⭐",
	"epic": "⭐⭐⭐",
}

## 12 котов (GDD §8.2). `level` — нужный уровень кофейни, `orders` — сколько
## заказов надо выполнить, `chest` — выпадает только из котового сундука.
const CATS: Array = [
	{
		"id": "mocha", "name": "Мокко", "role": "Бариста", "rarity": "common",
		"level": 1, "orders": 0, "story": "Первый кот в кафе. Умеет взбивать молоко так, что пенка стоит горкой.",
	},
	{
		"id": "latte", "name": "Латте", "role": "Официант", "rarity": "common",
		"level": 1, "orders": 3, "story": "Носит поднос на хвосте и никогда не проливает ни капли.",
	},
	{
		"id": "bublik", "name": "Бублик", "role": "Пекарь", "rarity": "common",
		"level": 2, "orders": 8, "story": "Просыпается в пять утра, чтобы тесто успело отдохнуть.",
	},
	{
		"id": "tiramisu", "name": "Тирамису", "role": "Гость", "rarity": "common",
		"level": 3, "orders": 15, "story": "Приходит каждый день в одно и то же время и заказывает одно и то же.",
	},
	{
		"id": "espresso", "name": "Эспрессо", "role": "Старший бариста", "rarity": "rare",
		"level": 5, "orders": 25, "story": "Считает, что хороший день начинается с правильной проливки.",
	},
	{
		"id": "choco", "name": "Шоко", "role": "Кондитер", "rarity": "rare",
		"level": 7, "orders": 35, "story": "Знает тридцать два способа украсить эклер и никому их не рассказывает.",
	},
	{
		"id": "mimi", "name": "Мими", "role": "Гость-критик", "rarity": "rare",
		"level": 9, "orders": 50, "story": "Пишет обзоры кафе в лапку и ставит звёзды без жалости.",
	},
	{
		"id": "flora", "name": "Флора", "role": "Садовник", "rarity": "rare",
		"level": 12, "orders": 70, "story": "Выращивает цветы для букетов на столах и никогда не срезает последний.",
	},
	{
		"id": "caramel", "name": "Карамель", "role": "Шеф-пекарь", "rarity": "epic",
		"level": 14, "orders": 0, "chest": true, "story": "Появилась из котового сундука вместе с запахом карамели.",
	},
	{
		"id": "mochi", "name": "Моти", "role": "Дегустатор", "rarity": "epic",
		"level": 16, "orders": 0, "chest": true, "story": "Мягкая, как рисовое пирожное, и невероятно придирчивая.",
	},
	{
		"id": "velvet", "name": "Бархат", "role": "Инспектор уюта", "rarity": "epic",
		"level": 18, "orders": 100, "story": "Проверяет, удобно ли гостям сидеть, и одобряет только лучшие диваны.",
	},
	{
		"id": "star", "name": "Звёздочка", "role": "Легенда кафе", "rarity": "epic",
		"level": 20, "orders": 0, "chest": true, "story": "О ней пишут в путеводителях. Приходит, когда кафе уже знаменито.",
	},
]

## Декор кофейни (GDD §8.1). Покупка за монеты даёт XP; уровни кофейни гейтят котов.
## `room` — комната, куда предмет ставится; `short` — подпись на слоте расстановки.
const DECOR: Array = [
	{"id": "sofa", "name": "Диван у окна", "short": "Диван", "room": "Зал", "cost": 120, "xp": 40},
	{"id": "rug", "name": "Пушистый ковёр", "short": "Ковёр", "room": "Зал", "cost": 250, "xp": 60},
	{"id": "espresso_machine", "name": "Эспрессо-машина", "short": "Кофемашина", "room": "Кухня", "cost": 400, "xp": 90},
	{"id": "display_case", "name": "Витрина с десертами", "short": "Витрина", "room": "Кухня", "cost": 650, "xp": 120},
	{"id": "terrace_table", "name": "Столик на террасе", "short": "Столик", "room": "Терраса", "cost": 900, "xp": 150},
	{"id": "umbrella", "name": "Полосатый зонт", "short": "Зонт", "room": "Терраса", "cost": 1200, "xp": 180},
	{"id": "garland", "name": "Гирлянда огней", "short": "Гирлянда", "room": "Терраса", "cost": 1500, "xp": 210},
	{"id": "flower_bed", "name": "Клумба с ромашками", "short": "Клумба", "room": "Сад", "cost": 1800, "xp": 240},
	{"id": "fountain", "name": "Фонтан с карпами", "short": "Фонтан", "room": "Сад", "cost": 2400, "xp": 300},
]

## Комнаты кофейни по порядку (GDD §8.1): зал → кухня → терраса → сад.
## `floor` — цвет пола комнаты в попапе расстановки (hex).
const ROOMS: Array = [
	{"id": "hall", "name": "Зал", "floor": "E8D6BE"},
	{"id": "kitchen", "name": "Кухня", "floor": "EADFCB"},
	{"id": "terrace", "name": "Терраса", "floor": "DCE6D2"},
	{"id": "garden", "name": "Сад", "floor": "D2E4C8"},
]

## Слоты расстановки мебели: `x`, `y` — центр слота внутри комнаты (0..1).
const SLOTS: Array = [
	{"id": "hall_1", "room": "Зал", "x": 0.2, "y": 0.62},
	{"id": "hall_2", "room": "Зал", "x": 0.5, "y": 0.62},
	{"id": "hall_3", "room": "Зал", "x": 0.8, "y": 0.62},
	{"id": "kitchen_1", "room": "Кухня", "x": 0.28, "y": 0.6},
	{"id": "kitchen_2", "room": "Кухня", "x": 0.72, "y": 0.6},
	{"id": "terrace_1", "room": "Терраса", "x": 0.18, "y": 0.5},
	{"id": "terrace_2", "room": "Терраса", "x": 0.5, "y": 0.75},
	{"id": "terrace_3", "room": "Терраса", "x": 0.82, "y": 0.5},
	{"id": "garden_1", "room": "Сад", "x": 0.3, "y": 0.6},
	{"id": "garden_2", "room": "Сад", "x": 0.7, "y": 0.6},
]


## Кот по id. Пустой словарь, если такого нет.
static func cat(cat_id: String) -> Dictionary:
	for item in CATS:
		if String(item.get("id", "")) == cat_id:
			return item
	return {}


## Предмет декора по id. Пустой словарь, если такого нет.
static func decor(decor_id: String) -> Dictionary:
	for item in DECOR:
		if String(item.get("id", "")) == decor_id:
			return item
	return {}


## Награда за день стрика (1..DAILY_DAYS); вне диапазона — ближайшая.
static func daily_reward(day: int) -> Dictionary:
	var index := clampi(day - 1, 0, DAILY_REWARDS.size() - 1)
	return DAILY_REWARDS[index]


## Коты, которые выпадают только из сундука (эпики).
static func chest_cats() -> Array:
	var out := []
	for item in CATS:
		if bool(item.get("chest", false)):
			out.append(item)
	return out


## Осталось ли что-то в котовом сундуке (иначе выдаём гемы).
static func chest_has_new(unlocked: Array) -> bool:
	for item in chest_cats():
		if not unlocked.has(String(item.get("id", ""))):
			return true
	return false


static func rarity_name(rarity: String) -> String:
	return String(RARITY_NAMES.get(rarity, rarity))


static func rarity_icon(rarity: String) -> String:
	return String(RARITY_ICONS.get(rarity, "⭐"))


## Условие открытия кота словарем — для карточек альбома.
static func cat_requirement(item: Dictionary) -> String:
	if bool(item.get("chest", false)):
		return "Из котового сундука"
	var level := int(item.get("level", 1))
	var orders := int(item.get("orders", 0))
	if orders > 0:
		return "Уровень %d и %d заказов" % [level, orders]
	return "Уровень кофейни %d" % level


## Короткая подпись предмета для слота расстановки.
static func decor_short(item: Dictionary) -> String:
	var short_name := String(item.get("short", ""))
	if short_name != "":
		return short_name
	return String(item.get("name", ""))


## Слот расстановки по id. Пустой словарь, если такого нет.
static func slot(slot_id: String) -> Dictionary:
	for item in SLOTS:
		if String(item.get("id", "")) == slot_id:
			return item
	return {}


## Слоты комнаты по названию («Зал», «Кухня», …).
static func room_slots(room_name: String) -> Array:
	var out := []
	for item in SLOTS:
		if String(item.get("room", "")) == room_name:
			out.append(item)
	return out


## Цвет пола комнаты (hex-строка) — для попапа расстановки.
static func room_floor(room_name: String) -> String:
	for item in ROOMS:
		if String(item.get("name", "")) == room_name:
			return String(item.get("floor", "E8D6BE"))
	return "E8D6BE"

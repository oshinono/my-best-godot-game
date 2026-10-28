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
## `room` — комната; `short` — подпись; `w`/`h` — размер в тайлах изо-сетки;
## `rot` — можно ли поворачивать (4 ракурса N/E/S/W, см. `decor_sprite`);
## `wall` — настенный предмет (пока ставится как обычный, на пол).
## Расстановка свободная: предмет встаёт куда угодно, лишь бы влез в одну
## комнату и не пересёкся с другой мебелью (Meta.can_place).
## Первые 9 id (sofa…fountain) сохранены из старой таблицы — старые сейвы не ломаются.
const DECOR: Array = [
	# --- Зал ---
	{"id": "sofa", "name": "Диван у окна", "short": "Диван", "room": "Зал", "cost": 120, "xp": 40, "w": 2, "h": 1, "rot": true},
	{"id": "armchair", "name": "Кресло", "short": "Кресло", "room": "Зал", "cost": 180, "xp": 50, "w": 1, "h": 1, "rot": true},
	{"id": "round_table", "name": "Круглый столик", "short": "Столик", "room": "Зал", "cost": 300, "xp": 70, "w": 1, "h": 1},
	{"id": "chair", "name": "Стул", "short": "Стул", "room": "Зал", "cost": 200, "xp": 55, "w": 1, "h": 1, "rot": true},
	{"id": "rug", "name": "Пушистый ковёр", "short": "Ковёр", "room": "Зал", "cost": 250, "xp": 60, "w": 3, "h": 2},
	{"id": "bookshelf", "name": "Полка с книгами", "short": "Полка", "room": "Зал", "cost": 700, "xp": 130, "w": 1, "h": 1, "rot": true},
	{"id": "counter", "name": "Стойка бара", "short": "Стойка", "room": "Зал", "cost": 1100, "xp": 160, "w": 3, "h": 1, "rot": true},
	{"id": "fireplace", "name": "Камин", "short": "Камин", "room": "Зал", "cost": 1600, "xp": 220, "w": 2, "h": 1, "rot": true},
	{"id": "floor_lamp", "name": "Торшер", "short": "Торшер", "room": "Зал", "cost": 350, "xp": 80, "w": 1, "h": 1},
	{"id": "plant", "name": "Растение в кадке", "short": "Растение", "room": "Зал", "cost": 260, "xp": 65, "w": 1, "h": 1},
	{"id": "painting", "name": "Картина", "short": "Картина", "room": "Зал", "cost": 500, "xp": 100, "w": 1, "h": 1, "wall": true},
	# --- Кухня ---
	{"id": "espresso_machine", "name": "Эспрессо-машина", "short": "Кофемашина", "room": "Кухня", "cost": 400, "xp": 90, "w": 1, "h": 1, "rot": true},
	{"id": "display_case", "name": "Витрина с десертами", "short": "Витрина", "room": "Кухня", "cost": 650, "xp": 120, "w": 2, "h": 1, "rot": true},
	{"id": "fridge", "name": "Холодильник", "short": "Холодильник", "room": "Кухня", "cost": 800, "xp": 140, "w": 1, "h": 1, "rot": true},
	{"id": "prep_table", "name": "Стол для готовки", "short": "Стол", "room": "Кухня", "cost": 950, "xp": 150, "w": 2, "h": 1, "rot": true},
	{"id": "oven", "name": "Печь", "short": "Печь", "room": "Кухня", "cost": 900, "xp": 145, "w": 1, "h": 1, "rot": true},
	{"id": "shelf", "name": "Стеллаж", "short": "Стеллаж", "room": "Кухня", "cost": 550, "xp": 110, "w": 1, "h": 1, "rot": true},
	# --- Терраса ---
	{"id": "terrace_table", "name": "Столик на террасе", "short": "Столик", "room": "Терраса", "cost": 900, "xp": 150, "w": 1, "h": 1},
	{"id": "umbrella", "name": "Полосатый зонт", "short": "Зонт", "room": "Терраса", "cost": 1200, "xp": 180, "w": 1, "h": 1},
	{"id": "wicker_chair", "name": "Плетёное кресло", "short": "Кресло", "room": "Терраса", "cost": 1000, "xp": 155, "w": 1, "h": 1, "rot": true},
	{"id": "planter", "name": "Кашпо с цветами", "short": "Кашпо", "room": "Терраса", "cost": 800, "xp": 140, "w": 1, "h": 1},
	{"id": "garland", "name": "Гирлянда огней", "short": "Гирлянда", "room": "Терраса", "cost": 1500, "xp": 210, "w": 3, "h": 1, "wall": true},
	# --- Сад ---
	{"id": "flower_bed", "name": "Клумба с ромашками", "short": "Клумба", "room": "Сад", "cost": 1800, "xp": 240, "w": 2, "h": 1},
	{"id": "bench", "name": "Садовая скамья", "short": "Скамья", "room": "Сад", "cost": 1700, "xp": 230, "w": 2, "h": 1, "rot": true},
	{"id": "fountain", "name": "Фонтан с карпами", "short": "Фонтан", "room": "Сад", "cost": 2400, "xp": 300, "w": 2, "h": 2},
	{"id": "tree", "name": "Дерево", "short": "Дерево", "room": "Сад", "cost": 2600, "xp": 320, "w": 1, "h": 1},
	{"id": "bush", "name": "Куст", "short": "Куст", "room": "Сад", "cost": 2200, "xp": 280, "w": 1, "h": 1},
]

## Комнаты кофейни в одной изо-сцене (GDD §8.1): зал → кухня → терраса → сад.
## `floor` — цвет пола комнаты в изо-виде (hex). Область комнаты на тайловой
## сетке: `tx`,`ty` — левый верхний тайл, `w`,`h` — размер в тайлах.
const ROOMS: Array = [
	{"id": "hall", "name": "Зал", "floor": "E8D6BE", "tx": 0, "ty": 7, "w": 10, "h": 7},
	{"id": "kitchen", "name": "Кухня", "floor": "EADFCB", "tx": 0, "ty": 0, "w": 7, "h": 6},
	{"id": "terrace", "name": "Терраса", "floor": "DCE6D2", "tx": 7, "ty": 0, "w": 6, "h": 7},
	{"id": "garden", "name": "Сад", "floor": "D2E4C8", "tx": 10, "ty": 7, "w": 8, "h": 7},
]

## Старые фиксированные слоты расстановки (до свободной расстановки):
## slot_id → левый верхний тайл. Нужны только для переноса старых сейвов
## (`decor_placed`) в координаты — см. Meta._restore.
const LEGACY_SLOT_TILES := {
	"kitchen_1": Vector2i(1, 1), "kitchen_2": Vector2i(3, 1), "kitchen_3": Vector2i(5, 2),
	"kitchen_4": Vector2i(1, 3), "kitchen_5": Vector2i(4, 3), "kitchen_6": Vector2i(5, 3),
	"hall_w1": Vector2i(3, 7), "hall_1": Vector2i(1, 9), "hall_2": Vector2i(3, 9),
	"hall_3": Vector2i(6, 9), "hall_8": Vector2i(5, 7), "hall_4": Vector2i(1, 11),
	"hall_5": Vector2i(5, 11), "hall_6": Vector2i(7, 11), "hall_7": Vector2i(9, 10),
	"hall_9": Vector2i(8, 10), "hall_10": Vector2i(2, 10), "hall_11": Vector2i(9, 12),
	"terrace_w1": Vector2i(8, 1), "terrace_1": Vector2i(8, 2), "terrace_2": Vector2i(10, 2),
	"terrace_3": Vector2i(8, 4), "terrace_4": Vector2i(10, 4),
	"garden_1": Vector2i(12, 9), "garden_2": Vector2i(15, 9), "garden_3": Vector2i(13, 12),
	"garden_4": Vector2i(11, 11), "garden_5": Vector2i(16, 11),
}


## Индексы id → запись: кофейня ищет декор и слоты в циклах на каждое касание.
## Строятся при первом обращении (таблицы — константы, не меняются).
static var _index := {}


static func _by_id(table_name: String, table: Array, id: String) -> Dictionary:
	if not _index.has(table_name):
		var map := {}
		for item in table:
			map[String(item.get("id", ""))] = item
		_index[table_name] = map
	return (_index[table_name] as Dictionary).get(id, {})


## Кот по id. Пустой словарь, если такого нет.
static func cat(cat_id: String) -> Dictionary:
	return _by_id("cats", CATS, cat_id)


## Предмет декора по id. Пустой словарь, если такого нет.
static func decor(decor_id: String) -> Dictionary:
	return _by_id("decor", DECOR, decor_id)


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


## Число звёзд редкости (1..3) — для иконки/подписи.
static func rarity_stars(rarity: String) -> int:
	return rarity_icon(rarity).length()


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


## Цвет пола комнаты (hex-строка) — для изо-вида.
static func room_floor(room_name: String) -> String:
	for item in ROOMS:
		if String(item.get("name", "")) == room_name:
			return String(item.get("floor", "E8D6BE"))
	return "E8D6BE"


## Комната по названию. Пустой словарь, если такой нет.
static func room(room_name: String) -> Dictionary:
	for item in ROOMS:
		if String(item.get("name", "")) == room_name:
			return item
	return {}


## Размер предмета с учётом поворота: нечётный поворот меняет местами w/h.
static func rotated_size(item: Dictionary, rot: int) -> Vector2i:
	var w := int(item.get("w", 1))
	var h := int(item.get("h", 1))
	if ((int(rot) % 4) + 4) % 4 % 2 == 1:
		var t := w
		w = h
		h = t
	return Vector2i(maxi(w, 1), maxi(h, 1))


## Комната, которой принадлежит тайл. Пустой словарь — тайл вне плана.
static func room_at(tile: Vector2i) -> Dictionary:
	for item in ROOMS:
		var tx := int(item["tx"])
		var ty := int(item["ty"])
		if tile.x >= tx and tile.x < tx + int(item["w"]) \
				and tile.y >= ty and tile.y < ty + int(item["h"]):
			return item
	return {}


## Комната, в которую целиком помещается область (tx, ty, size). Пустой
## словарь — область вылезает за пол или лежит на стыке двух комнат
## (между комнатами стоят стены, мебель через них не ставим).
static func area_room(tile: Vector2i, size: Vector2i) -> Dictionary:
	var found := room_at(tile)
	if found.is_empty():
		return {}
	var far := tile + size - Vector2i.ONE
	if room_at(far) != found:
		return {}
	return found


## Можно ли поворачивать предмет (4 ракурса).
static func is_rotatable(item: Dictionary) -> bool:
	return bool(item.get("rot", false))


## Путь к спрайту предмета для ракурса 0..3 (0=N, 1=E, 2=S, 3=W).
## Соглашение: assets/decor/<id>/<id>_<N|E|S|W>.png.
## Порядок ракурсов = поворот по часовой: 0=фасад к зрителю (S),
## дальше W, N, E. Так rot по умолчанию ставит предмет лицом к игроку.
const SPRITE_DIRS: PackedStringArray = ["S", "W", "N", "E"]
static func decor_sprite(decor_id: String, rot: int) -> String:
	var dir: String = SPRITE_DIRS[((int(rot) % 4) + 4) % 4]
	# Арт лежит плоско: assets/decor/<id>_<S|W|N|E>.png (старый вариант с
	# подпапкой на предмет тоже понимаем).
	var flat := "res://assets/decor/%s_%s.png" % [decor_id, dir]
	if ResourceLoader.exists(flat):
		return flat
	return "res://assets/decor/%s/%s_%s.png" % [decor_id, decor_id, dir]

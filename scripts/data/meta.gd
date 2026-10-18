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
## `wall` — предмет висит на стене (ставится только в стенные слоты).
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

## Слоты расстановки мебели: фиксированные места на тайловой сетке.
## `tx`,`ty` — левый верхний тайл слота, `w`,`h` — размер в тайлах;
## `wall` — место на стене (для картин/гирлянд). Предмет подходит слоту, если
## совпадают комната и признак стены, а размер предмета (с учётом поворота)
## не больше слота — см. `fits()`.
const SLOTS: Array = [
	# --- Кухня ---
	{"id": "kitchen_1", "room": "Кухня", "tx": 1, "ty": 1, "w": 1, "h": 1},
	{"id": "kitchen_2", "room": "Кухня", "tx": 3, "ty": 1, "w": 2, "h": 1},
	{"id": "kitchen_3", "room": "Кухня", "tx": 5, "ty": 2, "w": 1, "h": 1},
	{"id": "kitchen_4", "room": "Кухня", "tx": 1, "ty": 3, "w": 2, "h": 1},
	{"id": "kitchen_5", "room": "Кухня", "tx": 4, "ty": 3, "w": 1, "h": 1},
	{"id": "kitchen_6", "room": "Кухня", "tx": 5, "ty": 3, "w": 1, "h": 1},
	# --- Зал ---
	{"id": "hall_w1", "room": "Зал", "tx": 3, "ty": 7, "w": 1, "h": 1, "wall": true},
	{"id": "hall_1", "room": "Зал", "tx": 1, "ty": 9, "w": 1, "h": 1},
	{"id": "hall_2", "room": "Зал", "tx": 3, "ty": 9, "w": 2, "h": 1},
	{"id": "hall_3", "room": "Зал", "tx": 6, "ty": 9, "w": 3, "h": 1},
	{"id": "hall_8", "room": "Зал", "tx": 5, "ty": 7, "w": 2, "h": 1},
	{"id": "hall_4", "room": "Зал", "tx": 1, "ty": 11, "w": 3, "h": 2},
	{"id": "hall_5", "room": "Зал", "tx": 5, "ty": 11, "w": 1, "h": 1},
	{"id": "hall_6", "room": "Зал", "tx": 7, "ty": 11, "w": 1, "h": 1},
	{"id": "hall_7", "room": "Зал", "tx": 9, "ty": 10, "w": 1, "h": 1},
	{"id": "hall_9", "room": "Зал", "tx": 8, "ty": 10, "w": 1, "h": 1},
	{"id": "hall_10", "room": "Зал", "tx": 2, "ty": 10, "w": 1, "h": 1},
	{"id": "hall_11", "room": "Зал", "tx": 9, "ty": 12, "w": 1, "h": 1},
	# --- Терраса ---
	{"id": "terrace_w1", "room": "Терраса", "tx": 8, "ty": 1, "w": 3, "h": 1, "wall": true},
	{"id": "terrace_1", "room": "Терраса", "tx": 8, "ty": 2, "w": 1, "h": 1},
	{"id": "terrace_2", "room": "Терраса", "tx": 10, "ty": 2, "w": 1, "h": 1},
	{"id": "terrace_3", "room": "Терраса", "tx": 8, "ty": 4, "w": 1, "h": 1},
	{"id": "terrace_4", "room": "Терраса", "tx": 10, "ty": 4, "w": 1, "h": 1},
	# --- Сад ---
	{"id": "garden_1", "room": "Сад", "tx": 12, "ty": 9, "w": 2, "h": 1},
	{"id": "garden_2", "room": "Сад", "tx": 15, "ty": 9, "w": 2, "h": 1},
	{"id": "garden_3", "room": "Сад", "tx": 13, "ty": 12, "w": 2, "h": 2},
	{"id": "garden_4", "room": "Сад", "tx": 11, "ty": 11, "w": 1, "h": 1},
	{"id": "garden_5", "room": "Сад", "tx": 16, "ty": 11, "w": 1, "h": 1},
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


## Подходит ли предмет слоту при повороте `rot`: совпадают комната и признак
## стены, а размер (с учётом поворота) не больше слота.
static func fits(item: Dictionary, slot_data: Dictionary, rot := 0) -> bool:
	if item.is_empty() or slot_data.is_empty():
		return false
	if String(item.get("room", "")) != String(slot_data.get("room", "")):
		return false
	if bool(item.get("wall", false)) != bool(slot_data.get("wall", false)):
		return false
	var size := rotated_size(item, rot)
	return size.x <= int(slot_data.get("w", 1)) and size.y <= int(slot_data.get("h", 1))


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
	return "res://assets/decor/%s/%s_%s.png" % [decor_id, decor_id, dir]

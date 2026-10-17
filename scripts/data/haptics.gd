extends RefCounted
## Таблица вибраций (GDD §15, docs/haptics.md).
##
## Звука в прототипе нет — вся «сочность» держится на тактильной отдаче, поэтому
## у каждого игрового события свой профиль: сила + рисунок.
##
## pattern   — [жужжание, пауза, жужжание, ...] в миллисекундах. Чётные индексы
##             вибрируют, нечётные — паузы (Android держит паузы честно; на iOS
##             получается серия коротких системных откликов).
## amplitude — сила 0.0..1.0 (учитывается на Android; на iOS система задаёт
##             отклик сама, поэтому длинные рисунки там «склеиваются»).
##
## Длительности короткие намеренно: тап — «щелчок» (~10 мс), награда — серия.
## Лестница силы: LIGHT < MEDIUM < HEAVY.

const LIGHT := 0.35
const MEDIUM := 0.6
const HEAVY := 0.9

const PROFILES := {
	# --- Тапы и UI ---
	"button": {"pattern": [12], "amplitude": LIGHT},
	"button_alt": {"pattern": [16], "amplitude": 0.45},
	"tap": {"pattern": [10], "amplitude": LIGHT},
	"generator_tap": {"pattern": [14], "amplitude": 0.4},
	# --- Ядро: слияния ---
	"merge": {"pattern": [20], "amplitude": MEDIUM},
	"merge_high": {"pattern": [32], "amplitude": HEAVY},
	"merge_fail": {"pattern": [18, 60, 18], "amplitude": MEDIUM},
	"error": {"pattern": [20, 60, 20], "amplitude": MEDIUM},
	"out_of_energy": {"pattern": [14, 50, 14, 50, 14], "amplitude": 0.5},
	# --- Награды ---
	"coins": {"pattern": [14], "amplitude": LIGHT},
	"gem": {"pattern": [12, 40, 12], "amplitude": 0.5},
	"order_done": {"pattern": [18, 45, 26], "amplitude": MEDIUM},
	"level_up": {"pattern": [35, 60, 35], "amplitude": HEAVY},
	"chest": {"pattern": [40, 70, 40, 70, 90], "amplitude": 1.0},
	"cat_unlock": {"pattern": [26, 50, 40], "amplitude": HEAVY},
	"daily": {"pattern": [20, 55, 30], "amplitude": 0.65},
	"purchase": {"pattern": [30, 60, 70], "amplitude": HEAVY},
	# --- Реклама ---
	"rewarded_start": {"pattern": [14], "amplitude": LIGHT},
	"rewarded_done": {"pattern": [20, 50, 30], "amplitude": 0.65},
	# --- Зарезервировано (GDD §15): вызовов в game.gd пока нет ---
	"order": {"pattern": [14], "amplitude": LIGHT},
	"xp": {"pattern": [12], "amplitude": LIGHT},
}


## Профиль по имени; пустой словарь — такого события нет. Копия, чтобы вызывающий
## код не мог испортить таблицу. В копию добавляется поле "id" (для троттлинга).
static func profile(event_id: String) -> Dictionary:
	if not PROFILES.has(event_id):
		return {}
	var result: Dictionary = (PROFILES[event_id] as Dictionary).duplicate()
	result["id"] = event_id
	return result


static func ids() -> Array:
	return PROFILES.keys()


## Все имена событий, которые зовёт игра (для документации и селфтеста).
static func used_ids() -> Array:
	return [
		"button", "button_alt", "tap", "generator_tap",
		"merge", "merge_high", "merge_fail", "error", "out_of_energy",
		"coins", "gem", "order_done", "level_up", "chest", "cat_unlock",
		"daily", "purchase", "rewarded_start", "rewarded_done",
	]

extends RefCounted

## Самопроверка ядра при старте (только debug-сборки, только по запросу).
##
## Включение — любое из двух (оба работают лишь в debug-сборке, в релизе
## самопроверки и файлового лога нет вовсе):
##   • настройка проекта `dev/selftest/enabled = true` (project.godot или
##     project_manage settings_set через MCP) — для запуска из редактора;
##   • аргумент командной строки после `--`: `godot -- --selftest` (CI, headless).
## По умолчанию выключено.
##
## Тесты трогают настоящее состояние: Progress.level/xp, монеты/гемы, поле и
## заказы. Перед прогоном снимаем полный слепок SaveManager.data + поля и
## заказов, на время прогона запрещаем запись сейва, а в конце возвращаем всё
## безусловно — даже если какая-то проверка упала с ошибкой скрипта (проверки
## вызываются отдельной функцией: ошибка обрывает её, но не откат).
##
## Берём через preload (без class_name) — см. комментарий у ORDER_MANAGER в game.gd.

const SETTING := "dev/selftest/enabled"
const CMDLINE_FLAG := "--selftest"
## Результат пишется ещё и в файл: stdout при headless-запуске через MCP
## перехватывается не всегда.
const LOG_PATH := "user://selftest_result.txt"

const META_DATA := preload("res://scripts/data/meta.gd")
const ISO := preload("res://scripts/data/iso.gd")
const COIN_ICON := preload("res://assets/ui/theme/icon_coin.png")
const GEM_ICON := preload("res://assets/ui/theme/icon_gem.png")
const ENERGY_ICON := preload("res://assets/ui/theme/icon_energy.png")

## Проверка арта интерфейса: вариации темы, на которых держатся попапы и кнопки.
## Арт темы собирает tools/build_ui_theme.gd (docs/ui-icons.md).
const THEME_ART_VARIATIONS := {
	"PrimaryButton": ["Button", "normal"],
	"SecondaryButton": ["Button", "normal"],
	"DangerButton": ["Button", "normal"],
	"PopupFrame": ["PanelContainer", "panel"],
	"ListCard": ["PanelContainer", "panel"],
}

## Файл лога держим открытым всю сессию, а не открываем на каждую строку.
static var _log_file: FileAccess


## Самопроверка (и файловый лог) включена: debug-сборка + настройка/флаг.
static func enabled() -> bool:
	if not OS.is_debug_build():
		return false
	if bool(ProjectSettings.get_setting(SETTING, false)):
		return true
	return OS.get_cmdline_user_args().has(CMDLINE_FLAG)


## Начать файл лога заново (только если самопроверка включена).
static func reset_log() -> void:
	_log_file = null
	if not enabled():
		return
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log_file != null:
		_log_file.store_line("run at %s" % Time.get_datetime_string_from_system())
		_log_file.flush()


## Шаг запуска: в stdout всегда, в файл — только при включённой самопроверке.
static func log_step(text: String) -> void:
	print(text)
	if _log_file != null:
		_log_file.store_line(text)
		_log_file.flush()


## Прогон: спавн → слияние → сериализация → загрузка, затем заказы, прогресс,
## бустеры, награды, мета, иконки, изометрия. Печатает "[selftest] <имя>: OK".
## Возвращает true, если всё прошло. Состояние восстанавливается всегда.
static func run(board: Board, orders) -> bool:
	var save_before: Dictionary = SaveManager.snapshot()
	var board_before: Array = board.serialize()
	var orders_before: Array = orders.orders().duplicate(true) if orders != null else []
	SaveManager.suspend(true)

	var result = _run_checks(board, orders)

	# Откат — безусловно и в обратном порядке: поле и заказы, затем сейв
	# целиком (монеты, гемы, XP, уровень, мета…) и автолоады, что его кешируют.
	board.clear()
	board.load_from(board_before)
	if orders != null:
		orders.load_orders(orders_before)
	SaveManager.restore_snapshot(save_before)
	SaveManager.suspend(false)
	return result == true


static func _run_checks(board: Board, orders) -> bool:
	var ok := _test_board(board)
	if not ok:
		log_step("[selftest] board FAILED")
		push_error("[selftest] board FAILED")
		return false
	var results := {
		"orders": _test_orders(board, orders) > 0,
		"progress": _test_progress(),
		"boosters": _test_boosters(board),
		"rewards": _test_rewards(orders),
		"meta": _test_meta(),
		"icons": _test_icons(),
		"iso": _test_iso(),
	}
	for test_name: String in results:
		var passed: bool = results[test_name] == true
		log_step("[selftest] %s: %s" % [test_name, "OK" if passed else "FAILED"])
		ok = passed and ok
	log_step("[selftest] board: OK")
	return ok


## Ядро поля: спавн, слияние, запрет слияния с собой, сериализация ↔ загрузка.
static func _test_board(board: Board) -> bool:
	var ok := true
	board.clear()
	ok = board.spawn(Chains.COFFEE, 1) and ok
	ok = board.spawn(Chains.COFFEE, 1) and ok

	var first := -1
	var second := -1
	for i in board.cells.size():
		if board.has_item(i):
			if first < 0:
				first = i
			else:
				second = i

	ok = first >= 0 and second >= 0 and ok
	ok = board.can_merge(first, second) and ok
	ok = board.merge(first, second) and ok
	ok = board.item_at(first) == null and ok
	ok = board.item_at(second) != null and board.item_at(second).data.level == 2 and ok
	ok = not board.can_merge(second, second) and ok
	ok = not board.merge(second, second) and ok

	var snapshot := board.serialize()
	board.clear()
	ok = board.cells.size() == board.columns * board.rows and ok
	board.load_from(snapshot)
	ok = board.item_at(second) != null and board.item_at(second).data.level == 2 and ok
	board.clear()
	return ok


## Проверка таблиц меты (docs/GDD.md §8): 12 котов, 7 дней стрика, декор, бонус котов.
static func _test_meta() -> bool:
	if META_DATA.CATS.size() != 12:
		push_error("[selftest] meta: котов %d, ожидалось 12" % META_DATA.CATS.size())
		return false
	if META_DATA.DAILY_REWARDS.size() != 7 or not META_DATA.DAILY_REWARDS[6].has("chest"):
		push_error("[selftest] meta: таблица ежедневных наград не совпадает с 7-дневным стриком")
		return false
	if META_DATA.chest_cats().is_empty() or META_DATA.DECOR.size() < 5:
		push_error("[selftest] meta: пустой список котов из сундука или мало декора")
		return false
	if Meta.cat_bonus() < 1.0 or Meta.cat_bonus_percent() < 0:
		push_error("[selftest] meta: бонус котов меньше 1.0")
		return false
	if Meta.can_claim() and Meta.next_day() < 1:
		push_error("[selftest] meta: неверный номер следующего дня")
		return false
	if Meta.unplaced_decor().size() > Meta.decor_count():
		push_error("[selftest] meta: непоставленных предметов больше, чем куплено")
		return false
	# Свободная расстановка: каждый предмет влезает хотя бы в свою комнату.
	for item in META_DATA.DECOR:
		var home: Dictionary = META_DATA.room(String(item.get("room", "")))
		var size: Vector2i = META_DATA.rotated_size(item, 0)
		if home.is_empty() or META_DATA.area_room(Vector2i(int(home["tx"]), int(home["ty"])), size) != home:
			push_error("[selftest] meta: предмет %s не влезает в свою комнату" % String(item.get("id", "")))
			return false
		if int(item.get("w", 1)) != int(item.get("h", 1)):
			var swapped: Vector2i = META_DATA.rotated_size(item, 1)
			if swapped != Vector2i(int(item.get("h", 1)), int(item.get("w", 1))):
				push_error("[selftest] meta: поворот не меняет габарит у %s" % String(item.get("id", "")))
				return false
	# Через стену между комнатами и за план ставить нельзя.
	if not META_DATA.area_room(Vector2i(6, 0), Vector2i(2, 1)).is_empty():
		push_error("[selftest] meta: предмет встал на стык Кухни и Террасы")
		return false
	if not META_DATA.area_room(Vector2i(-1, 3), Vector2i(1, 1)).is_empty():
		push_error("[selftest] meta: предмет встал за пределами плана")
		return false
	for key: String in META_DATA.LEGACY_SLOT_TILES:
		if META_DATA.room_at(META_DATA.LEGACY_SLOT_TILES[key]).is_empty():
			push_error("[selftest] meta: старый слот %s вне комнат — сейв не перенесётся" % key)
			return false
	if Meta.decor_at(Vector2i(-5, -5)) != "" or bool(Meta.can_place("нет-такого", Vector2i(1, 1)).get("ok", false)):
		push_error("[selftest] meta: пустое место занято или неизвестный предмет поставился")
		return false
	# Пересечение: на место стоящего предмета другой не встанет.
	for key in Meta.placed:
		var area: Rect2i = Meta.decor_area(String(key))
		var other := "chair" if String(key) != "chair" else "armchair"
		if Meta.decor_at(area.position) != String(key) \
				or bool(Meta.can_place(other, area.position).get("ok", false)):
			push_error("[selftest] meta: место предмета %s не считается занятым" % String(key))
			return false
		break
	return true


## Проверка изометрии (scripts/data/iso.gd): тайл ↔ экран без потерь, ромб.
static func _test_iso() -> bool:
	var point: Vector2 = ISO.tile_to_screen(3.0, 5.0)
	var back: Vector2 = ISO.screen_to_tile(point)
	if back.distance_to(Vector2(3.0, 5.0)) > 0.001:
		push_error("[selftest] iso: tile_to_screen ↔ screen_to_tile не сходятся: %s" % str(back))
		return false

	var center_1: Vector2 = ISO.tile_center(2.0, 4.0, 1.0, 1.0)
	if center_1.distance_to(ISO.tile_to_screen(2.5, 4.5)) > 0.001:
		push_error("[selftest] iso: tile_center 1×1 не совпадает с центром тайла")
		return false

	var center_2: Vector2 = ISO.tile_center(2.0, 4.0, 2.0, 1.0)
	var expected_2: Vector2 = ISO.tile_to_screen(3.0, 4.5)
	if not is_equal_approx(center_2.x, expected_2.x) or not is_equal_approx(center_2.y, expected_2.y):
		push_error("[selftest] iso: tile_center 2×1 посчитан неверно: %s" % str(center_2))
		return false

	var diamond: PackedVector2Array = ISO.diamond(0.0, 0.0, 1.0, 1.0)
	if diamond.size() != 4:
		push_error("[selftest] iso: diamond вернул %d точек вместо 4" % diamond.size())
		return false
	var sum := Vector2.ZERO
	for corner in diamond:
		sum += corner
	if sum.distance_to(Vector2.ZERO) > 0.001:
		push_error("[selftest] iso: diamond не центрирован: %s" % str(sum))
		return false

	var sofa: Dictionary = META_DATA.decor("sofa")
	if META_DATA.rotated_size(sofa, 0) != Vector2i(2, 1) or META_DATA.rotated_size(sofa, 1) != Vector2i(1, 2):
		push_error("[selftest] iso: поворот дивана 2×1 посчитан неверно")
		return false
	return true


## Тема проекта загружена, вариации на месте, их 9-slice текстуры разобрались.
static func _test_icons() -> bool:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		push_error("[selftest] icons: тема проекта не загружена")
		return false
	for variation: String in THEME_ART_VARIATIONS:
		var spec: Array = THEME_ART_VARIATIONS[variation]
		if theme.get_type_variation_base(variation) != StringName(spec[0]):
			push_error("[selftest] icons: в теме нет вариации %s" % variation)
			return false
		var box := theme.get_stylebox(StringName(spec[1]), variation) as StyleBoxTexture
		if box == null or box.texture == null or box.texture.get_width() <= 0:
			push_error("[selftest] icons: у %s нет арта" % variation)
			return false
	for icon: Texture2D in [COIN_ICON, GEM_ICON, ENERGY_ICON]:
		if icon == null or icon.get_width() <= 0:
			push_error("[selftest] icons: не загрузилась иконка ресурса")
			return false
	return true


## Проверка прогресса: порог XP растёт с уровнем, на пороге уровень берётся.
## Уровень/XP вернёт общий откат (SaveManager.restore_snapshot → Progress).
static func _test_progress() -> bool:
	var previous := 0
	for lvl in range(1, 11):
		var need := Progress.xp_next(lvl)
		if need <= previous:
			push_error("[selftest] progress: порог XP не растёт на уровне %d" % lvl)
			return false
		previous = need

	Progress.level = 1
	Progress.xp = 0
	var taken := Progress.add_xp(Progress.xp_next())
	if not (taken >= 1 and Progress.level == 2):
		push_error("[selftest] progress: уровень не поднялся на пороге")
		return false
	return true


## Проверка заказов и продажи: ставит предметы под требования и «сдаёт» их.
static func _test_orders(board: Board, orders) -> int:
	board.clear()
	var index := 0
	var order: Dictionary = orders.order_at(index)
	if order.is_empty():
		push_error("[selftest] orders: пустой заказ")
		return 0

	var entries: Array = []
	var cell := 0
	for req in order.get("items", []):
		entries.append({
			"cell": cell,
			"chain": String(req.get("chain", "")),
			"level": int(req.get("level", 1)),
		})
		cell += 1
	board.load_from(entries)

	var before := Wallet.coins()
	var result: Dictionary = orders.try_deliver(index, board)
	if not bool(result.get("ok", false)):
		push_error("[selftest] orders: отказ — " + String(result.get("reason", "")))
		return 0
	Wallet.add_coins(int(result.get("coins", 0)))
	var gained := Wallet.coins() - before
	if gained <= 0:
		push_error("[selftest] orders: монеты не начислены")
		return 0

	# продажа идёт тем же путём, что drag мимо поля (board.sell_at → item_sold → game.gd)
	board.clear()
	board.load_from([{"cell": 0, "chain": String(Chains.COFFEE), "level": 1}])
	var before_sell := Wallet.coins()
	if not board.sell_at(0) or Wallet.coins() <= before_sell:
		push_error("[selftest] sell: монеты не начислены")
		return 0
	return gained


## Проверка бустеров: шафл не теряет предметы, хаммер убирает один,
## магнит ставит 3, гемы списываются.
static func _test_boosters(board: Board) -> bool:
	board.clear()
	board.load_from([
		{"cell": 0, "chain": String(Chains.COFFEE), "level": 1},
		{"cell": 1, "chain": String(Chains.COFFEE), "level": 2},
		{"cell": 2, "chain": String(Chains.PASTRY), "level": 1},
	])
	var before := board.serialize().size()
	if not board.shuffle() or board.serialize().size() != before:
		push_error("[selftest] boosters: шафл сломал поле")
		return false

	board.remove_at_cell(1)
	if board.serialize().size() != before - 1:
		push_error("[selftest] boosters: хаммер не убрал предмет")
		return false

	var gems_before := Wallet.gems()
	Wallet.add_gems(50)
	if not (Wallet.spend_gems(5) and Wallet.gems() == gems_before + 45):
		push_error("[selftest] boosters: гемы не списались")
		return false
	if Wallet.spend_gems(Wallet.gems() + 1):
		push_error("[selftest] boosters: гемы списались в минус")
		return false

	var chain := _first_unlocked_chain()
	var placed := 0
	for i in 3:
		if board.spawn(chain, 1):
			placed += 1
	if placed != 3:
		push_error("[selftest] boosters: магнит поставил %d из 3" % placed)
		return false

	board.clear()
	return true


## Проверка наград заказа: свежий заказ даёт бонус за скорость,
## монеты/XP считаются из базы, реролл заменяет заказ.
static func _test_rewards(orders) -> bool:
	var order: Dictionary = orders.make_order()
	var reward: Dictionary = orders.reward_for(order)
	if float(reward.get("bonus", 1.0)) <= 1.0:
		push_error("[selftest] rewards: свежий заказ без бонуса за скорость")
		return false
	if int(reward.get("seconds_left", 0)) <= 0:
		push_error("[selftest] rewards: не посчитан таймер бонуса")
		return false
	var base: int = orders.compute_coins(order)
	if int(reward.get("coins", 0)) != int(round(float(base) * float(reward.get("bonus", 1.0)))):
		push_error("[selftest] rewards: монеты не совпали с бонусом")
		return false
	if int(reward.get("xp", 0)) <= 0:
		push_error("[selftest] rewards: XP не начислен")
		return false

	if not orders.replace(0):
		push_error("[selftest] rewards: реролл не сработал")
		return false
	var after: Dictionary = orders.order_at(0)
	if after.is_empty():
		push_error("[selftest] rewards: реролл оставил пустой слот")
		return false
	return true


static func _first_unlocked_chain() -> StringName:
	for chain in Chains.all_chains():
		if Progress.is_generator_unlocked(chain):
			return chain
	return Chains.COFFEE

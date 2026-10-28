extends Node

## Кошелёк: монеты и гемы (docs/economy.md). Автолоад: Wallet.
##
## Источник правды — SaveManager, ключи `coins` и `gems` (как и раньше, сейвы
## совместимы); здесь только API и сигналы. HUD подписан на сигналы, вручную
## его после начисления обновлять не нужно. Запись на диск — отложенная запись
## SaveManager (set_value сам заводит таймер).

signal coins_changed(value: int)
signal gems_changed(value: int)


func _ready() -> void:
	## Загрузку зовём явно: порядок автолоадов не должен влиять на результат.
	SaveManager.ensure_loaded()
	SaveManager.reset_done.connect(_restore)
	_restore()


## Старт и замена сейва целиком (сброс прогресса, откат самопроверки).
func _restore() -> void:
	_ensure_start_gems()
	coins_changed.emit(coins())
	gems_changed.emit(gems())


# --- Монеты --------------------------------------------------------------------

func coins() -> int:
	return int(SaveManager.get_value("coins", 0))


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	SaveManager.set_value("coins", coins() + amount)
	coins_changed.emit(coins())


## Списать монеты, если хватает. Возвращает false и ничего не меняет иначе.
func spend_coins(cost: int) -> bool:
	if cost <= 0:
		return true
	if coins() < cost:
		return false
	SaveManager.set_value("coins", coins() - cost)
	coins_changed.emit(coins())
	return true


# --- Гемы ------------------------------------------------------------------------

func gems() -> int:
	return int(SaveManager.get_value("gems", 0))


func add_gems(amount: int) -> void:
	if amount == 0:
		return
	SaveManager.set_value("gems", gems() + amount)
	gems_changed.emit(gems())


## Списать гемы, если хватает. Возвращает false и ничего не меняет иначе.
func spend_gems(cost: int) -> bool:
	if cost <= 0:
		return true
	if gems() < cost:
		return false
	SaveManager.set_value("gems", gems() - cost)
	gems_changed.emit(gems())
	return true


## dev-грант: стартовые гемы (Config.start_gems) выдаём только если ключа ещё
## нет в сохранении — новый игрок или сброс прогресса.
func _ensure_start_gems() -> void:
	if SaveManager.get_value("gems") != null:
		return
	var value = Config.get_value("start_gems")
	var start := int(value) if value != null else 0
	if start > 0:
		# Напрямую в data, без таймера записи: это не действие игрока.
		SaveManager.data["gems"] = start

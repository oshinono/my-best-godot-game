extends "res://scripts/ui/popup_base.gd"

## Экран «энергия закончилась» (docs/GDD.md §6, §9): таймер до следующей
## единицы + rewarded-кнопка (лимит в сутки — из Config) + закрыть.
##
## Вёрстка — сцена scenes/ui/energy_popup.tscn (контейнеры + Theme), скрипт
## только заполняет данные. Рекламу дёргает не этот экран, а game.gd:
## он слушает signal rewarded_requested и зовёт Ads.show_rewarded.

signal rewarded_requested

@onready var _timer_label: Label = %Timer
@onready var _hint: Label = %Hint
@onready var _reward_button: Button = %Reward


func _ready() -> void:
	super()
	_reward_button.pressed.connect(func() -> void: rewarded_requested.emit())
	(%Close as Button).pressed.connect(close)
	(%Ticker as Timer).timeout.connect(_refresh)
	_refresh()


func open() -> void:
	super()
	_refresh()


## Текст/доступность кнопки рекламы задаёт game.gd (кэп на сутки — из Config).
func set_reward_state(available: bool, text: String, hint: String) -> void:
	if not is_node_ready():
		await ready
	_reward_button.disabled = not available
	_reward_button.text = text
	_hint.text = hint
	_hint.visible = not hint.is_empty()


func _refresh() -> void:
	if not is_node_ready():
		return
	if Energy.is_full():
		_timer_label.text = "Энергия полная: %d/%d" % [Energy.current(), Energy.maximum]
		return
	var seconds := maxi(0, Energy.seconds_to_next())
	_timer_label.text = "%d/%d · до +%d через %d:%02d" % [
		Energy.current(), Energy.maximum,
		int(Config.get_value("energy_regen_amount")),
		floori(seconds / 60.0), seconds % 60,
	]

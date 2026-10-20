extends "res://scripts/ui/popup_base.gd"

## Настройки прототипа (docs/GDD.md §20, §21): «продать всё поле» для тестов
## тупиков, «сбросить прогресс» (чистый save для плейтеста), бустеры
## (docs/GDD.md §18) и вибрация. Логику делают обработчики в game.gd.
##
## Вёрстка — сцена scenes/ui/settings_popup.tscn (контейнеры + Theme):
## панель по высоте контента, длинный список прокручивается в %Scroll.

signal sell_all_requested
signal reset_requested
## Бустер: "hammer" | "shuffle" | "magnet".
signal booster_requested(kind: String)
## Техспайк фазы 0 (docs/technspike.md): проверка рекламы, консента и покупок
## на живом устройстве. action: "rewarded" | "interstitial" | "consent" |
## "purchase" | "restore".
signal technospike_action(action: String)

## kind → кнопка, состояние обновляет game.gd через refresh_boosters().
@onready var _booster_buttons := {
	"hammer": %Hammer as Button,
	"shuffle": %Shuffle as Button,
	"magnet": %Magnet as Button,
}
var _pending_boosters: Dictionary = {}


func _ready() -> void:
	super()
	var tech := {
		%Rewarded: "rewarded", %Interstitial: "interstitial", %Consent: "consent",
		%Purchase: "purchase", %Restore: "restore",
	}
	for button: Button in tech:
		var action: String = tech[button]
		button.pressed.connect(func() -> void: technospike_action.emit(action))

	for kind: String in _booster_buttons:
		(_booster_buttons[kind] as Button).pressed.connect(
			func() -> void: booster_requested.emit(kind))

	# Звука в прототипе нет: вся обратная связь — тактильная (docs/haptics.md).
	var vibration := %Vibration as Button
	vibration.button_pressed = Haptics.enabled
	vibration.text = _toggle_text("Вибрация", Haptics.enabled)
	vibration.toggled.connect(func(pressed: bool) -> void:
		Haptics.set_enabled(pressed)
		vibration.text = _toggle_text("Вибрация", pressed)
	)

	(%SellAll as Button).pressed.connect(func() -> void: sell_all_requested.emit())
	(%Reset as Button).pressed.connect(func() -> void: reset_requested.emit())
	(%Close as Button).pressed.connect(close)
	if not _pending_boosters.is_empty():
		refresh_boosters(_pending_boosters)


## Состояние бустеров задаёт game.gd: цена, лимит сессии, хватает ли гемов.
## info: kind → {text: String, enabled: bool}
func refresh_boosters(info: Dictionary) -> void:
	if not is_node_ready():
		_pending_boosters = info
		return
	for kind: String in _booster_buttons:
		var button := _booster_buttons[kind] as Button
		var data: Dictionary = info.get(kind, {})
		button.text = String(data.get("text", kind))
		button.disabled = not bool(data.get("enabled", true))


func _toggle_text(label_text: String, value: bool) -> String:
	return "%s: %s" % [label_text, "Вкл" if value else "Выкл"]

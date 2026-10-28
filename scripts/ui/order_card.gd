extends AspectRatioContainer

## Карточка заказа (scenes/ui/order_card.tscn): арт order_card во всю ширину
## колонки в своих пропорциях, в слотах — иконки нужных предметов, справа —
## награда и таймер бонуса; на углу — значок смены заказа за гемы.

signal order_pressed
signal reroll_pressed

const ART := preload("res://scripts/data/art.gd")

@onready var _items: Array[TextureRect] = [%Item1, %Item2]


func _ready() -> void:
	(%Card as BaseButton).pressed.connect(func() -> void: order_pressed.emit())
	(%Reroll as BaseButton).pressed.connect(func() -> void: reroll_pressed.emit())


## Предмета для заказа ещё нет на поле — иконка приглушена: готовые к сдаче
## заказы видно с первого взгляда.
const MISSING_TINT := Color(0.55, 0.5, 0.45, 0.55)


## order — словарь OrderManager; reward/seconds_left — посчитаны в game.gd;
## have — есть ли на поле каждый предмет заказа (пусто — считаем, что есть).
func show_order(order: Dictionary, reward_coins: int, seconds_left: int,
		have: Array = []) -> void:
	var reqs: Array = order.get("items", [])
	for i in _items.size():
		var rect := _items[i]
		if i < reqs.size():
			var req: Dictionary = reqs[i]
			rect.texture = ART.item_texture(StringName(String(req.get("chain", ""))),
				int(req.get("level", 1)))
			var ready: bool = i >= have.size() or bool(have[i])
			rect.modulate = Color.WHITE if ready else MISSING_TINT
		else:
			rect.texture = null
	var reward := "%d" % reward_coins
	if seconds_left > 0:
		reward += "\n%d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]
	(%Reward as Label).text = reward


func set_reroll(cost: int, affordable: bool) -> void:
	var reroll := %Reroll as Button
	reroll.text = "%d" % cost
	reroll.disabled = not affordable


## Заказ пока не сдать: карточка коротко встряхивается.
func shake() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	for angle in [0.06, -0.05, 0.035, -0.02, 0.0]:
		tween.tween_property(self, "rotation", angle, 0.05)

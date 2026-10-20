extends HBoxContainer

## Карточка заказа (scenes/ui/order_card.tscn): арт order_card в своих
## пропорциях (AspectRatioContainer), в его слотах — иконки нужных предметов,
## справа — награда и таймер бонуса; рядом кнопка смены заказа за гемы.

signal order_pressed
signal reroll_pressed

const ART := preload("res://scripts/data/art.gd")

@onready var _items: Array[TextureRect] = [%Item1, %Item2]


func _ready() -> void:
	(%Card as BaseButton).pressed.connect(func() -> void: order_pressed.emit())
	(%Reroll as BaseButton).pressed.connect(func() -> void: reroll_pressed.emit())


## order — словарь OrderManager; reward/seconds_left — посчитаны в game.gd.
func show_order(order: Dictionary, reward_coins: int, seconds_left: int) -> void:
	var reqs: Array = order.get("items", [])
	for i in _items.size():
		var rect := _items[i]
		if i < reqs.size():
			var req: Dictionary = reqs[i]
			rect.texture = ART.item_texture(StringName(String(req.get("chain", ""))),
				int(req.get("level", 1)))
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

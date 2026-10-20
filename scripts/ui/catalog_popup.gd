extends "res://scripts/ui/popup_base.gd"

## Каталог мебели (GDD §8.1): покупка живёт только внутри изо-кофейни.
## Вёрстка — scenes/ui/catalog_popup.tscn, строка товара — компонент
## scenes/ui/catalog_row.tscn. Покупку проводит game.gd (сигнал наружу).

signal buy_requested(decor_id: String)

const DATA := preload("res://scripts/data/meta.gd")
const ROW := preload("res://scenes/ui/catalog_row.tscn")

@onready var _list: VBoxContainer = %List
@onready var _coins: Label = %Coins
var _coins_value := -1


func _ready() -> void:
	super()
	(%Close as Button).pressed.connect(close)


func open() -> void:
	rebuild()
	super()


## Пересобрать список (после покупки — статус «Куплено»).
func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_refresh_coins(true)
	for item in DATA.DECOR:
		var row := ROW.instantiate()
		_list.add_child(row)
		row.setup(item, Meta.owns_decor(String(item.get("id", ""))))
		row.buy_pressed.connect(func(decor_id: String) -> void: buy_requested.emit(decor_id))


## Баланс мог поменяться, пока окно открыто: обновляем на лету.
func _process(_delta: float) -> void:
	if visible:
		_refresh_coins()


func _refresh_coins(force := false) -> void:
	var coins := int(SaveManager.get_value("coins", 0))
	if not force and coins == _coins_value:
		return
	_coins_value = coins
	_coins.text = "%d" % coins

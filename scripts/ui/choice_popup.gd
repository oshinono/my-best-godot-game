extends "res://scripts/ui/popup_base.gd"

signal barista_selected(id: String)
const DATA := preload("res://scripts/data/meta.gd")
const ART := preload("res://scripts/data/art.gd")
const ICONS := {
	"coins": preload("res://assets/ui/theme/icon_coin_main.png"),
	"gems": preload("res://assets/ui/theme/icon_gem_main.png"),
}
var _pending := ""
var _currency := ""

func _ready() -> void:
	super()
	%Close.pressed.connect(close)
	Iap.purchase_failed.connect(_purchase_done)
	Iap.purchase_succeeded.connect(_purchase_done)

func _reset(title: String, hint: String) -> void:
	%Title.text = title
	%Hint.text = hint
	for child in %List.get_children():
		%List.remove_child(child)
		child.queue_free()

func _card(caption: String, icon: Texture2D, active: bool = false) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"PrimaryButton" if active else &"SecondaryButton"
	button.custom_minimum_size.y = 92
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 72)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = caption
	%List.add_child(button)
	return button

func open_baristas(active: String, cats: Array) -> void:
	_currency = ""
	_reset("Выбрать бариста", "")
	%Hint.hide()
	for entry in cats:
		var id := String(entry)
		var name_text := tr(String(DATA.cat(id).get("name", id)))
		var perk := tr(DATA.perk_text(DATA.barista_perk(id)))
		var selected := id == active
		var button := _card(("✓ " if selected else "") + name_text + "\n" + perk, ART.cat_texture(id), selected)
		button.pressed.connect(func() -> void:
			barista_selected.emit(id)
			close())
	open()

func open_shop(kind: String) -> void:
	if not ICONS.has(kind):
		return
	_currency = kind
	var available := Iap.store_available()
	_reset("Магазин валюты", "Цена и оплата — в магазине устройства." if available else "Покупки на этом устройстве недоступны.")
	%Hint.show()
	var products := String(Config.get_value("iap_products")).split(",", false)
	var grants: Dictionary = Config.get_value("iap_grants")
	for product in products:
		var sku := product.strip_edges()
		var grant: Dictionary = grants.get(sku, {})
		var amount := int(grant.get(kind, 0))
		if amount <= 0 or grant.get("once", false):
			continue
		var caption := tr("+%d монет" if kind == "coins" else "+%d гемов") % amount
		var button := _card(caption, ICONS[kind], true)
		button.disabled = not available or not _pending.is_empty()
		button.pressed.connect(_buy.bind(sku))
	open()

func _buy(sku: String) -> void:
	if not _pending.is_empty() or not Iap.store_available():
		return
	_pending = sku
	for button: Button in %List.get_children():
		button.disabled = true
	Iap.purchase(sku)

func _purchase_done(sku: String, _result: Variant) -> void:
	if not _pending.is_empty() and sku in [_pending, ""]:
		_pending = ""
		if visible and not _currency.is_empty():
			open_shop(_currency)

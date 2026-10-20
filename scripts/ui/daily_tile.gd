extends VBoxContainer

## Плитка дня ежедневной награды (scenes/ui/daily_tile.tscn): подпись дня,
## карточка арта — иконка награды в окне, значение на жёлтой плашке.
## Пройденные дни приглушены, текущий подписан акцентом.

const COLOR_ACCENT := Color("C05621")


func setup(reward: Dictionary, number: int, today: int) -> void:
	var caption := %Caption as Label
	caption.text = "Сегодня" if number == today else "День %d" % number
	if number == today:
		caption.add_theme_color_override("font_color", COLOR_ACCENT)
	if number < today:
		(%Card as Control).modulate = Color(1, 1, 1, 0.55)

	var info := _reward_info(reward)
	var icon := %Icon as TextureRect
	icon.texture = Icons.texture(String(info["icon"]), 96.0)
	# Сундук без PNG: вместо иконки — «?» (сюрприз).
	(%Glyph as Label).visible = icon.texture == null
	(%Value as Label).text = String(info["text"])


## Награда → id иконки (docs/ui-icons.md) и подпись.
static func _reward_info(reward: Dictionary) -> Dictionary:
	if reward.has("chest"):
		return {"icon": "chest", "text": "Сундук"}
	if reward.has("coins"):
		return {"icon": "coin", "text": str(int(reward.get("coins", 0)))}
	if reward.has("gems"):
		return {"icon": "gem", "text": str(int(reward.get("gems", 0)))}
	if reward.has("energy"):
		return {"icon": "energy", "text": str(int(reward.get("energy", 0)))}
	return {"icon": "", "text": ""}

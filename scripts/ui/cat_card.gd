extends PanelContainer

## Карточка кота (scenes/ui/cat_card.tscn) на арте popup_list_card: слот слева
## под портрет (портретов пока нет — первая буква имени, у закрытых «?»),
## справа имя, редкость и история. Высота растёт за текстом (9-slice).

const DATA := preload("res://scripts/data/meta.gd")
const COLOR_TEXT := Color("4A3A2E")
const COLOR_MUTED := Color("8A7566")


func setup(cat: Dictionary, unlocked: bool) -> void:
	var cat_name := String(cat.get("name", ""))
	var rarity := String(cat.get("rarity", "common"))
	(%Letter as Label).text = cat_name.left(1) if unlocked else "?"
	var name_label := %Name as Label
	name_label.text = "%s · %s" % [cat_name, String(cat.get("role", ""))]
	name_label.add_theme_color_override("font_color", COLOR_TEXT if unlocked else COLOR_MUTED)
	(%Stars as Label).text = "★".repeat(DATA.rarity_stars(rarity))
	(%Status as Label).text = "%s · %s" % [
		DATA.rarity_name(rarity), "В кафе" if unlocked else Meta.cat_status(cat),
	]
	var story := %Story as Label
	story.text = String(cat.get("story", ""))
	story.visible = not story.text.is_empty()

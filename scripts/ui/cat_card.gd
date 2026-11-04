extends PanelContainer

## Карточка кота (scenes/ui/cat_card.tscn) на арте popup_list_card: слот слева
## под портрет (у закрытых «?»),
## справа имя, редкость и история. Высота растёт за текстом (9-slice).

const DATA := preload("res://scripts/data/meta.gd")
const ART := preload("res://scripts/data/art.gd")
const COLOR_TEXT := Color("4A3A2E")
const COLOR_MUTED := Color("8A7566")


func setup(cat: Dictionary, unlocked: bool) -> void:
	# Общую тему не меняем: широкий портрет нужен только карточкам котов.
	var style := get_theme_stylebox("panel").duplicate() as StyleBox
	style.content_margin_left = 116.0
	add_theme_stylebox_override("panel", style)
	var cat_name := String(cat.get("name", ""))
	var rarity := String(cat.get("rarity", "common"))
	# Портрет есть — показываем его; нет (или кот закрыт) — букву/«?» как раньше.
	var portrait := %Portrait as TextureRect
	var art := ART.cat_texture(String(cat.get("id", ""))) if unlocked else null
	portrait.texture = art
	portrait.visible = art != null
	var letter := %Letter as Label
	letter.visible = art == null
	letter.text = cat_name.left(1) if unlocked else "?"
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

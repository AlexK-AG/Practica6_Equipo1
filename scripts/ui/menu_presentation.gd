extends RefCounted

const CYAN := Color("69dfe8")
const AMBER := Color("ffc36a")
const VIOLET := Color("bb9af7")
const GREEN := Color("87d4b5")

static func panel_style(color: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 3
	style.border_color = accent
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func button_style(button: BaseButton, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", panel_style(Color(0.045, 0.09, 0.14), accent.darkened(0.5)))
	button.add_theme_stylebox_override("hover", panel_style(Color(0.1, 0.2, 0.27), accent))
	button.add_theme_stylebox_override("pressed", panel_style(Color(0.13, 0.25, 0.3), accent))
	button.add_theme_stylebox_override("focus", panel_style(Color(0.07, 0.17, 0.23), accent))

## The pages and cards are authored in start.tscn; refresh only profile data.
static func profile_color(node: Label, known: bool, locked_color: Color) -> void:
	if not node.has_meta("authored_color"):
		node.set_meta("authored_color",node.get_theme_color("font_color"))
	node.add_theme_color_override("font_color",node.get_meta("authored_color") if known else locked_color)

static func refresh_index(menu: Control) -> void:
	var page := menu.get_node("Margin/Stack/EnemyPage")
	var grid: GridContainer = page.get_node("Scroll/EnemyCards")
	var catalog = preload("res://scripts/enemies/enemy_catalog.gd")
	var discovered: Array = menu.get_node("/root/Campaign").profile().get("discovered_enemies",[])
	page.get_node("DiscoveryCount").text = "%02d / %02d especies descubiertas · se registran al encontrarlas en una misión" % [discovered.size(),catalog.ENTRIES.size()]
	for index in range(catalog.ENTRIES.size()):
		var card: PanelContainer = grid.get_node("EnemyCard%d" % index)
		var entry: Dictionary = catalog.ENTRIES[index]
		var known: bool = discovered.has(index)
		if not card.has_meta("authored_style"):
			card.set_meta("authored_style",card.get_theme_stylebox("panel").duplicate())
		var style := card.get_meta("authored_style").duplicate() as StyleBoxFlat
		if not known:
			style.bg_color = Color("101722")
			style.border_color = Color("536071")
		card.add_theme_stylebox_override("panel",style)
		card.set_meta("discovered",known)
		card.set_meta("enemy_kind",index)
		var preview: TextureRect = card.get_node("Row/EnemyPreview")
		preview.modulate = Color.WHITE if known else Color(.22,.25,.29)
		var content := card.get_node("Row/Content")
		content.get_node("State").text = "DESCUBIERTO" if known else "NO DESCUBIERTO"
		profile_color(content.get_node("State"),known,AMBER)
		var heading: Label = content.get_node("Title")
		if not heading.has_meta("authored_color"):
			heading.set_meta("authored_color",heading.get_theme_color("font_color"))
		heading.text = entry.name.to_upper() if known else "SEÑAL DESCONOCIDA"
		heading.add_theme_color_override("font_color",heading.get_meta("authored_color") if known else Color("91a0b1"))
		content.get_node("Role").text = entry.role if known else "Encuentra esta amenaza durante una misión para registrar su identidad y su táctica."
		content.get_node("Height").text = catalog.height_text(index)
		content.get_node("Behavior").text = entry.behavior
		content.get_node("Tactic").text = entry.weakness
		for section in ["Height", "DescriptionTitle", "Behavior", "TacticDivider", "TacticTitle", "Tactic"]:
			content.get_node(section).visible = known

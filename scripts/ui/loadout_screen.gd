extends CanvasLayer
signal confirmed
const Weapons = preload("res://scripts/combat/weapon_catalog.gd")
const ACCENTS := {"pistol": Color("6cd9d1"), "rifle": Color("7aaee8"), "shotgun": Color("e9af67"), "precision": Color("9cbb89"), "plasma": Color("c99ae8")}
const ROLES := {"pistol": "Precisa y económica · semiautomática", "rifle": "Versátil · fuego automático", "shotgun": "Control cercano · ocho perdigones", "precision": "Largo alcance · mira con clic derecho", "plasma": "Impacto de área · radio de 3 m"}
var game: Node
var choices: Array[String] = []
var first: OptionButton
var second: OptionButton
var note: Label
var active_slot := 0
var cards: Array[PanelContainer] = []
var previews: Array[TextureRect] = []
var details: Array[Label] = []
var roles: Array[Label] = []
var tiles: Dictionary = {}
var launch: Button

func style(accent: Color, selected: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("10212f") if selected else Color("0b1824")
	box.border_color = accent if selected else accent.darkened(0.55)
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func label(text: String, size: int, parent: Node) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	game = get_parent()
	choices = get_node("/root/Campaign").available_weapons(game.level_number)
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.032, 0.055, 0.98)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.theme = preload("res://assets/ui_theme.tres")
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	shade.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = minf(1020, get_viewport().get_visible_rect().size.x - 64)
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)
	label("ARSENAL / PREPARACIÓN DE MISIÓN", 16, panel).modulate = Color("76c4d1")
	label("NIVEL %02d · CONFIGURA TU EQUIPO" % game.level_number, 26, panel)
	label("Selecciona una ranura y asigna un arma. Cuchillo permanente y tres granadas incluidos.", 16, panel)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 16)
	panel.add_child(slots)
	for slot in range(2):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(card)
		cards.append(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		card.add_child(content)
		var activate := Button.new()
		activate.text = "RANURA %d · %s" % [slot + 1, "PRINCIPAL" if slot == 0 else "SECUNDARIA"]
		activate.pressed.connect(select_slot.bind(slot))
		content.add_child(activate)
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(0, 100)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(preview)
		previews.append(preview)
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 40
		for id in choices:
			selector.add_item(Weapons.DATA[id].title)
		content.add_child(selector)
		if slot == 0:
			first = selector
		else:
			second = selector
		selector.item_selected.connect(changed.bind(slot))
		roles.append(label("", 15, content))
		details.append(label("", 15, content))
	first.select(maxi(0, choices.find(game.player.loadout[0])))
	second.select(maxi(0, choices.find(game.player.loadout[1])))
	if first.selected == second.selected:
		second.select((first.selected + 1) % choices.size())
	label("ARMAS ASEGURADAS · asignar a la ranura activa", 16, panel)
	var grid := GridContainer.new()
	grid.columns = mini(5, choices.size()) if panel.custom_minimum_size.x >= 850 else 3
	grid.add_theme_constant_override("h_separation", 8)
	panel.add_child(grid)
	for id in choices:
		var tile := Button.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(150, 88)
		tile.icon = load("res://assets/previews/weapons/%s.png" % id)
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.add_theme_constant_override("icon_max_width", 120)
		tile.pressed.connect(assign_weapon.bind(id))
		grid.add_child(tile)
		tiles[id] = tile
	note = label("", 15, panel)
	note.modulate = Color("9bb3c6")
	launch = Button.new()
	launch.text = "DESPLEGAR · COMENZAR MISIÓN"
	launch.custom_minimum_size.y = 48
	launch.add_theme_stylebox_override("normal", style(Color("71d5c2"), true))
	launch.pressed.connect(accept)
	panel.add_child(launch)
	describe()
	launch.grab_focus()

func select_slot(slot: int) -> void:
	active_slot = slot
	describe()

func changed(index: int, slot: int) -> void:
	active_slot = slot
	var other := second if slot == 0 else first
	if other.selected == index:
		# Also protect programmatic changes: the last changed slot keeps its choice.
		for replacement in range(choices.size()):
			if replacement != index:
				other.select(replacement)
				break
	describe()

func assign_weapon(id: String) -> void:
	var selector := first if active_slot == 0 else second
	var other := second if active_slot == 0 else first
	var index := choices.find(id)
	if index < 0 or index == other.selected:
		return
	selector.select(index)
	changed(index, active_slot)

func describe() -> void:
	for slot in range(2):
		var selector := first if slot == 0 else second
		var other := second if slot == 0 else first
		for index in range(choices.size()):
			selector.set_item_disabled(index, index == other.selected)
		var id: String = choices[selector.selected]
		var data: Dictionary = Weapons.DATA[id]
		cards[slot].add_theme_stylebox_override("panel", style(ACCENTS[id], slot == active_slot))
		previews[slot].texture = load("res://assets/previews/weapons/%s.png" % id)
		roles[slot].text = ROLES[id]
		roles[slot].modulate = ACCENTS[id]
		details[slot].text = "CARGADOR %d   /   RESERVA %d\nDAÑO %d%s   ·   RECARGA %.1f s" % [game.player.capacity_for(id), int(game.player.inventory[id].reserve), int(data.damage), " × 8" if id == "shotgun" else "", float(data.reload)]
	var other := second if active_slot == 0 else first
	for id in choices:
		var tile: Button = tiles[id]
		var selected := choices[first.selected] == id or choices[second.selected] == id
		tile.text = str(Weapons.DATA[id].title) + (" · 1" if choices[first.selected] == id else (" · 2" if choices[second.selected] == id else ""))
		tile.disabled = choices[other.selected] == id
		tile.add_theme_stylebox_override("normal", style(ACCENTS[id], selected))
		tile.add_theme_stylebox_override("disabled", style(ACCENTS[id], selected))
		tile.add_theme_stylebox_override("hover", style(ACCENTS[id], true))
	note.text = "RANURA %d ACTIVA · El arma de la otra ranura está bloqueada para evitar duplicados." % (active_slot + 1)
	launch.disabled = first.selected == second.selected

func accept() -> void:
	if first.selected == second.selected:
		note.text = "Selecciona dos armas diferentes."
		return
	if not game.player.set_loadout([choices[first.selected], choices[second.selected]]):
		return
	get_node("/root/Campaign").profile()["loadout"] = game.player.loadout.duplicate()
	get_node("/root/Campaign").save_data()
	game.loadout_pending = false
	hide()
	game.set_pause(false)
	confirmed.emit()
	queue_free()

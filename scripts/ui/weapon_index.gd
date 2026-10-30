extends RefCounted
## Arsenal reference uses permanent profile unlocks, never level selection alone.
const Weapons = preload("res://scripts/combat/weapon_catalog.gd")
const UI = preload("res://scripts/ui/menu_presentation.gd")
const IDS := ["pistol", "rifle", "shotgun", "precision", "plasma", "knife"]
const ACCENTS := [Color("69dfe8"), Color("7aaee8"), Color("ffc36a"), Color("87d4b5"), Color("bb9af7"), Color("d9dfe7")]
const ROLES := {
	"pistol": "Precisión y ahorro de munición. Disparo semiautomático.",
	"rifle": "Arma versátil para controlar grupos. Fuego automático.",
	"shotgun": "Ocho perdigones por disparo. Más efectiva de cerca.",
	"precision": "Daño elevado a distancia. Clic derecho para usar la mira.",
	"plasma": "Fuego automático con explosión de área al impactar.",
	"knife": "Respaldo permanente sin munición. Acércate y ataca con el cuchillo."
}

static func refresh(menu: Control) -> void:
	var campaign = menu.get_node("/root/Campaign")
	var page := menu.get_node("Margin/Stack/WeaponPage")
	var grid: GridContainer = page.get_node("Scroll/WeaponCards")
	var available: Array = campaign.available_weapons(1)
	page.get_node("WeaponCount").text = "%d / 5 armas de fuego desbloqueadas · cuchillo permanente" % available.size()
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var known: bool = id == "knife" or available.has(id)
		var card: PanelContainer = grid.get_node("WeaponCard_" + id)
		if not card.has_meta("authored_style"):
			card.set_meta("authored_style",card.get_theme_stylebox("panel").duplicate())
		var style := card.get_meta("authored_style").duplicate() as StyleBoxFlat
		if not known:
			style.bg_color = Color("101722")
			style.border_color = Color("536071")
		card.add_theme_stylebox_override("panel",style)
		card.set_meta("weapon_id",id)
		card.set_meta("unlocked",known)
		card.get_node("Row/WeaponPreview").modulate = Color.WHITE if known else Color(.22,.25,.29)
		var content := card.get_node("Row/Content")
		content.get_node("State").text = "DISPONIBLE" if known else "NO DESBLOQUEADA"
		UI.profile_color(content.get_node("State"),known,UI.AMBER)
		var heading: Label = content.get_node("Title")
		if not heading.has_meta("authored_color"):
			heading.set_meta("authored_color",heading.get_theme_color("font_color"))
		heading.text = "CUCHILLO" if id == "knife" else Weapons.DATA[id].title
		heading.add_theme_color_override("font_color",heading.get_meta("authored_color") if known else Color("91a0b1"))
		content.get_node("Role").text = ROLES[id] if known else "Encuéntrala dentro del nivel %d y completa esa misión para conservarla y elegirla en tu equipo." % Weapons.DATA[id].unlock
		var details: Label = content.get_node("Details")
		details.visible = known
		if id == "knife":
			details.text = "65 de daño base · sin munición · siempre equipado"
		else:
			var data: Dictionary = Weapons.DATA[id]
			var damage: String = "%d × %d perdigones" % [data.damage,data.pellets] if int(data.pellets) > 1 else "%d de daño" % data.damage
			details.text = "%s · cargador %d\nAlcance %d m · recarga %.1f s" % [damage,data.capacity,data.range,data.reload]

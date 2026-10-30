extends CanvasLayer

signal selected
signal back_requested
var stage: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%UpgradeBack.pressed.connect(func(): back_requested.emit())
	refresh()

func refresh() -> void:
	stage = Campaign.pending()
	visible = stage >= 0
	if stage < 0:
		return
	%UpgradeHeading.text = "SECTOR ASEGURADO · MEJORA %d / %d" % [stage + 1, Campaign.OFFERS.size()]
	%UpgradeHint.text = "Elige una mejora permanente para esta campaña. Tu progreso ya se guardó."
	%UpgradeHeading.add_theme_color_override("font_color", Color("87d4b5"))
	for index in range(3):
		var id: String = Campaign.offers_for_stage(stage)[index]
		var data: Dictionary = Campaign.UPGRADES[id]
		var card: Node = get_node("Screen/Center/Panel/Stack/Cards/Card%d" % index)
		var accent: Color = [Color("69dfe8"), Color("bb9af7"), Color("ffc36a")][index]
		var presentation = preload("res://scripts/ui/menu_presentation.gd")
		card.add_theme_stylebox_override("panel", presentation.panel_style(Color("131e2d"), accent))
		card.get_node("Margin/Content/Title").text = data.title
		card.get_node("Margin/Content/Title").add_theme_color_override("font_color", accent)
		card.get_node("Margin/Content/Description").text = data.text
		var rank: int = Campaign.rank_of(id)
		card.get_node("Margin/Content/Rank").text = "Rango %d → %d / %d" % [rank, mini(rank + 1, data.max), data.max]
		var button: Button = card.get_node("Margin/Content/Select")
		presentation.button_style(button, accent)
		button.disabled = rank >= int(data.max)
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(choose.bind(id))
		if index == 0:
			button.grab_focus()

func choose(id: String) -> void:
	if Campaign.choose_upgrade(id):
		visible = false
		selected.emit()
	else:
		%UpgradeHint.text = Campaign.save_error if not Campaign.save_error.is_empty() else "Esta mejora no está disponible."

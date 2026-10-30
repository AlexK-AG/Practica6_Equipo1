class_name StartMenu
extends Control

var page_names := ["ProfilePage", "MainPage", "LevelsPage", "SettingsPage", "ScoresPage", "EnemyPage", "WeaponPage"]
var profile_ids: Array[String] = []
var menu_music_player: AudioStreamPlayer
var pending_delete_id: String = ""

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Campaign.music.stop()
	menu_music_player = $MenuMusic
	if menu_music_player.stream != null:
		var menu_music := menu_music_player.stream.duplicate() as AudioStreamWAV
		menu_music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		menu_music.loop_begin = 0
		menu_music.loop_end = roundi(menu_music.get_length() * menu_music.mix_rate)
		menu_music_player.stream = menu_music
		apply_menu_audio()
		menu_music_player.play()
	$Margin/Stack/MainPage/Layout/Buttons/EnemyIndex.pressed.connect(func(): show_page("EnemyPage"))
	$Margin/Stack/MainPage/Layout/Buttons/WeaponIndex.pressed.connect(func(): show_page("WeaponPage"))
	var headings := ["POSICIÓN", "JUGADOR", "RÉCORD", "CAMPAÑA ACTUAL"]
	for column in range(headings.size()):
		%ScoreTable.set_column_title(column, headings[column])
	%EnterProfile.pressed.connect(enter_profile)
	%PlayerName.text_submitted.connect(func(_text: String): enter_profile())
	%SavedProfiles.item_activated.connect(select_saved_profile)
	%SavedProfiles.item_selected.connect(profile_selection_changed)
	get_node("DeleteConfirmation").confirmed.connect(confirm_profile_deletion)
	get_node("DeleteConfirmation").canceled.connect(func(): pending_delete_id = "")
	find_child("DeleteProfile", true, false).pressed.connect(request_profile_deletion)
	%Play.pressed.connect(show_levels)
	%Settings.pressed.connect(func(): show_page("SettingsPage"))
	%Tutorial.pressed.connect(open_tutorial)
	%Scores.pressed.connect(show_scores)
	%SwitchPlayer.pressed.connect(show_profiles)
	%ResetCampaign.pressed.connect(func(): %ResetConfirmation.popup_centered())
	%ResetConfirmation.confirmed.connect(reset_profile)
	%Quit.pressed.connect(func(): get_tree().quit())
	%Back.pressed.connect(func(): show_page("MainPage"))
	%MusicSlider.value = Campaign.music_volume
	%EffectsSlider.value = Campaign.effects_volume
	%SensitivitySlider.value = Campaign.sensitivity
	%MusicSlider.value_changed.connect(change_music)
	%EffectsSlider.value_changed.connect(change_effects)
	%SensitivitySlider.value_changed.connect(change_sensitivity)
	$UpgradeScreen.selected.connect(show_levels)
	$UpgradeScreen.back_requested.connect(func(): $UpgradeScreen.hide(); show_page("MainPage"))
	for index in range(Campaign.LEVELS.size()):
		get_node("Margin/Stack/LevelsPage/Scroll/Grid/Level%d/Content/Launch" % index).pressed.connect(open_level.bind(index))
	if Campaign.profile().is_empty():
		show_profiles()
	else:
		show_page("MainPage")
	$UpgradeScreen.hide()

func show_page(name_of_page: String) -> void:
	var trained: bool = bool(Campaign.profile().get("tutorial_completed",false))
	%Tutorial.text = "Entrenamiento · completado" if trained else "¡ Entrenamiento recomendado · pendiente"
	%Tutorial.tooltip_text = "Repetir el entrenamiento opcional" if trained else "Primera vez: conoce el HUD, las interacciones y el combate sin perder tu progreso."
	%Tutorial.add_theme_color_override("font_color",Color("8cd6b0") if trained else Color("f0be76"))
	if name_of_page == "EnemyPage":
		preload("res://scripts/ui/menu_presentation.gd").refresh_index(self)
	elif name_of_page == "WeaponPage":
		preload("res://scripts/ui/weapon_index.gd").refresh(self)
	for page in page_names:
		find_child(page, true, false).visible = page == name_of_page
	%Back.visible = name_of_page not in ["MainPage", "ProfilePage"]
	%Identity.text = "PERFILES LOCALES" if Campaign.profile().is_empty() else "%s · campaña %d/10 · %d puntos" % [Campaign.profile().name, Campaign.profile().completed.size(), Campaign.total_score()]
	%Status.text = Campaign.save_error
	var focus: Control = {"MainPage": %Play, "ProfilePage": %PlayerName, "LevelsPage": %Back, "ScoresPage": %Back, "SettingsPage": %MusicSlider, "EnemyPage": %Back, "WeaponPage": %Back}[name_of_page]
	focus.grab_focus()

func show_profiles() -> void:
	%SavedProfiles.clear()
	profile_ids.clear()
	for id in Campaign.profiles:
		profile_ids.append(id)
		var data: Dictionary = Campaign.profiles[id]
		%SavedProfiles.add_item("%s · %d/10 completados · récord %d" % [data.name, data.completed.size(), data.record])
	%PlayerName.text = ""
	find_child("DeleteProfile", true, false).disabled = true
	if profile_ids.has(Campaign.active_id):
		var selected_index := profile_ids.find(Campaign.active_id)
		%SavedProfiles.select(selected_index)
		profile_selection_changed(selected_index)
	show_page("ProfilePage")

func profile_selection_changed(index: int) -> void:
	if index < 0 or index >= profile_ids.size():
		return
	%PlayerName.text = Campaign.profiles[profile_ids[index]].name
	find_child("DeleteProfile", true, false).disabled = false

func request_profile_deletion() -> void:
	var selected: PackedInt32Array = %SavedProfiles.get_selected_items()
	if selected.is_empty() or selected[0] >= profile_ids.size():
		return
	pending_delete_id = profile_ids[selected[0]]
	if not Campaign.profiles.has(pending_delete_id):
		show_profiles()
		return
	var dialog: ConfirmationDialog = get_node("DeleteConfirmation")
	dialog.dialog_text = "¿Eliminar definitivamente el perfil «%s»?\n\nSe borrarán su campaña, armas, descubrimientos y récords.\nEsta acción no se puede deshacer." % Campaign.profiles[pending_delete_id].name
	dialog.popup_centered()
	dialog.get_cancel_button().grab_focus()

func confirm_profile_deletion() -> void:
	if pending_delete_id.is_empty():
		return
	var deleted_name: String = Campaign.profiles.get(pending_delete_id, {}).get("name", "")
	var deleted := Campaign.delete_profile(pending_delete_id)
	pending_delete_id = ""
	show_profiles()
	if deleted:
		%Status.text = "Perfil «%s» eliminado." % deleted_name

func enter_profile() -> void:
	if Campaign.select_profile(%PlayerName.text):
		show_page("MainPage")
	else:
		%Status.text = Campaign.save_error if not Campaign.save_error.is_empty() else "Escribe un nombre de 1 a 20 caracteres."

func select_saved_profile(index: int) -> void:
	%PlayerName.text = Campaign.profiles[profile_ids[index]].name
	enter_profile()

func show_levels() -> void:
	show_page("LevelsPage")
	for index in range(Campaign.LEVELS.size()):
		var card: Node = get_node("Margin/Stack/LevelsPage/Scroll/Grid/Level%d/Content" % index)
		var done: bool = Campaign.profile().completed.has(index)
		card.get_node("State").text = "COMPLETADO · %d pts" % int(Campaign.profile().scores.get(str(index), 0)) if done else ("DISPONIBLE" if Campaign.unlocked(index) else "BLOQUEADO · completa el anterior")
		card.get_node("Launch").disabled = not Campaign.unlocked(index)
		card.get_node("Launch").text = "Repetir misión" if done else "Jugar misión"
		card.get_node("Launch").tooltip_text = Campaign.LEVELS[index].brief
		for label in card.find_children("*", "Label", true, false):
			if label.name not in ["State"]:
				label.text = "%02d / %s" % [index + 1, Campaign.LEVELS[index].title]
	if Campaign.pending() >= 0:
		$UpgradeScreen.refresh()

func open_level(index: int) -> void:
	if not Campaign.unlocked(index):
		return
	if Campaign.pending() >= 0:
		$UpgradeScreen.refresh()
		return
	get_tree().change_scene_to_file(Campaign.LEVELS[index].path)

func show_scores() -> void:
	show_page("ScoresPage")
	%ScoreTable.clear()
	var root: TreeItem = %ScoreTable.create_item()
	var rows: Array = Campaign.profiles.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.record) > int(b.record))
	for i in range(rows.size()):
		var row: TreeItem = %ScoreTable.create_item(root)
		row.set_text(0, str(i + 1))
		row.set_text(1, rows[i].name)
		row.set_text(2, str(rows[i].record))
		row.set_text(3, "%d / 10" % rows[i].completed.size())

func reset_profile() -> void:
	Campaign.reset_campaign()
	show_page("MainPage")

func change_music(value: float) -> void:
	Campaign.music_volume = value
	store_settings()

func change_effects(value: float) -> void:
	Campaign.effects_volume = value
	store_settings()

func change_sensitivity(value: float) -> void:
	Campaign.sensitivity = value
	store_settings()

func store_settings() -> void:
	Campaign.apply_audio()
	apply_menu_audio()
	Campaign.save_data()
	%Status.text = Campaign.save_error

func apply_menu_audio() -> void:
	if is_instance_valid(menu_music_player):
		menu_music_player.volume_db = linear_to_db(maxf(0.0001, Campaign.music_volume)) - 1.0
		menu_music_player.stream_paused = Campaign.music_volume <= 0

func open_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")

func _exit_tree() -> void:
	if is_instance_valid(menu_music_player):
		menu_music_player.stream_paused = false
		menu_music_player.stop()
		menu_music_player.stream = null

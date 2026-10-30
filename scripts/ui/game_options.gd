extends ScrollContainer
## Existing settings, with reversible screen previews and profile-safe defaults.
const SCALES := [0.5, 0.67, 0.75, 0.85, 1.0]
const BINDINGS := [["forward", "Avanzar"], ["back", "Retroceder"], ["left", "Izquierda"], ["right", "Derecha"], ["jump", "Saltar"], ["sprint", "Correr"], ["reload", "Recargar"], ["melee", "Cuchillo"], ["interact", "Interactuar"], ["grenade", "Granada"], ["grenade_cycle", "Cambiar granada"], ["weapon_one", "Arma 1"], ["weapon_two", "Arma 2"]]
var waiting_action: String = ""
var waiting_button: Button
var syncing := false
var fov: HSlider
var brightness: HSlider
var brightness_label: Label
var difficulty: OptionButton
var difficulty_hint: Label
var resolution: OptionButton
var render_scale: OptionButton
var fullscreen: CheckButton
var display_hint: Label
var state: Label
var touch_opacity: HSlider
var touch_size: HSlider
var touch_deadzone: HSlider
var touch_opacity_label: Label
var touch_size_label: Label
var touch_deadzone_label: Label
var mobile_sync_url: LineEdit
var mobile_sync_token: LineEdit
var mobile_sync_button: Button
var mobile_sync_state: Label
var mobile_sync_nodes: Array[Control] = []
var screen_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var toggles: Dictionary = {}
var binding_buttons: Dictionary = {}

func _ready() -> void:
	# All controls and dialogs are authored in start.tscn; only bind behavior.
	fov = $Content/FieldOfView
	brightness = $Content/Brightness
	brightness_label = $Content/BrightnessLabel
	difficulty = $Content/Difficulty
	difficulty_hint = $Content/DifficultyHint
	resolution = $Content/WindowSize
	render_scale = $Content/RenderScale
	fullscreen = $Content/Fullscreen
	display_hint = $Content/DisplayHint
	state = $Content/State
	touch_opacity = $Content/TouchOpacity
	touch_size = $Content/TouchSize
	touch_deadzone = $Content/TouchDeadzone
	touch_opacity_label = $Content/TouchOpacityLabel
	touch_size_label = $Content/TouchSizeLabel
	touch_deadzone_label = $Content/TouchDeadzoneLabel
	mobile_sync_url = $Content/MobileSyncURL
	mobile_sync_token = $Content/MobileSyncToken
	mobile_sync_button = $Content/MobileSyncButton
	mobile_sync_state = $Content/MobileSyncState
	mobile_sync_nodes = [$Content/MobileSyncTitle, $Content/MobileSyncURLLabel, mobile_sync_url, $Content/MobileSyncTokenLabel, mobile_sync_token, $Content/MobileSyncHint, mobile_sync_button, mobile_sync_state]
	screen_dialog = $ScreenConfirmation
	reset_dialog = $DefaultsConfirmation
	resolution.item_selected.connect(func(index: int): request_screen_change("resolution", index))
	fullscreen.toggled.connect(func(value: bool): request_screen_change("fullscreen", value))
	render_scale.item_selected.connect(func(index: int): request_screen_change("render_scale", SCALES[index]))
	brightness.value_changed.connect(func(value: float): set_option("brightness", value))
	fov.value_changed.connect(func(value: float): set_option("fov", value))
	difficulty.item_selected.connect(func(index: int): set_option("difficulty", index))
	touch_opacity.value_changed.connect(func(value: float): set_option("touch_opacity", value))
	touch_size.value_changed.connect(func(value: float): set_option("touch_size", value))
	touch_deadzone.value_changed.connect(func(value: float): set_option("touch_deadzone", value))
	for action in ["reduced_motion","reduced_flashes","crosshair","touch_haptics","touch_debug"]:
		var toggle: CheckButton = get_node("Content/Toggle_" + action)
		toggles[action] = toggle
		toggle.toggled.connect(set_toggle.bind(action))
	for entry in BINDINGS:
		var action: String = entry[0]
		var button: Button = get_node("Content/Bind_" + action)
		binding_buttons[action] = button
		button.pressed.connect(func(): waiting_action = action; waiting_button = button; button.text = "Pulsa una tecla…")
	screen_dialog.confirmed.connect(Campaign.confirm_display_preview)
	screen_dialog.canceled.connect(Campaign.revert_display_preview)
	$Content/ResetDefaults.pressed.connect(func(): reset_dialog.popup_centered(Vector2i(560,220)); reset_dialog.get_cancel_button().grab_focus())
	mobile_sync_button.pressed.connect(save_mobile_sync_settings)
	reset_dialog.confirmed.connect(reset_settings)
	Campaign.settings_changed.connect(sync_controls)
	Campaign.display_preview_finished.connect(preview_finished)
	Campaign.mobile_sync_finished.connect(mobile_sync_finished)
	visibility_changed.connect(page_visibility_changed)
	sync_controls()

func sync_controls() -> void:
	if not is_inside_tree() or not is_instance_valid(fov):
		return
	syncing = true
	fov.set_value_no_signal(float(Campaign.options.fov))
	brightness.set_value_no_signal(float(Campaign.options.brightness))
	brightness_label.text = "Brillo del escenario · %d %%" % roundi(float(Campaign.options.brightness) * 100)
	difficulty.select(int(Campaign.options.difficulty))
	var modifiers: Dictionary = preload("res://scripts/enemies/enemy_catalog.gd").DIFFICULTY[int(Campaign.options.difficulty)]
	difficulty_hint.text = "Enemigos: HP %d %% · daño %d %%\nFrecuencia de ataque %d %% · movimiento %d %%\nSe aplica al empezar o reiniciar la misión desde cero." % [roundi(float(modifiers.health) * 100), roundi(float(modifiers.damage) * 100), roundi(float(modifiers.attack) * 100), roundi(float(modifiers.movement) * 100)]
	resolution.select(int(Campaign.options.resolution))
	fullscreen.set_pressed_no_signal(bool(Campaign.options.fullscreen))
	var scale_index: int = 0
	var distance: float = INF
	for index in range(SCALES.size()):
		if absf(SCALES[index] - float(Campaign.options.render_scale)) < distance:
			distance = absf(SCALES[index] - float(Campaign.options.render_scale))
			scale_index = index
	render_scale.select(scale_index)
	apply_display_context(Campaign.display_context())
	for key in toggles:
		toggles[key].set_pressed_no_signal(bool(Campaign.options[key]))
	touch_opacity.set_value_no_signal(float(Campaign.options.touch_opacity))
	touch_size.set_value_no_signal(float(Campaign.options.touch_size))
	touch_deadzone.set_value_no_signal(float(Campaign.options.touch_deadzone))
	touch_opacity_label.text = "Opacidad táctil · %d %%" % roundi(float(Campaign.options.touch_opacity) * 100)
	touch_size_label.text = "Tamaño táctil · %d %%" % roundi(float(Campaign.options.touch_size) * 100)
	touch_deadzone_label.text = "Zona muerta del joystick · %.2f" % float(Campaign.options.touch_deadzone)
	mobile_sync_url.text = str(Campaign.options.get("mobile_sync_url", ""))
	mobile_sync_token.text = str(Campaign.options.get("mobile_sync_token", ""))
	var mobile_settings_visible := OS.get_name() in ["Android", "iOS"] or bool(Campaign.options.get("touch_debug", false))
	for node in mobile_sync_nodes:
		node.visible = mobile_settings_visible
	for entry in BINDINGS:
		binding_buttons[entry[0]].text = entry[1] + " · " + OS.get_keycode_string(int(Campaign.bindings.get(entry[0], Campaign.DEFAULT_KEYS[entry[0]])))
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("apply_menu_audio"):
		for entry in [["MusicSlider", Campaign.music_volume], ["EffectsSlider", Campaign.effects_volume], ["SensitivitySlider", Campaign.sensitivity]]:
			var slider := scene.find_child(entry[0], true, false)
			if slider is Range:
				slider.set_value_no_signal(float(entry[1]))
		scene.apply_menu_audio()
	syncing = false

func apply_display_context(context: String) -> void:
	var embedded: bool = context == "embedded"
	resolution.disabled = embedded or bool(Campaign.options.fullscreen)
	fullscreen.disabled = embedded
	if embedded:
		display_hint.text = "Vista incrustada: el editor controla tamaño y pantalla completa. Prueba estas opciones en una ventana independiente."
	elif Campaign.options.fullscreen:
		display_hint.text = "Pantalla completa usa el tamaño del monitor. La escala 3D funciona en ambos modos."
	else:
		var actual_size := DisplayServer.window_get_size()
		display_hint.text = "Ventana independiente: %d × %d. El tamaño solicitado se adapta al espacio del monitor." % [actual_size.x, actual_size.y]

func set_option(key: String, value: Variant) -> void:
	if syncing:
		return
	Campaign.options[key] = value
	Campaign.apply_game_options()
	Campaign.save_data()
	sync_controls()
	state.text = Campaign.save_error

func set_toggle(value: bool, key: String) -> void:
	set_option(key, value)

func save_mobile_sync_settings() -> void:
	mobile_sync_state.text = "Guardando y conectando con el PC…"
	if not Campaign.save_mobile_sync_settings(mobile_sync_url.text, mobile_sync_token.text):
		mobile_sync_state.text = Campaign.save_error

func mobile_sync_finished(success: bool, message: String) -> void:
	if is_instance_valid(mobile_sync_state):
		mobile_sync_state.text = message
		mobile_sync_state.modulate = Color("70d5a2") if success else Color("f0be76")

func request_screen_change(key: String, value: Variant) -> void:
	if syncing:
		return
	if Campaign.preview_display({key: value}):
		open_screen_confirmation()
	else:
		state.text = Campaign.save_error
	sync_controls()

func open_screen_confirmation() -> void:
	update_countdown()
	screen_dialog.popup_centered(Vector2i(540, 220))
	screen_dialog.get_cancel_button().grab_focus()

func update_countdown() -> void:
	screen_dialog.dialog_text = "¿Conservar estos ajustes de pantalla?\nRestauración automática en %d segundos.\n\nEscala 3D: %d %% · %s" % [Campaign.screen_preview_seconds(), roundi(float(Campaign.options.render_scale) * 100), "pantalla completa" if Campaign.options.fullscreen else "modo ventana"]

func _process(_delta: float) -> void:
	if is_instance_valid(screen_dialog) and Campaign.screen_preview_active():
		update_countdown()

func preview_finished(confirmed: bool) -> void:
	if is_instance_valid(screen_dialog):
		screen_dialog.hide()
	state.text = "Pantalla confirmada." if confirmed else "Se restauró la pantalla anterior."
	if not Campaign.save_error.is_empty():
		state.text = Campaign.save_error
	sync_controls()

func reset_settings() -> void:
	waiting_action = ""
	if Campaign.reset_settings():
		state.text = "Ajustes restablecidos. Tus perfiles y progreso se conservan."
		if Campaign.screen_preview_active():
			open_screen_confirmation()
	else:
		state.text = Campaign.save_error
	sync_controls()

func page_visibility_changed() -> void:
	if not is_visible_in_tree():
		waiting_action = ""
		Campaign.revert_display_preview()

func _exit_tree() -> void:
	if Campaign.settings_changed.is_connected(sync_controls):
		Campaign.settings_changed.disconnect(sync_controls)
	if Campaign.display_preview_finished.is_connected(preview_finished):
		Campaign.display_preview_finished.disconnect(preview_finished)
	if Campaign.mobile_sync_finished.is_connected(mobile_sync_finished):
		Campaign.mobile_sync_finished.disconnect(mobile_sync_finished)
	Campaign.revert_display_preview()

func _input(event: InputEvent) -> void:
	if waiting_action.is_empty() or not is_visible_in_tree() or Campaign.screen_preview_active() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_ESCAPE:
		for action in Campaign.DEFAULT_KEYS:
			if action != waiting_action and int(Campaign.bindings.get(action, Campaign.DEFAULT_KEYS[action])) == event.physical_keycode:
				waiting_button.text = "Tecla ocupada · elige otra o ESC"
				get_viewport().set_input_as_handled()
				return
		Campaign.set_key_binding(waiting_action, event.physical_keycode)
	waiting_action = ""
	sync_controls()
	get_viewport().set_input_as_handled()

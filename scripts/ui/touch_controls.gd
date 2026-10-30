extends Control
## Touch input overlay. Child Controls in hud.tscn are the editable visual layout.

const BUTTON_ACTIONS := ["shoot", "jump", "melee", "grenade", "reload", "sprint", "weapon_next", "aim", "interact", "pause"]
const LAYOUT_NODES := ["Joystick", "ShootButton", "JumpButton", "MeleeButton", "GrenadeButton", "ReloadButton", "SprintButton", "WeaponButton", "AimButton", "InteractButton", "PauseButton"]

var _active_touches: Dictionary = {}
var _button_touch_counts: Dictionary = {}
var _virtual_strengths: Dictionary = {}
var _base_offsets: Dictionary = {}
var _safe_margins := Vector4.ZERO # left, top, right, bottom in viewport units
var _size_scale := 1.0
var _opacity := 0.55
var _deadzone := 0.2
var _enabled := false
var _look_actions_pending := false
var _look_release_physics_frame := -1
var _pending_look_delta := Vector2.ZERO
var _pulse_actions: Array[String] = []
var _sprint_toggled := false
var _aim_toggled := false
var _interaction_available := false
var _has_two_weapons := false
var _weapon_id := ""

@onready var _joystick: Control = $Joystick
@onready var _knob: Control = $Joystick/Knob
@onready var _buttons: Dictionary = {
	"shoot": $ShootButton,
	"jump": $JumpButton,
	"melee": $MeleeButton,
	"grenade": $GrenadeButton,
	"reload": $ReloadButton,
	"sprint": $SprintButton,
	"weapon_next": $WeaponButton,
	"aim": $AimButton,
	"interact": $InteractButton,
	"pause": $PauseButton
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for node_name in LAYOUT_NODES:
		var control := get_node(node_name) as Control
		_base_offsets[node_name] = Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_refresh_options()

func _process(_delta: float) -> void:
	_refresh_options()
	_refresh_player_actions()
	_sync_pause_state()
	if _pending_look_delta.length_squared() > 0.0:
		_update_touch_look(_pending_look_delta)
		_pending_look_delta = Vector2.ZERO
	# Clear touch-look only after one physics step has consumed the action.
	if _look_actions_pending and Engine.get_physics_frames() >= _look_release_physics_frame:
		_set_look_actions(Vector2.ZERO)
		_look_actions_pending = false
	if not _pulse_actions.is_empty() and Engine.get_physics_frames() >= _look_release_physics_frame:
		for action in _pulse_actions:
			_emit_action(action, false, 0.0)
		_pulse_actions.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all_actions()

func _refresh_options() -> void:
	var game := get_tree().current_scene
	var game_finished := false
	if is_instance_valid(game):
		for property: Dictionary in game.get_property_list():
			if property.get("name", "") == "finished":
				game_finished = game.get("finished") == true
				break
	var mobile_platform := OS.get_name() in ["Android", "iOS"]
	var new_enabled := (mobile_platform or bool(Campaign.options.get("touch_debug", false))) and not game_finished
	var new_opacity := clampf(float(Campaign.options.get("touch_opacity", 0.55)), 0.4, 0.7)
	var new_size := clampf(float(Campaign.options.get("touch_size", 1.0)), 0.9, 1.2)
	var new_deadzone := clampf(float(Campaign.options.get("touch_deadzone", 0.2)), 0.15, 0.25)
	if new_enabled != _enabled or not is_equal_approx(new_opacity, _opacity) or not is_equal_approx(new_size, _size_scale) or not is_equal_approx(new_deadzone, _deadzone):
		if _enabled and not new_enabled:
			_release_all_actions()
		var layout := get_node_or_null("../GameHUD")
		if is_instance_valid(layout) and layout.has_method("apply_touch_layout"):
			layout.apply_touch_layout(new_enabled)
		_enabled = new_enabled
		_opacity = new_opacity
		_size_scale = new_size
		_deadzone = new_deadzone
		_update_layout()
		_update_button_visuals()
	visible = _enabled
	_sync_pause_state()

func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_safe_margins = Vector4.ZERO
	var safe_area := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0 and safe_area.size.x > 0 and safe_area.size.y > 0:
		_safe_margins.x = viewport_size.x * float(safe_area.position.x) / float(screen_size.x)
		_safe_margins.y = viewport_size.y * float(safe_area.position.y) / float(screen_size.y)
		_safe_margins.z = viewport_size.x * float(screen_size.x - safe_area.end.x) / float(screen_size.x)
		_safe_margins.w = viewport_size.y * float(screen_size.y - safe_area.end.y) / float(screen_size.y)
	_safe_margins.x = maxf(20.0, _safe_margins.x)
	_safe_margins.y = maxf(20.0, _safe_margins.y)
	_safe_margins.z = maxf(20.0, _safe_margins.z)
	_safe_margins.w = maxf(20.0, _safe_margins.w)
	for node_name in LAYOUT_NODES:
		var control := get_node(node_name) as Control
		var base: Vector4 = _base_offsets.get(node_name, Vector4.ZERO)
		var center := Vector2((base.x + base.z) * 0.5, (base.y + base.w) * 0.5)
		var shift := Vector2.ZERO
		if node_name == "Joystick":
			shift = Vector2(_safe_margins.x, -_safe_margins.w)
		elif node_name == "PauseButton":
			shift = Vector2(0.0, _safe_margins.y)
		elif node_name == "InteractButton":
			shift = Vector2(-_safe_margins.z, _safe_margins.y)
		else:
			shift = Vector2(-_safe_margins.z, -_safe_margins.w)
		center += shift
		var scaled_size := Vector2(base.z - base.x, base.w - base.y) * _size_scale
		if node_name == "ShootButton":
			scaled_size = scaled_size.max(Vector2(96.0, 96.0))
		elif node_name not in ["Joystick", "InteractButton", "PauseButton"]:
			scaled_size = scaled_size.max(Vector2(72.0, 72.0))
		control.offset_left = center.x - scaled_size.x * 0.5
		control.offset_top = center.y - scaled_size.y * 0.5
		control.offset_right = center.x + scaled_size.x * 0.5
		control.offset_bottom = center.y + scaled_size.y * 0.5
	var knob_size := 68.0 * _size_scale
	_knob.offset_left = 0.0
	_knob.offset_top = 0.0
	_knob.offset_right = knob_size
	_knob.offset_bottom = knob_size
	_update_joystick_knob()

func _sync_pause_state() -> void:
	if not is_node_ready():
		return
	var paused := get_tree().paused
	_joystick.visible = not paused
	for action in BUTTON_ACTIONS:
		var button: Button = _buttons[action]
		var context_available: bool = action != "interact" or _interaction_available
		if action == "weapon_next":
			context_available = _has_two_weapons
		elif action == "aim":
			context_available = _weapon_id == "precision"
		button.visible = action == "pause" or (not paused and context_available)
	_buttons["sprint"].text = "CORRER ON" if _sprint_toggled else "CORRER"
	_buttons["aim"].text = "MIRA ON" if _aim_toggled else "MIRA"
	_buttons["pause"].text = "▶" if paused else "Ⅱ"

func _refresh_player_actions() -> void:
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") if is_instance_valid(scene) else null
	if not is_instance_valid(player):
		_has_two_weapons = false
		_weapon_id = ""
		return
	var loadout: Variant = player.get("loadout")
	_has_two_weapons = loadout is Array and loadout.size() > 1
	_weapon_id = str(player.get("weapon_id"))

func set_interaction_prompt(available: bool) -> void:
	_interaction_available = available
	_sync_pause_state()

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var touch_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event.pressed:
		if get_tree().paused and not _button_at(event.position, ["pause"]):
			return
		var button := _button_at(event.position, BUTTON_ACTIONS)
		if not button.is_empty():
			_active_touches[event.index] = {"type": "button", "action": button}
			_set_button_pressed(button, true)
			return
		var joystick_center := _joystick.position + _joystick.size * 0.5
		var joystick_activation_radius := minf(_joystick.size.x, _joystick.size.y) * 0.68
		if not get_tree().paused and touch_position.distance_to(joystick_center) <= joystick_activation_radius:
			_active_touches[event.index] = {"type": "joystick"}
			_update_joystick(touch_position)
			return
		if not get_tree().paused and touch_position.x >= size.x * 0.47:
			_active_touches[event.index] = {"type": "look"}
	else:
		_release_touch(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		return
	var touch: Dictionary = _active_touches[event.index]
	if touch.type == "joystick":
		_update_joystick(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif touch.type == "look" and not get_tree().paused:
		_pending_look_delta += event.relative

func _release_touch(index: int) -> void:
	if not _active_touches.has(index):
		return
	var touch: Dictionary = _active_touches[index]
	_active_touches.erase(index)
	if touch.type == "button":
		_set_button_pressed(str(touch.action), false)
	elif touch.type == "joystick":
		_update_joystick(_joystick.position + _joystick.size * 0.5)
		_update_layout()
	elif touch.type == "look":
		# Let the last drag sample reach the player's next physics step before
		# the queued release in _process clears it.
		pass

func _button_at(screen_position: Vector2, actions: Array) -> String:
	for action in actions:
		var button: Control = _buttons[action]
		if not button.visible:
			continue
		var button_position: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * screen_position
		if Rect2(Vector2.ZERO, button.size).has_point(button_position):
			return str(action)
	return ""

func _set_button_pressed(action: String, pressed: bool) -> void:
	var count := int(_button_touch_counts.get(action, 0))
	var previous_count := count
	count += 1 if pressed else -1
	count = maxi(0, count)
	_button_touch_counts[action] = count
	if action == "sprint" and pressed and previous_count == 0:
		_sprint_toggled = not _sprint_toggled
	if action == "aim" and pressed and previous_count == 0:
		_aim_toggled = not _aim_toggled
	_update_button_visuals()
	if action in ["aim", "weapon_next"]:
		if pressed and previous_count == 0:
			_emit_action(action, true)
			_pulse_actions.append(action)
			_look_release_physics_frame = Engine.get_physics_frames() + 1
	else:
		_emit_action(action, _sprint_toggled if action == "sprint" else count > 0)

func _update_joystick(point: Vector2) -> void:
	var center := _joystick.position + _joystick.size * 0.5
	var radius := minf(_joystick.size.x, _joystick.size.y) * 0.5
	var raw := (point - center) / maxf(1.0, radius)
	if raw.length() > 1.0:
		raw = raw.normalized()
	var magnitude := raw.length()
	var axis := Vector2.ZERO
	if magnitude > _deadzone:
		axis = raw.normalized() * inverse_lerp(_deadzone, 1.0, magnitude)
	_set_virtual_strength("left", maxf(0.0, -axis.x))
	_set_virtual_strength("right", maxf(0.0, axis.x))
	_set_virtual_strength("forward", maxf(0.0, -axis.y))
	_set_virtual_strength("back", maxf(0.0, axis.y))
	_update_joystick_knob(axis)

func _update_joystick_knob(axis: Vector2 = Vector2.ZERO) -> void:
	if not is_node_ready():
		return
	var radius := minf(_joystick.size.x, _joystick.size.y) * 0.5
	var knob_center := _joystick.size * 0.5 + axis * radius * 0.62
	_knob.position = knob_center - _knob.size * 0.5

func _update_touch_look(relative: Vector2) -> void:
	var frame_radians := 3.5 / float(Engine.physics_ticks_per_second)
	const MOBILE_LOOK_SENSITIVITY := 1.8
	var axis := Vector2(
		clampf(relative.x * Campaign.sensitivity * MOBILE_LOOK_SENSITIVITY / maxf(0.001, frame_radians), -1.0, 1.0),
		clampf(relative.y * Campaign.sensitivity * MOBILE_LOOK_SENSITIVITY / maxf(0.001, frame_radians), -1.0, 1.0)
	)
	_set_look_actions(axis)
	_look_actions_pending = true
	_look_release_physics_frame = Engine.get_physics_frames() + 1

func _set_look_actions(axis: Vector2) -> void:
	_set_virtual_strength("look_left", maxf(0.0, -axis.x))
	_set_virtual_strength("look_right", maxf(0.0, axis.x))
	_set_virtual_strength("look_up", maxf(0.0, -axis.y))
	_set_virtual_strength("look_down", maxf(0.0, axis.y))

func _set_virtual_strength(action: String, strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	var previous := float(_virtual_strengths.get(action, 0.0))
	if absf(previous - strength) < 0.015:
		return
	_virtual_strengths[action] = strength
	_emit_action(action, strength > 0.0, strength)

func _emit_action(action: String, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)

func _update_button_visuals() -> void:
	if not is_node_ready():
		return
	for action in BUTTON_ACTIONS:
		var button: Control = _buttons[action]
		var pressed := _sprint_toggled if action == "sprint" else (_aim_toggled if action == "aim" else int(_button_touch_counts.get(action, 0)) > 0)
		button.modulate.a = minf(1.0, _opacity * (1.25 if pressed else 1.0))
		if action in ["pause", "interact", "weapon_next", "aim"]:
			button.modulate.a = minf(1.0, _opacity)
	_joystick.modulate.a = _opacity
	_knob.modulate.a = _opacity

func _release_all_actions() -> void:
	for action in _button_touch_counts:
		_emit_action(str(action), false, 0.0)
	for action in _virtual_strengths:
		_emit_action(str(action), false, 0.0)
	_button_touch_counts.clear()
	_virtual_strengths.clear()
	_sprint_toggled = false
	_aim_toggled = false
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") if is_instance_valid(scene) else null
	if is_instance_valid(player) and player.has_method("_update_aim_zoom"):
		player.touch_aim_enabled = false
		player._update_aim_zoom()
	_active_touches.clear()
	_look_actions_pending = false
	_look_release_physics_frame = -1
	_pending_look_delta = Vector2.ZERO
	for action in _pulse_actions:
		_emit_action(action, false, 0.0)
	_pulse_actions.clear()
	_update_joystick_knob()
	_update_button_visuals()

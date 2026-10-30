extends Control
## Authored in scenes/ui/hud.tscn. This controller updates data and states only.
@export var warning_color := Color("f0be76")
@export var danger_color := Color("f08b8b")
var game: Node
@onready var health_value: Label = $VitalsInstrument/Content/HealthRow/Value
@onready var health_bar: ProgressBar = $VitalsInstrument/Content/HealthBar
@onready var shield_value: Label = $VitalsInstrument/Content/ShieldRow/Value
@onready var shield_bar: ProgressBar = $VitalsInstrument/Content/ShieldBar
@onready var recovery: Label = $VitalsInstrument/Content/Recovery
@onready var ammunition: Label = $ArsenalInstrument/Content/AmmoRow/Ammunition
@onready var reserve: Label = $ArsenalInstrument/Content/AmmoRow/Reserve
@onready var gun_title: Label = $ArsenalInstrument/Content/WeaponRow/Title
@onready var gun_state: Label = $ArsenalInstrument/Content/WeaponRow/State
@onready var ammo_bar: ProgressBar = $ArsenalInstrument/Content/AmmoBar
@onready var grenade: Label = $ArsenalInstrument/Content/GrenadeRow/Type
@onready var grenade_stocks: Label = $ArsenalInstrument/Content/GrenadeStocks
@onready var grenade_key: Label = $ArsenalInstrument/Content/GrenadeRow/CycleKey
@onready var telemetry: Label = $SectorInstrument/Content/Telemetry
@onready var objective_stage: Label = $"../MissionPanel/Content/Stage"
@onready var objective_title: Label = $"../MissionPanel/Content/Title"
@onready var objective_details: Label = $"../MissionPanel/Content/Details"
var mission_source: Label
var last_mission_text: String = ""
var health_color: Color
var ammo_color: Color

func _ready() -> void:
	# State changes must not recolor other instances of the shared HUD scene.
	for bar in [health_bar,ammo_bar]:
		bar.add_theme_stylebox_override("fill",bar.get_theme_stylebox("fill").duplicate())
	health_color = (health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	ammo_color = (ammo_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color

func bind_game(controller: Node) -> void:
	game = controller
	$SectorInstrument/Content/SectorCode.text = "SECTOR 07 / %02d" % game.level_number if not game.tutorial_mode else "SECTOR 07 / ENTRENAMIENTO"
	$SectorInstrument/Content/SectorTitle.text = game.level_title.to_upper() if not game.tutorial_mode else "SIMULACIÓN OPCIONAL"
	refresh()

func bind_mission(mission: Node) -> void:
	mission_source = mission.hint
	update_objective()

func apply_touch_layout(enabled: bool) -> void:
	var vitals: Control = $VitalsInstrument
	var arsenal: Control = $ArsenalInstrument
	var mission_panel: Control = get_node("../MissionPanel")
	if enabled:
		# Compact the information panels on phones; keep the touch targets full size.
		vitals.scale = Vector2(0.88, 0.88)
		arsenal.scale = Vector2(0.88, 0.88)
		mission_panel.scale = Vector2(0.90, 0.90)
		vitals.anchor_top = 0.0
		vitals.anchor_bottom = 0.0
		vitals.offset_left = 22.0
		vitals.offset_top = 108.0
		vitals.offset_right = 322.0
		vitals.offset_bottom = 229.0
		arsenal.anchor_left = 0.5
		arsenal.anchor_top = 1.0
		arsenal.anchor_right = 0.5
		arsenal.anchor_bottom = 1.0
		arsenal.offset_left = -144.0
		arsenal.offset_top = -203.0
		arsenal.offset_right = 144.0
		arsenal.offset_bottom = -22.0
		mission_panel.offset_top = 24.0
		mission_panel.offset_bottom = 24.0
	else:
		vitals.scale = Vector2.ONE
		arsenal.scale = Vector2.ONE
		mission_panel.scale = Vector2.ONE
		vitals.anchor_top = 1.0
		vitals.anchor_bottom = 1.0
		vitals.offset_left = 22.0
		vitals.offset_top = -143.0
		vitals.offset_right = 322.0
		vitals.offset_bottom = -22.0
		arsenal.anchor_left = 1.0
		arsenal.anchor_top = 1.0
		arsenal.anchor_right = 1.0
		arsenal.anchor_bottom = 1.0
		arsenal.offset_left = -310.0
		arsenal.offset_top = -203.0
		arsenal.offset_right = -22.0
		arsenal.offset_bottom = -22.0
		mission_panel.offset_top = 24.0
		mission_panel.offset_bottom = 24.0

func update_objective() -> void:
	if not is_instance_valid(mission_source) or mission_source.text == last_mission_text:
		return
	last_mission_text = mission_source.text
	var lines := last_mission_text.split("\n", false)
	objective_stage.text = lines[0] if not lines.is_empty() else "OBJETIVO ACTIVO"
	objective_title.text = lines[1] if lines.size() > 1 else "Explora el sector"
	objective_details.text = "\n".join(lines.slice(2))
	objective_details.visible = not objective_details.text.is_empty()

func refresh() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or not is_instance_valid(health_value):
		return
	var player = game.player
	health_value.text = "%d / %d" % [player.health, player.max_health]
	var danger: bool = player.health <= player.max_health * 0.3
	health_value.modulate = danger_color if danger else Color.WHITE
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = danger_color if danger else health_color
	shield_value.text = "%d / %d" % [int(player.shield), int(player.shield_max)] if player.shield_max > 0 else "SIN MÓDULO"
	shield_value.modulate.a = 1.0 if player.shield_max > 0 else 0.55
	shield_bar.max_value = maxf(1, player.shield_max)
	shield_bar.value = player.shield
	recovery.text = "ESTADO ESTABLE"
	if player.health > 0 and player.health < player.max_health:
		recovery.text = "REPARACIÓN EN %.1f s" % player.regen_wait if player.regen_wait > 0 else "REPARANDO +%d PV/s" % player.regen_rate
	telemetry.text = "BAJAS %02d    /    %02d:%02d" % [game.kills, int(game.elapsed / 60), int(game.elapsed) % 60]
	gun_title.text = player.Weapons.DATA[player.weapon_id].title
	ammunition.text = "%02d / %02d" % [player.ammo, player.ammo_capacity]
	ammunition.modulate = danger_color if player.ammo == 0 else (warning_color if player.ammo <= player.ammo_capacity * 0.25 else Color.WHITE)
	reserve.text = "RESERVA\n%03d" % player.reserve
	gun_state.text = "RECARGANDO" if player.reload_time > 0 else ("SIN MUNICIÓN" if player.ammo == 0 and player.reserve == 0 else "")
	ammo_bar.max_value = 1.0
	ammo_bar.value = 1.0 - player.reload_time / player.reload_duration if player.reload_time > 0 else float(player.ammo) / maxf(1, player.ammo_capacity)
	(ammo_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = warning_color if player.reload_time > 0 else ammo_color
	grenade.text = player.grenade_label() if player.has_method("grenade_label") else "GRANADA  /  %d" % player.grenades
	grenade_key.text = ""
	grenade_stocks.text = "EQUIPO TÁCTICO"
	if player.has_method("available_grenades"):
		var available: Array = player.available_grenades()
		if available.size() > 1:
			var cycle_key: int = int(game.get_node("/root/Campaign").bindings.get("grenade_cycle", KEY_Q))
			grenade_key.text = "%s  /  CAMBIAR" % OS.get_keycode_string(cycle_key)
		var counts: Array[String] = []
		for id: String in available:
			counts.append("%s %d" % [{"basic": "BÁS.", "fragmentation": "FRAG.", "slow": "EST."}.get(id, id.to_upper()), int(player.grenade_inventory.get(id, 0))])
		grenade_stocks.text = "   ·   ".join(counts)
	if player.grenade_wait > 0:
		grenade_stocks.text += "  /  %.1f s" % player.grenade_wait
	var cargo_panel: Control = $"../MissionPanel/Content/CargoVitality"
	var defense = game.mission.early.get("defense") if is_instance_valid(game.mission) and game.mission.early != null else null
	cargo_panel.visible = defense != null and defense.started
	if cargo_panel.visible:
		cargo_panel.get_node("Value").text = "INTEGRIDAD DE CARGA  %d / 150" % defense.health
		cargo_panel.get_node("Bar").value = defense.health
	update_objective()

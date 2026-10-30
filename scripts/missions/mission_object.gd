extends StaticBody3D
const Kit = preload("res://scripts/common/kit.gd")
var mission: Node
var object_id: int = 0
var title: String = "TERMINAL"
var destructible: bool = false
var health: int = 140
var active: bool = true
var label: Label3D
var beacon: MeshInstance3D
var weapon_id: String = ""
var grenade_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var is_card := title == "TARJETA" or title.begins_with("LLAVE DE MANDO")
	var is_cargo := title.begins_with("RECUPERAR CARGA")
	var compact: bool = true
	Kit.model(self, "Prop_ItemHolder" if is_card or not weapon_id.is_empty() else ("Alien_Oculichrysalis" if destructible else ("Prop_Chest" if is_cargo or object_id < 0 or title.begins_with("SUMINISTROS") else "Prop_AccessPoint")), Vector3(0.8, 1.2, 0.8), Vector3(0, 0.6, 0))
	if is_card:
		Kit.box(self, Vector3(0.25, 0.025, 0.16), Vector3(0, 1.25, 0), Color("ffda57"), true)
	if not grenade_id.is_empty():
		var tint: Color = preload("res://scripts/combat/grenade_catalog.gd").DATA[grenade_id].color
		Kit.box(self, Vector3(.30, .34, .30), Vector3(0, 1.35, 0), tint)
		Kit.box(self, Vector3(.10, .09, .14), Vector3(0, 1.56, 0), Color("66707d"))
	if not weapon_id.is_empty():
		var gun := preload("res://scripts/visuals/combat_visuals.gd").weapon(weapon_id)
		gun.position = Vector3(-.3,1.6,.7)
		add_child(gun)
	Kit.collider(self, Vector3(0.8, 1.6 if not weapon_id.is_empty() else 1.2, 0.8), Vector3(0, 0.8 if not weapon_id.is_empty() else 0.6, 0))
	label = Label3D.new()
	label.position.y = 2.0
	label.font_size = 32 if compact else 48
	label.pixel_size = 0.0028 if compact else 0.004
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffda85")
	var action_hint: String = "DISPARA" if destructible else mission.key_name("interact")
	if mission.game.tutorial_mode and object_id == 0:
		action_hint = "ACÉRCATE"
	elif mission.game.tutorial_mode and object_id == 2:
		action_hint = mission.key_name("melee")
	label.text = title + " · " + action_hint
	add_child(label)
	beacon = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42 if compact else 0.7
	ring.outer_radius = 0.55 if compact else 0.9
	beacon.mesh = ring
	beacon.position.y = 0.1
	beacon.material_override = Kit.material(Color("61dfff") if object_id < 0 else Color("ffc348"), true)
	add_child(beacon)

func interact() -> void:
	if active and not destructible and mission.interact_object(object_id):
		deactivate()

func take_damage(amount: int) -> void:
	if not active or not destructible:
		return
	if mission.game.tutorial_mode and (not is_instance_valid(mission.tutorial_guide) or not mission.tutorial_guide.accepts(object_id)):
		return
	if mission.early != null and object_id != mission.early.stage:
		return
	if mission.early != null and mission.early.guards_alive() > 0:
		mission.notify("Asegura el sector antes de destruir el objetivo", "")
		return
	if mission.game.tutorial_mode and object_id == 2 and mission.game.player.melee_flash <= 0:
		mission.notify("Usa el cuchillo contra este blanco", "")
		return
	health -= amount
	if health <= 0 and mission.interact_object(object_id):
		deactivate()

func deactivate() -> void:
	active = false
	beacon.hide()
	label.hide()
	label.text = title + " · COMPLETADO"
	label.modulate = Color("70d5a2")
	collision_layer = 0
	for child in get_children():
		if child is MeshInstance3D or child.name.begins_with("Model_"):
			child.hide()

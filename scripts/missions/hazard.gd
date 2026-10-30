extends Area3D
const Kit = preload("res://scripts/common/kit.gd")
var mission: Node
var elapsed: float = 0
var damage_wait: float = 0
var visual: MeshInstance3D
var warning: Label3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 0.8, 5)
	shape.shape = box
	add_child(shape)
	visual = Kit.box(self, Vector3(5, 0.08, 5), Vector3.ZERO, Color("ff702a"), true)
	warning = Label3D.new()
	warning.position.y = 1.2
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning.font_size = 28
	warning.pixel_size = .004
	add_child(warning)

func _physics_process(delta: float) -> void:
	if mission.game.finished:
		return
	elapsed += delta
	damage_wait -= delta
	var disabled: bool = mission.done.size() >= 3
	if mission.game.level_number <= 3:
		disabled = mission.done.has({1: 0, 2: 4, 3: 2}[mission.game.level_number])
	else:
		disabled = mission.done.has({4:4,5:5,6:2,7:3,8:4,9:3,10:4}[mission.game.level_number])
	var active: bool = fmod(elapsed, 7.0) > 4 and not disabled
	visual.visible = not disabled and (active or fmod(elapsed, 0.5) > 0.25)
	warning.text = "" if disabled else ("PELIGRO · DESCARGA" if active else "AVISO · DESCARGA EN %ds" % ceili(4 - fmod(elapsed, 7.0)))
	if active and damage_wait <= 0 and overlaps_body(mission.game.player):
		mission.game.player.take_damage(12)
		damage_wait = 0.75

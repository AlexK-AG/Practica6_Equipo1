extends StaticBody3D
## A visible, destructible relay. Its owner completes or cancels deployment.
var owner_enemy: Node3D
var health: int = 90

func _ready() -> void:
	add_to_group("enemy_deployments")
	var kit = preload("res://scripts/common/kit.gd")
	kit.model(self, "Prop_ItemHolder", Vector3(.8, 1.0, .8), Vector3(0,.5,0), Color("e58e66"))
	kit.box(self, Vector3(.45,.20,.45), Vector3(0,1.1,0), Color("ff7759"), true)
	kit.collider(self, Vector3(.9,1.3,.9), Vector3(0,.65,0))
	var label := Label3D.new()
	label.name = "Warning"
	label.text = "BALIZA DE REFUERZOS · DESTRÚYELA"
	label.position.y = 1.65
	label.font_size = 24
	label.pixel_size = .003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _process(_delta: float) -> void:
	if not is_instance_valid(owner_enemy) or owner_enemy.health <= 0 or owner_enemy.game.finished:
		queue_free()

func take_damage(amount: int) -> void:
	health -= maxi(0, amount)
	if health <= 0:
		queue_free()

extends StaticBody3D
## Player fire cannot damage the objective; attackers supply explicit context.
var defense: RefCounted

func take_damage(amount: int, context: Dictionary = {}) -> void:
	if defense != null and context.get("source","") == "enemy":
		defense.damage(amount,context)

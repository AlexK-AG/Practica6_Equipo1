extends RefCounted
## Verify authored connectivity separately from deliberate objective locks.
static func route(game: Node, from: Vector3, to: Vector3) -> PackedVector2Array:
	if game.mission.doors == null:
		return game.route(from,to)
	var saved: Dictionary = {}
	for cell in game.mission.doors.baseline:
		saved[cell] = game.grid.is_point_solid(cell)
		game.grid.set_point_solid(cell,game.mission.doors.baseline[cell])
	var path: PackedVector2Array = game.route(from,to)
	for cell in saved:
		game.grid.set_point_solid(cell,saved[cell])
	return path

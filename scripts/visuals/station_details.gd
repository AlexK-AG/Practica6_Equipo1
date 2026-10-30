extends RefCounted
## Sparse room dressing with physical cover; every authored route is checked.
const Kit = preload("res://scripts/common/kit.gd")
const THEMES := {
	1:["Prop_Computer","Prop_Crate3","Column_Astra"],2:["Prop_Crate4","Prop_Barrel_Large","Column_Astra"],
	3:["Column_Astra","Prop_Computer","Prop_Barrel_Large"],4:["Prop_Barrel_Large","Column_Astra","Prop_Crate4"],
	5:["Prop_Computer","Prop_Barrel_Large","Prop_Crate3"],6:["Column_Astra","Prop_Crate4","Prop_Computer"],
	7:["Prop_Computer","Column_Astra","Prop_Crate3"],8:["Prop_Crate4","Column_Astra","Prop_Barrel_Large"],
	9:["Prop_Crate3","Prop_Computer","Column_Astra"],10:["Column_Astra","Prop_Computer","Prop_Crate4"]}

static func populate(game: Node3D) -> int:
	var arena: Node3D = game.get_node("Arena")
	if arena.has_node("Details"):return 0
	var group := Node3D.new()
	group.name = "Details"
	arena.add_child(group)
	var protected: Array[Vector3] = [game.player.position]
	if not game.tutorial_mode:
		var plans: Dictionary = preload("res://scripts/missions/early_missions.gd").PLANS if game.level_number <= 3 else preload("res://scripts/missions/late_missions.gd").PLANS
		for point in plans[game.level_number].points:protected.append(point)
	for point in game.get_node("MissionPoints").get_children():
		if point is Marker3D:protected.append(point.position)
	for enemy in game.get_children():
		if enemy is EnemyController:protected.append(enemy.position)
	var anchors: Array[Vector3] = []
	for point in protected:
		if game.route(game.player.position,point).size() > 0:anchors.append(point)
	var existing: Array[Vector3] = []
	for body in arena.get_children():
		if body is StaticBody3D and str(body.name).begins_with("Cover"):existing.append(body.position)
	var count := 0
	var room_index := 0
	for floor_node in arena.get_children():
		if not str(floor_node.name).begins_with("Floor"):continue
		var shape: CollisionShape3D = floor_node.get_node("Collision")
		var floor_size: Vector3 = shape.shape.size
		if floor_size.x < 12 or floor_size.z < 10:continue
		var center: Vector3 = floor_node.position
		var limit := 3 if floor_size.x * floor_size.z > 320 else 2
		var room_count := 0
		for corner in [Vector2(-1,-1),Vector2(1,1),Vector2(1,-1),Vector2(-1,1)]:
			if room_count >= limit:break
			var point := Vector3(center.x + corner.x * (floor_size.x / 2 - 2.6),.05,center.z + corner.y * (floor_size.z / 2 - 2.6))
			var crowded := false
			for target in protected:
				if point.distance_to(target) < 3:crowded = true
			for target in existing:
				if point.distance_to(target) < 2.3:crowded = true
			if crowded:continue
			var model: String = THEMES[game.level_number][(room_index + room_count) % 3]
			var size: Vector3 = {"Column_Astra":Vector3(.8,4.05,.8),"Prop_Computer":Vector3(1,1.5,.8),"Prop_Barrel_Large":Vector3(.95,1.45,.95),"Prop_Crate3":Vector3(1.25,1.15,1.25),"Prop_Crate4":Vector3(1.3,1.4,1.3)}[model]
			var changed: Dictionary = {}
			for x in range(floori(point.x - size.x / 2 - .6),ceili(point.x + size.x / 2 + .6) + 1):
				for z in range(floori(point.z - size.z / 2 - .6),ceili(point.z + size.z / 2 + .6) + 1):
					if absf(x - point.x) >= size.x / 2 + .6 or absf(z - point.z) >= size.z / 2 + .6:continue
					var cell := Vector2i(x,z)
					changed[cell] = game.grid.is_point_solid(cell)
					game.grid.set_point_solid(cell,true)
			var connected := true
			for target in anchors:
				if game.route(game.player.position,target).is_empty():
					connected = false
					break
			if not connected:
				for cell in changed:game.grid.set_point_solid(cell,changed[cell])
				continue
			var prop := StaticBody3D.new()
			prop.name = "Dressing%d" % count
			prop.position = point
			group.add_child(prop)
			Kit.model(prop,model,size,Vector3(0,size.y / 2,0))
			Kit.collider(prop,size,Vector3(0,size.y / 2,0))
			existing.append(point)
			count += 1
			room_count += 1
		# Wall equipment stays above player height and cannot obstruct an entrance.
		var fixture := Node3D.new()
		fixture.name = "MountedEquipment%d" % room_index
		fixture.position = Vector3(center.x - floor_size.x * .24,2.6,center.z - floor_size.z / 2 + .3)
		group.add_child(fixture)
		Kit.model(fixture,"Prop_Vent_Small" if room_index % 2 == 0 else "Prop_Fan_Small",Vector3(.8,.65,.18),Vector3.ZERO)
		Kit.model(fixture,"Prop_Cable_1",Vector3(.12,.9,.12),Vector3(.6,-.15,0))
		room_index += 1
	group.set_meta("solid_props",count)
	return count

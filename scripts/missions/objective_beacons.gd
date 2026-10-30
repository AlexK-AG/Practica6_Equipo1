extends Control
## Screen-space signs remain readable through walls and at viewport edges.
var mission: Node
var signs: Array[PanelContainer] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for item in mission.objects:
		var compact: bool = true
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.04, 0.08, 0.65 if compact else 0.88)
		style.border_color = Color("ffc965")
		style.set_border_width_all(1 if compact else 2)
		style.content_margin_left = 6 if compact else 10
		style.content_margin_right = 6 if compact else 10
		style.content_margin_top = 3 if compact else 5
		style.content_margin_bottom = 3 if compact else 5
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.name = "Text"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("ffdc80"))
		panel.add_child(label)
		add_child(panel)
		signs.append(panel)

func _process(_delta: float) -> void:
	if not is_instance_valid(mission) or mission.game.finished:
		hide()
		return
	var camera: Camera3D = mission.game.player.camera
	var viewport_size := get_viewport_rect().size
	var occupied: Array[Rect2] = []
	for i in range(signs.size()):
		var item: Node3D = mission.objects[i]
		var panel := signs[i]
		var distance := camera.global_position.distance_to(item.global_position)
		if mission.game.tutorial_mode and is_instance_valid(mission.tutorial_guide):
			var shown: bool = item.active and mission.tutorial_guide.accepts(item.object_id)
			item.label.visible = shown and distance < 16
			panel.visible = shown
			if not shown:
				continue
		item.label.visible = item.active and distance < 16
		panel.visible = item.active and (item.object_id >= 0 or distance < 22)
		if mission.early != null and item.object_id >= 0:
			panel.visible = item.active and item.object_id == mission.early.stage
		if item.title == "RESERVA OCULTA":
			panel.visible = item.active and distance < 5
		if mission.game.tutorial_mode:
			panel.visible = item.active and mission.tutorial_guide.accepts(item.object_id)
		if not panel.visible:
			continue
		var locked: bool = item.object_id == mission.objective_count - 1 and mission.done.size() < mission.objective_count - 1
		if item.object_id == mission.objective_count - 1:
			if mission.game.level_number == 2:
				locked = locked or mission.wave < mission.WAVE_SIZES.size() or mission.wave_remaining > 0 or mission.living_enemies() > 0
			elif mission.game.level_number in [7, 8]:
				locked = locked or mission.defense_time != 0
			elif mission.game.level_number in [5, 6, 10]:
				locked = locked or mission.living_enemies() > 0
				if mission.game.level_number == 5:
					locked = locked or mission.defense_time != 0
		var label: Label = panel.get_node("Text")
		var compact: bool = true
		label.text = "%s %s · %dm%s" % ["◆" if item.object_id >= 0 else "▣", item.title, roundi(distance), (" · bloqueada" if compact else "\nREQUISITOS PENDIENTES") if locked else ""]
		label.add_theme_color_override("font_color", Color("88e8ff") if item.object_id < 0 else (Color("b3b6c3") if locked else Color("ffdc80")))
		var point := item.global_position + Vector3.UP * 2.6
		var projected: Vector2 = camera.unproject_position(point)
		if camera.is_position_behind(point):
			var local := camera.to_local(point)
			projected = viewport_size / 2 + Vector2(local.x, -local.y - 0.5).normalized() * viewport_size
		var width := maxf(100, panel.get_combined_minimum_size().x)
		var height := maxf(24, panel.get_combined_minimum_size().y)
		panel.size = Vector2(width, height)
		var pos := Vector2(clampf(projected.x - width / 2, 18, viewport_size.x - width - 18), clampf(projected.y, 250, viewport_size.y - height - 65))
		if mission.game.tutorial_mode:
			var guide_rect: Rect2 = mission.tutorial_guide.panel.get_global_rect()
			if Rect2(pos,panel.size).intersects(guide_rect.grow(8)):
				pos.y = minf(guide_rect.end.y + 12,viewport_size.y - height - 65)
		var rectangle := Rect2(pos, panel.size)
		for other in occupied:
			if rectangle.intersects(other):
				rectangle.position.y = minf(other.end.y + 8, viewport_size.y - height - 65)
		panel.position = rectangle.position
		occupied.append(rectangle)

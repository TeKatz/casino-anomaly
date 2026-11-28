extends SceneTree
const Targets = preload("res://addons/casino_model_preview/voxel_bake_targets.gd")
const Baker = preload("res://tools/bake_backrooms_voxel_gi.gd")
## Standalone geometry/asset QA. Run after Godot editor import.
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func world_point(p: Array) -> Vector2:
	return Vector2((float(p[0]) - 625.0) / 32.0, (float(p[1]) - 633.0) / 32.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://backrooms/backrooms_labyrinth.tscn") as PackedScene
	if packed == null:
		push_error("Backrooms scene could not load")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://backrooms/sketch_02_layout.json"))
	var walls := scene.get_node("Architecture/Walls")
	check(walls.get_child_count() == 43, "Expected 43 saved wall bodies")
	var rects: Array[Rect2] = []
	for spec: Dictionary in layout["walls"]:
		var body := walls.get_node_or_null(str(spec["name"])) as StaticBody3D
		check(body != null, "Missing native wall: " + str(spec["name"]))
		if body == null:
			continue
		var a := world_point(spec["from"])
		var b := world_point(spec["to"])
		var mid := (a + b) * 0.5
		var size := Vector3(absf(b.x-a.x)+0.4, 3.0, absf(b.y-a.y)+0.4)
		check(body.position.is_equal_approx(Vector3(mid.x,1.5,mid.y)), "Wall center: " + str(spec["name"]))
		var visual := body.get_node("Mesh") as MeshInstance3D
		var collider := body.get_node("Collision") as CollisionShape3D
		check(visual.mesh is BoxMesh and (visual.mesh as BoxMesh).size.is_equal_approx(size), "Wall mesh size: " + str(spec["name"]))
		check(collider.shape is BoxShape3D and (collider.shape as BoxShape3D).size.is_equal_approx(size), "Wall collision size: " + str(spec["name"]))
		check(body.owner == scene and visual.owner == scene and collider.owner == scene, "Wall not saved as editor-owned nodes: " + str(spec["name"]))
		rects.append(Rect2(mid-Vector2(size.x,size.z)*0.5, Vector2(size.x,size.z)).grow(0.35))
	# 0.25 m grid, conservative 0.35 m player-radius clearance from wall edges.
	var start := world_point(layout["entry_px"])
	var target := world_point(layout["exit_px"])
	var open_cells: Dictionary = {}
	var grid_origin := Vector2(-16.5,-13.25)
	for y in range(107):
		for x in range(133):
			var cell := Vector2i(x,y)
			var p := grid_origin + Vector2(cell)*0.25
			if absf(p.x) > 16.18 or absf(p.y) > 12.9:
				continue
			var blocked := false
			for rect in rects:
				if rect.has_point(p):
					blocked = true
					break
			if not blocked:
				open_cells[cell] = true
	var source_cell := Vector2i(((start-grid_origin)/0.25).round())
	var end_cell := Vector2i(((target-grid_origin)/0.25).round())
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	if open_cells.has(source_cell):
		queue.append(source_cell)
		seen[source_cell] = true
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + step
			if open_cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	check(seen.has(end_cell), "Entrance cannot reach exit")
	for point: Array in layout["accessible_points_px"]:
		var cell := Vector2i(((world_point(point)-grid_origin)/0.25).round())
		check(seen.has(cell), "Expected accessible room: " + str(point))
	var sealed := Vector2i(((world_point(layout["intentionally_sealed_px"])-grid_origin)/0.25).round())
	check(open_cells.has(sealed) and not seen.has(sealed), "Sealed rectangle differs from selected sketch")
	for path in ["Architecture/Floor", "Architecture/Ceiling"]:
		var body := scene.get_node(path) as StaticBody3D
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var shape := body.get_node("Collision") as CollisionShape3D
		check((mesh.mesh as BoxMesh).size.is_equal_approx((shape.shape as BoxShape3D).size), "Slab collision mismatch: " + path)
	for path in ["wall","floor","ceiling"]:
		var material := load("res://backrooms/materials/"+path+".tres") as StandardMaterial3D
		check(material != null and material.albedo_texture != null and material.uv1_triplanar, "Missing native Oxygen material: " + path)
	var fixtures := scene.get_node("Lighting/CeilingFixtures")
	check(fixtures.get_child_count() == 17, "Expected 17 native editable ceiling fixtures")
	var active := 0
	for fixture in fixtures.get_children():
		var spot := fixture.get_node("Downlight") as SpotLight3D
		check(spot != null and spot.shadow_enabled and spot.light_energy <= 0.217, "Invalid fixture " + str(fixture.name))
		if spot != null and spot.visible:
			active += 1
	check(active == 14, "Expected 14 dim active spots")
	var probe := scene.get_node_or_null("Lighting/BackroomsVoxelGI") as VoxelGI
	if probe == null or not probe.has_method("reload_baked_data"):
		push_error("Backrooms VoxelGI probe or its reload script is missing from the saved scene")
		scene.free()
		quit(1)
		return
	check(probe.size.x >= 33.5 and probe.size.z >= 27.0, "Missing room-local VoxelGI probe")
	check(probe.subdiv == VoxelGI.SUBDIV_128, "Unexpected VoxelGI resolution")
	check(probe.get_script().resource_path == "res://backrooms/voxel_gi.gd", "Wrong VoxelGI reload script")
	# Both menu routes stay isolated; unknown scenes never launch a bake.
	check(Targets.for_scene(Targets.CASINO_SCENE).get("script") == "res://tools/bake_voxel_gi.gd", "Casino bake route changed")
	check(Targets.for_scene(Targets.BACKROOMS_SCENE).get("script") == "res://tools/bake_backrooms_voxel_gi.gd", "Backrooms bake route missing")
	check(Targets.for_scene(Targets.BACKROOMS_SCENE).get("output") == "res://backrooms/backrooms_voxel_gi.res", "Backrooms bake output changed")
	check(Targets.for_scene("res://ui/menu.tscn").is_empty() and Targets.process_args("res://ui/menu.tscn", ".").is_empty(), "Unsupported scene routes to baker")
	var args := Targets.process_args(Targets.BACKROOMS_SCENE, ".")
	check(args.has("forward_plus") and not args.has("--headless"), "Offline process must use Forward+ GPU")
	if not FileAccess.file_exists(Targets.BACKROOMS_OUTPUT):
		check(not bool(probe.call("reload_baked_data")) and probe.data == null, "Missing bake must safely use direct light")
	Baker.prepare_lights(scene)
	for fixture in fixtures.get_children():
		var spot := fixture.get_node("Downlight") as SpotLight3D
		if not spot.visible:
			check(spot.light_bake_mode == Light3D.BAKE_DISABLED, "Hidden fixture participates in bake")
		else:
			check(spot.light_bake_mode == Light3D.BAKE_STATIC, "Active fixture's authored bake mode changed")
	var first := walls.get_child(0) as StaticBody3D
	var old: Vector3 = first.get("dimensions")
	first.set("dimensions", old + Vector3(0.2, 0.0, 0.0))
	var first_mesh := first.get_node("Mesh") as MeshInstance3D
	var first_shape := first.get_node("Collision") as CollisionShape3D
	check((first_mesh.mesh as BoxMesh).size.is_equal_approx((first_shape.shape as BoxShape3D).size), "Editor resize must synchronize collision")
	first.set("dimensions", old)
	scene.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Backrooms sketch 02 native layout QA PASS")
	quit(0)

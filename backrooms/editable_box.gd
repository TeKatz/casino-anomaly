@tool
extends StaticBody3D
## The scene stores both the native box mesh and its matching native collider.
## Edit Dimensions on this body rather than scaling its visual child.

@export var dimensions: Vector3 = Vector3.ONE:
	set(value):
		dimensions = Vector3(maxf(0.05, value.x), maxf(0.05, value.y), maxf(0.05, value.z))
		if is_node_ready():
			_sync_dimensions()

func _ready() -> void:
	_sync_dimensions()

func _sync_dimensions() -> void:
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	var collider := get_node_or_null("Collision") as CollisionShape3D
	if visual == null or collider == null:
		return
	var box := visual.mesh as BoxMesh
	var shape := collider.shape as BoxShape3D
	if box != null and not box.size.is_equal_approx(dimensions):
		box.size = dimensions
	if shape != null and not shape.size.is_equal_approx(dimensions):
		shape.size = dimensions

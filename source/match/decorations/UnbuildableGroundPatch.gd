@tool
extends Node3D

@export var footprint_size := Vector2i.ONE:
	set(value):
		footprint_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_update_visual()
		update_configuration_warnings()

@export var color := Color(0.24, 0.14, 0.08):
	set(value):
		color = value
		_update_visual()


func _ready():
	_update_visual()


func get_blocked_structure_grid_cells() -> Array[Vector2i]:
	return Utils.Match.StructureGrid.occupied_cells(global_position, footprint_size, global_basis)


func _update_visual():
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var plane_mesh := mesh_instance.mesh as PlaneMesh
	plane_mesh.size = Vector2(footprint_size) * Utils.Match.StructureGrid.CELL_SIZE
	var material := plane_mesh.material as StandardMaterial3D
	material.albedo_color = color


func _get_configuration_warnings():
	var warnings := PackedStringArray()
	var quarter_turn := roundi(rotation.y / (PI / 2.0))
	if (
		not is_zero_approx(rotation.x)
		or not is_zero_approx(rotation.z)
		or not is_equal_approx(rotation.y, quarter_turn * PI / 2.0)
	):
		warnings.append("Rotation must use quarter turns around the Y axis.")
	var quantized_basis := Utils.Match.StructureGrid.quantize_basis(global_basis)
	var snapped_position := Utils.Match.StructureGrid.snap_position(
		global_position, footprint_size, quantized_basis
	)
	if not (global_position * Vector3(1, 0, 1)).is_equal_approx(
		snapped_position * Vector3(1, 0, 1)
	):
		warnings.append("Position must align with the structure grid.")
	return warnings

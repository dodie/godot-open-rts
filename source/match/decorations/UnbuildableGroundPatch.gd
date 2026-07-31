@tool
extends Node3D

const EDGE_FADE_WIDTH := 0.12
const VISUAL_MARGIN := 0.40

@export var footprint_size := Vector2i.ONE:
	set(value):
		footprint_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_update_visual()
		update_configuration_warnings()

@export var color := Color(0.24, 0.14, 0.08):
	set(value):
		color = value
		_update_visual()

@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:m") var corner_radius := 0.45:
	set(value):
		corner_radius = maxf(value, 0.0)
		_update_visual()

@export_range(0.0, 1.0, 0.01) var texture_strength := 0.22:
	set(value):
		texture_strength = clampf(value, 0.0, 1.0)
		_update_visual()

@export_range(0.01, 20.0, 0.01, "or_greater") var texture_scale := 2.0:
	set(value):
		texture_scale = maxf(value, 0.01)
		_update_visual()


func _ready():
	set_notify_transform(true)
	_update_visual()


func _notification(what: int):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_queue_region_join_update()


func get_blocked_structure_grid_cells() -> Array[Vector2i]:
	return Utils.Match.StructureGrid.occupied_cells(global_position, footprint_size, global_basis)


func _update_visual():
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var plane_mesh := mesh_instance.mesh as PlaneMesh
	var patch_size := Vector2(footprint_size) * Utils.Match.StructureGrid.CELL_SIZE
	plane_mesh.size = patch_size + Vector2.ONE * VISUAL_MARGIN * 2.0
	var material := plane_mesh.material as ShaderMaterial
	material.set_shader_parameter("patch_size", patch_size)
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("corner_radius", corner_radius)
	material.set_shader_parameter("texture_strength", texture_strength)
	material.set_shader_parameter("texture_scale", texture_scale)
	material.set_shader_parameter("edge_fade_width", EDGE_FADE_WIDTH)
	_queue_region_join_update()


func _set_visual_cutouts(cutouts: PackedVector4Array):
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var material := (mesh_instance.mesh as PlaneMesh).material as ShaderMaterial
	var cutout_count := mini(cutouts.size(), 16)
	var shader_cutouts := PackedVector4Array()
	shader_cutouts.resize(16)
	for index in cutout_count:
		shader_cutouts[index] = cutouts[index]
	material.set_shader_parameter("cutout_count", cutout_count)
	material.set_shader_parameter("cutouts", shader_cutouts)


func _queue_region_join_update():
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_method("_queue_join_update"):
		parent_node._queue_join_update()


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

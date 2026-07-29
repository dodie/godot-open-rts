extends Node3D

const Structure = preload("res://source/match/units/Structure.gd")

const CELL_PADDING := 0.1
const GRID_HEIGHT := 0.015
const GRID_COLOR := Color(0.0, 0.45, 1.0)
const TERRAIN_BLOCKED_COLOR := Color(1.0, 0.05, 0.05)
const PREVIEW_COLOR := Color(0.0, 0.16, 0.45)
const EMPTY_CELL_OPACITY := 0.2
const OCCUPIED_CELL_OPACITY := 0.4
const TERRAIN_BLOCKED_CELL_OPACITY := 0.4
const PREVIEW_CELL_OPACITY := 0.55
const STRUCTURE_NAVIGATION_PADDING_CELLS := ceili(
	Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS / Utils.Match.StructureGrid.CELL_SIZE
)

var _map_size := Vector2.ZERO
var _navigation_map_rid := RID()
var _structures := []
var _empty_cells := MultiMeshInstance3D.new()
var _occupied_cells := MultiMeshInstance3D.new()
var _terrain_blocked_cells := MultiMeshInstance3D.new()
var _preview_cells := MultiMeshInstance3D.new()


func _ready():
	top_level = true
	_empty_cells.name = "EmptyCells"
	_occupied_cells.name = "OccupiedCells"
	_terrain_blocked_cells.name = "TerrainBlockedCells"
	_preview_cells.name = "PreviewCells"
	add_child(_empty_cells)
	add_child(_occupied_cells)
	add_child(_terrain_blocked_cells)
	add_child(_preview_cells)
	_empty_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_occupied_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_blocked_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_empty_cells.multimesh = _create_multimesh(GRID_COLOR, EMPTY_CELL_OPACITY)
	_occupied_cells.multimesh = _create_multimesh(GRID_COLOR, OCCUPIED_CELL_OPACITY)
	_terrain_blocked_cells.multimesh = _create_multimesh(
		TERRAIN_BLOCKED_COLOR, TERRAIN_BLOCKED_CELL_OPACITY
	)
	_preview_cells.multimesh = _create_multimesh(PREVIEW_COLOR, PREVIEW_CELL_OPACITY)
	hide()


func show_grid(map_size: Vector2, navigation_map_rid: RID, structures):
	_map_size = map_size
	_navigation_map_rid = navigation_map_rid
	refresh(structures)
	set_preview([])
	show()


func refresh(structures):
	if _map_size == Vector2.ZERO:
		return
	_structures = structures.filter(func(unit): return unit is Structure)
	var occupied = {}
	for structure in _structures:
		for cell in Utils.Match.StructureGrid.occupied_cells(
			structure.global_position, structure.footprint_size, structure.global_basis
		):
			if Utils.Match.StructureGrid.cell_is_inside_map(cell, _map_size):
				occupied[cell] = true

	var empty_transforms: Array[Transform3D] = []
	var occupied_transforms: Array[Transform3D] = []
	var terrain_blocked_transforms: Array[Transform3D] = []
	var cell_count_x := floori(_map_size.x / Utils.Match.StructureGrid.CELL_SIZE)
	var cell_count_z := floori(_map_size.y / Utils.Match.StructureGrid.CELL_SIZE)
	for x in range(cell_count_x):
		for z in range(cell_count_z):
			var cell := Vector2i(x, z)
			var cell_transform := Transform3D(
				Basis(), Utils.Match.StructureGrid.cell_center(cell, GRID_HEIGHT)
			)
			if occupied.has(cell):
				occupied_transforms.append(cell_transform)
			elif not _cell_is_navigable(cell):
				terrain_blocked_transforms.append(cell_transform)
			else:
				empty_transforms.append(cell_transform)
	_set_instances(_empty_cells.multimesh, empty_transforms)
	_set_instances(_occupied_cells.multimesh, occupied_transforms)
	_set_instances(_terrain_blocked_cells.multimesh, terrain_blocked_transforms)


func _cell_is_navigable(cell: Vector2i) -> bool:
	var point := Utils.Match.StructureGrid.cell_center(cell)
	var closest_point := NavigationServer3D.map_get_closest_point(_navigation_map_rid, point)
	if (point * Vector3(1, 0, 1)).is_equal_approx(closest_point * Vector3(1, 0, 1)):
		return true
	# Structure geometry is baked into the unit navigation map with agent clearance.
	# Placement occupancy is footprint-based, so ignore that clearance ring here.
	for structure in _structures:
		if Utils.Match.StructureGrid.cell_is_within_footprint_padding(
			cell,
			structure.global_position,
			structure.footprint_size,
			structure.global_basis,
			STRUCTURE_NAVIGATION_PADDING_CELLS
		):
			return true
	return false


func set_preview(cells):
	var transforms: Array[Transform3D] = []
	for cell in cells:
		if not Utils.Match.StructureGrid.cell_is_inside_map(cell, _map_size):
			continue
		transforms.append(
			Transform3D(Basis(), Utils.Match.StructureGrid.cell_center(cell, GRID_HEIGHT + 0.002))
		)
	_set_instances(_preview_cells.multimesh, transforms)


func _create_multimesh(color: Color, opacity: float) -> MultiMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, opacity)

	var cell_mesh := PlaneMesh.new()
	cell_mesh.size = Vector2.ONE * (Utils.Match.StructureGrid.CELL_SIZE - CELL_PADDING)
	cell_mesh.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cell_mesh
	return multimesh


func _set_instances(multimesh: MultiMesh, transforms: Array[Transform3D]):
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])

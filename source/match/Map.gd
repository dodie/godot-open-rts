@tool
extends Node3D

# TODO: add editor-only 2nd pass shader to 'Terrain' mesh highlighting map boundries

const EXTRA_MARGIN = 2

@export var size = Vector2(50, 50):
	set(a_size):
		size = a_size
		find_child("Terrain").mesh.size = size + Vector2(EXTRA_MARGIN, EXTRA_MARGIN) * 2
		find_child("Terrain").mesh.center_offset = Vector3(size.x, 0.0, size.y) / 2.0

var _structure_placement_blocked_cells = null


func get_topdown_polygon_2d():
	return [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]


func is_structure_placement_cell_buildable(cell: Vector2i) -> bool:
	_index_structure_placement_blocked_cells()
	return not _structure_placement_blocked_cells.has(cell)


func is_structure_footprint_buildable(position: Vector3, footprint: Vector2i, basis: Basis) -> bool:
	for cell in Utils.Match.StructureGrid.occupied_cells(position, footprint, basis):
		if not is_structure_placement_cell_buildable(cell):
			return false
	return true


func _index_structure_placement_blocked_cells():
	if _structure_placement_blocked_cells != null:
		return
	_structure_placement_blocked_cells = {}
	for blocker in get_tree().get_nodes_in_group("structure_placement_blockers"):
		if not is_ancestor_of(blocker):
			continue
		assert(blocker.has_method("get_blocked_structure_grid_cells"))
		for cell in blocker.get_blocked_structure_grid_cells():
			_structure_placement_blocked_cells[cell] = true

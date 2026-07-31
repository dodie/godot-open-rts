@tool
extends Node3D

var _join_update_queued := false


func _ready():
	_queue_join_update()


func _queue_join_update():
	if _join_update_queued or not is_inside_tree():
		return
	_join_update_queued = true
	_rebuild_rounded_joins.call_deferred()


func _rebuild_rounded_joins():
	_join_update_queued = false
	var patches := _get_patches()
	if patches.is_empty():
		return

	var blocked_cells := {}
	var cells_by_patch := {}
	for patch in patches:
		var patch_cells := {}
		for cell in patch.get_blocked_structure_grid_cells():
			blocked_cells[cell] = true
			patch_cells[cell] = true
		cells_by_patch[patch] = patch_cells

	var candidate_vertices := {}
	for cell in blocked_cells:
		candidate_vertices[cell] = true
		candidate_vertices[cell + Vector2i.RIGHT] = true
		candidate_vertices[cell + Vector2i.DOWN] = true
		candidate_vertices[cell + Vector2i.ONE] = true

	var cutouts_by_patch := {}
	for patch in patches:
		cutouts_by_patch[patch] = PackedVector4Array()

	for vertex in candidate_vertices:
		if _blocked_cell_count_around_vertex(vertex, blocked_cells) == 3:
			var center := Vector2(vertex) * Utils.Match.StructureGrid.CELL_SIZE
			var direction := _missing_quadrant_direction(vertex, blocked_cells)
			var cutout := Vector4(center.x, center.y, direction.x, direction.y)
			for patch in patches:
				if _patch_touches_vertex(vertex, cells_by_patch[patch]):
					var patch_cutouts: PackedVector4Array = cutouts_by_patch[patch]
					patch_cutouts.append(cutout)
					cutouts_by_patch[patch] = patch_cutouts

	for patch in patches:
		patch._set_visual_cutouts(cutouts_by_patch[patch])


func _get_patches() -> Array[Node]:
	var patches: Array[Node] = []
	for child in get_children():
		if child.is_in_group("structure_placement_blockers"):
			patches.append(child)
	return patches


func _blocked_cell_count_around_vertex(vertex: Vector2i, blocked_cells: Dictionary) -> int:
	var count := 0
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		if blocked_cells.has(vertex + offset):
			count += 1
	return count


func _patch_touches_vertex(vertex: Vector2i, patch_cells: Dictionary) -> bool:
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		if patch_cells.has(vertex + offset):
			return true
	return false


func _missing_quadrant_direction(vertex: Vector2i, blocked_cells: Dictionary) -> Vector2:
	var quadrants := {
		Vector2i(-1, -1): Vector2(-1.0, -1.0),
		Vector2i(0, -1): Vector2(1.0, -1.0),
		Vector2i(-1, 0): Vector2(-1.0, 1.0),
		Vector2i.ZERO: Vector2(1.0, 1.0),
	}
	for cell_offset in quadrants:
		if not blocked_cells.has(vertex + cell_offset):
			return quadrants[cell_offset]
	return Vector2.ONE

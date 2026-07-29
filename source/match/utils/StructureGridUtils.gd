const CELL_SIZE := 1.0


static func oriented_footprint(footprint: Vector2i, basis: Basis) -> Vector2i:
	var local_x := basis * Vector3.RIGHT
	if abs(local_x.z) > abs(local_x.x):
		return Vector2i(footprint.y, footprint.x)
	return footprint


static func snap_position(position: Vector3, footprint: Vector2i, basis: Basis) -> Vector3:
	var oriented_size := oriented_footprint(footprint, basis)
	var anchor := Vector2i(
		roundi(position.x / CELL_SIZE - oriented_size.x / 2.0),
		roundi(position.z / CELL_SIZE - oriented_size.y / 2.0)
	)
	return Vector3(
		(anchor.x + oriented_size.x / 2.0) * CELL_SIZE,
		position.y,
		(anchor.y + oriented_size.y / 2.0) * CELL_SIZE
	)


static func occupied_cells(position: Vector3, footprint: Vector2i, basis: Basis) -> Array[Vector2i]:
	var oriented_size := oriented_footprint(footprint, basis)
	var snapped := snap_position(position, footprint, basis)
	var anchor := Vector2i(
		roundi(snapped.x / CELL_SIZE - oriented_size.x / 2.0),
		roundi(snapped.z / CELL_SIZE - oriented_size.y / 2.0)
	)
	var cells: Array[Vector2i] = []
	for x in range(anchor.x, anchor.x + oriented_size.x):
		for z in range(anchor.y, anchor.y + oriented_size.y):
			cells.append(Vector2i(x, z))
	return cells


static func cell_is_within_footprint_padding(
	cell: Vector2i, position: Vector3, footprint: Vector2i, basis: Basis, padding: int
) -> bool:
	var occupied := occupied_cells(position, footprint, basis)
	var minimum := occupied[0]
	var maximum := occupied[0]
	for occupied_cell in occupied:
		minimum.x = mini(minimum.x, occupied_cell.x)
		minimum.y = mini(minimum.y, occupied_cell.y)
		maximum.x = maxi(maximum.x, occupied_cell.x)
		maximum.y = maxi(maximum.y, occupied_cell.y)
	return (
		cell.x >= minimum.x - padding
		and cell.x <= maximum.x + padding
		and cell.y >= minimum.y - padding
		and cell.y <= maximum.y + padding
	)


static func cell_center(cell: Vector2i, y := 0.0) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, y, (cell.y + 0.5) * CELL_SIZE)


static func cell_is_inside_map(cell: Vector2i, map_size: Vector2) -> bool:
	var minimum := Vector2(cell.x, cell.y) * CELL_SIZE
	var maximum := minimum + Vector2.ONE * CELL_SIZE
	return (
		minimum.x >= 0.0
		and minimum.y >= 0.0
		and maximum.x <= map_size.x
		and maximum.y <= map_size.y
	)


static func quantize_basis(basis: Basis) -> Basis:
	var quarter_turn := roundi(basis.get_euler().y / (PI / 2.0))
	return Basis(Vector3.UP, quarter_turn * PI / 2.0)

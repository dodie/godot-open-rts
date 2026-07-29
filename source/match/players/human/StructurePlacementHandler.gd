extends Node3D

enum BlueprintPositionValidity {
	VALID,
	COLLIDES_WITH_OBJECT,
	NOT_BUILDABLE,
	NOT_NAVIGABLE,
	NOT_ENOUGH_RESOURCES,
	OUT_OF_MAP,
}

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const StructureGridOverlay = preload("res://source/match/players/human/StructureGridOverlay.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")

const ROTATION_BY_KEY_STEP = 90.0
const ROTATION_DEAD_ZONE_DISTANCE = 0.1
const TOUCH_LONG_PRESS_DURATION_SECONDS = 0.6
const TOUCH_LONG_PRESS_MOVEMENT_TOLERANCE = 20.0
const STRUCTURE_NAVIGATION_PADDING_CELLS := ceili(
	Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS / Utils.Match.StructureGrid.CELL_SIZE
)

const MATERIALS_ROOT = "res://source/match/resources/materials/"
const BLUEPRINT_VALID_PATH = MATERIALS_ROOT + "blueprint_valid.material.tres"
const BLUEPRINT_INVALID_PATH = MATERIALS_ROOT + "blueprint_invalid.material.tres"

var _active_blueprint_node = null
var _pending_structure_footprint = Vector2i.ONE
var _pending_structure_navmap_rid = null
var _pending_structure_prototype = null
var _blueprint_rotating = false
var _using_touch_input = false
var _placement_touch_index = -1
var _placement_touch_started_at_msec = 0
var _placement_touch_start_position = Vector2.ZERO
var _placement_touch_cancelled = false
var _grid_overlay = null

@onready var _player = get_parent()
@onready var _match = find_parent("Match")
@onready var _feedback_label = find_child("FeedbackLabel3D")


func _ready():
	_feedback_label.hide()
	_grid_overlay = StructureGridOverlay.new()
	add_child(_grid_overlay)
	MatchSignals.place_structure.connect(_on_structure_placement_request)
	MatchSignals.unit_spawned.connect(_on_unit_grid_occupancy_changed)
	MatchSignals.unit_died.connect(_on_unit_grid_occupancy_changed)


func _process(_delta):
	if not _using_touch_input or not _structure_placement_started():
		return
	_set_blueprint_position_to_screen_center()
	_update_blueprint_validity_feedback()
	if _placement_touch_index == -1 or _placement_touch_cancelled:
		return
	if (
		Time.get_ticks_msec() - _placement_touch_started_at_msec
		>= TOUCH_LONG_PRESS_DURATION_SECONDS * 1000.0
	):
		_placement_touch_cancelled = true
		_cancel_structure_placement()


func _input(event):
	if event is InputEventScreenTouch:
		_using_touch_input = true
		if not _structure_placement_started():
			return
		_match.handle_screen_touch_during_structure_placement(event)
		get_viewport().set_input_as_handled()
		if event.pressed and _placement_touch_index == -1:
			_placement_touch_index = event.index
			_placement_touch_started_at_msec = Time.get_ticks_msec()
			_placement_touch_start_position = event.position
			_placement_touch_cancelled = false
		elif event.pressed:
			_placement_touch_cancelled = true
		elif not event.pressed and event.index == _placement_touch_index:
			_placement_touch_index = -1
			if not _placement_touch_cancelled:
				_try_finishing_structure_placement()
	elif event is InputEventScreenDrag and _using_touch_input and _structure_placement_started():
		_match.handle_screen_drag_during_structure_placement(event)
		get_viewport().set_input_as_handled()
		if (
			event.index == _placement_touch_index
			and (
				event.position.distance_to(_placement_touch_start_position)
				> TOUCH_LONG_PRESS_MOVEMENT_TOLERANCE
			)
		):
			_placement_touch_cancelled = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_using_touch_input = false


func _unhandled_input(event):
	if not _structure_placement_started():
		return
	if _using_touch_input and event is InputEventMouseButton:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_lmb_down_event(event)
	if event.is_action_pressed("rotate_structure"):
		_try_rotating_blueprint_by(ROTATION_BY_KEY_STEP)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_handle_lmb_up_event(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_rmb_event(event)
	if event is InputEventMouseMotion:
		_handle_mouse_motion_event(event)


func _handle_lmb_down_event(_event):
	get_viewport().set_input_as_handled()
	_start_blueprint_rotation()


func _handle_lmb_up_event(_event):
	get_viewport().set_input_as_handled()
	_try_finishing_structure_placement()
	_finish_blueprint_rotation()


func _try_finishing_structure_placement():
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	if blueprint_position_validity == BlueprintPositionValidity.VALID:
		_finish_structure_placement()
	elif blueprint_position_validity == BlueprintPositionValidity.COLLIDES_WITH_OBJECT:
		_move_owned_ground_units_out_of_blueprint()
	elif blueprint_position_validity == BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
		MatchSignals.not_enough_resources_for_construction.emit(_player)


func _handle_rmb_event(event):
	get_viewport().set_input_as_handled()
	if event.pressed:
		_finish_blueprint_rotation()
		_cancel_structure_placement()


func _handle_mouse_motion_event(_event):
	get_viewport().set_input_as_handled()
	if _blueprint_rotation_started():
		_rotate_blueprint_towards_mouse_pos()
	else:
		_set_blueprint_position_based_on_mouse_pos()
	_update_blueprint_validity_feedback()


func _update_blueprint_validity_feedback():
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	_update_feedback_label(blueprint_position_validity)
	_update_blueprint_color(blueprint_position_validity == BlueprintPositionValidity.VALID)


func _structure_placement_started():
	return _active_blueprint_node != null


func _blueprint_rotation_started():
	return _blueprint_rotating == true


func _calculate_blueprint_position_validity():
	var occupied_cells = Utils.Match.StructureGrid.occupied_cells(
		_active_blueprint_node.global_position,
		_pending_structure_footprint,
		_active_blueprint_node.global_basis
	)
	if _active_blueprint_out_of_map(occupied_cells):
		return BlueprintPositionValidity.OUT_OF_MAP
	if not _player_has_enough_resources():
		return BlueprintPositionValidity.NOT_ENOUGH_RESOURCES
	if _grid_cells_collide_with_units(occupied_cells):
		return BlueprintPositionValidity.COLLIDES_WITH_OBJECT
	if not _match.map.is_structure_footprint_buildable(
		_active_blueprint_node.global_position,
		_pending_structure_footprint,
		_active_blueprint_node.global_basis
	):
		return BlueprintPositionValidity.NOT_BUILDABLE
	if not _grid_cells_are_navigable(occupied_cells):
		return BlueprintPositionValidity.NOT_NAVIGABLE
	return BlueprintPositionValidity.VALID


func _player_has_enough_resources():
	var construction_cost = Constants.Match.Units.CONSTRUCTION_COSTS[
		_pending_structure_prototype.resource_path
	]
	return _player.has_resources(construction_cost)


func _active_blueprint_out_of_map(occupied_cells):
	return occupied_cells.any(
		func(cell): return not Utils.Match.StructureGrid.cell_is_inside_map(cell, _match.map.size)
	)


func _grid_cells_collide_with_units(occupied_cells):
	var occupied_cell_set = {}
	for cell in occupied_cells:
		occupied_cell_set[cell] = true
	for unit in (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	):
		if unit is Unit and unit.movement_domain == Constants.Match.Navigation.Domain.AIR:
			continue
		if unit is Structure:
			for cell in Utils.Match.StructureGrid.occupied_cells(
				unit.global_position, unit.footprint_size, unit.global_basis
			):
				if occupied_cell_set.has(cell):
					return true
			continue
		if _unit_overlaps_cells(unit, occupied_cells):
			return true
	return false


func _unit_overlaps_cells(unit, cells, position = null):
	var unit_position: Vector3 = unit.global_position if position == null else position
	for cell in cells:
		var center = Utils.Match.StructureGrid.cell_center(cell, unit_position.y)
		var half_cell = Utils.Match.StructureGrid.CELL_SIZE / 2.0
		var closest_x = clamp(unit_position.x, center.x - half_cell, center.x + half_cell)
		var closest_z = clamp(unit_position.z, center.z - half_cell, center.z + half_cell)
		if (
			Vector2(unit_position.x, unit_position.z).distance_to(Vector2(closest_x, closest_z))
			<= unit.radius
		):
			return true
	return false


func _move_owned_ground_units_out_of_blueprint():
	var occupied_cells = Utils.Match.StructureGrid.occupied_cells(
		_active_blueprint_node.global_position,
		_pending_structure_footprint,
		_active_blueprint_node.global_basis
	)
	var reserved_destinations = []
	for unit in get_tree().get_nodes_in_group("units"):
		if (
			unit is Structure
			or not unit is Unit
			or unit.player != _player
			or unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
			or not Moving.is_applicable(unit)
			or not _unit_overlaps_cells(unit, occupied_cells)
		):
			continue
		var destination = _find_nearest_unblocking_position(
			unit, occupied_cells, reserved_destinations
		)
		if destination != null:
			reserved_destinations.append([destination, unit.radius])
			unit.action = Moving.new(destination)


func _find_nearest_unblocking_position(unit, occupied_cells, reserved_destinations):
	var units = get_tree().get_nodes_in_group("units")
	var resource_units = get_tree().get_nodes_in_group("resource_units")
	var other_units = (units + resource_units).filter(
		func(other):
			return (
				other != unit
				and not (
					other is Unit and other.movement_domain == Constants.Match.Navigation.Domain.AIR
				)
			)
	)
	var away_from_blueprint = (
		(unit.global_position - _active_blueprint_node.global_position) * Vector3(1, 0, 1)
	)
	if away_from_blueprint.is_zero_approx():
		away_from_blueprint = Vector3.FORWARD
	var distance_step = Utils.Match.StructureGrid.CELL_SIZE / 2.0
	for ring in range(1, 129):
		var distance = ring * distance_step
		var sample_count = maxi(8, ceili(TAU * distance / distance_step))
		for sample in sample_count:
			var direction = away_from_blueprint.normalized().rotated(
				Vector3.UP, sample * TAU / sample_count
			)
			var candidate = unit.global_position + direction * distance
			if _unit_overlaps_cells(unit, occupied_cells, candidate):
				continue
			if reserved_destinations.any(
				func(reserved):
					return (
						(candidate * Vector3(1, 0, 1)).distance_to(reserved[0] * Vector3(1, 0, 1))
						<= unit.radius + reserved[1]
					)
			):
				continue
			if (
				Utils.Match.Unit.Placement.validate_agent_placement_position(
					candidate, unit.radius, other_units, _pending_structure_navmap_rid
				)
				== Utils.Match.Unit.Placement.VALID
			):
				return candidate
	return null


func _grid_cells_are_navigable(occupied_cells):
	for cell in occupied_cells:
		var point = Utils.Match.StructureGrid.cell_center(
			cell, _active_blueprint_node.global_position.y
		)
		var closest_point = NavigationServer3D.map_get_closest_point(
			_pending_structure_navmap_rid, point
		)
		if (
			not (point * Vector3(1, 0, 1)).is_equal_approx(closest_point * Vector3(1, 0, 1))
			and not _cell_is_in_structure_navigation_padding(cell)
		):
			return false
	return true


func _cell_is_in_structure_navigation_padding(cell):
	for unit in get_tree().get_nodes_in_group("units"):
		if (
			unit is Structure
			and Utils.Match.StructureGrid.cell_is_within_footprint_padding(
				cell,
				unit.global_position,
				unit.footprint_size,
				unit.global_basis,
				STRUCTURE_NAVIGATION_PADDING_CELLS
			)
		):
			return true
	return false


func _update_feedback_label(blueprint_position_validity):
	_feedback_label.visible = (blueprint_position_validity != BlueprintPositionValidity.VALID)
	match blueprint_position_validity:
		BlueprintPositionValidity.COLLIDES_WITH_OBJECT:
			_feedback_label.text = tr("BLUEPRINT_COLLIDES_WITH_OBJECT")
		BlueprintPositionValidity.NOT_BUILDABLE:
			_feedback_label.text = tr("BLUEPRINT_NOT_BUILDABLE")
		BlueprintPositionValidity.NOT_NAVIGABLE:
			_feedback_label.text = tr("BLUEPRINT_NOT_NAVIGABLE")
		BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
			_feedback_label.text = tr("BLUEPRINT_NOT_ENOUGH_RESOURCES")
		BlueprintPositionValidity.OUT_OF_MAP:
			_feedback_label.text = tr("BLUEPRINT_OUT_OF_MAP")


func _start_structure_placement(structure_prototype):
	if _structure_placement_started():
		return
	_pending_structure_prototype = structure_prototype
	_active_blueprint_node = (
		load(Constants.Match.Units.STRUCTURE_BLUEPRINTS[structure_prototype.resource_path])
		. instantiate()
	)
	var blueprint_origin = Vector3(-999, 0, -999)
	# Building orientation belongs to the world grid, not to the current camera angle.
	# A player can still rotate the blueprint explicitly in 90-degree steps.
	_active_blueprint_node.global_transform = Transform3D(Basis(), blueprint_origin)
	add_child(_active_blueprint_node)
	var temporary_structure_instance = _pending_structure_prototype.instantiate()
	_active_blueprint_node.global_basis = Basis(
		Vector3.UP, deg_to_rad(temporary_structure_instance.placement_rotation_degrees)
	)
	_pending_structure_footprint = temporary_structure_instance.footprint_size
	_pending_structure_navmap_rid = (
		find_parent("Match")
		. navigation
		. get_navigation_map_rid_by_domain(temporary_structure_instance.movement_domain)
	)
	temporary_structure_instance.free()
	_grid_overlay.show_grid(
		_match.map, _pending_structure_navmap_rid, get_tree().get_nodes_in_group("units")
	)
	if _using_touch_input:
		_set_blueprint_position_to_screen_center()
		_update_blueprint_validity_feedback()


func _set_blueprint_position_based_on_mouse_pos():
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	_active_blueprint_node.global_transform.origin = mouse_pos_3d
	_snap_blueprint_to_grid()
	_feedback_label.global_transform.origin = mouse_pos_3d


func _set_blueprint_position_to_screen_center():
	var screen_center = Vector2(get_viewport().size) / 2.0
	var center_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(screen_center)
	if center_pos_3d == null:
		return
	_active_blueprint_node.global_transform.origin = center_pos_3d
	_snap_blueprint_to_grid()
	_feedback_label.global_transform.origin = center_pos_3d


func _update_blueprint_color(blueprint_position_is_valid):
	var material_to_set = (
		preload(BLUEPRINT_VALID_PATH)
		if blueprint_position_is_valid
		else preload(BLUEPRINT_INVALID_PATH)
	)
	for child in _active_blueprint_node.find_children("*"):
		if "material_override" in child:
			child.material_override = material_to_set


func _cancel_structure_placement():
	if _structure_placement_started():
		_placement_touch_index = -1
		_feedback_label.hide()
		_grid_overlay.hide()
		_active_blueprint_node.queue_free()
		_active_blueprint_node = null


func _finish_structure_placement():
	if _player_has_enough_resources():
		var construction_cost = Constants.Match.Units.CONSTRUCTION_COSTS[
			_pending_structure_prototype.resource_path
		]
		_player.subtract_resources(construction_cost)
		MatchSignals.setup_and_spawn_unit.emit(
			_pending_structure_prototype.instantiate(),
			_active_blueprint_node.global_transform,
			_player
		)
	_cancel_structure_placement()


func _start_blueprint_rotation():
	_blueprint_rotating = true


func _try_rotating_blueprint_by(degrees):
	if not _structure_placement_started():
		return
	_active_blueprint_node.global_transform.basis = (
		_active_blueprint_node.global_transform.basis.rotated(Vector3.UP, deg_to_rad(degrees))
	)
	_active_blueprint_node.global_transform.basis = Utils.Match.StructureGrid.quantize_basis(
		_active_blueprint_node.global_transform.basis
	)
	_snap_blueprint_to_grid()


func _rotate_blueprint_towards_mouse_pos():
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	var mouse_pos_yless = mouse_pos_3d * Vector3(1, 0, 1)
	var blueprint_pos_3d = _active_blueprint_node.global_transform.origin
	var blueprint_pos_yless = blueprint_pos_3d * Vector3(-999, 0, -999)
	if mouse_pos_yless.distance_to(blueprint_pos_yless) < ROTATION_DEAD_ZONE_DISTANCE:
		return
	var rotation_target = Vector3(mouse_pos_yless.x, blueprint_pos_3d.y, mouse_pos_yless.z)
	if rotation_target.is_equal_approx(_active_blueprint_node.global_transform.origin):
		return
	_active_blueprint_node.global_transform = _active_blueprint_node.global_transform.looking_at(
		rotation_target, Vector3.UP
	)
	_active_blueprint_node.global_transform.basis = Utils.Match.StructureGrid.quantize_basis(
		_active_blueprint_node.global_transform.basis
	)
	_snap_blueprint_to_grid()


func _snap_blueprint_to_grid():
	_active_blueprint_node.global_position = Utils.Match.StructureGrid.snap_position(
		_active_blueprint_node.global_position,
		_pending_structure_footprint,
		_active_blueprint_node.global_basis
	)
	_grid_overlay.set_preview(
		Utils.Match.StructureGrid.occupied_cells(
			_active_blueprint_node.global_position,
			_pending_structure_footprint,
			_active_blueprint_node.global_basis
		)
	)


func _finish_blueprint_rotation():
	_blueprint_rotating = false


func _on_structure_placement_request(structure_prototype):
	_start_structure_placement(structure_prototype)


func _on_unit_grid_occupancy_changed(_unit):
	if _structure_placement_started():
		_grid_overlay.refresh(get_tree().get_nodes_in_group("units"))

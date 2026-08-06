extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")


class Actions:
	const Moving = preload("res://source/match/units/actions/Moving.gd")
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const Following = preload("res://source/match/units/actions/Following.gd")
	const CollectingResourcesSequentially = preload(
		"res://source/match/units/actions/CollectingResourcesSequentially.gd"
	)
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
	const Constructing = preload("res://source/match/units/actions/Constructing.gd")
	const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
	const HoldingPosition = preload("res://source/match/units/actions/HoldingPosition.gd")
	const Patrolling = preload("res://source/match/units/actions/Patrolling.gd")


var _pending_command: StringName = &""


func _ready():
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.unit_targeted.connect(_on_unit_targeted)
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	MatchSignals.navigate_unit_to_rally_point.connect(_on_navigate_unit_to_rally_point)
	MatchSignals.unit_command_requested.connect(_on_unit_command_requested)
	MatchSignals.command_target_requested.connect(_on_command_target_requested)


func _try_navigating_selected_units_towards_position(target_point):
	var terrain_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.Moving.is_applicable(unit)
			)
	)
	var air_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.AIR
				and Actions.Moving.is_applicable(unit)
			)
	)
	var new_unit_targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		terrain_units_to_move, target_point
	)
	new_unit_targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		air_units_to_move, target_point
	)
	for tuple in new_unit_targets:
		var unit = tuple[0]
		var new_target = tuple[1]
		unit.action = Actions.Moving.new(new_target)


func _try_setting_rally_points(target_point: Vector3):
	var controlled_structures = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and unit.find_child("RallyPoint") != null
	)
	for structure in controlled_structures:
		var rally_point = structure.find_child("RallyPoint")
		if rally_point != null:
			rally_point.target_unit = null
			rally_point.global_position = target_point


func _try_ordering_selected_workers_to_construct_structure(potential_structure):
	if not potential_structure is Structure or potential_structure.is_constructed():
		return
	var structure = potential_structure
	var selected_constructors = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and Actions.Constructing.is_applicable(unit, structure)
			)
	)
	for unit in selected_constructors:
		unit.action = Actions.Constructing.new(structure)


func _navigate_selected_units_towards_unit(target_unit):
	var at_least_one_unit_navigated = false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		if _navigate_unit_towards_unit(unit, target_unit):
			at_least_one_unit_navigated = true
	return at_least_one_unit_navigated


func _navigate_unit_towards_unit(unit, target_unit):
	if Actions.CollectingResourcesSequentially.is_applicable(unit, target_unit):
		unit.action = Actions.CollectingResourcesSequentially.new(target_unit)
		return true
	if Actions.AutoAttacking.is_applicable(unit, target_unit):
		unit.action = Actions.AutoAttacking.new(target_unit)
		return true
	if Actions.Constructing.is_applicable(unit, target_unit):
		unit.action = Actions.Constructing.new(target_unit)
		return true
	if (
		(target_unit.is_in_group("adversary_units") or target_unit.is_in_group("controlled_units"))
		and Actions.Following.is_applicable(unit)
	):
		unit.action = Actions.Following.new(target_unit)
		return true
	if Actions.MovingToUnit.is_applicable(unit):
		unit.action = Actions.MovingToUnit.new(target_unit)
		return true
	if _try_setting_rally_point_to_unit(unit, target_unit):
		return true
	return false  # gdlint: ignore = max-returns


func _try_setting_rally_point_to_unit(unit, target_unit):
	if not unit is Structure:
		return false
	if not target_unit is ResourceUnit and unit.player != target_unit.player:
		# it's not allowed to set rally point to enemy at the moment as with current implementation
		# the position of enemy unit hidden in the fog of war could be hinted
		return false
	var rally_point = unit.find_child("RallyPoint")
	if rally_point == null:
		return false
	rally_point.target_unit = target_unit
	return true


func _on_terrain_targeted(position):
	if _pending_command != &"":
		_execute_terrain_command(position)
		return
	_try_navigating_selected_units_towards_position(position)
	_try_setting_rally_points(position)


func _on_unit_targeted(unit):
	if _pending_command != &"":
		_execute_unit_command(unit)
		return
	if _navigate_selected_units_towards_unit(unit):
		var targetability = unit.find_child("Targetability")
		if targetability != null:
			targetability.animate()


func _on_unit_spawned(unit):
	_try_ordering_selected_workers_to_construct_structure(unit)


func _on_navigate_unit_to_rally_point(unit, rally_point):
	if rally_point.target_unit != null:
		_navigate_unit_towards_unit(unit, rally_point.target_unit)
	elif rally_point.global_position != rally_point.get_parent().global_position:
		unit.action = Actions.Moving.new(rally_point.global_position)


func _on_unit_command_requested(command: StringName):
	_cancel_pending_command()
	if command == &"stop":
		for unit in _selected_controlled_units():
			unit.action = null
	elif command == &"hold":
		for unit in _selected_controlled_units():
			if Actions.HoldingPosition.is_applicable(unit):
				unit.action = Actions.HoldingPosition.new()
	else:
		_pending_command = command
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		MatchSignals.command_targeting_changed.emit(true)


func _on_command_target_requested(screen_position: Vector2):
	var camera = get_viewport().get_camera_3d()
	var ray_origin = camera.project_ray_origin(screen_position)
	var ray_end = ray_origin + camera.project_ray_normal(screen_position) * 10000.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	var hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	var targeted_unit = null
	if not hit.is_empty():
		var candidate = hit.collider
		while candidate != null:
			if candidate.is_in_group("units"):
				targeted_unit = candidate
				break
			candidate = candidate.get_parent()
	if targeted_unit != null:
		_execute_unit_command(targeted_unit)
	else:
		_execute_terrain_command(camera.get_ray_intersection(screen_position))


func _execute_terrain_command(position: Vector3):
	var command = _pending_command
	_cancel_pending_command()
	if command == &"move":
		_try_navigating_selected_units_towards_position(position)
	elif command == &"attack":
		for unit in _selected_controlled_units():
			if Actions.AttackMoving.is_applicable(unit):
				unit.action = Actions.AttackMoving.new(position)
	elif command == &"patrol":
		for unit in _selected_controlled_units():
			if Actions.AttackMoving.is_applicable(unit):
				unit.action = Actions.Patrolling.new(unit.global_position, position)


func _execute_unit_command(target_unit):
	var command = _pending_command
	_cancel_pending_command()
	if command == &"attack":
		for unit in _selected_controlled_units():
			if Actions.AutoAttacking.is_applicable(unit, target_unit):
				unit.action = Actions.AutoAttacking.new(target_unit)
	elif command == &"move":
		for unit in _selected_controlled_units():
			if Actions.Following.is_applicable(unit):
				unit.action = Actions.Following.new(target_unit)
	elif command == &"patrol":
		for unit in _selected_controlled_units():
			if Actions.AttackMoving.is_applicable(unit):
				unit.action = Actions.Patrolling.new(
					unit.global_position, target_unit.global_position
				)


func _cancel_pending_command():
	_pending_command = &""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	MatchSignals.command_targeting_changed.emit(false)


func _selected_controlled_units():
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)

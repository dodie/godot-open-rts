extends Node

signal resources_required(resources, metadata)

const REFRESH_INTERVAL_S = 1.0 / 60.0 * 30.0

var _player = null
var _number_of_pending_ag_turret_resource_requests = 0
var _number_of_pending_aa_turret_resource_requests = 0

@onready var _ai = get_parent()


func setup(player):
	_setup_refresh_timer()
	_player = player
	_attach_current_turrets()
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	_enforce_number_of_ag_turrets()
	_enforce_number_of_aa_turrets()


func provision(resources, metadata):
	var workers = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.definition.has_tag(&"worker") and unit.player == _player
	)
	var ccs = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.definition.has_tag(&"command_center") and unit.player == _player
	)
	if metadata == "ag_turret":
		assert(
			resources == UnitCatalog.get_definition(&"anti_ground_turret").cost(),
			"unexpected amount of resources"
		)
		_number_of_pending_ag_turret_resource_requests -= 1
		if workers.is_empty() or ccs.is_empty():
			return
		_construct_turret(&"anti_ground_turret")
	elif metadata == "aa_turret":
		assert(
			resources == UnitCatalog.get_definition(&"anti_air_turret").cost(),
			"unexpected amount of resources"
		)
		_number_of_pending_aa_turret_resource_requests -= 1
		if workers.is_empty() or ccs.is_empty():
			return
		_construct_turret(&"anti_air_turret")
	else:
		assert(false, "unexpected flow")


func _setup_refresh_timer():
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_refresh_timer_timeout)
	timer.start(REFRESH_INTERVAL_S)


func _attach_current_turrets():
	var turrets = get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player == _player
				and (
					unit.definition.has_tag(&"defense_ground")
					or unit.definition.has_tag(&"defense_air")
				)
			)
	)
	for turret in turrets:
		_attach_turret(turret)


func _attach_turret(turret):
	turret.tree_exited.connect(_on_unit_died.bind(turret))


func _enforce_number_of_ag_turrets():
	var ag_turrets = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.definition.has_tag(&"defense_ground") and unit.player == _player
	)
	if (
		ag_turrets.size() + _number_of_pending_ag_turret_resource_requests
		>= _ai.expected_number_of_ag_turrets
	):
		return
	var number_of_extra_ag_turrets_required = (
		_ai.expected_number_of_ag_turrets
		- (ag_turrets.size() + _number_of_pending_ag_turret_resource_requests)
	)
	for _i in range(number_of_extra_ag_turrets_required):
		resources_required.emit(
			UnitCatalog.get_definition(&"anti_ground_turret").cost(), "ag_turret"
		)
		_number_of_pending_ag_turret_resource_requests += 1


func _enforce_number_of_aa_turrets():
	var aa_turrets = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.definition.has_tag(&"defense_air") and unit.player == _player
	)
	if (
		aa_turrets.size() + _number_of_pending_aa_turret_resource_requests
		>= _ai.expected_number_of_aa_turrets
	):
		return
	var number_of_extra_aa_turrets_required = (
		_ai.expected_number_of_aa_turrets
		- (aa_turrets.size() + _number_of_pending_aa_turret_resource_requests)
	)
	for _i in range(number_of_extra_aa_turrets_required):
		resources_required.emit(UnitCatalog.get_definition(&"anti_air_turret").cost(), "aa_turret")
		_number_of_pending_aa_turret_resource_requests += 1


func _construct_turret(turret_id):
	var construction_cost = UnitCatalog.get_definition(turret_id).cost()
	assert(
		_player.has_resources(construction_cost),
		"player should have enough resources at this point"
	)
	var ccs = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.definition.has_tag(&"command_center") and unit.player == _player
	)
	var unit_to_spawn = UnitCatalog.instantiate(turret_id)
	var match_node = find_parent("Match")
	var target_basis = Utils.Match.StructureGrid.quantize_basis(
		Transform3D(Basis(), Vector3.ZERO).looking_at(Vector3(0, 0, 1), Vector3.UP).basis
	)
	var buildability_validator = match_node.map.is_structure_footprint_buildable.bind(
		unit_to_spawn.footprint_size, target_basis
	)
	# TODO: introduce actual algorithm which takes enemy positions into account
	var placement_position = Utils.Match.Unit.Placement.find_valid_position_radially(
		ccs[0].global_position,
		unit_to_spawn.radius + Constants.Match.Units.EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M,
		match_node.navigation.get_navigation_map_rid_by_domain(unit_to_spawn.movement_domain),
		get_tree(),
		buildability_validator
	)
	var target_transform = Transform3D(Basis(), placement_position).looking_at(
		placement_position + Vector3(0, 0, 1), Vector3.UP
	)
	_player.subtract_resources(construction_cost)
	MatchSignals.setup_and_spawn_unit.emit(unit_to_spawn, target_transform, _player)


func _on_unit_died(unit):
	if not is_inside_tree():
		return
	if unit.definition.has_tag(&"defense_ground"):
		_enforce_number_of_ag_turrets()
	elif unit.definition.has_tag(&"defense_air"):
		_enforce_number_of_aa_turrets()
	else:
		assert(false, "unexpected flow")


func _on_unit_spawned(unit):
	if unit.player != _player:
		return
	if unit.definition.has_tag(&"defense_ground") or unit.definition.has_tag(&"defense_air"):
		_attach_turret(unit)


func _on_refresh_timer_timeout():
	_enforce_number_of_ag_turrets()
	_enforce_number_of_aa_turrets()

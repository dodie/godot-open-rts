extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05
const DeathExplosion = preload("res://source/match/units/projectiles/CannonImpact.tscn")

const DEATH_EXPLOSION_SCALE = 1.65
const DEATH_EXPLOSION_PARTICLE_MULTIPLIER = 1.5

var hp = null:
	set = _set_hp
var hp_max = null:
	set = _set_hp_max
var attack_damage = null
var attack_interval = null
var attack_range = null
var attack_domains = []
var radius:
	get = _get_radius
var movement_domain:
	get = _get_movement_domain
var movement_speed:
	get = _get_movement_speed
var sight_range = null
var definition = null
var player:
	get:
		return get_parent()
var color:
	get:
		return player.color
var action = null:
	set = _set_action
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var type:
	get = _get_type

var _action_locked = false

@onready var _match = find_parent("Match")


func _ready():
	if definition == null:
		definition = UnitCatalog.get_by_scene_path(scene_file_path)
	if not _match.is_node_ready():
		await _match.ready
	_setup_color()
	_setup_properties_from_definition()
	assert(_safety_checks())


func is_revealing():
	return is_in_group("revealed_units") and visible


func _set_hp(value):
	var old_hp = hp
	hp = max(0, value)
	if old_hp != null and hp < old_hp:
		MatchSignals.unit_damaged.emit(self)
	hp_changed.emit()
	if hp == 0:
		_handle_unit_death()


func _set_hp_max(value):
	hp_max = value
	hp_changed.emit()


func _get_radius():
	if find_child("Movement") != null:
		return find_child("Movement").radius
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").radius
	return null


func _get_movement_domain():
	if find_child("Movement") != null:
		return find_child("Movement").domain
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").domain
	return null


func _get_movement_speed():
	if find_child("Movement") != null:
		return find_child("Movement").speed
	return 0.0


func _is_movable():
	return _get_movement_speed() > 0.0


func _setup_color():
	var material = player.get_color_material()
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"),
		MATERIAL_ALBEDO_TO_REPLACE,
		MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		material
	)


func _set_action(action_node):
	if not is_inside_tree() or _action_locked:
		if action_node != null:
			action_node.queue_free()
		return
	_action_locked = true
	_teardown_current_action()
	action = action_node
	if action != null:
		var action_copy = action  # bind() performs copy itself, but lets force copy just in case
		action.tree_exited.connect(_on_action_node_tree_exited.bind(action_copy))
		add_child(action_node)
	_action_locked = false
	action_changed.emit(action)


func _get_type():
	return definition.id if definition != null else &""


func _teardown_current_action():
	if action != null and action.is_inside_tree():
		action.queue_free()
		remove_child(action)  # triggers _on_action_node_tree_exited immediately


func _safety_checks():
	if movement_domain == Constants.Match.Navigation.Domain.AIR:
		assert(
			(
				radius < Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS
				or is_equal_approx(radius, Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS)
			),
			"Unit radius exceeds the established limit"
		)
	elif movement_domain == Constants.Match.Navigation.Domain.TERRAIN:
		assert(
			(
				not _is_movable()
				or (
					radius < Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
					or is_equal_approx(radius, Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS)
				)
			),
			"Unit radius exceeds the established limit"
		)
	return true


func _handle_unit_death():
	_spawn_death_explosion()
	tree_exited.connect(func(): MatchSignals.unit_died.emit(self))
	queue_free()


func _spawn_death_explosion():
	var explosion_scale = _get_death_explosion_scale()
	var explosion = DeathExplosion.instantiate()
	explosion.visible = visible
	explosion.scale = Vector3.ONE * explosion_scale
	for particles in explosion.find_children("*", "GPUParticles3D", true, false):
		particles.amount = roundi(particles.amount * _get_death_explosion_particle_multiplier())
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position + Vector3.UP * 0.35 * explosion_scale


func _get_death_explosion_scale() -> float:
	return DEATH_EXPLOSION_SCALE


func _get_death_explosion_particle_multiplier() -> float:
	return DEATH_EXPLOSION_PARTICLE_MULTIPLIER


func _setup_properties_from_definition():
	hp_max = definition.hp_max
	hp = definition.hp_max
	sight_range = definition.sight_range
	if not definition.attack.is_empty():
		attack_damage = definition.attack["damage"]
		attack_interval = definition.attack["interval"]
		attack_range = definition.attack["range"]
		attack_domains = definition.attack["domains"]
	var movement = find_child("Movement")
	if movement == null:
		movement = find_child("MovementObstacle")
	if movement != null and not definition.movement.is_empty():
		movement.domain = definition.movement["domain"]
		movement.radius = definition.movement["radius"]
		if "speed" in movement:
			movement.speed = definition.movement["speed"]


func _on_action_node_tree_exited(action_node):
	assert(action_node == action, "unexpected action released")
	action = null

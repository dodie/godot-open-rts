extends Node

const UnitDefinitionType = preload("res://source/match/units/UnitDefinition.gd")
const DEFINITION_SCRIPTS := [
	preload("res://content/units/AircraftFactory.gd"),
	preload("res://content/units/AntiAirTurret.gd"),
	preload("res://content/units/AntiGroundTurret.gd"),
	preload("res://content/units/CommandCenter.gd"),
	preload("res://content/units/Drone.gd"),
	preload("res://content/units/Helicopter.gd"),
	preload("res://content/units/Launcher.gd"),
	preload("res://content/units/Tank.gd"),
	preload("res://content/units/VehicleFactory.gd"),
	preload("res://content/units/Worker.gd"),
]

var _by_id := {}
var _by_scene_path := {}


func _init():
	_load_definitions()
	_validate_definitions()


func get_definition(id: StringName):
	assert(_by_id.has(id), "Unknown unit definition: %s" % id)
	return _by_id[id]


func get_by_scene_path(scene_path: String):
	assert(_by_scene_path.has(scene_path), "No unit definition for scene: %s" % scene_path)
	return _by_scene_path[scene_path]


func all() -> Array:
	return _by_id.values()


func get_products(producer_id: StringName) -> Array:
	var products = all().filter(func(definition): return definition.producer_id() == producer_id)
	products.sort_custom(
		func(a, b):
			return a.menu_order < b.menu_order or (a.menu_order == b.menu_order and a.id < b.id)
	)
	return products


func instantiate(id: StringName):
	var definition = get_definition(id)
	var unit = load(definition.scene_path).instantiate()
	unit.definition = definition
	return unit


func dependency_paths() -> Array:
	var paths := []
	for definition in all():
		paths.append(definition.scene_path)
		if definition.has_attack():
			paths.append(definition.attack["projectile_path"])
		if definition.is_structure():
			paths.append(definition.structure["blueprint_path"])
	return paths


func _load_definitions():
	# Runtime directory enumeration cannot reliably find remapped scripts in exported PCKs.
	# Explicit references also let the exporter discover and include every definition.
	for definition_script in DEFINITION_SCRIPTS:
		var definition = definition_script.new()
		assert(
			definition is UnitDefinitionType,
			"%s is not a UnitDefinition" % definition_script.resource_path
		)
		assert(not _by_id.has(definition.id), "Duplicate unit id: %s" % definition.id)
		assert(
			not _by_scene_path.has(definition.scene_path),
			"Duplicate unit scene: %s" % definition.scene_path
		)
		_by_id[definition.id] = definition
		_by_scene_path[definition.scene_path] = definition


func _validate_definitions():
	assert(not _by_id.is_empty(), "No unit definitions found")
	for definition in all():
		assert(definition.id != &"", "Unit definition has an empty id")
		assert(not definition.display_name.is_empty(), "%s has no display name" % definition.id)
		assert(ResourceLoader.exists(definition.scene_path), "%s has no scene" % definition.id)
		assert(
			ResourceLoader.exists(definition.behavior_path), "%s has no behavior" % definition.id
		)
		assert(ResourceLoader.exists(definition.icon_path), "%s has no icon" % definition.id)
		assert(definition.hp_max > 0, "%s has invalid health" % definition.id)
		assert(definition.supply_cost >= 0, "%s has invalid supply cost" % definition.id)
		assert(definition.supply_granted >= 0, "%s has invalid supplied capacity" % definition.id)
		if definition.has_attack():
			assert(definition.attack["damage"] > 0, "%s has invalid damage" % definition.id)
			assert(
				definition.attack["interval"] > 0.0,
				"%s has invalid attack interval" % definition.id
			)
			assert(ResourceLoader.exists(definition.attack["projectile_path"]))
		if definition.build_mode() != UnitDefinitionType.BuildMode.NONE:
			assert(
				_by_id.has(definition.producer_id()), "%s has an unknown producer" % definition.id
			)
			for amount in definition.cost().values():
				assert(amount >= 0, "%s has a negative cost" % definition.id)
		if definition.is_structure():
			assert(ResourceLoader.exists(definition.structure["blueprint_path"]))

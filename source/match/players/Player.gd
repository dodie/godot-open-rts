extends Node3D

signal changed

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")

@export var resource_a = 0:
	set(value):
		resource_a = value
		emit_changed()
@export var resource_b = 0:
	set(value):
		resource_b = value
		emit_changed()
@export var color = Color.WHITE

var _color_material = null
var _reserved_supply := 0


var population: int:
	get:
		var result = _reserved_supply
		for unit in get_children():
			if unit is Unit and unit.definition != null:
				result += unit.definition.supply_cost
		return result

var max_supply: int:
	get:
		var result := 0
		for unit in get_children():
			if unit is Unit and unit.definition != null:
				if unit is Structure and not unit.is_constructed():
					continue
				result += unit.definition.supply_granted
		return result


func _enter_tree():
	child_entered_tree.connect(_on_unit_tree_changed)
	child_exiting_tree.connect(_on_unit_tree_changed)
	MatchSignals.unit_construction_finished.connect(_on_unit_construction_finished)


func add_resources(resources):
	for resource in resources:
		set(resource, get(resource) + resources[resource])


func has_resources(resources):
	if FeatureFlags.allow_resources_deficit_spending:
		return true
	for resource in resources:
		if get(resource) < resources[resource]:
			return false
	return true


func subtract_resources(resources):
	for resource in resources:
		set(resource, get(resource) - resources[resource])


func has_supply(amount: int) -> bool:
	return population + amount <= max_supply


func has_prerequisites(definition) -> bool:
	for prerequisite_id in definition.prerequisites:
		var is_satisfied := false
		for unit in get_children():
			if (
				unit is Structure
				and unit.definition != null
				and unit.definition.id == prerequisite_id
				and unit.is_constructed()
			):
				is_satisfied = true
				break
		if not is_satisfied:
			return false
	return true


func reserve_supply(amount: int):
	assert(has_supply(amount), "not enough supply")
	_reserved_supply += amount
	emit_changed()


func release_supply(amount: int):
	_reserved_supply -= amount
	assert(_reserved_supply >= 0, "released more supply than was reserved")
	emit_changed()


func _on_unit_tree_changed(node):
	if node is Unit:
		call_deferred("emit_changed")


func _on_unit_construction_finished(unit):
	if unit.player == self:
		emit_changed()


func get_color_material():
	if _color_material == null:
		_color_material = StandardMaterial3D.new()
		_color_material.vertex_color_use_as_albedo = true
		_color_material.albedo_color = color
		_color_material.metallic = 1
	return _color_material


func emit_changed():
	changed.emit()

extends Node3D

const MuzzleFlash = preload("res://source/match/units/projectiles/CannonMuzzleFlash.tscn")
const Impact = preload("res://source/match/units/projectiles/CannonImpact.tscn")

var target_unit = null

@onready var _unit = get_parent()


func _ready():
	assert(target_unit != null, "target unit was not provided")
	_spawn_effect(MuzzleFlash, _get_projectile_origin(), _unit.visible)
	_spawn_effect(Impact, Transform3D(Basis(), _get_impact_position()), target_unit.visible)
	target_unit.hp -= _unit.attack_damage
	queue_free()


func _get_projectile_origin() -> Transform3D:
	var projectile_origin = _unit.find_child("ProjectileOrigin")
	return (
		_unit.global_transform if projectile_origin == null else projectile_origin.global_transform
	)


func _get_impact_position() -> Vector3:
	return target_unit.global_position + Vector3.UP * 0.35


func _spawn_effect(scene: PackedScene, effect_transform: Transform3D, is_visible: bool):
	var effect = scene.instantiate()
	effect.visible = is_visible
	get_tree().current_scene.add_child(effect)
	effect.global_transform = effect_transform

extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"anti_ground_turret"
	display_name = "Anti-ground turret"
	description = "fights ground targets"
	scene_path = "res://source/match/units/AntiGroundTurret.tscn"
	behavior_path = "res://source/match/units/AntiGroundTurret.gd"
	icon_path = "res://assets/ui/icons/AntiGroundTurret.png"
	menu_order = 9
	tags = [&"defense_ground"]
	hp_max = 8
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 0.0, "radius": 0.6}
	attack = {
		"damage": 2,
		"interval": 1.0,
		"range": 8.0,
		"domains": [Constants.Match.Navigation.Domain.TERRAIN],
		"projectile_path": "res://source/match/units/projectiles/CannonShell.tscn"
	}
	structure = {
		"footprint": Vector2i(1, 1),
		"placement_rotation_degrees": 0.0,
		"blueprint_path": "res://source/match/units/structure-geometries/AntiGroundTurret.tscn",
		"queue_limit": 0
	}
	build = {
		"mode": BuildMode.CONSTRUCTION,
		"producer_id": &"worker",
		"cost": {"resource_a": 2, "resource_b": 2}
	}

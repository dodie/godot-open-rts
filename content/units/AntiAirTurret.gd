extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"anti_air_turret"
	display_name = "Anti-air turret"
	description = "fights air targets"
	scene_path = "res://source/match/units/AntiAirTurret.tscn"
	behavior_path = "res://source/match/units/AntiAirTurret.gd"
	icon_path = "res://assets/ui/icons/AntiAirTurret.png"
	menu_order = 10
	tags = [&"defense_air"]
	hp_max = 8
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 0.0, "radius": 0.6}
	attack = {
		"damage": 2,
		"interval": 0.75,
		"range": 8.0,
		"domains": [Constants.Match.Navigation.Domain.AIR],
		"projectile_path": "res://source/match/units/projectiles/Rocket.tscn"
	}
	structure = {
		"footprint": Vector2i(1, 1),
		"placement_rotation_degrees": 0.0,
		"blueprint_path": "res://source/match/units/structure-geometries/AntiAirTurret.tscn",
		"queue_limit": 0
	}
	build = {
		"mode": BuildMode.CONSTRUCTION,
		"producer_id": &"worker",
		"cost": {"resource_a": 2, "resource_b": 2}
	}

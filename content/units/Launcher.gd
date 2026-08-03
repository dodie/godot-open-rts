extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"launcher"
	display_name = "Launcher"
	description = "fights ground targets"
	scene_path = "res://source/match/units/Launcher.tscn"
	behavior_path = "res://source/match/units/CombatUnit.gd"
	icon_path = "res://assets/ui/icons/Tank.png"
	menu_order = 14
	hp_max = 10
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 2.75, "radius": 0.9}
	attack = {
		"damage": 2,
		"interval": 0.75,
		"range": 5.0,
		"domains": [Constants.Match.Navigation.Domain.TERRAIN],
		"projectile_path": "res://source/match/units/projectiles/CannonShell.tscn"
	}
	build = {
		"mode": BuildMode.PRODUCTION,
		"producer_id": &"vehicle_factory",
		"cost": {"resource_a": 3, "resource_b": 1},
		"time": 6.0
	}

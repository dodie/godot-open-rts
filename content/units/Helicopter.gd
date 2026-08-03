extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"helicopter"
	display_name = "Helicopter"
	description = "fights ground and air targets"
	scene_path = "res://source/match/units/Helicopter.tscn"
	behavior_path = "res://source/match/units/Helicopter.gd"
	icon_path = "res://assets/ui/icons/Helicopter.png"
	menu_order = 13
	hp_max = 10
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.AIR, "speed": 4.0, "radius": 0.8}
	attack = {
		"damage": 1,
		"interval": 1.0,
		"range": 5.0,
		"domains":
		[Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR],
		"projectile_path": "res://source/match/units/projectiles/Rocket.tscn"
	}
	build = {
		"mode": BuildMode.PRODUCTION,
		"producer_id": &"aircraft_factory",
		"cost": {"resource_a": 1, "resource_b": 3},
		"time": 6.0
	}

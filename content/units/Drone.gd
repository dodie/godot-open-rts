extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"drone"
	display_name = "Scout drone"
	description = "performs scouting"
	scene_path = "res://source/match/units/Drone.tscn"
	behavior_path = "res://source/match/units/Drone.gd"
	icon_path = "res://assets/ui/icons/Drone.png"
	menu_order = 14
	tags = [&"scout"]
	hp_max = 6
	sight_range = 10.0
	movement = {"domain": Constants.Match.Navigation.Domain.AIR, "speed": 4.0, "radius": 0.6}
	build = {
		"mode": BuildMode.PRODUCTION,
		"producer_id": &"aircraft_factory",
		"cost": {"resource_a": 2, "resource_b": 0},
		"time": 3.0
	}

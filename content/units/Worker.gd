extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"worker"
	display_name = "Worker"
	description = "collects resources"
	scene_path = "res://source/match/units/Worker.tscn"
	behavior_path = "res://source/match/units/Worker.gd"
	icon_path = "res://assets/ui/icons/Worker.png"
	menu_order = 13
	tags = [&"worker"]
	supply_cost = 1
	hp_max = 6
	sight_range = 5.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 2.5, "radius": 0.6}
	cargo = {"capacity": 2, "construction_speed": 0.3}
	build = {
		"mode": BuildMode.PRODUCTION,
		"producer_id": &"command_center",
		"cost": {"resource_a": 2, "resource_b": 0},
		"time": 3.0
	}

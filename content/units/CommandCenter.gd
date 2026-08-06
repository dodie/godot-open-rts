extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"command_center"
	display_name = "Command center"
	description = "produces workers"
	scene_path = "res://source/match/units/CommandCenter.tscn"
	behavior_path = "res://source/match/units/CommandCenter.gd"
	icon_path = "res://assets/ui/icons/CommandCenter.png"
	menu_order = 13
	tags = [&"command_center"]
	supply_granted = 8
	hp_max = 20
	sight_range = 10.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 0.0, "radius": 2.0}
	structure = {
		"footprint": Vector2i(3, 3),
		"placement_rotation_degrees": 180.0,
		"blueprint_path": "res://source/match/units/structure-geometries/CommandCenter.tscn",
		"queue_limit": 5
	}
	build = {
		"mode": BuildMode.CONSTRUCTION,
		"producer_id": &"worker",
		"cost": {"resource_a": 8, "resource_b": 8}
	}

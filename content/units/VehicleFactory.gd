extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"vehicle_factory"
	display_name = "Vehicle factory"
	description = "produces vehicles"
	scene_path = "res://source/match/units/VehicleFactory.tscn"
	behavior_path = "res://source/match/units/VehicleFactory.gd"
	icon_path = "res://assets/ui/icons/VehicleFactory.png"
	menu_order = 14
	hp_max = 16
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 0.0, "radius": 1.5}
	structure = {
		"footprint": Vector2i(3, 2),
		"placement_rotation_degrees": 0.0,
		"blueprint_path": "res://source/match/units/structure-geometries/VehicleFactory.tscn",
		"queue_limit": 5
	}
	build = {
		"mode": BuildMode.CONSTRUCTION,
		"producer_id": &"worker",
		"cost": {"resource_a": 6, "resource_b": 0}
	}

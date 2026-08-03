extends "res://source/match/units/UnitDefinition.gd"


func _init():
	id = &"aircraft_factory"
	display_name = "Aircraft factory"
	description = "produces air units"
	scene_path = "res://source/match/units/AircraftFactory.tscn"
	behavior_path = "res://source/match/units/AircraftFactory.gd"
	icon_path = "res://assets/ui/icons/AircraftFactory.png"
	menu_order = 15
	hp_max = 16
	sight_range = 8.0
	movement = {"domain": Constants.Match.Navigation.Domain.TERRAIN, "speed": 0.0, "radius": 1.5}
	structure = {
		"footprint": Vector2i(3, 2),
		"placement_rotation_degrees": 0.0,
		"blueprint_path": "res://source/match/units/structure-geometries/AircraftFactory.tscn",
		"queue_limit": 5
	}
	build = {
		"mode": BuildMode.CONSTRUCTION,
		"producer_id": &"worker",
		"cost": {"resource_a": 4, "resource_b": 4}
	}

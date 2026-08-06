extends "res://content/units/AntiAirTurret.gd"
# FIXME: temporary anti-air turret stand-in until the Armory gets its own visuals and behavior.


func _init():
	super()
	id = &"armory"
	display_name = "Armory"
	description = "unlocks advanced units"
	scene_path = "res://source/match/units/Armory.tscn"
	menu_order = 11
	structure = structure.duplicate()
	structure["footprint"] = Vector2i(2, 2)

extends "res://content/units/AntiAirTurret.gd"
# FIXME: should not extend anti air turret, this is just for the first try


func _init():
	super()
	id = &"supply_farm"
	display_name = "Supply Farm"
	description = "provides additional supply"
	scene_path = "res://source/match/units/SupplyFarm.tscn"
	supply_granted = 8
	structure = structure.duplicate()
	structure["footprint"] = Vector2i(2, 2)

extends GridContainer

const TankUnit = preload("res://source/match/units/Tank.tscn")
const LauncherUnit = preload("res://source/match/units/Launcher.tscn")

var unit = null

@onready var _tank_button = find_child("ProduceTankButton")
@onready var _launcher_button = find_child("ProduceLauncherButton")


func _ready():
	var tank_properties = Constants.Match.Units.DEFAULT_PROPERTIES[TankUnit.resource_path]
	_tank_button.tooltip_text = ("{0} - {1}\n{2} HP, {3} DPS\n{4}: {5}, {6}: {7}".format(
		[
			tr("TANK"),
			tr("TANK_DESCRIPTION"),
			tank_properties["hp_max"],
			tank_properties["attack_damage"] * tank_properties["attack_interval"],
			tr("RESOURCE_A"),
			Constants.Match.Units.PRODUCTION_COSTS[TankUnit.resource_path]["resource_a"],
			tr("RESOURCE_B"),
			Constants.Match.Units.PRODUCTION_COSTS[TankUnit.resource_path]["resource_b"]
		]
	))
	var launcher_properties = Constants.Match.Units.DEFAULT_PROPERTIES[LauncherUnit.resource_path]
	_launcher_button.tooltip_text = ("{0} - {1}\n{2} HP, {3} DPS\n{4}: {5}, {6}: {7}".format(
		[
			tr("LAUNCHER"),
			tr("LAUNCHER_DESCRIPTION"),
			launcher_properties["hp_max"],
			launcher_properties["attack_damage"] * launcher_properties["attack_interval"],
			tr("RESOURCE_A"),
			Constants.Match.Units.PRODUCTION_COSTS[LauncherUnit.resource_path]["resource_a"],
			tr("RESOURCE_B"),
			Constants.Match.Units.PRODUCTION_COSTS[LauncherUnit.resource_path]["resource_b"]
		]
	))


func _on_produce_tank_button_pressed():
	unit.production_queue.produce(TankUnit)


func _on_produce_launcher_button_pressed():
	unit.production_queue.produce(LauncherUnit)

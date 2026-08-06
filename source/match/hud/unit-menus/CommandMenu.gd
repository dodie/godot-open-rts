extends GridContainer

signal build_requested

var units := []
var can_attack := false:
	set(value):
		can_attack = value
		if is_node_ready():
			$AttackButton.visible = value
var can_build := false:
	set(value):
		can_build = value
		if is_node_ready():
			$BuildButton.visible = value


func _ready():
	$AttackButton.visible = can_attack
	$BuildButton.visible = can_build


func _request(command: StringName):
	MatchSignals.unit_command_requested.emit(command)


func _on_build_pressed():
	build_requested.emit()

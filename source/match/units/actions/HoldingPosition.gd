extends "res://source/match/units/actions/Action.gd"

const AttackingWhileInRange = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
const REFRESH_INTERVAL := 1.0 / 6.0

var _timer: Timer
var _sub_action = null
var _movement = null
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(unit):
	return unit.attack_range != null


func _ready():
	_movement = _unit.find_child("Movement")
	if _movement != null:
		_movement.lock_position()
	_timer = Timer.new()
	_timer.timeout.connect(_look_for_target)
	add_child(_timer)
	_timer.start(REFRESH_INTERVAL)
	_look_for_target()


func _exit_tree():
	if _movement != null and is_instance_valid(_movement):
		_movement.unlock_position()


func _look_for_target():
	if _sub_action != null:
		return
	var targets = get_tree().get_nodes_in_group("units").filter(
		func(target):
			return (
				target.player != _unit.player
				and target.movement_domain in _unit.attack_domains
				and (
					_unit.global_position_yless.distance_to(target.global_position_yless)
					<= _unit.attack_range
				)
			)
	)
	if targets.is_empty():
		return
	_sub_action = AttackingWhileInRange.new(
		preload("res://source/match/units/actions/WaitingForTargets.gd")._pick_closest_unit(
			targets, _unit
		)
	)
	_sub_action.tree_exited.connect(func(): _sub_action = null)
	add_child(_sub_action)

extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")
const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const REFRESH_INTERVAL := 1.0 / 6.0

var _destination: Vector3
var _sub_action = null
var _engagement_target = null
var _timer: Timer
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(unit):
	return Moving.is_applicable(unit)


func _init(destination: Vector3):
	_destination = destination


func _ready():
	_timer = Timer.new()
	_timer.timeout.connect(_look_for_target)
	add_child(_timer)
	_timer.start(REFRESH_INTERVAL)
	_move()


func _move():
	_engagement_target = null
	_set_sub_action(Moving.new(_destination), queue_free)


func _look_for_target():
	if _sub_action is AutoAttacking:
		if (
			not is_instance_valid(_engagement_target)
			or not _engagement_target.is_inside_tree()
			or (
				_unit.global_position_yless.distance_to(_engagement_target.global_position_yless)
				> _unit.sight_range
			)
		):
			_move()
		return
	if _unit.attack_range == null:
		return
	var targets = get_tree().get_nodes_in_group("units").filter(
		func(target):
			return (
				target.player != _unit.player
				and target.movement_domain in _unit.attack_domains
				and (
					_unit.global_position_yless.distance_to(target.global_position_yless)
					<= _unit.sight_range
				)
			)
	)
	if targets.is_empty():
		return
	_engagement_target = WaitingForTargets._pick_closest_unit(targets, _unit)
	_set_sub_action(AutoAttacking.new(_engagement_target), _move)


func _set_sub_action(next_action, finished: Callable):
	if _sub_action != null:
		var previous_action = _sub_action
		_sub_action = null
		previous_action.queue_free()
		remove_child(previous_action)
	_sub_action = next_action
	var expected_action = _sub_action
	_sub_action.tree_exited.connect(
		func():
			if _sub_action == expected_action:
				_sub_action = null
				if is_inside_tree():
					finished.call()
	)
	add_child(_sub_action)

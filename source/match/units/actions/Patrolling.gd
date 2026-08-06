extends "res://source/match/units/actions/Action.gd"

const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")

var _first: Vector3
var _second: Vector3
var _towards_second := true
var _sub_action = null


func _init(first: Vector3, second: Vector3):
	_first = first
	_second = second


func _ready():
	_start_leg()


func _start_leg():
	_sub_action = AttackMoving.new(_second if _towards_second else _first)
	_towards_second = not _towards_second
	_sub_action.tree_exited.connect(
		func():
			_sub_action = null
			if is_inside_tree():
				_start_leg()
	)
	add_child(_sub_action)

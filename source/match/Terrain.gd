extends StaticBody3D

var _command_targeting := false
@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	input_event.connect(_on_input_event)
	MatchSignals.command_targeting_changed.connect(func(active): _command_targeting = active)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if (
		event is InputEventMouseButton
		and (
			event.button_index == MOUSE_BUTTON_RIGHT
			or (_command_targeting and event.button_index == MOUSE_BUTTON_LEFT)
		)
		and event.pressed
	):
		var target_point = get_viewport().get_camera_3d().get_ray_intersection(event.position)
		MatchSignals.terrain_targeted.emit(target_point)

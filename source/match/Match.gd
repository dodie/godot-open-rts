extends Node3D

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Player = preload("res://source/match/players/Player.gd")
const Human = preload("res://source/match/players/human/Human.gd")

const CommandCenter = preload("res://source/match/units/CommandCenter.tscn")
const Drone = preload("res://source/match/units/Drone.tscn")
const Worker = preload("res://source/match/units/Worker.tscn")

const TOUCH_LONG_PRESS_DURATION_SECONDS = 0.6
const TOUCH_LONG_PRESS_MOVEMENT_TOLERANCE = 20.0

@export var settings: Resource = null

var map:
	set = _set_map,
	get = _get_map
var visible_player = null:
	set = _set_visible_player
var visible_players = null:
	set = _ignore,
	get = _get_visible_players

var _touch_positions = {}
var _single_touch_started_at_msec = 0
var _single_touch_start_position = Vector2.ZERO
var _long_press_cancelled = false
var _long_press_triggered = false
var _last_touch_ended_as_tap = false

@onready var navigation = $Navigation
@onready var fog_of_war = $FogOfWar

@onready var _camera = $IsometricCamera3D
@onready var _players = $Players
@onready var _terrain = $Terrain


func _enter_tree():
	assert(settings != null, "match cannot start without settings, see examples in tests/manual/")
	assert(map != null, "match cannot start without map, see examples in tests/manual/")


func _ready():
	MatchSignals.setup_and_spawn_unit.connect(_setup_and_spawn_unit)
	_setup_subsystems_dependent_on_map()
	_setup_players()
	_setup_player_units()
	visible_player = get_tree().get_nodes_in_group("players")[settings.visible_player]
	_move_camera_to_initial_position()
	if settings.visibility == settings.Visibility.FULL:
		fog_of_war.reveal()
	MatchSignals.match_started.emit()


func _process(_delta):
	_try_triggering_touch_long_press()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# A screen touch may also arrive as an emulated left click. Handling that click here
		# would deselect units before the touch has a chance to become a long-press command.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if Input.is_action_pressed("shift_selecting"):
			return
		MatchSignals.deselect_all_units.emit()
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch):
	if event.pressed:
		_last_touch_ended_as_tap = false
		_touch_positions[event.index] = event.position
		if _touch_positions.size() == 1:
			_single_touch_started_at_msec = Time.get_ticks_msec()
			_single_touch_start_position = event.position
			_long_press_cancelled = false
			_long_press_triggered = false
		else:
			_long_press_cancelled = true
	else:
		_touch_positions.erase(event.index)
		if _touch_positions.is_empty():
			_last_touch_ended_as_tap = not _long_press_cancelled and not _long_press_triggered
			_long_press_cancelled = true


func did_last_touch_end_as_tap():
	return _last_touch_ended_as_tap


func handle_screen_touch_during_structure_placement(event: InputEventScreenTouch):
	_handle_screen_touch(event)


func handle_screen_drag_during_structure_placement(event: InputEventScreenDrag):
	_handle_screen_drag(event)


func _handle_screen_drag(event: InputEventScreenDrag):
	if not _touch_positions.has(event.index):
		return
	var previous_positions = _touch_positions.duplicate()
	_touch_positions[event.index] = event.position
	if _touch_positions.size() == 1:
		if (
			event.position.distance_to(_single_touch_start_position)
			> TOUCH_LONG_PRESS_MOVEMENT_TOLERANCE
		):
			_long_press_cancelled = true
		return
	if _touch_positions.size() != 2:
		return

	_long_press_cancelled = true
	var touch_indices = _touch_positions.keys()
	var first_index = touch_indices[0]
	var second_index = touch_indices[1]
	var previous_center = (previous_positions[first_index] + previous_positions[second_index]) / 2.0
	var current_center = (_touch_positions[first_index] + _touch_positions[second_index]) / 2.0
	var previous_distance = previous_positions[first_index].distance_to(
		previous_positions[second_index]
	)
	var current_distance = _touch_positions[first_index].distance_to(_touch_positions[second_index])

	_camera.pan_from_screen_drag(previous_center, current_center)
	if previous_distance > 0.0 and current_distance > 0.0:
		_camera.zoom_at_screen_position(current_center, current_distance / previous_distance)


func _try_triggering_touch_long_press():
	if _long_press_cancelled or _long_press_triggered or _touch_positions.size() != 1:
		return
	if get_tree().get_nodes_in_group("selected_units").is_empty():
		return
	var elapsed_msec = Time.get_ticks_msec() - _single_touch_started_at_msec
	if elapsed_msec < TOUCH_LONG_PRESS_DURATION_SECONDS * 1000.0:
		return
	_long_press_triggered = true
	_emit_right_mouse_click(_single_touch_start_position)


func _emit_right_mouse_click(position: Vector2):
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_RIGHT
	press_event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	press_event.position = position
	press_event.global_position = position
	press_event.pressed = true
	Input.parse_input_event(press_event)

	var release_event = press_event.duplicate()
	release_event.button_mask = 0
	release_event.pressed = false
	Input.parse_input_event(release_event)


func _set_map(a_map):
	assert(get_node_or_null("Map") == null, "map already set")
	a_map.name = "Map"
	add_child(a_map)
	a_map.owner = self


func _ignore(_value):
	pass


func _get_map():
	return get_node_or_null("Map")


func _set_visible_player(player):
	_conceal_player_units(visible_player)
	_reveal_player_units(player)
	visible_player = player


func _get_visible_players():
	if settings.visibility == settings.Visibility.PER_PLAYER:
		return [visible_player]
	return get_tree().get_nodes_in_group("players")


func _setup_subsystems_dependent_on_map():
	_terrain.update_shape(map.find_child("Terrain").mesh)
	fog_of_war.resize(map.size)
	_recalculate_camera_bounding_planes(map.size)
	navigation.setup(map)


func _recalculate_camera_bounding_planes(map_size: Vector2):
	_camera.bounding_planes[1] = Plane(-1, 0, 0, -map_size.x)
	_camera.bounding_planes[3] = Plane(0, 0, -1, -map_size.y)


func _setup_players():
	assert(
		_players.get_children().is_empty() or settings.players.is_empty(),
		"players can be defined either in settings or in scene tree, not in both"
	)
	if _players.get_children().is_empty():
		_create_players_from_settings()
	for node in _players.get_children():
		if node is Player:
			node.add_to_group("players")


func _create_players_from_settings():
	for player_settings in settings.players:
		var player_scene = Constants.Match.Player.CONTROLLER_SCENES[player_settings.controller]
		var player = player_scene.instantiate()
		player.color = player_settings.color
		if player_settings.spawn_index_offset > 0:
			for _i in range(player_settings.spawn_index_offset):
				_players.add_child(Node.new())
		_players.add_child(player)


func _setup_player_units():
	for player in _players.get_children():
		if not player is Player:
			continue
		var player_index = player.get_index()
		var predefined_units = player.get_children().filter(func(child): return child is Unit)
		if not predefined_units.is_empty():
			predefined_units.map(func(unit): _setup_unit_groups(unit, unit.player))
		else:
			_spawn_player_units(
				player, map.find_child("SpawnPoints").get_child(player_index).global_transform
			)


func _spawn_player_units(player, spawn_transform):
	_setup_and_spawn_unit(CommandCenter.instantiate(), spawn_transform, player, false)
	_setup_and_spawn_unit(
		Drone.instantiate(), spawn_transform.translated(Vector3(-2, 0, -2)), player
	)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(-3, 0, 3)), player
	)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(3, 0, 3)), player
	)


func _setup_and_spawn_unit(unit, a_transform, player, mark_structure_under_construction = true):
	unit.global_transform = a_transform
	if unit is Structure and mark_structure_under_construction:
		unit.mark_as_under_construction()
	_setup_unit_groups(unit, player)
	player.add_child(unit)
	MatchSignals.unit_spawned.emit(unit)


func _setup_unit_groups(unit, player):
	unit.add_to_group("units")
	if player == _get_human_player():
		unit.add_to_group("controlled_units")
	else:
		unit.add_to_group("adversary_units")
	if player in visible_players:
		unit.add_to_group("revealed_units")


func _get_human_player():
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	assert(human_players.size() <= 1, "more than one human player is not allowed")
	if not human_players.is_empty():
		return human_players[0]
	return null


func _move_camera_to_initial_position():
	var human_player = _get_human_player()
	if human_player != null:
		_move_camera_to_player_units_crowd_pivot(human_player)
	else:
		_move_camera_to_player_units_crowd_pivot(get_tree().get_nodes_in_group("players")[0])


func _move_camera_to_player_units_crowd_pivot(player):
	var player_units = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.player == player
	)
	assert(not player_units.is_empty(), "player must have at least one initial unit")
	var crowd_pivot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(player_units)
	_camera.set_position_safely(crowd_pivot)


func _reveal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.add_to_group("revealed_units")


func _conceal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.remove_from_group("revealed_units")

extends NavigationObstacle3D

@export var domain = Constants.Match.Navigation.Domain.TERRAIN
@export var path_height_offset = 0.0

@onready var _match = find_parent("Match")
@onready var _unit = get_parent()


func _ready():
	if _match.navigation == null:
		await _match.ready
	set_navigation_map(_match.navigation.get_navigation_map_rid_by_domain(domain))
	await _align_unit_position_to_navigation()
	_affect_navigation_if_needed()


func _exit_tree():
	if affect_navigation_mesh:
		remove_from_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)


func _align_unit_position_to_navigation():
	# Runtime-baked navigation changes are synchronized on physics frames. Until a
	# region is synchronized, closest-point queries return Vector3.ZERO, which
	# would move every structure to the map origin.
	var navigation_map = get_navigation_map()
	while not _is_navigation_map_ready(navigation_map):
		await get_tree().physics_frame
	_unit.global_transform.origin = (
		NavigationServer3D.map_get_closest_point(
			navigation_map, get_parent().global_transform.origin
		)
		- Vector3(0, path_height_offset, 0)
	)


func _is_navigation_map_ready(navigation_map: RID):
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return false
	return (
		NavigationServer3D
		. map_get_closest_point_owner(navigation_map, _unit.global_position)
		. is_valid()
	)


func _affect_navigation_if_needed():
	if affect_navigation_mesh:
		add_to_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)

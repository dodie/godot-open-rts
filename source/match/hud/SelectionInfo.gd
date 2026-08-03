extends PanelContainer

const UNIT_ICONS = {
	"AircraftFactory": preload("res://assets/ui/icons/AircraftFactory.png"),
	"AntiAirTurret": preload("res://assets/ui/icons/AntiAirTurret.png"),
	"AntiGroundTurret": preload("res://assets/ui/icons/AntiGroundTurret.png"),
	"CommandCenter": preload("res://assets/ui/icons/CommandCenter.png"),
	"Drone": preload("res://assets/ui/icons/Drone.png"),
	"Helicopter": preload("res://assets/ui/icons/Helicopter.png"),
	"Launcher": preload("res://assets/ui/icons/Tank.png"),
	"Tank": preload("res://assets/ui/icons/Tank.png"),
	"VehicleFactory": preload("res://assets/ui/icons/VehicleFactory.png"),
	"Worker": preload("res://assets/ui/icons/Worker.png"),
}

const UNIT_NAMES = {
	"AircraftFactory": "Aircraft Factory",
	"AntiAirTurret": "Anti-air Turret",
	"AntiGroundTurret": "Anti-ground Turret",
	"CommandCenter": "Command Center",
	"Drone": "Drone",
	"Helicopter": "Helicopter",
	"Launcher": "Launcher",
	"Tank": "Tank",
	"VehicleFactory": "Vehicle Factory",
	"Worker": "Worker",
}

var _observed_unit = null
var _multiple_unit_health_connections = {}

@onready var _single_unit = %SingleUnit
@onready var _unit_icon = %UnitIcon
@onready var _unit_name = %UnitName
@onready var _health = %Health
@onready var _health_value = %HealthValue
@onready var _damage_value = %DamageValue
@onready var _multiple_units = %MultipleUnits
@onready var _unit_grid = %UnitGrid


func _ready():
	MatchSignals.unit_selected.connect(_on_selection_changed)
	MatchSignals.unit_deselected.connect(_on_selection_changed)
	MatchSignals.unit_died.connect(_on_selection_changed)
	_refresh()


func _on_selection_changed(_unit):
	_refresh()


func _refresh():
	_stop_observing_unit()
	_single_unit.hide()
	_multiple_units.hide()

	var selected_units = get_tree().get_nodes_in_group("selected_units")
	if selected_units.size() == 1:
		_show_single_unit(selected_units[0])
	elif selected_units.size() > 1:
		_show_multiple_units(selected_units)


func _show_single_unit(unit):
	_observed_unit = unit
	if not unit.hp_changed.is_connected(_update_single_unit_health):
		unit.hp_changed.connect(_update_single_unit_health)

	_unit_icon.texture = UNIT_ICONS.get(unit.type)
	_unit_name.text = UNIT_NAMES.get(unit.type, unit.type)
	_damage_value.text = "—" if unit.attack_damage == null else str(unit.attack_damage)
	_update_single_unit_health()
	_single_unit.show()


func _update_single_unit_health():
	if not is_instance_valid(_observed_unit):
		return
	_health.max_value = max(1, _observed_unit.hp_max)
	_health.value = _observed_unit.hp
	_health_value.text = "%s / %s" % [_observed_unit.hp, _observed_unit.hp_max]


func _show_multiple_units(units):
	for child in _unit_grid.get_children():
		child.queue_free()

	for unit in units:
		var unit_tile = VBoxContainer.new()
		unit_tile.custom_minimum_size = Vector2(42, 48)
		unit_tile.add_theme_constant_override("separation", 2)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.texture = UNIT_ICONS.get(unit.type)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = UNIT_NAMES.get(unit.type, unit.type)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		unit_tile.add_child(icon)

		var health = ProgressBar.new()
		health.custom_minimum_size = Vector2(42, 5)
		health.max_value = max(1, unit.hp_max)
		health.value = unit.hp
		health.show_percentage = false
		health.visible = unit.hp < unit.hp_max
		unit_tile.add_child(health)

		var update_health = func():
			if not is_instance_valid(unit):
				return
			health.max_value = max(1, unit.hp_max)
			health.value = unit.hp
			health.visible = unit.hp < unit.hp_max
		unit.hp_changed.connect(update_health)
		_multiple_unit_health_connections[unit] = update_health
		_unit_grid.add_child(unit_tile)
	_multiple_units.show()


func _stop_observing_unit():
	if (
		is_instance_valid(_observed_unit)
		and _observed_unit.hp_changed.is_connected(_update_single_unit_health)
	):
		_observed_unit.hp_changed.disconnect(_update_single_unit_health)
	_observed_unit = null
	for unit in _multiple_unit_health_connections:
		var connection = _multiple_unit_health_connections[unit]
		if is_instance_valid(unit) and unit.hp_changed.is_connected(connection):
			unit.hp_changed.disconnect(connection)
	_multiple_unit_health_connections.clear()

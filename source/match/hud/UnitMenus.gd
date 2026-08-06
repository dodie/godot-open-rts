extends PanelContainer

@onready var _generic_menu = find_child("GenericMenu")
@onready var _build_menu = find_child("BuildMenu")
@onready var _command_menu = find_child("CommandMenu")


func _ready():
	_command_menu.build_requested.connect(_show_build_menu)
	_build_menu.back_requested.connect(_reset_menus)
	_reset_menus()
	MatchSignals.unit_selected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_deselected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_died.connect(func(_unit): _reset_menus())


func _reset_menus():
	_hide_all_menus()
	if _try_showing_any_menu():
		show()
	else:
		hide()


func _hide_all_menus():
	_generic_menu.hide()
	_build_menu.hide()
	_command_menu.hide()


func _try_showing_any_menu():
	var selected_controlled_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	if selected_controlled_units.size() == 1:
		var selected_unit = selected_controlled_units[0]
		var can_build = not UnitCatalog.get_products(selected_unit.definition.id).is_empty()
		if "is_constructed" in selected_unit and not selected_unit.is_constructed():
			can_build = false
		if selected_unit.movement_speed > 0.0:
			_command_menu.units = selected_controlled_units
			_command_menu.can_attack = selected_unit.attack_range != null
			_command_menu.can_build = can_build
			_command_menu.show()
			return true
		if can_build:
			_build_menu.unit = selected_unit
			_build_menu.show_back_button = false
			_build_menu.show()
			if not selected_unit.definition.has_tag(&"worker"):
				return true
	if selected_controlled_units.any(func(unit): return unit.movement_speed > 0.0):
		_command_menu.units = selected_controlled_units
		_command_menu.can_attack = selected_controlled_units.any(
			func(unit): return unit.attack_range != null
		)
		_command_menu.can_build = false
		_command_menu.show()
		return true
	if selected_controlled_units.size() > 0:
		_generic_menu.units = selected_controlled_units
		_generic_menu.show()
		return true
	return false


func _show_build_menu():
	var selected = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	if selected.size() != 1:
		return
	_command_menu.hide()
	_build_menu.unit = selected[0]
	_build_menu.show_back_button = true
	_build_menu._rebuild()
	_build_menu.show()

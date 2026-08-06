extends GridContainer

signal back_requested

const UnitDefinitionType = preload("res://source/match/units/UnitDefinition.gd")

var unit = null:
	set(value):
		if unit != null and unit.player.changed.is_connected(_on_player_changed):
			unit.player.changed.disconnect(_on_player_changed)
		unit = value
		if unit != null and not unit.player.changed.is_connected(_on_player_changed):
			unit.player.changed.connect(_on_player_changed)
		if is_node_ready():
			_rebuild()
var show_back_button := false


func _ready():
	_rebuild()


func _exit_tree():
	if unit != null and unit.player.changed.is_connected(_on_player_changed):
		unit.player.changed.disconnect(_on_player_changed)


func _on_player_changed():
	_rebuild()


func _rebuild():
	for child in get_children():
		child.queue_free()
	if unit == null:
		return
	var next_slot := 1
	for definition in UnitCatalog.get_products(unit.definition.id):
		while next_slot < definition.menu_order:
			_add_padding()
			next_slot += 1
		_add_button(definition)
		next_slot += 1
	if show_back_button:
		while next_slot < 16:
			_add_padding()
			next_slot += 1
		_add_back_button()


func _add_padding():
	var padding = Control.new()
	padding.custom_minimum_size = Vector2(48, 48)
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(padding)


func _add_button(definition):
	var button = Button.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _tooltip(definition)
	var prerequisites_met = unit.player.has_prerequisites(definition)
	button.disabled = not prerequisites_met
	var icon = TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load(definition.icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not prerequisites_met:
		icon.self_modulate = Color(0.35, 0.35, 0.35, 0.75)
	button.add_child(icon)
	button.pressed.connect(_build.bind(definition))
	add_child(button)


func _add_back_button():
	var button = Button.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Back to commands"
	button.text = "↩"
	button.pressed.connect(func(): back_requested.emit())
	add_child(button)


func _tooltip(definition) -> String:
	var combat = ""
	if definition.has_attack():
		combat = ", %.2f DPS" % (definition.attack["damage"] / definition.attack["interval"])
	var prerequisite_text := ""
	if not unit.player.has_prerequisites(definition):
		var names := PackedStringArray()
		for prerequisite_id in definition.prerequisites:
			names.append(UnitCatalog.get_definition(prerequisite_id).display_name)
		prerequisite_text = "\nRequires: %s" % ", ".join(names)
	return (
		"%s - %s\n%s HP%s\n%s: %s, %s: %s%s"
		% [
			definition.display_name,
			definition.description,
			definition.hp_max,
			combat,
			tr("RESOURCE_A"),
			definition.cost().get("resource_a", 0),
			tr("RESOURCE_B"),
			definition.cost().get("resource_b", 0),
			prerequisite_text,
		]
	)


func _build(definition):
	if not unit.player.has_prerequisites(definition):
		return
	if definition.build_mode() == UnitDefinitionType.BuildMode.PRODUCTION:
		unit.production_queue.produce(definition.id)
	else:
		MatchSignals.place_structure.emit(definition.id)

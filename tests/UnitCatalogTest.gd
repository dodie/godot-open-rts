extends SceneTree


func _initialize():
	var catalog = root.get_node("UnitCatalog")
	assert(catalog.all().size() == 12)
	for definition in catalog.all():
		var unit = catalog.instantiate(definition.id)
		assert(unit.definition == definition)
		assert(unit.get_script().resource_path == definition.behavior_path)
		unit.free()
	assert(_ids(catalog.get_products(&"command_center")) == [&"worker"])
	assert(_ids(catalog.get_products(&"vehicle_factory")) == [&"tank", &"launcher"])
	assert(_ids(catalog.get_products(&"aircraft_factory")) == [&"helicopter", &"drone"])
	assert(catalog.get_definition(&"command_center").supply_granted == 8)
	assert(catalog.get_definition(&"helicopter").prerequisites == [&"armory"])
	var armory = catalog.get_definition(&"armory")
	assert(armory.structure["footprint"] == Vector2i(2, 2))
	var supply_farm = catalog.get_definition(&"supply_farm")
	assert(supply_farm.supply_granted == 8)
	assert(supply_farm.structure["footprint"] == Vector2i(2, 2))
	for id in [&"worker", &"drone", &"launcher"]:
		assert(catalog.get_definition(id).supply_cost == 1)
	for id in [&"tank", &"helicopter"]:
		assert(catalog.get_definition(id).supply_cost == 2)
	assert(
		(
			_ids(catalog.get_products(&"worker"))
			== [
				&"anti_ground_turret",
				&"anti_air_turret",
				&"supply_farm",
				&"armory",
				&"command_center",
				&"vehicle_factory",
				&"aircraft_factory",
			]
		)
	)
	quit()


func _ids(definitions: Array) -> Array:
	return definitions.map(func(definition): return definition.id)

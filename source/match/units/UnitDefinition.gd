class_name UnitDefinition
extends RefCounted

enum BuildMode { NONE, PRODUCTION, CONSTRUCTION }

var id: StringName
var display_name := ""
var description := ""
var scene_path := ""
var behavior_path := ""
var icon_path := ""
var menu_order := 0
var tags: Array[StringName] = []

var hp_max := 1
var sight_range := 0.0
var movement := {}
var attack := {}
var build := {"mode": BuildMode.NONE}
var structure := {}
var cargo := {}


func has_attack() -> bool:
	return not attack.is_empty()


func is_structure() -> bool:
	return not structure.is_empty()


func producer_id() -> StringName:
	return build.get("producer_id", &"")


func build_mode() -> BuildMode:
	return build.get("mode", BuildMode.NONE)


func cost() -> Dictionary:
	return build.get("cost", {})


func has_tag(tag: StringName) -> bool:
	return tag in tags

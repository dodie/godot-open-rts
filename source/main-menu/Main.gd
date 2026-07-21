extends Control

const BUILD_INFO_PATH = "res://source/BuildInfo.gd"


func _ready():
	if ResourceLoader.exists(BUILD_INFO_PATH):
		$BuildTimestamp.text = "Build: %s" % load(BUILD_INFO_PATH).BUILD_TIMESTAMP


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Play.tscn")


func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Options.tscn")


func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Credits.tscn")


func _on_quit_button_pressed():
	get_tree().quit()

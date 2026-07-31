extends Node3D


func _ready():
	var longest_lifetime := 0.0
	for particles in find_children("*", "GPUParticles3D", true, false):
		longest_lifetime = max(longest_lifetime, particles.lifetime)
		particles.restart()

	await get_tree().create_timer(longest_lifetime).timeout
	queue_free()

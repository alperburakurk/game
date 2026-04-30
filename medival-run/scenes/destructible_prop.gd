extends RigidBody2D

const MAX_SPAWN_COINS := 64

@export var coin_scene: PackedScene
@export_range(0, 64, 1) var coin_min: int = 0
@export_range(0, 64, 1) var coin_max: int = 0

func take_damage() -> void:
	_spawn_coins()
	queue_free()

func _spawn_coins() -> void:
	if coin_scene == null:
		return
	var lo: int = max(0, coin_min)
	var hi: int = max(lo, coin_max)
	if hi <= 0:
		return
	var count := randi_range(lo, hi)
	if count <= 0:
		return
	count = min(count, MAX_SPAWN_COINS)
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var spawn_global := global_position
	for i in count:
		var coin := coin_scene.instantiate()
		parent.add_child(coin)
		coin.global_position = spawn_global
		if coin.has_method("pop"):
			coin.call_deferred("pop", 0)

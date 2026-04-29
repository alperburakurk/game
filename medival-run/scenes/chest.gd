extends StaticBody2D

enum State { CLOSED, OPENING, OPEN }

@export var key_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea

var state: State = State.CLOSED
var player_in_range := false

func _ready() -> void:
	sprite.play("closed")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)

func _unhandled_input(event: InputEvent) -> void:
	if state != State.CLOSED or not player_in_range:
		return
	if event.is_action_pressed("attack"):
		_open()

func _open() -> void:
	state = State.OPENING
	sprite.play("opening")

func _on_animation_finished() -> void:
	if sprite.animation == "opening":
		state = State.OPEN
		sprite.play("open")
		_spawn_key()

func _spawn_key() -> void:
	if key_scene == null:
		return
	var key := key_scene.instantiate()
	get_tree().current_scene.add_child(key)
	key.global_position = global_position + Vector2(0, -2)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false

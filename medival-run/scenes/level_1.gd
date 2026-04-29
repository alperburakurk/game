extends Node2D

@onready var player = $Floor/Player
@onready var game_over_label = $UI/"Game Over"
@onready var key_count_label: Label = $UI/KeyCounter/Count

var game_over := false
var key_count := 0

func _ready() -> void:
	game_over_label.visible = false
	_refresh_key_label()

func _process(_delta: float) -> void:
	if game_over:
		return

	if player != null and player.has_method("is_player_dead") and player.is_player_dead():
		game_over = true
		game_over_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func add_key() -> void:
	key_count += 1
	_refresh_key_label()

func _refresh_key_label() -> void:
	if key_count_label != null:
		key_count_label.text = "x %d" % key_count

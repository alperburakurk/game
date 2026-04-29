extends Node2D

@onready var player = $Floor/Player
@onready var game_over_label = $"UI/Game Over"

var game_over := false

func _ready():
	game_over_label.visible = false

func _process(_delta):
	if not game_over and player.has_method("is_player_dead") and player.is_player_dead():
		game_over = true
		game_over_label.visible = true

func _unhandled_input(event):
	if not game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

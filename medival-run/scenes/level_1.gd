extends Node2D

@onready var player = $Floor/Player
@onready var game_over_label = $"UI/Game Over"
@onready var ui_layer = $UI

var game_over := false
var game_over_overlay: ColorRect

func _ready():
	game_over_overlay = ColorRect.new()
	game_over_overlay.color = Color(0, 0, 0, 0.7)
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	ui_layer.add_child(game_over_overlay)

	game_over_label.modulate = Color(1, 1, 1, 1)
	game_over_label.text = "GAME OVER\nPress R to Restart"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.z_index = 1
	_center_game_over_label()
	game_over_label.visible = false

func _process(_delta):
	if not game_over and player.has_method("is_player_dead") and player.is_player_dead():
		game_over = true
		game_over_overlay.visible = true
		game_over_label.visible = true

func _unhandled_input(event):
	if not game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _center_game_over_label():
	var viewport_size = get_viewport_rect().size
	var panel_width = 500.0
	var panel_height = 140.0
	game_over_label.position = Vector2(
		(viewport_size.x - panel_width) * 0.5,
		(viewport_size.y - panel_height) * 0.5
	)
	game_over_label.size = Vector2(panel_width, panel_height)

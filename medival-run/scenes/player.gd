extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_bar = get_tree().current_scene.get_node("UI/HealthBar")
@onready var ui_layer = get_tree().current_scene.get_node_or_null("UI")
@onready var game_over_label = get_tree().current_scene.get_node_or_null("UI/Game Over")

var is_attacking := false
var facing_direction := 1

var max_health := 6
var health := 6
var is_dead := false
var game_over_overlay: ColorRect

func _ready():
	attack_area.monitoring = false
	health_bar.max_value = max_health
	health_bar.value = health
	
	if ui_layer != null and game_over_label != null:
		game_over_overlay = ColorRect.new()
		game_over_overlay.color = Color(0, 0, 0, 0.7)
		game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		game_over_overlay.visible = false
		ui_layer.add_child(game_over_overlay)
		
		game_over_label.modulate = Color(1, 1, 1, 1)
		game_over_label.text = "GAME OVER\nPress R to Restart"
		game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		game_over_label.position = Vector2(326, 254)
		game_over_label.size = Vector2(500, 140)
		game_over_label.z_index = 1
		game_over_label.visible = false

func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction = Input.get_axis("ui_left", "ui_right")

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	if not is_attacking:
		if direction != 0:
			velocity.x = direction * SPEED
			facing_direction = direction
			sprite.flip_h = direction < 0
			attack_area.position.x = abs(attack_area.position.x) * facing_direction
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	if not is_attacking:
		if not is_on_floor():
			if velocity.y < 0:
				sprite.play("jump")
			else:
				sprite.play("fall")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()

func attack():
	is_attacking = true
	velocity.x = 0
	
	attack_area.monitoring = true
	sprite.play("attack")

	await get_tree().physics_frame

	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage()

	await sprite.animation_finished

	attack_area.monitoring = false
	is_attacking = false

func take_damage(amount := 1):
	if is_dead:
		return
	
	health -= amount
	health = max(health, 0)
	health_bar.value = health
	
	if health <= 0:
		die()
	else:
		is_attacking = false
		sprite.play("hurt_effect")
		await get_tree().create_timer(0.5).timeout

func die():
	is_dead = true
	velocity = Vector2.ZERO
	attack_area.monitoring = false
	sprite.play("death")
	if game_over_label != null:
		game_over_label.visible = true
	if game_over_overlay != null:
		game_over_overlay.visible = true
	await sprite.animation_finished

func _unhandled_input(event):
	if not is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func is_player_dead():
	return is_dead

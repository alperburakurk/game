extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var health_bar = get_tree().current_scene.get_node("UI/HealthBar")

var is_attacking := false
var facing_direction := 1

var max_health := 6
var health := 6
var is_dead := false

func _ready():
	attack_area.monitoring = false
	health_bar.max_value = max_health
	health_bar.value = health

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
	await sprite.animation_finished

func is_player_dead():
	return is_dead

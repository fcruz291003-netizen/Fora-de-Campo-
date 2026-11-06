class_name SoccerBall
extends Node2D
## Bola com física simples: atrito no chão, gravidade no ar (cruzamentos/lançamentos).

const GRAVITY := 900.0
const FRICTION := 1.1

var vel: Vector2 = Vector2.ZERO
var z: float = 0.0          # altura
var vz: float = 0.0
var holder: Footballer = null      # quem está conduzindo a bola
var pickup_cd: float = 0.0
var kicker: Footballer = null      # último a chutar/passar
var assister: Footballer = null
var target_receiver: Footballer = null
var shot_active: bool = false
var shot_team: int = -1
var kick_was_shot: bool = false
var last_touch_team: int = 0


func physics_step(delta: float) -> void:
	if holder != null:
		return
	pickup_cd = maxf(0.0, pickup_cd - delta)
	if z > 0.0 or vz != 0.0:
		vz -= GRAVITY * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			if absf(vz) > 140.0:
				vz = -vz * 0.45
				vel *= 0.55
			else:
				vz = 0.0
	else:
		vel *= exp(-FRICTION * delta)
		if vel.length() < 8.0:
			vel = Vector2.ZERO
	position += vel * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
	var off := Vector2(0.0, -z * 0.6)
	var r: float = 8.0 + z * 0.012
	draw_circle(off, r, Color(1, 1, 1))
	draw_arc(off, r, 0.0, TAU, 16, Color(0.1, 0.1, 0.1), 2.0)

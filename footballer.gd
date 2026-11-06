class_name Footballer
extends Node2D
## Um jogador em campo (seu jogador, companheiros e adversários).

var team: int = 0                      # 0 = seu time, 1 = rival
var role: String = "CM"
var number: int = 1
var is_gk: bool = false
var is_user: bool = false
var formation_pos: Vector2 = Vector2.ZERO   # posição tática normalizada (x: -1 próprio gol .. +1 gol rival)
var attrs: Dictionary = {
	"pace": 70, "shooting": 70, "passing": 70,
	"dribbling": 70, "defending": 70, "physical": 70
}
var kit_color: Color = Color.WHITE

var stamina: float = 100.0
var facing: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var sprinting: bool = false

var no_pickup: float = 0.0      # tempo sem poder pegar a bola (depois de chutar/perder)
var tackle_cd: float = 0.0
var hold_timer: float = 0.0     # espera antes de agir (reposições)
var think_timer: float = 0.0
var carry_time: float = 0.0

var move_input: Vector2 = Vector2.ZERO
var slide_t: float = 0.0
var slide_recover: float = 0.0
var slide_dir: Vector2 = Vector2.RIGHT
var slide_resolved: bool = false

var assist_from: Footballer = null
var assist_timer: float = 0.0   # por quanto tempo o passe recebido ainda conta como assistência


func _draw() -> void:
	if is_user:
		draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.9, 0.2, 0.30))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -34), Vector2(-9, -50), Vector2(9, -50)]),
			Color(1.0, 0.9, 0.2))
	draw_circle(Vector2(2, 3), 14.0, Color(0, 0, 0, 0.25))
	var body: Color = kit_color
	if slide_t > 0.0:
		body = body.lightened(0.35)
	draw_circle(Vector2.ZERO, 14.0, body)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
	draw_line(Vector2.ZERO, facing * 20.0, Color(1, 1, 1, 0.9), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-14, 5), str(number),
		HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color(1, 1, 1))

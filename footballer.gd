class_name Footballer
extends Node2D
## Um jogador em campo (seu jogador, companheiros, adversários e árbitro).
## Desenhado "de cima": sombra, pés, braços, tronco (ombros), cabeça com cabelo.

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
var kit_trim: Color = Color.WHITE        # mangas
var skin: Color = Color(0.93, 0.76, 0.62)
var hair: Color = Color(0.15, 0.10, 0.08)
var show_number: bool = true
var anim_t: float = 0.0                  # fase da corrida (animação dos pés/braços)

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
		draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.9, 0.2, 0.22))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)

	# sombra
	draw_set_transform(Vector2(3.0, 5.0), 0.0, Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.22))

	var ang: float = facing.angle()
	var run: float = clampf(velocity.length() / 260.0, 0.0, 1.3)
	var sw: float = sin(anim_t) * 7.0 * run
	var sliding: bool = slide_t > 0.0
	var shirt: Color = kit_color.lightened(0.3) if sliding else kit_color
	var boot: Color = Color(0.1, 0.1, 0.1)
	var glove: Color = Color(1.0, 0.55, 0.1) if is_gk else skin

	# pés (eixo +x = para onde ele olha)
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	if sliding:
		draw_circle(Vector2(13.0, -3.0), 3.8, boot)
		draw_circle(Vector2(11.0, 3.0), 3.8, boot)
	else:
		draw_circle(Vector2(sw, -5.0), 3.8, boot)
		draw_circle(Vector2(-sw, 5.0), 3.8, boot)

	# braços: manga + mão
	draw_circle(Vector2(-sw * 0.6, -10.0), 3.4, kit_trim)
	draw_circle(Vector2(sw * 0.6, 10.0), 3.4, kit_trim)
	draw_circle(Vector2(-sw * 0.6 + 1.5, -11.5), 2.2, glove)
	draw_circle(Vector2(sw * 0.6 + 1.5, 11.5), 2.2, glove)

	# tronco (ombros largos, vistos de cima)
	draw_set_transform(Vector2.ZERO, ang, Vector2(0.62, 1.0))
	draw_circle(Vector2.ZERO, 10.5, shirt)
	draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 20, kit_trim, 1.5)

	# cabeça: cabelo + rosto virado para frente
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_circle(Vector2(1.0, 0.0), 5.6, hair)
	draw_circle(Vector2(3.0, 0.0), 3.0, skin)

	# marcador do seu jogador (sempre na vertical da tela)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_user:
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -30), Vector2(-9, -46), Vector2(9, -46)]),
			Color(1.0, 0.9, 0.2))
	if show_number and is_user:
		draw_string(ThemeDB.fallback_font, Vector2(-14, -52), str(number),
			HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color(1, 1, 1))

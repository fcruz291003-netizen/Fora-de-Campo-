class_name PitchView
extends Node2D
## Desenha o gramado, as linhas e os gols.

const W := 1200.0
const H := 700.0
const GOAL_HALF := 100.0


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	var line_col := Color(1, 1, 1, 0.85)
	# fora do campo
	draw_rect(Rect2(-W - 500.0, -H - 500.0, 2.0 * W + 1000.0, 2.0 * H + 1000.0), Color(0.08, 0.24, 0.09))
	# faixas do gramado
	var n: int = 12
	var sw: float = 2.0 * W / float(n)
	for i in range(n):
		var c: Color = Color(0.16, 0.50, 0.18) if i % 2 == 0 else Color(0.14, 0.46, 0.16)
		draw_rect(Rect2(-W + float(i) * sw, -H, sw, 2.0 * H), c)
	# linhas
	draw_rect(Rect2(-W, -H, 2.0 * W, 2.0 * H), line_col, false, 4.0)
	draw_line(Vector2(0, -H), Vector2(0, H), line_col, 4.0)
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 64, line_col, 4.0)
	draw_circle(Vector2.ZERO, 6.0, line_col)
	for s in [-1.0, 1.0]:
		var sx: float = s
		# grande área
		var bx: float = sx * W if sx < 0.0 else sx * W - 260.0
		draw_rect(Rect2(bx, -330.0, 260.0, 660.0), line_col, false, 4.0)
		# pequena área
		var sbx: float = sx * W if sx < 0.0 else sx * W - 90.0
		draw_rect(Rect2(sbx, -170.0, 90.0, 340.0), line_col, false, 4.0)
		# marca do pênalti
		draw_circle(Vector2(sx * (W - 170.0), 0.0), 5.0, line_col)
		# gol
		var gx: float = sx * W if sx < 0.0 else sx * W
		var goal_rect: Rect2
		if sx < 0.0:
			goal_rect = Rect2(-W - 50.0, -GOAL_HALF, 50.0, 2.0 * GOAL_HALF)
		else:
			goal_rect = Rect2(W, -GOAL_HALF, 50.0, 2.0 * GOAL_HALF)
		draw_rect(goal_rect, Color(0, 0, 0, 0.35))
		draw_rect(goal_rect, Color(1, 1, 1, 0.95), false, 4.0)
		gx += 0.0

class_name MatchHud
extends Control
## Placar, relógio, fôlego, barra de força do chute, mensagens e tela de fim de jogo.

var team_names: Array = ["MEU TIME", "RIVAL FC"]
var score: Array = [0, 0]
var clock_text: String = "0'"
var half_text: String = "1T"
var stamina: float = 100.0
var charge: float = 0.0
var message: String = ""
var hint: String = ""
var show_end: bool = false
var end_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font

	# placar + relógio
	var bw := 520.0
	var bx: float = (s.x - bw) * 0.5
	draw_rect(Rect2(bx, 10.0, bw, 76.0), Color(0, 0, 0, 0.55))
	var line: String = "%s  %d x %d  %s" % [team_names[0], score[0], score[1], team_names[1]]
	draw_string(font, Vector2(bx, 44.0), line, HORIZONTAL_ALIGNMENT_CENTER, bw, 26, Color.WHITE)
	draw_string(font, Vector2(bx, 74.0), "%s   %s" % [clock_text, half_text],
		HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color(1, 1, 1, 0.85))

	# fôlego
	draw_string(font, Vector2(20.0, 22.0), "FÔLEGO", HORIZONTAL_ALIGNMENT_LEFT, 200.0, 14, Color(1, 1, 1, 0.9))
	draw_rect(Rect2(20.0, 28.0, 200.0, 14.0), Color(0, 0, 0, 0.5))
	var sf: float = clampf(stamina / 100.0, 0.0, 1.0)
	var scol: Color = Color(0.3, 0.9, 0.35) if sf > 0.35 else Color(0.95, 0.35, 0.25)
	draw_rect(Rect2(20.0, 28.0, 200.0 * sf, 14.0), scol)

	# força do chute (perto do botão CHUTE)
	if charge > 0.0:
		var cx: float = s.x - 170.0
		var cy: float = s.y - 228.0
		draw_rect(Rect2(cx, cy, 100.0, 12.0), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(cx, cy, 100.0 * charge, 12.0), Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.25, 0.1), charge))

	# dica de controles (teclado)
	if hint != "":
		draw_string(font, Vector2(0.0, s.y - 12.0), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(1, 1, 1, 0.7))

	# mensagem central
	if message != "":
		draw_string(font, Vector2(3.0, s.y * 0.33 + 3.0), message, HORIZONTAL_ALIGNMENT_CENTER, s.x, 56, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0.0, s.y * 0.33), message, HORIZONTAL_ALIGNMENT_CENTER, s.x, 56, Color(1, 1, 1))

	# fim de jogo
	if show_end:
		var pw := 640.0
		var ph: float = 90.0 + 40.0 * float(end_lines.size())
		var px: float = (s.x - pw) * 0.5
		var py: float = (s.y - ph) * 0.5
		draw_rect(Rect2(px, py, pw, ph), Color(0, 0, 0, 0.82))
		draw_rect(Rect2(px, py, pw, ph), Color(1, 1, 1, 0.8), false, 3.0)
		draw_string(font, Vector2(px, py + 48.0), "FIM DE JOGO", HORIZONTAL_ALIGNMENT_CENTER, pw, 34, Color(1.0, 0.9, 0.3))
		for i in range(end_lines.size()):
			draw_string(font, Vector2(px, py + 92.0 + 40.0 * float(i)), end_lines[i],
				HORIZONTAL_ALIGNMENT_CENTER, pw, 24, Color.WHITE)

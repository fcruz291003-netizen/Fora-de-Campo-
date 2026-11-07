class_name PitchView
extends Node2D
## Campo + estádio: gramado, linhas, gols com rede, placas de publicidade,
## arquibancadas com torcida, bancos de reserva (reservas + técnico) e bandeirinhas.
## Tudo desenhado por código (arte própria), sem imagens externas.

const W := 1200.0
const H := 700.0
const GOAL_HALF := 100.0
const MARGIN := 130.0        # faixa de grama entre as linhas e as placas
const STAND := 300.0         # profundidade das arquibancadas

const HOME_SHIRT := Color(0.15, 0.45, 1.0)
const AWAY_SHIRT := Color(0.9, 0.2, 0.2)

const SKINS := [
	Color(0.96, 0.80, 0.66), Color(0.87, 0.68, 0.52), Color(0.72, 0.52, 0.38),
	Color(0.55, 0.37, 0.26), Color(0.38, 0.25, 0.18),
]
const HAIRS := [
	Color(0.08, 0.06, 0.05), Color(0.25, 0.15, 0.08), Color(0.55, 0.35, 0.15),
	Color(0.85, 0.70, 0.35), Color(0.15, 0.15, 0.15),
]


func _ready() -> void:
	z_index = -10
	var long_tex: ImageTexture = _make_crowd(int(2.0 * (W + MARGIN + STAND)), int(STAND), 0, 11)
	var side_tex: ImageTexture = _make_crowd(int(STAND), int(2.0 * (H + MARGIN)), 1, 22)
	var x0: float = -(W + MARGIN + STAND)
	_add_stand(long_tex, Vector2(x0, -H - MARGIN - STAND), false, false)   # topo
	_add_stand(long_tex, Vector2(x0, H + MARGIN), false, true)             # baixo (espelhada)
	_add_stand(side_tex, Vector2(-W - MARGIN - STAND, -H - MARGIN), false, false)  # esquerda
	_add_stand(side_tex, Vector2(W + MARGIN, -H - MARGIN), true, false)            # direita


func _add_stand(tex: Texture2D, pos: Vector2, flip_h: bool, flip_v: bool) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.flip_h = flip_h
	s.flip_v = flip_v
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)


# ---------------------------------------------------------------- torcida (textura gerada uma vez)
# orient 0: o campo fica embaixo da imagem; orient 1: o campo fica à direita.
func _make_crowd(w: int, h: int, orient: int, seed_v: int) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.80, 0.80, 0.84))
	var shirts: Array = [
		HOME_SHIRT, HOME_SHIRT, HOME_SHIRT, AWAY_SHIRT, AWAY_SHIRT,
		Color(1, 1, 1), Color(0.95, 0.85, 0.2), Color(0.2, 0.2, 0.25),
		Color(0.2, 0.7, 0.35), Color(0.9, 0.5, 0.1), Color(0.6, 0.3, 0.8),
	]
	var step_a: int = 13
	var step_b: int = 14
	var dark := Color(0.62, 0.62, 0.68)
	if orient == 0:
		var rows: int = h / step_b
		for row in range(rows):
			var y: int = row * step_b
			img.fill_rect(Rect2i(0, y + step_b - 3, w, 3), dark)
			var x: int = 6 + (row % 2) * 6
			while x < w - 6:
				if r.randf() < 0.9:
					var sh: Color = shirts[r.randi() % shirts.size()]
					var sk: Color = SKINS[r.randi() % SKINS.size()]
					var hr: Color = HAIRS[r.randi() % HAIRS.size()]
					_put_person(img, x, y + 6, 0, 1, sh, sk, hr, r.randf() < 0.12)
				x += step_a
	else:
		var cols: int = w / step_b
		for col in range(cols):
			var cx: int = col * step_b
			img.fill_rect(Rect2i(cx + step_b - 3, 0, 3, h), dark)
			var y2: int = 6 + (col % 2) * 6
			while y2 < h - 6:
				if r.randf() < 0.9:
					var sh2: Color = shirts[r.randi() % shirts.size()]
					var sk2: Color = SKINS[r.randi() % SKINS.size()]
					var hr2: Color = HAIRS[r.randi() % HAIRS.size()]
					_put_person(img, cx + 5, y2, 1, 0, sh2, sk2, hr2, r.randf() < 0.12)
				y2 += step_a
	return ImageTexture.create_from_image(img)


# (dx, dy) = direção para onde a pessoa olha (para o campo)
func _put_person(img: Image, cx: int, cy: int, dx: int, dy: int, shirt: Color, skin: Color, hair: Color, arms_up: bool) -> void:
	if dx == 0:
		img.fill_rect(Rect2i(cx - 4, cy - 3, 9, 5), shirt)
		var hy: int = cy + 2 if dy > 0 else cy - 6
		img.fill_rect(Rect2i(cx - 2, hy, 5, 4), skin)
		var hair_y: int = hy if dy > 0 else hy + 2
		img.fill_rect(Rect2i(cx - 2, hair_y, 5, 2), hair)
		if arms_up:
			var ay: int = cy + 2 if dy > 0 else cy - 7
			img.fill_rect(Rect2i(cx - 6, ay, 2, 5), skin)
			img.fill_rect(Rect2i(cx + 5, ay, 2, 5), skin)
	else:
		img.fill_rect(Rect2i(cx - 3, cy - 4, 5, 9), shirt)
		var hx: int = cx + 2 if dx > 0 else cx - 6
		img.fill_rect(Rect2i(hx, cy - 2, 4, 5), skin)
		var hair_x: int = hx if dx > 0 else hx + 2
		img.fill_rect(Rect2i(hair_x, cy - 2, 2, 5), hair)
		if arms_up:
			var ax: int = cx + 2 if dx > 0 else cx - 7
			img.fill_rect(Rect2i(ax, cy - 6, 5, 2), skin)
			img.fill_rect(Rect2i(ax, cy + 5, 5, 2), skin)


# ---------------------------------------------------------------- campo
func _draw() -> void:
	var line_col := Color(1, 1, 1, 0.88)
	var rr := RandomNumberGenerator.new()
	rr.seed = 7

	# chão do estádio e grama externa
	var ext: float = W + MARGIN + STAND + 40.0
	var exth: float = H + MARGIN + STAND + 40.0
	draw_rect(Rect2(-ext, -exth, 2.0 * ext, 2.0 * exth), Color(0.12, 0.13, 0.16))
	draw_rect(Rect2(-W - MARGIN, -H - MARGIN, 2.0 * (W + MARGIN), 2.0 * (H + MARGIN)), Color(0.10, 0.34, 0.12))

	# faixas do gramado
	var n: int = 16
	var sw: float = 2.0 * W / float(n)
	for i in range(n):
		var c: Color = Color(0.17, 0.52, 0.19) if i % 2 == 0 else Color(0.14, 0.46, 0.16)
		draw_rect(Rect2(-W + float(i) * sw, -H, sw, 2.0 * H), c)
	# manchas leves no gramado
	for i in range(450):
		var px: float = rr.randf_range(-W, W)
		var py: float = rr.randf_range(-H, H)
		var pw: float = rr.randf_range(30.0, 140.0)
		var ph: float = rr.randf_range(20.0, 90.0)
		var a: float = rr.randf_range(0.015, 0.04)
		var pc: Color = Color(0, 0, 0, a) if rr.randf() < 0.5 else Color(1, 1, 1, a)
		draw_rect(Rect2(px, py, pw, ph), pc)

	# linhas
	draw_rect(Rect2(-W, -H, 2.0 * W, 2.0 * H), line_col, false, 4.0)
	draw_line(Vector2(0, -H), Vector2(0, H), line_col, 4.0)
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 64, line_col, 4.0)
	draw_circle(Vector2.ZERO, 6.0, line_col)
	for s: float in [-1.0, 1.0]:
		var bx: float = s * W if s < 0.0 else s * W - 260.0
		draw_rect(Rect2(bx, -330.0, 260.0, 660.0), line_col, false, 4.0)
		var sbx: float = s * W if s < 0.0 else s * W - 90.0
		draw_rect(Rect2(sbx, -170.0, 90.0, 340.0), line_col, false, 4.0)
		var spot := Vector2(s * (W - 170.0), 0.0)
		draw_circle(spot, 5.0, line_col)
		# meia-lua da área
		if s < 0.0:
			draw_arc(spot, 150.0, -0.927, 0.927, 24, line_col, 4.0)
		else:
			draw_arc(spot, 150.0, PI - 0.927, PI + 0.927, 24, line_col, 4.0)
		# gol com rede
		var gr: Rect2
		if s < 0.0:
			gr = Rect2(-W - 50.0, -GOAL_HALF, 50.0, 2.0 * GOAL_HALF)
		else:
			gr = Rect2(W, -GOAL_HALF, 50.0, 2.0 * GOAL_HALF)
		draw_rect(gr, Color(0, 0, 0, 0.30))
		var yy: float = gr.position.y
		while yy <= gr.position.y + gr.size.y:
			draw_line(Vector2(gr.position.x, yy), Vector2(gr.position.x + gr.size.x, yy), Color(1, 1, 1, 0.28), 1.0)
			yy += 10.0
		var xx: float = gr.position.x
		while xx <= gr.position.x + gr.size.x:
			draw_line(Vector2(xx, gr.position.y), Vector2(xx, gr.position.y + gr.size.y), Color(1, 1, 1, 0.28), 1.0)
			xx += 10.0
		draw_rect(gr, Color(1, 1, 1, 0.95), false, 4.0)
		draw_circle(Vector2(s * W, -GOAL_HALF), 6.0, Color(1, 1, 1))
		draw_circle(Vector2(s * W, GOAL_HALF), 6.0, Color(1, 1, 1))

	# arcos de escanteio e bandeirinhas
	draw_arc(Vector2(-W, -H), 22.0, 0.0, PI * 0.5, 8, line_col, 3.0)
	draw_arc(Vector2(W, -H), 22.0, PI * 0.5, PI, 8, line_col, 3.0)
	draw_arc(Vector2(W, H), 22.0, PI, PI * 1.5, 8, line_col, 3.0)
	draw_arc(Vector2(-W, H), 22.0, PI * 1.5, TAU, 8, line_col, 3.0)
	for fx: float in [-W, W]:
		for fy: float in [-H, H]:
			var sx: float = signf(fx)
			var sy: float = signf(fy)
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx, fy),
				Vector2(fx - sx * 18.0, fy - sy * 4.0),
				Vector2(fx - sx * 8.0, fy - sy * 14.0)]), Color(0.95, 0.8, 0.1))
			draw_circle(Vector2(fx, fy), 3.5, Color(1, 1, 1))

	_draw_boards()
	# bancos de reserva (lado de baixo, um de cada lado da linha do meio)
	_draw_dugout(-560.0, HOME_SHIRT, Color(0.1, 0.15, 0.3))
	_draw_dugout(560.0, AWAY_SHIRT, Color(0.3, 0.1, 0.1))


# ---------------------------------------------------------------- placas de publicidade (marcas fictícias)
func _draw_boards() -> void:
	var font: Font = ThemeDB.fallback_font
	var names: Array = ["CARREIRA FC", "SUPER LIGA", "GOL TV", "FUTEBOL MAX", "RADIO TORCIDA", "PASSA BOLA"]
	var cols: Array = [
		Color(0.85, 0.15, 0.15), Color(0.10, 0.35, 0.80), Color(0.90, 0.70, 0.10),
		Color(0.10, 0.55, 0.30), Color(0.35, 0.15, 0.60), Color(0.90, 0.40, 0.10),
	]
	var seg: float = 240.0
	var total: float = 2.0 * (W + MARGIN)
	var count: int = int(total / seg) + 1
	for i in range(count):
		var x: float = -W - MARGIN + float(i) * seg
		var wseg: float = minf(seg, W + MARGIN - x)
		if wseg <= 4.0:
			break
		var c: Color = cols[i % cols.size()]
		var nm: String = names[i % names.size()]
		for side: float in [-1.0, 1.0]:
			var y: float = -H - MARGIN if side < 0.0 else H + MARGIN - 16.0
			draw_rect(Rect2(x, y, wseg - 3.0, 16.0), c)
			draw_string(font, Vector2(x, y + 12.0), nm, HORIZONTAL_ALIGNMENT_CENTER, wseg - 3.0, 12, Color(1, 1, 1))
	var vtotal: float = 2.0 * (H + MARGIN)
	var vcount: int = int(vtotal / seg) + 1
	for j in range(vcount):
		var y0: float = -H - MARGIN + float(j) * seg
		var hseg: float = minf(seg, H + MARGIN - y0)
		if hseg <= 4.0:
			break
		var vc: Color = cols[(j + 2) % cols.size()]
		draw_rect(Rect2(-W - MARGIN, y0, 16.0, hseg - 3.0), vc)
		draw_rect(Rect2(W + MARGIN - 16.0, y0, 16.0, hseg - 3.0), vc)


# ---------------------------------------------------------------- banco de reservas
func _draw_dugout(cx: float, shirt: Color, suit: Color) -> void:
	var top: float = H + 30.0
	var dw: float = 420.0
	draw_rect(Rect2(cx - dw * 0.5, top, dw, 62.0), Color(0.22, 0.24, 0.28))
	draw_rect(Rect2(cx - dw * 0.5 + 6.0, top + 34.0, dw - 12.0, 16.0), Color(0.45, 0.30, 0.18))
	# reservas sentados, virados para o campo
	for i in range(8):
		var px: float = cx - dw * 0.5 + 36.0 + float(i) * 48.0
		_draw_person(Vector2(px, top + 34.0), -PI * 0.5, shirt, Color(1, 1, 1),
			SKINS[i % SKINS.size()], HAIRS[(i * 2) % HAIRS.size()], 0.95)
	# teto transparente
	draw_rect(Rect2(cx - dw * 0.5 - 6.0, top + 22.0, dw + 12.0, 44.0), Color(0.72, 0.76, 0.96, 0.50))
	draw_rect(Rect2(cx - dw * 0.5 - 6.0, top + 22.0, dw + 12.0, 44.0), Color(1, 1, 1, 0.8), false, 2.0)
	# técnico em pé na beira do campo
	_draw_person(Vector2(cx + 120.0, top - 16.0), -PI * 0.5, suit, suit.lightened(0.15),
		SKINS[1], HAIRS[1], 1.0)


func _draw_person(pos: Vector2, ang: float, shirt: Color, trim: Color, skin: Color, hair: Color, sc: float) -> void:
	draw_set_transform(pos + Vector2(2.0, 3.0), 0.0, Vector2(sc, sc * 0.8))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.22))
	draw_set_transform(pos, ang, Vector2(sc, sc))
	draw_circle(Vector2(0.0, -10.0), 3.4, trim)
	draw_circle(Vector2(0.0, 10.0), 3.4, trim)
	draw_circle(Vector2(1.5, -11.5), 2.2, skin)
	draw_circle(Vector2(1.5, 11.5), 2.2, skin)
	draw_set_transform(pos, ang, Vector2(sc * 0.62, sc))
	draw_circle(Vector2.ZERO, 10.5, shirt)
	draw_set_transform(pos, ang, Vector2(sc, sc))
	draw_circle(Vector2(1.0, 0.0), 5.6, hair)
	draw_circle(Vector2(3.0, 0.0), 3.0, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

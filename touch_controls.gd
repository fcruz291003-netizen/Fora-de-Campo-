class_name TouchControls
extends Control
## Joystick flutuante (metade esquerda da tela) + botões de ação (direita) que MUDAM conforme o momento:
##   "attack"  (você está com a bola)      -> CHUTE, PASSE, CRUZ., CORRER
##   "support" (um companheiro tem a bola) -> PEDIR, CORRER
##   "defend"  (o rival tem a bola)        -> PRESSIONAR, CARRINHO, DESARME, CORRER
##   "loose"   (bola solta)                -> PEGAR, CARRINHO, CORRER
## Também aceita teclado para testar no PC:
##   WASD/setas = mover | Espaço ou J = chute (segure) | K = passe | L = cruzamento
##   Shift = correr | E = pedir a bola | R = pressionar | Q = carrinho | F = desarme

const STICK_RADIUS := 105.0

const KEY_MAP := {
	KEY_SPACE: "shoot",
	KEY_J: "shoot",
	KEY_K: "pass",
	KEY_L: "cross",
	KEY_SHIFT: "sprint",
	KEY_E: "call",
	KEY_R: "press",
	KEY_Q: "slide",
	KEY_F: "tackle",
}

var context: String = "loose"      # definido pela partida a cada frame

var held: Dictionary = {}          # nome -> true enquanto o botão está pressionado
var pressed: Dictionary = {}       # nome -> true no frame em que foi pressionado (consumir com take_pressed)
var tap_flag: bool = false

var stick_id: int = -1
var stick_origin: Vector2 = Vector2.ZERO
var stick_vec: Vector2 = Vector2.ZERO
var finger_btn: Dictionary = {}    # índice do dedo -> nome do botão


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- API
func get_move() -> Vector2:
	if stick_id != -1:
		return stick_vec
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.limit_length(1.0)


func is_held(name_: String) -> bool:
	return held.has(name_)


func take_pressed(name_: String) -> bool:
	if pressed.has(name_):
		pressed.erase(name_)
		return true
	return false


func take_tap() -> bool:
	var t: bool = tap_flag
	tap_flag = false
	return t


# ---------------------------------------------------------------- layout (botões grandes, por contexto)
# cada botão: [centro, raio, texto, cor]
func _layout() -> Dictionary:
	var s: Vector2 = get_viewport_rect().size
	var p1 := Vector2(s.x - 130.0, s.y - 150.0)    # ação principal (maior)
	var p2 := Vector2(s.x - 315.0, s.y - 110.0)
	var p3 := Vector2(s.x - 290.0, s.y - 270.0)
	var psp := Vector2(s.x - 120.0, s.y - 335.0)   # CORRER fica sempre no mesmo lugar
	var atk := Color(0.25, 0.75, 0.35)
	var dfn := Color(0.85, 0.30, 0.25)
	var run := Color(0.95, 0.80, 0.20)
	var shoot_col := Color(0.95, 0.45, 0.15)
	var out: Dictionary = {}
	if context == "attack":
		out["shoot"] = [p1, 84.0, "CHUTE", shoot_col]
		out["pass"] = [p2, 66.0, "PASSE", atk]
		out["cross"] = [p3, 56.0, "CRUZ.", atk]
		out["sprint"] = [psp, 58.0, "CORRER", run]
	elif context == "support":
		out["call"] = [p1, 88.0, "PEDIR", atk]
		out["sprint"] = [psp, 58.0, "CORRER", run]
	elif context == "defend":
		out["press"] = [p1, 84.0, "PRESSIONAR", dfn]
		out["slide"] = [p2, 66.0, "CARRINHO", dfn]
		out["tackle"] = [p3, 56.0, "DESARME", dfn]
		out["sprint"] = [psp, 58.0, "CORRER", run]
	else:
		out["press"] = [p1, 84.0, "PEGAR", dfn]
		out["slide"] = [p2, 66.0, "CARRINHO", dfn]
		out["sprint"] = [psp, 58.0, "CORRER", run]
	return out


# ---------------------------------------------------------------- entrada
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			return
		var kc: int = k.keycode
		if KEY_MAP.has(kc):
			var nm: String = KEY_MAP[kc]
			if k.pressed:
				held[nm] = true
				pressed[nm] = true
				tap_flag = true
			else:
				held.erase(nm)


func _touch_down(idx: int, pos: Vector2) -> void:
	tap_flag = true
	var lay: Dictionary = _layout()
	for nm: String in lay.keys():
		var info: Array = lay[nm]
		var center: Vector2 = info[0]
		var r: float = info[1]
		if pos.distance_to(center) <= r * 1.15:
			finger_btn[idx] = nm
			held[nm] = true
			pressed[nm] = true
			return
	if stick_id == -1 and pos.x < get_viewport_rect().size.x * 0.5:
		stick_id = idx
		stick_origin = pos
		stick_vec = Vector2.ZERO


func _touch_move(idx: int, pos: Vector2) -> void:
	if idx != stick_id:
		return
	var v: Vector2 = pos - stick_origin
	if v.length() > STICK_RADIUS:
		# joystick flutuante: a base acompanha o dedo
		stick_origin = pos - v.limit_length(STICK_RADIUS)
		v = v.limit_length(STICK_RADIUS)
	var n: Vector2 = v / STICK_RADIUS
	stick_vec = n if n.length() > 0.12 else Vector2.ZERO


func _touch_up(idx: int) -> void:
	if idx == stick_id:
		stick_id = -1
		stick_vec = Vector2.ZERO
	if finger_btn.has(idx):
		var nm: String = finger_btn[idx]
		held.erase(nm)
		finger_btn.erase(idx)


# ---------------------------------------------------------------- desenho
func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var lay: Dictionary = _layout()
	for nm: String in lay.keys():
		var info: Array = lay[nm]
		var center: Vector2 = info[0]
		var r: float = info[1]
		var label: String = info[2]
		var col: Color = info[3]
		var on: bool = held.has(nm)
		draw_circle(center, r, Color(col.r, col.g, col.b, 0.55 if on else 0.28))
		draw_arc(center, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.95), 4.0)
		var fs: int = int(r * 0.30)
		draw_string(font, center + Vector2(-r, float(fs) * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.97))
	# joystick
	var s: Vector2 = get_viewport_rect().size
	var base: Vector2 = stick_origin if stick_id != -1 else Vector2(190.0, s.y - 160.0)
	var alpha: float = 0.35 if stick_id != -1 else 0.14
	draw_circle(base, STICK_RADIUS, Color(1, 1, 1, alpha * 0.5))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, alpha + 0.2), 3.0)
	draw_circle(base + stick_vec * STICK_RADIUS, 40.0, Color(1, 1, 1, alpha + 0.2))

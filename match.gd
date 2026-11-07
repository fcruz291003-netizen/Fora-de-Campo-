extends Node2D
## Partida completa (Carreira FC).
## Você controla SÓ o seu jogador (camisa 9); os outros 21 são IA.
## O time 0 (seu) ataca para a direita (+x); o time 1 (rival) ataca para a esquerda (-x).

enum State { KICKOFF, PLAYING, GOAL, HALFTIME, ENDED }

const W := 1200.0
const H := 700.0
const GOAL_HALF := 100.0
const MATCH_REAL_SECONDS := 360.0              # 90 min de jogo em 6 min reais
const REAL_PER_MIN := MATCH_REAL_SECONDS / 90.0
const AI_SPEED := 0.9

# [posição, x (-1 = próprio gol .. +1 = gol rival), y]
const FORMATION := [
	["GK", -0.95, 0.0],
	["LB", -0.60, -0.70], ["CB", -0.65, -0.25], ["CB", -0.65, 0.25], ["RB", -0.60, 0.70],
	["CM", -0.20, -0.40], ["CM", -0.25, 0.0], ["CM", -0.20, 0.40],
	["LW", 0.35, -0.65], ["ST", 0.45, 0.0], ["RW", 0.35, 0.65],
]
const NUMBERS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7]

var pitch: PitchView
var ball: SoccerBall
var cam: Camera2D
var hud: MatchHud
var controls: TouchControls
var user: Footballer
var referee: Footballer

var players: Array[Footballer] = []
var team0: Array[Footballer] = []
var team1: Array[Footballer] = []
var gks: Array[Footballer] = []

var state: int = State.KICKOFF
var state_t: float = 0.0
var match_time: float = 0.0
var half: int = 1
var score: Array[int] = [0, 0]
var kickoff_team: int = 0

var chasing: Dictionary = {}
var role_timer: float = 0.0
var charging: bool = false
var charge: float = 0.0
var calling: bool = false
var last_kick_type: String = ""
var set_piece_taker: Footballer = null
var set_piece_kind: String = ""
var msg_t: float = 0.0

var rng := RandomNumberGenerator.new()
var stats: Dictionary = {
	"goals": 0, "assists": 0, "shots": 0, "on_target": 0,
	"passes": 0, "passes_ok": 0, "tackles": 0, "lost": 0,
}


# ================================================================ setup
func _ready() -> void:
	rng.randomize()
	pitch = PitchView.new()
	add_child(pitch)

	_spawn_team(0)
	_spawn_team(1)
	_spawn_referee()

	ball = SoccerBall.new()
	ball.z_index = 5
	add_child(ball)

	cam = Camera2D.new()
	cam.zoom = Vector2(0.85, 0.85)
	cam.limit_left = -1650
	cam.limit_right = 1650
	cam.limit_top = -1150
	cam.limit_bottom = 1150
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = MatchHud.new()
	layer.add_child(hud)
	controls = TouchControls.new()
	layer.add_child(controls)
	hud.hint = "WASD mover · Espaço chutar (segure p/ força) · K passe/desarme · L cruzamento · Shift correr · E pedir bola · Q carrinho"

	_start_kickoff(0)
	cam.position = user.position


func _spawn_team(t: int) -> void:
	for i in range(FORMATION.size()):
		var row: Array = FORMATION[i]
		var p := Footballer.new()
		p.team = t
		p.role = row[0]
		p.number = NUMBERS[i]
		p.is_gk = (i == 0)
		p.formation_pos = Vector2(float(row[1]), float(row[2]))
		if t == 0:
			p.kit_color = Color(0.95, 0.75, 0.1) if p.is_gk else Color(0.15, 0.45, 1.0)
		else:
			p.kit_color = Color(0.2, 0.8, 0.3) if p.is_gk else Color(0.9, 0.2, 0.2)
		p.kit_trim = Color(0.1, 0.1, 0.1) if p.is_gk else Color(1, 1, 1)
		p.skin = PitchView.SKINS[rng.randi() % PitchView.SKINS.size()]
		p.hair = PitchView.HAIRS[rng.randi() % PitchView.HAIRS.size()]
		var is_user: bool = (t == 0 and i == 9)
		p.is_user = is_user
		p.attrs = _make_attrs(p.role, is_user)
		if is_user:
			user = p
		if i == 0:
			gks.append(p)
		add_child(p)
		players.append(p)
		_team(t).append(p)


func _spawn_referee() -> void:
	referee = Footballer.new()
	referee.team = 2
	referee.number = 0
	referee.show_number = false
	referee.kit_color = Color(0.08, 0.08, 0.10)
	referee.kit_trim = Color(0.95, 0.85, 0.10)
	referee.skin = PitchView.SKINS[1]
	referee.hair = PitchView.HAIRS[0]
	referee.position = Vector2(0.0, 160.0)
	add_child(referee)


func _update_referee(delta: float) -> void:
	var target: Vector2 = ball.position + Vector2(-90.0, 140.0)
	target.x = clampf(target.x, -W + 100.0, W - 100.0)
	target.y = clampf(target.y, -H + 60.0, H - 60.0)
	_move_ai(referee, target, 0.8, delta)


func _a(pace: int, sho: int, pas: int, dri: int, def: int, phy: int) -> Dictionary:
	return {"pace": pace, "shooting": sho, "passing": pas, "dribbling": dri, "defending": def, "physical": phy}


func _make_attrs(role: String, is_user: bool) -> Dictionary:
	if is_user:
		return _a(78, 76, 66, 72, 35, 70)
	var base: Dictionary
	match role:
		"GK": base = _a(50, 30, 60, 40, 78, 70)
		"CB": base = _a(62, 42, 60, 55, 76, 76)
		"LB", "RB": base = _a(72, 48, 64, 62, 68, 68)
		"CM": base = _a(66, 62, 74, 70, 62, 66)
		"LW", "RW": base = _a(78, 66, 66, 74, 40, 60)
		"ST": base = _a(74, 76, 62, 68, 35, 70)
		_: base = _a(68, 60, 66, 64, 60, 66)
	for k: String in base.keys():
		base[k] = int(base[k]) + rng.randi_range(-4, 4)
	return base


func _team(t: int) -> Array[Footballer]:
	return team0 if t == 0 else team1


func _dir(t: int) -> float:
	return 1.0 if t == 0 else -1.0


# ================================================================ loop
func _process(delta: float) -> void:
	for p: Footballer in players:
		p.anim_t += delta * p.velocity.length() * 0.055
		p.queue_redraw()
	referee.anim_t += delta * referee.velocity.length() * 0.055
	referee.queue_redraw()
	ball.queue_redraw()
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0:
			hud.message = ""
	_update_hud()


func _physics_process(delta: float) -> void:
	match state:
		State.KICKOFF:
			state_t += delta
			_glue_ball()
			if state_t >= 1.6:
				state = State.PLAYING
				hud.message = ""
		State.PLAYING:
			_play(delta)
		State.GOAL:
			state_t += delta
			if state_t >= 3.0:
				_start_kickoff(kickoff_team)
		State.HALFTIME:
			state_t += delta
			if state_t >= 3.0:
				half = 2
				_start_kickoff(1, "Segundo tempo!")
		State.ENDED:
			state_t += delta
			if state_t > 2.0 and controls.take_tap():
				get_tree().reload_current_scene()
	cam.position = cam.position.lerp(user.position + user.velocity * 0.25, minf(1.0, delta * 6.0))


func _play(delta: float) -> void:
	match_time += delta
	if half == 1 and match_time >= MATCH_REAL_SECONDS * 0.5:
		_halftime()
		return
	if match_time >= MATCH_REAL_SECONDS:
		_full_time()
		return

	for p: Footballer in players:
		_tick(p, delta)

	role_timer -= delta
	if role_timer <= 0.0:
		role_timer = 0.2
		_assign_chasers()

	_update_user(delta)
	for p: Footballer in players:
		if p != user:
			_update_ai(p, delta)

	_update_referee(delta)
	_separate_players()
	_clamp_players()

	ball.physics_step(delta)
	_update_pickups()
	_glue_ball()
	_check_ball_bounds()


func _tick(p: Footballer, delta: float) -> void:
	p.no_pickup = maxf(0.0, p.no_pickup - delta)
	p.tackle_cd = maxf(0.0, p.tackle_cd - delta)
	p.hold_timer = maxf(0.0, p.hold_timer - delta)
	p.slide_recover = maxf(0.0, p.slide_recover - delta)
	p.assist_timer = maxf(0.0, p.assist_timer - delta)


func _glue_ball() -> void:
	if ball.holder != null:
		var h: Footballer = ball.holder
		ball.position = h.position + h.facing * 20.0
		ball.z = 0.0
		ball.vz = 0.0
		ball.vel = Vector2.ZERO


func _say(text: String, secs: float) -> void:
	hud.message = text
	msg_t = secs


func _update_hud() -> void:
	hud.score = score
	var minute: int = clampi(int(match_time / REAL_PER_MIN), 0, 90)
	hud.clock_text = "%d'" % minute
	hud.half_text = "1T" if half == 1 else "2T"
	hud.stamina = user.stamina
	hud.charge = charge if charging else 0.0
	hud.queue_redraw()


# ================================================================ fluxo da partida
func _start_kickoff(team: int, text: String = "Bola rolando!") -> void:
	kickoff_team = team
	state = State.KICKOFF
	state_t = 0.0
	charging = false
	charge = 0.0
	set_piece_taker = null
	for p: Footballer in players:
		var dir: float = _dir(p.team)
		var xn: float = minf(p.formation_pos.x, -0.08)
		p.position = Vector2(xn * dir * W * 0.9, p.formation_pos.y * H * 0.8)
		p.velocity = Vector2.ZERO
		p.facing = Vector2(dir, 0.0)
		p.hold_timer = 0.0
		p.no_pickup = 0.0
		p.tackle_cd = 0.0
		p.slide_t = 0.0
		p.slide_recover = 0.0
		p.assist_from = null
		p.assist_timer = 0.0
		p.carry_time = 0.0
		p.think_timer = 0.3
	var taker: Footballer = user if team == 0 else _striker(1)
	taker.position = Vector2(-_dir(team) * 12.0, 0.0)
	ball.position = Vector2.ZERO
	ball.vel = Vector2.ZERO
	ball.z = 0.0
	ball.vz = 0.0
	ball.kicker = null
	ball.assister = null
	ball.target_receiver = null
	ball.shot_active = false
	ball.holder = taker
	ball.last_touch_team = team
	last_kick_type = ""
	_glue_ball()
	_say(text, 1.4)


func _striker(t: int) -> Footballer:
	for p: Footballer in _team(t):
		if p.role == "ST":
			return p
	return _team(t)[10]


func _halftime() -> void:
	state = State.HALFTIME
	state_t = 0.0
	charging = false
	charge = 0.0
	ball.holder = null
	ball.vel = Vector2.ZERO
	_say("Fim do 1º tempo", 3.0)


func _full_time() -> void:
	state = State.ENDED
	state_t = 0.0
	charging = false
	charge = 0.0
	controls.take_tap()
	ball.vel = Vector2.ZERO
	var rating: float = _rating()
	var res: String = "Vitória!" if score[0] > score[1] else ("Derrota" if score[0] < score[1] else "Empate")
	var acc: String = "-"
	if int(stats["passes"]) > 0:
		acc = "%d%%" % int(round(100.0 * float(stats["passes_ok"]) / float(stats["passes"])))
	hud.end_lines = PackedStringArray([
		"%s  %d x %d  %s   (%s)" % [hud.team_names[0], score[0], score[1], hud.team_names[1], res],
		"Sua nota: %.1f" % rating,
		"Gols: %d   Assistências: %d" % [stats["goals"], stats["assists"]],
		"Chutes: %d (%d no gol)" % [stats["shots"], stats["on_target"]],
		"Passes certos: %d/%d (%s)" % [stats["passes_ok"], stats["passes"], acc],
		"Desarmes: %d   Bolas perdidas: %d" % [stats["tackles"], stats["lost"]],
		"Toque na tela para jogar de novo",
	])
	hud.show_end = true
	hud.message = ""
	_save_summary(rating, res)


func _rating() -> float:
	var r: float = 6.0
	r += float(stats["goals"]) * 1.3
	r += float(stats["assists"]) * 0.9
	r += float(stats["on_target"]) * 0.2
	r += float(stats["tackles"]) * 0.25
	r -= float(stats["lost"]) * 0.15
	if int(stats["passes"]) >= 4:
		r += (float(stats["passes_ok"]) / float(stats["passes"]) - 0.75) * 2.0
	if score[0] > score[1]:
		r += 0.4
	elif score[0] < score[1]:
		r -= 0.3
	return clampf(r, 3.0, 10.0)


func _save_summary(rating: float, result: String) -> void:
	# Esse arquivo é o "resumo da partida" que vai alimentar a IA de entrevistas depois.
	var data: Dictionary = {
		"score": {"home": score[0], "away": score[1]},
		"result": result,
		"rating": snappedf(rating, 0.1),
		"stats": stats,
		"minutes": 90,
	}
	var f := FileAccess.open("user://last_match.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


# ================================================================ gols / bola fora
func _check_ball_bounds() -> void:
	if ball.holder != null:
		return
	var bp: Vector2 = ball.position
	if absf(bp.x) > W:
		if absf(bp.y) < GOAL_HALF and ball.z < 110.0:
			_goal(0 if bp.x > 0.0 else 1)
		else:
			var def_team: int = 1 if bp.x > 0.0 else 0
			if ball.last_touch_team == def_team:
				var att: int = 1 - def_team
				var corner := Vector2(_dir(att) * (W - 14.0), signf(bp.y) * (H - 14.0))
				_restart("corner", att, corner)
			else:
				_restart("goalkick", def_team, Vector2(-_dir(def_team) * (W - 90.0), 0.0))
	elif absf(bp.y) > H:
		var team: int = 1 - ball.last_touch_team
		_restart("throwin", team, Vector2(clampf(bp.x, -W + 30.0, W - 30.0), signf(bp.y) * (H - 6.0)))


func _goal(team: int) -> void:
	score[team] += 1
	ball.vel = Vector2.ZERO
	ball.vz = 0.0
	ball.z = 0.0
	ball.position.x = clampf(ball.position.x, -W - 40.0, W + 40.0)
	var scorer: Footballer = ball.kicker
	var text: String = "GOL!"
	if team == 0:
		if scorer != null and scorer.is_user:
			stats["goals"] += 1
			text = "GOOOL! VOCÊ MARCOU!"
		elif ball.assister != null and ball.assister.is_user and ball.assister != scorer:
			stats["assists"] += 1
			text = "GOL! ASSISTÊNCIA SUA!"
		else:
			text = "GOL DO MEU TIME!"
	else:
		text = "Gol do rival..."
	_say(text, 3.0)
	state = State.GOAL
	state_t = 0.0
	kickoff_team = 1 - team
	charging = false
	charge = 0.0


func _restart(kind: String, team: int, at: Vector2) -> void:
	var taker: Footballer = null
	if kind == "goalkick":
		taker = gks[team]
	else:
		var best_d: float = 1e9
		for p: Footballer in _team(team):
			if p.is_gk:
				continue
			var d: float = p.position.distance_to(at)
			if d < best_d:
				best_d = d
				taker = p
	var spot: Vector2 = at.move_toward(Vector2.ZERO, 16.0)
	taker.position = spot
	taker.velocity = Vector2.ZERO
	taker.facing = (Vector2.ZERO - spot).normalized()
	taker.no_pickup = 0.0
	ball.holder = taker
	ball.vel = Vector2.ZERO
	ball.vz = 0.0
	ball.z = 0.0
	ball.shot_active = false
	ball.kicker = null
	ball.assister = null
	ball.target_receiver = null
	ball.last_touch_team = team
	ball.pickup_cd = 0.1
	last_kick_type = ""
	charging = false
	charge = 0.0
	if taker.is_user:
		set_piece_taker = null
	else:
		taker.hold_timer = 1.0
		taker.carry_time = 0.0
		taker.think_timer = 0.0
		set_piece_taker = taker
		set_piece_kind = kind
	match kind:
		"corner": _say("Escanteio", 1.2)
		"goalkick": _say("Tiro de meta", 1.2)
		_: _say("Lateral", 1.0)
	_glue_ball()


# ================================================================ chutes e passes
func _kick(p: Footballer, vel: Vector2, lift: float, is_shot: bool) -> void:
	ball.holder = null
	ball.vel = vel
	ball.vz = lift
	ball.z = 0.0
	ball.kicker = p
	ball.assister = null
	ball.last_touch_team = p.team
	ball.pickup_cd = 0.18
	ball.shot_active = is_shot
	ball.shot_team = p.team
	ball.kick_was_shot = is_shot
	ball.target_receiver = null
	p.no_pickup = 0.35
	p.carry_time = 0.0
	if vel.length() > 1.0:
		p.facing = vel.normalized()
	if p == set_piece_taker:
		set_piece_taker = null
	last_kick_type = ""


func _pass_to(p: Footballer, pos: Vector2, lofted: bool, q: Footballer) -> void:
	var to: Vector2 = pos - p.position
	var dist: float = maxf(to.length(), 40.0)
	var dirv: Vector2 = to.normalized()
	var err: float = (1.0 - float(p.attrs["passing"]) / 100.0) * 0.16
	dirv = dirv.rotated(rng.randf_range(-err, err))
	var speed: float = 0.0
	var lift: float = 0.0
	if lofted:
		lift = clampf(280.0 + dist * 0.35, 300.0, 560.0)
		speed = dist / (2.0 * lift / SoccerBall.GRAVITY)
	else:
		speed = clampf(dist * 1.25 + 120.0, 260.0, 950.0)
	_kick(p, dirv * speed, lift, false)
	ball.target_receiver = q
	last_kick_type = "pass"


func _do_pass(p: Footballer, q: Footballer, lofted: bool) -> void:
	var d: float = p.position.distance_to(q.position)
	var go_lofted: bool = lofted
	if not go_lofted and d > 700.0 and rng.randf() < 0.5:
		go_lofted = true
	var lead: Vector2 = q.velocity * clampf(d / 900.0, 0.0, 0.6)
	_pass_to(p, q.position + lead, go_lofted, q)


func _do_shot_dir(p: Footballer, dirv: Vector2, power: float) -> void:
	var shooting: float = float(p.attrs["shooting"])
	var err: float = 0.03 + (1.0 - shooting / 100.0) * 0.30 + power * 0.06
	var d: Vector2 = dirv.rotated(rng.randf_range(-err, err))
	var speed: float = lerpf(480.0, 1150.0, power) * (0.85 + shooting / 700.0)
	var lift: float = rng.randf() * power * power * 380.0
	var assister: Footballer = p.assist_from if p.assist_timer > 0.0 else null
	_kick(p, d * speed, lift, true)
	ball.assister = assister
	last_kick_type = "shot"
	if p.is_user:
		stats["shots"] += 1
		if _on_target(p.position, d, p.team):
			stats["on_target"] += 1


func _on_target(pos: Vector2, d: Vector2, team: int) -> bool:
	var gx: float = _dir(team) * W
	if absf(d.x) < 0.01 or (gx - pos.x) * d.x <= 0.0:
		return false
	var t: float = (gx - pos.x) / d.x
	return absf(pos.y + d.y * t) < GOAL_HALF


# ================================================================ bola: posse, defesas, desarmes
func _update_pickups() -> void:
	if ball.holder != null or ball.pickup_cd > 0.0 or ball.z > 40.0:
		return
	var best: Footballer = null
	var best_d: float = 1e9
	for p: Footballer in players:
		if p.no_pickup > 0.0:
			continue
		var reach: float = 24.0
		if p.is_gk:
			reach = 38.0
		elif p.slide_t > 0.0:
			reach = 34.0
		var d: float = p.position.distance_to(ball.position)
		if d < reach and d < best_d:
			best = p
			best_d = d
	if best == null:
		return
	if ball.shot_active and best.is_gk and best.team != ball.shot_team:
		_gk_save(best)
		return
	var spd: float = ball.vel.length()
	if spd > 650.0 and not best.is_gk:
		# bola muito rápida: o domínio pode falhar e a bola desvia
		if rng.randf() > 0.55 + float(best.attrs["dribbling"]) / 250.0:
			ball.vel = ball.vel.rotated(rng.randf_range(-0.8, 0.8)) * 0.45
			ball.shot_active = false
			ball.pickup_cd = 0.15
			ball.last_touch_team = best.team
			return
	_on_pickup(best)


func _on_pickup(q: Footballer) -> void:
	var prev: Footballer = ball.kicker
	if prev != null and last_kick_type == "pass" and prev != q:
		if prev.team == q.team:
			q.assist_from = prev
			q.assist_timer = 5.0
			if prev.is_user:
				stats["passes_ok"] += 1
		elif prev.is_user:
			stats["lost"] += 1
	if last_kick_type != "pass" or prev == null or prev.team != q.team:
		q.assist_from = null
	ball.holder = q
	ball.vel = Vector2.ZERO
	ball.vz = 0.0
	ball.z = 0.0
	ball.shot_active = false
	ball.target_receiver = null
	ball.last_touch_team = q.team
	q.carry_time = 0.0
	q.think_timer = rng.randf_range(0.1, 0.3)
	last_kick_type = ""
	if set_piece_taker != null and q != set_piece_taker:
		set_piece_taker = null


func _gk_save(gk: Footballer) -> void:
	var spd: float = ball.vel.length()
	var chance: float = clampf(0.85 - (spd - 400.0) / 1000.0, 0.2, 0.85) + float(gk.attrs["defending"]) / 1000.0
	var shooter: Footballer = ball.kicker
	if rng.randf() < chance:
		_on_pickup(gk)
		gk.hold_timer = 1.2
		if shooter != null and shooter.is_user:
			_say("Defendeu!", 1.0)
	else:
		# rebote
		ball.vel = Vector2(ball.vel.x * -0.35, ball.vel.y * 0.5 + rng.randf_range(-250.0, 250.0))
		ball.pickup_cd = 0.25
		ball.shot_active = false
		gk.no_pickup = 0.3
		if shooter != null and shooter.is_user:
			_say("Rebote!", 1.0)


func _try_tackle(t: Footballer, h: Footballer) -> void:
	t.tackle_cd = 1.1 if not t.is_user else 0.8
	var chance: float = 0.30 + (float(t.attrs["defending"]) - float(h.attrs["dribbling"])) / 250.0
	if h.is_user:
		chance *= 0.8
	chance = clampf(chance, 0.15, 0.65)
	if rng.randf() < chance:
		ball.holder = null
		ball.vel = Vector2.from_angle(rng.randf() * TAU) * 170.0
		ball.vz = 0.0
		ball.pickup_cd = 0.12
		ball.kicker = null
		ball.shot_active = false
		ball.last_touch_team = t.team
		h.no_pickup = 0.8
		last_kick_type = ""
		if t.is_user:
			stats["tackles"] += 1
			_say("Desarme!", 0.8)
		if h.is_user:
			stats["lost"] += 1
			_say("Perdeu a bola!", 0.8)


# ================================================================ jogador do usuário
func _update_user(delta: float) -> void:
	var u: Footballer = user
	var mv: Vector2 = controls.get_move()
	u.move_input = mv
	calling = controls.is_held("call")

	# consome os toques de botão todo frame (evita ações "guardadas")
	var pr_pass: bool = controls.take_pressed("pass")
	var pr_cross: bool = controls.take_pressed("cross")
	var pr_shoot: bool = controls.take_pressed("shoot")
	var pr_slide: bool = controls.take_pressed("slide")

	# movimento
	var sprint: bool = controls.is_held("sprint") and mv.length() > 0.2 and u.stamina > 3.0
	u.sprinting = sprint
	if u.slide_t > 0.0:
		var k: float = u.slide_t / 0.4
		u.position += u.slide_dir * (120.0 + 420.0 * k) * delta
		u.velocity = u.slide_dir * 300.0
		_resolve_slide(u)
		u.slide_t -= delta
		if u.slide_t <= 0.0:
			u.slide_t = 0.0
			u.slide_recover = maxf(u.slide_recover, 0.55)
	else:
		var speed: float = _speed_of(u)
		if sprint:
			speed *= 1.28
		if ball.holder == u:
			speed *= 0.93
		if u.slide_recover > 0.0:
			speed *= 0.35
		u.velocity = u.velocity.lerp(mv * speed, minf(1.0, delta * 9.0))
		u.position += u.velocity * delta
		if mv.length() > 0.15:
			var nf: Vector2 = u.facing.lerp(mv.normalized(), minf(1.0, delta * 14.0))
			u.facing = nf.normalized() if nf.length() > 0.01 else mv.normalized()

	# fôlego
	var cap: float = 100.0 - 25.0 * match_time / MATCH_REAL_SECONDS
	if sprint:
		u.stamina -= 16.0 * delta
	else:
		u.stamina += (7.0 if mv.length() < 0.2 else 3.5) * delta
	u.stamina = clampf(u.stamina, 0.0, cap)

	# ações
	if ball.holder == u:
		if pr_pass:
			_user_pass(false)
		elif pr_cross:
			_user_pass(true)
		elif pr_shoot:
			charging = true
			charge = 0.0
		if charging:
			charge = minf(1.0, charge + delta / 0.9)
			if not controls.is_held("shoot"):
				_user_shoot(charge)
				charging = false
				charge = 0.0
	else:
		charging = false
		charge = 0.0
		if pr_pass:
			var h: Footballer = ball.holder
			if h != null and h.team != u.team and u.tackle_cd <= 0.0 and u.position.distance_to(h.position) < 42.0:
				_try_tackle(u, h)
		if pr_slide and u.slide_t <= 0.0 and u.slide_recover <= 0.0:
			u.slide_t = 0.4
			u.slide_dir = mv.normalized() if mv.length() > 0.2 else u.facing
			u.slide_resolved = false
			u.stamina = maxf(0.0, u.stamina - 8.0)


func _resolve_slide(u: Footballer) -> void:
	if u.slide_resolved:
		return
	var h: Footballer = ball.holder
	if h != null and h.team != u.team and u.position.distance_to(h.position) < 38.0:
		u.slide_resolved = true
		var chance: float = clampf(0.55 + (float(u.attrs["defending"]) - float(h.attrs["dribbling"])) / 400.0, 0.25, 0.8)
		if rng.randf() < chance:
			ball.holder = null
			ball.vel = u.slide_dir * 260.0
			ball.vz = 0.0
			ball.pickup_cd = 0.05
			ball.kicker = null
			ball.shot_active = false
			ball.last_touch_team = u.team
			h.no_pickup = 0.8
			last_kick_type = ""
			stats["tackles"] += 1
			_say("Carrinho perfeito!", 0.9)
		else:
			u.slide_recover = 1.0
			_say("Errou o bote!", 0.8)


func _pick_user_target(aim: Vector2) -> Footballer:
	var best: Footballer = null
	var best_s: float = -999.0
	for q: Footballer in team0:
		if q == user:
			continue
		var to: Vector2 = q.position - user.position
		var d: float = to.length()
		if d < 60.0 or d > 1100.0:
			continue
		var c: float = to.normalized().dot(aim)
		if c < 0.5:
			continue
		var open: float = minf(_dist_to_nearest_opp(q.position, 0), 220.0) / 220.0
		var s: float = c * 2.0 - d / 1100.0 * 0.8 + open * 0.3
		if _lane_blocked(user.position, q.position, 0):
			s -= 0.5
		if s > best_s:
			best_s = s
			best = q
	return best


func _user_pass(lofted: bool) -> void:
	var u: Footballer = user
	var aim: Vector2 = u.move_input if u.move_input.length() > 0.25 else u.facing
	aim = aim.normalized()
	stats["passes"] += 1
	var tgt: Footballer = _pick_user_target(aim)
	if tgt != null:
		_pass_to(u, tgt.position + tgt.velocity * 0.3, lofted, tgt)
	elif lofted and u.position.x > 350.0 and absf(u.position.y) > H * 0.4:
		# cruzamento sem alvo definido: bola na área
		_pass_to(u, Vector2(W - 240.0, -signf(u.position.y) * 70.0), true, null)
	else:
		var d: float = 600.0 if lofted else 420.0
		_pass_to(u, u.position + aim * d, lofted, null)


func _user_shoot(c: float) -> void:
	var u: Footballer = user
	var power: float = lerpf(0.3, 1.0, c)
	var mv: Vector2 = u.move_input
	var aim_y: float = 0.0
	if mv.length() > 0.25:
		aim_y = clampf(mv.y * 1.4, -1.0, 1.0) * GOAL_HALF * 0.85
	elif absf(u.position.y) > 60.0:
		aim_y = -signf(u.position.y) * GOAL_HALF * 0.55
	var to_goal: Vector2 = (Vector2(W, aim_y) - u.position).normalized()
	var dirv: Vector2 = to_goal
	if u.position.x < 150.0:
		# longe do gol: chuta/limpa para onde está olhando
		var wanted: Vector2 = mv.normalized() if mv.length() > 0.25 else u.facing
		if wanted.dot(to_goal) < 0.6:
			dirv = wanted
	_do_shot_dir(u, dirv, power)


# ================================================================ IA
func _speed_of(p: Footballer) -> float:
	var f: float = 1.0
	if p.is_user:
		f = lerpf(0.72, 1.0, p.stamina / 100.0)
	return (150.0 + float(p.attrs["pace"]) * 1.5) * f


func _steer(p: Footballer, desired: Vector2, delta: float) -> void:
	p.velocity = p.velocity.lerp(desired, minf(1.0, delta * 7.0))
	p.position += p.velocity * delta
	if p.velocity.length() > 25.0:
		var nf: Vector2 = p.facing.lerp(p.velocity.normalized(), minf(1.0, delta * 10.0))
		p.facing = nf.normalized() if nf.length() > 0.01 else p.velocity.normalized()


func _move_ai(p: Footballer, target: Vector2, mult: float, delta: float) -> void:
	var to: Vector2 = target - p.position
	var dist: float = to.length()
	var desired: Vector2 = Vector2.ZERO
	if dist > 6.0:
		desired = to / dist * _speed_of(p) * AI_SPEED * mult * minf(1.0, dist / 50.0 + 0.15)
	_steer(p, desired, delta)


func _assign_chasers() -> void:
	chasing.clear()
	var holder_team: int = -1
	if ball.holder != null:
		holder_team = ball.holder.team
	for t in range(2):
		if holder_team == t:
			continue
		var n: int = 2 if holder_team != -1 else 1
		var list: Array = []
		for p: Footballer in _team(t):
			if p.is_gk:
				continue
			list.append([p.position.distance_to(ball.position), p])
		list.sort_custom(func(a, b): return a[0] < b[0])
		var c: int = 0
		for entry in list:
			if c >= n:
				break
			c += 1
			var q: Footballer = entry[1]
			if q.is_user:
				continue   # quem decide é você; ele conta como um dos mais próximos
			chasing[q] = true
		var rec: Footballer = ball.target_receiver
		if rec != null and rec.team == t and not rec.is_user:
			chasing[rec] = true


func _home_pos(p: Footballer) -> Vector2:
	var dir: float = _dir(p.team)
	var f: Vector2 = p.formation_pos
	var x: float = f.x * dir * W * 0.9 * 0.6 + ball.position.x * 0.5
	var y: float = f.y * H * 0.8 + ball.position.y * 0.25
	var in_poss: bool = ball.holder != null and ball.holder.team == p.team
	if in_poss:
		match p.role:
			"CB": x += dir * 60.0
			"LB", "RB": x += dir * 140.0
			_: x += dir * 220.0
	return Vector2(clampf(x, -W + 60.0, W - 60.0), clampf(y, -H + 50.0, H - 50.0))


func _update_ai(p: Footballer, delta: float) -> void:
	if p.hold_timer > 0.0:
		p.velocity = Vector2.ZERO
		return
	if p.is_gk:
		_update_gk(p, delta)
		return
	if ball.holder == p:
		_ai_with_ball(p, delta)
		return

	var target: Vector2 = _home_pos(p)
	var mult: float = 0.85
	if chasing.has(p):
		mult = 1.1
		if ball.holder != null:
			target = ball.holder.position + ball.holder.facing * 12.0
		else:
			target = ball.position + ball.vel * 0.3
	_move_ai(p, target, mult, delta)

	var h: Footballer = ball.holder
	if h != null and h.team != p.team and p.tackle_cd <= 0.0 and p.position.distance_to(h.position) < 26.0:
		_try_tackle(p, h)


func _update_gk(p: Footballer, delta: float) -> void:
	var dir: float = _dir(p.team)
	var line_x: float = -dir * (W - 70.0)
	if ball.holder == p:
		p.velocity = Vector2.ZERO
		var q: Footballer = _best_pass_target(p)
		if q != null:
			_do_pass(p, q, rng.randf() < 0.6)
		else:
			_kick(p, Vector2(dir, 0.0) * 620.0, 320.0, false)
			last_kick_type = "pass"
		return
	var target := Vector2(line_x, clampf(ball.position.y * 0.35, -GOAL_HALF * 0.8, GOAL_HALF * 0.8))
	var spd: float = 300.0
	if ball.holder == null and ball.shot_active and ball.shot_team != p.team and ball.vel.x * dir < -60.0:
		var t: float = (line_x - ball.position.x) / ball.vel.x
		if t > 0.0:
			target = Vector2(line_x, clampf(ball.position.y + ball.vel.y * t, -GOAL_HALF * 1.1, GOAL_HALF * 1.1))
			spd = 380.0
	elif ball.holder == null and absf(ball.position.x - line_x) < 330.0 and absf(ball.position.y) < 330.0 and ball.vel.length() < 200.0:
		target = ball.position
		spd = 320.0
	var to: Vector2 = target - p.position
	var desired: Vector2 = Vector2.ZERO
	if to.length() > 5.0:
		desired = to.normalized() * spd * minf(1.0, to.length() / 40.0 + 0.2)
	_steer(p, desired, delta)


func _ai_with_ball(p: Footballer, delta: float) -> void:
	var dir: float = _dir(p.team)
	var goal := Vector2(dir * W, 0.0)

	if p == set_piece_taker:
		var tq: Footballer = _best_pass_target(p)
		var lofted: bool = set_piece_kind == "goalkick" or set_piece_kind == "corner"
		if tq != null:
			_do_pass(p, tq, lofted)
		else:
			_kick(p, Vector2(dir, 0.0) * 450.0, 0.0, false)
			last_kick_type = "pass"
		return

	p.carry_time += delta
	p.think_timer -= delta
	var opp: Footballer = _nearest_opponent(p)
	var d_opp: float = 9999.0
	if opp != null:
		d_opp = p.position.distance_to(opp.position)
	var steer := Vector2.ZERO
	if opp != null and d_opp < 130.0:
		steer = (p.position - opp.position).normalized() * (1.0 - d_opp / 130.0) * 1.3
	var desired: Vector2 = ((goal - p.position).normalized() + steer).normalized()
	_steer(p, desired * _speed_of(p) * AI_SPEED * 0.92, delta)

	if p.think_timer > 0.0:
		return
	p.think_timer = rng.randf_range(0.3, 0.55)

	var dist_goal: float = p.position.distance_to(goal)
	var fwd: bool = p.role in ["ST", "LW", "RW"]
	var shoot_range: float = 520.0 if fwd else 380.0
	if dist_goal < shoot_range and absf(p.position.y) < 480.0:
		var sp: float = 0.15 + (shoot_range - dist_goal) / shoot_range * 0.55
		if rng.randf() < sp:
			var aim: Vector2 = (Vector2(goal.x, rng.randf_range(-0.8, 0.8) * GOAL_HALF) - p.position).normalized()
			_do_shot_dir(p, aim, rng.randf_range(0.6, 1.0))
			return

	var limit: float = 2.6
	match p.role:
		"CB", "LB", "RB": limit = 1.0
		"CM": limit = 1.8
	if d_opp < 75.0 or p.carry_time > limit or rng.randf() < 0.12:
		var q: Footballer = _best_pass_target(p)
		if q != null:
			_do_pass(p, q, false)


func _best_pass_target(p: Footballer) -> Footballer:
	var dir: float = _dir(p.team)
	var best: Footballer = null
	var best_s: float = -999.0
	for q: Footballer in _team(p.team):
		if q == p:
			continue
		var d: float = p.position.distance_to(q.position)
		if d < 110.0 or d > 900.0:
			continue
		var s: float = (q.position.x - p.position.x) * dir / 600.0
		s += minf(_dist_to_nearest_opp(q.position, p.team), 220.0) / 220.0
		s -= d / 1500.0
		if q.is_gk:
			s -= 1.0
		if q.is_user and calling:
			s += 0.9
		if _lane_blocked(p.position, q.position, p.team):
			s -= 0.8
		s += rng.randf_range(-0.2, 0.2)
		if s > best_s:
			best_s = s
			best = q
	return best


func _nearest_opponent(p: Footballer) -> Footballer:
	var best: Footballer = null
	var best_d: float = 1e9
	for o: Footballer in _team(1 - p.team):
		var d: float = p.position.distance_to(o.position)
		if d < best_d:
			best_d = d
			best = o
	return best


func _dist_to_nearest_opp(pos: Vector2, team: int) -> float:
	var best: float = 1e9
	for o: Footballer in _team(1 - team):
		best = minf(best, pos.distance_to(o.position))
	return best


func _lane_blocked(a: Vector2, b: Vector2, team: int) -> bool:
	for o: Footballer in _team(1 - team):
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, a, b)
		if c.distance_to(o.position) < 35.0:
			return true
	return false


# ================================================================ física entre jogadores
func _separate_players() -> void:
	for i in range(players.size()):
		var a: Footballer = players[i]
		for j in range(i + 1, players.size()):
			var b: Footballer = players[j]
			var d: Vector2 = a.position - b.position
			var l: float = d.length()
			if l < 26.0 and l > 0.01:
				var push: Vector2 = d / l * (26.0 - l) * 0.5
				if a.slide_t <= 0.0:
					a.position += push
				if b.slide_t <= 0.0:
					b.position -= push


func _clamp_players() -> void:
	for p: Footballer in players:
		p.position.x = clampf(p.position.x, -W + 8.0, W - 8.0)
		p.position.y = clampf(p.position.y, -H + 8.0, H - 8.0)

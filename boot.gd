extends Node2D
## Inicializador: confere se todos os scripts carregam e só então liga a partida.
## Se algo falhar, mostra na tela qual arquivo está com problema (para diagnóstico).

const FILES := [
	"footballer.gd", "soccer_ball.gd", "pitch_view.gd",
	"match_hud.gd", "touch_controls.gd", "match.gd",
]

var info: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	info = Label.new()
	info.position = Vector2(30.0, 30.0)
	info.add_theme_font_size_override("font_size", 26)
	info.add_theme_color_override("font_color", Color(1, 1, 1))
	info.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	layer.add_child(info)
	info.text = "Carregando..."

	var version: String = str(Engine.get_version_info()["string"])
	var report: Array = []
	var ok: bool = true
	for f: String in FILES:
		var path: String = "res://" + f
		if not ResourceLoader.exists(path):
			report.append("FALTA O ARQUIVO: " + f)
			ok = false
			continue
		var scr: Resource = load(path)
		if scr == null:
			report.append("NAO CARREGA: " + f)
			ok = false
			continue
		var gd: GDScript = scr as GDScript
		if gd != null and not gd.can_instantiate():
			report.append("ERRO NO SCRIPT: " + f)
			ok = false
		else:
			report.append("ok: " + f)

	if ok:
		var game_script: GDScript = load("res://match.gd") as GDScript
		var game: Node = game_script.new()
		add_child(game)
		get_tree().create_timer(2.0).timeout.connect(info.queue_free)
	else:
		info.text = "Nao foi possivel iniciar a partida.\nGodot " + version + "\n\n" + "\n".join(PackedStringArray(report)) + "\n\nMande um print desta tela."

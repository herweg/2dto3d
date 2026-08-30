extends Node3D
## POC de pivot a 3D — Fase A (docs/plan-fases.md, branch pivot-3d-poc).
## Solo comparación visual: importa los 4 GLB candidatos, cámara fija
## ortogonal (mismo criterio que se va a usar en el juego real), una sola
## luz direccional para que el material PBR real (si lo hay) se note contra
## el material "emissive-boosted" (ver hallazgo en docs/3d/monster). No
## toca nada de game/sim/ — es una escena aislada, de investigación.

## scale_fix: los 3 monster_* vinieron con la geometría 100x más grande de
## lo esperado (altura real 170 unidades locales en vez de ~1.7 — bounding
## box verificado directo sobre el GLB, no a ojo). Es justo el "bug de
## fábrica x0.01" que describe la nota de Post-proceso del pipeline del
## usuario — en estos 3 archivos concretos no llegó aplicada. Se compensa
## acá para poder comparar, no es un parche a repetir por asset en el
## pipeline real.
const ASSETS := [
	{"path": "res://assets3d/monster/monster_m5.glb", "label": "monster_m5", "scale_fix": 0.01},
	{"path": "res://assets3d/monster/monster_m7.glb", "label": "monster_m7", "scale_fix": 0.01},
	{"path": "res://assets3d/monster/monster_pbr_m5.glb", "label": "monster_pbr_m5", "scale_fix": 0.01},
	{"path": "res://assets3d/tower/tower_m5.glb", "label": "tower_m5", "scale_fix": 1.0},
]
const SPACING := 3.0
const WARMUP_FRAMES := 90

var _frames_waited := 0
var _shot_taken := false

func _ready() -> void:
	_setup_lighting()
	_setup_camera()
	_load_assets()

func _setup_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.12, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.15, 0.15, 0.18)
	e.ambient_light_energy = 0.3
	env.environment = e
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(ASSETS.size()) * SPACING + 3.0
	var center_x := (float(ASSETS.size()) - 1.0) * SPACING * 0.5
	var cam_pos := Vector3(center_x + 6.0, 6.0, 6.0)
	add_child(cam)
	cam.look_at_from_position(cam_pos, Vector3(center_x, 1.0, 0.0), Vector3.UP)

func _load_assets() -> void:
	for i in range(ASSETS.size()):
		var entry: Dictionary = ASSETS[i]
		var scene: PackedScene = load(entry["path"])
		if scene == null:
			push_error("POC3D: no se pudo cargar %s" % entry["path"])
			continue
		var inst := scene.instantiate()
		var s: float = entry.get("scale_fix", 1.0)
		inst.scale = Vector3(s, s, s)
		inst.position = Vector3(float(i) * SPACING, 0.0, 0.0)
		add_child(inst)

		var label := Label3D.new()
		label.text = entry["label"]
		label.position = Vector3(float(i) * SPACING, 2.6, 0.0)
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

		var anim_player := _find_animation_player(inst)
		if anim_player and anim_player.get_animation_list().size() > 0:
			anim_player.play(anim_player.get_animation_list()[0])
			print("[poc3d] %s anim=%s playing=%s" % [entry["label"], anim_player.get_animation_list()[0], anim_player.is_playing()])

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _process(_delta: float) -> void:
	if _shot_taken:
		return
	_frames_waited += 1
	if _frames_waited >= WARMUP_FRAMES:
		_shot_taken = true
		_take_screenshot()

func _take_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("benchmark_results"):
		dir.make_dir("benchmark_results")
	var path := "res://benchmark_results/poc3d_fase_a.png"
	img.save_png(path)
	print("[poc3d] screenshot: ", path)
	if OS.get_cmdline_user_args().has("quit"):
		get_tree().quit()

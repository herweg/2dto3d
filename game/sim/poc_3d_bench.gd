extends Node3D
## POC de pivot a 3D — Fase B/C (docs/plan-fases.md, branch pivot-3d-poc).
## Banco de costo por instancia y por población. Mismo criterio del resto
## del proyecto: vsync off, piso real (peor frame de la ventana medida), no
## solo promedio. No toca game/sim/ — escena aislada de investigación.
##
## CLI (-- args, mismo estilo que el resto del proyecto):
##   only=<label>   filtra a un solo asset (monster_m5/m7/pbr_m5/tower_m5)
##   count=<n>      instancias por asset filtrado (default 1)
##   anim=0|1       animación activa o no (default 1) — separa costo de rig
##   warmup=<n>     frames de calentamiento antes de medir (default 60)
##   screenshot=1   guarda una captura al terminar de medir
##   proj_count=<n>     instancias de proyectil (primitiva, no hay asset
##                      generado todavía — cápsula chica, material sin
##                      sombreado, mismo criterio de placeholder que ya usó
##                      este proyecto antes de tener arte real)
##   proj_multimesh=0|1 técnica: 1 = un solo MultiMeshInstance3D (default),
##                      0 = un MeshInstance3D por proyectil (comparación)

const PROJ_SCATTER := 12.0
const PROJ_RADIUS := 0.05
const PROJ_HEIGHT := 0.3

const ASSETS := {
	"monster_m5": {"path": "res://assets3d/monster/monster_m5.glb", "scale_fix": 0.01},
	"monster_m7": {"path": "res://assets3d/monster/monster_m7.glb", "scale_fix": 0.01},
	"monster_pbr_m5": {"path": "res://assets3d/monster/monster_pbr_m5.glb", "scale_fix": 0.01},
	"tower_m5": {"path": "res://assets3d/tower/tower_m5.glb", "scale_fix": 1.0},
}
const GRID_SPACING := 2.5
const MEASURE_WINDOW := 120

var _only := ""
var _count := 1
var _counts_override: Array = []
var _anim_enabled := true
var _warmup_frames := 60
var _screenshot := false

var _proj_count := 0
var _proj_multimesh := true

var _total_instances := 0
var _measuring := false
var _measured := false
var _frames_waited := 0
var _frame_times: PackedFloat64Array = []

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_parse_args()
	_setup_lighting()
	_spawn_instances()
	_spawn_projectiles()
	_setup_camera()

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		match parts[0]:
			"only":
				_only = parts[1]
			"count":
				_count = int(parts[1])
			"counts":
				_counts_override = parts[1].split(",")
			"anim":
				_anim_enabled = parts[1] == "1"
			"warmup":
				_warmup_frames = int(parts[1])
			"screenshot":
				_screenshot = parts[1] == "1"
			"proj_count":
				_proj_count = int(parts[1])
			"proj_multimesh":
				_proj_multimesh = parts[1] == "1"

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

func _spawn_instances() -> void:
	var labels: Array = ASSETS.keys() if _only == "" else _only.split(",")
	var total_planned: int = labels.size() * _count if _counts_override.is_empty() else 0
	if not _counts_override.is_empty():
		for c in _counts_override:
			total_planned += int(c)
	var cols: int = max(1, int(ceil(sqrt(float(total_planned)))))
	var idx := 0
	for li in range(labels.size()):
		var label = labels[li]
		var entry: Dictionary = ASSETS[label]
		var scene: PackedScene = load(entry["path"])
		if scene == null:
			push_error("POC3D bench: no se pudo cargar %s" % entry["path"])
			continue
		var this_count: int = int(_counts_override[li]) if li < _counts_override.size() else _count
		for n in range(this_count):
			var inst := scene.instantiate()
			var s: float = entry["scale_fix"]
			inst.scale = Vector3(s, s, s)
			var gx: int = idx % cols
			var gz: int = idx / cols
			inst.position = Vector3(float(gx) * GRID_SPACING, 0.0, float(gz) * GRID_SPACING)
			add_child(inst)
			if _anim_enabled:
				var ap := _find_animation_player(inst)
				if ap and ap.get_animation_list().size() > 0:
					ap.play(ap.get_animation_list()[0])
					ap.seek(randf() * ap.current_animation_length, true)
			idx += 1
	_total_instances = idx

func _spawn_projectiles() -> void:
	if _proj_count <= 0:
		return
	var mesh := CapsuleMesh.new()
	mesh.radius = PROJ_RADIUS
	mesh.height = PROJ_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	mesh.surface_set_material(0, mat)

	if _proj_multimesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = _proj_count
		for i in range(_proj_count):
			var pos := Vector3(randf_range(-PROJ_SCATTER, PROJ_SCATTER), 0.3, randf_range(-PROJ_SCATTER, PROJ_SCATTER))
			mm.set_instance_transform(i, Transform3D(Basis(), pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	else:
		for i in range(_proj_count):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3(randf_range(-PROJ_SCATTER, PROJ_SCATTER), 0.3, randf_range(-PROJ_SCATTER, PROJ_SCATTER))
			add_child(mi)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _setup_camera() -> void:
	var cols: int = max(1, int(ceil(sqrt(float(max(_total_instances, 1))))))
	var rows: int = max(1, int(ceil(float(_total_instances) / float(cols))))
	var extent: float = max(cols, rows) * GRID_SPACING
	if _proj_count > 0:
		extent = max(extent, PROJ_SCATTER)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = extent * 2.0 + 4.0
	var center := Vector3((cols - 1) * GRID_SPACING * 0.5, 0.0, (rows - 1) * GRID_SPACING * 0.5)
	var cam_pos := center + Vector3(extent * 0.6 + 5.0, extent * 0.6 + 5.0, extent * 0.6 + 5.0)
	add_child(cam)
	cam.look_at_from_position(cam_pos, center + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _process(delta: float) -> void:
	if _measured:
		return
	if not _measuring:
		_frames_waited += 1
		if _frames_waited >= _warmup_frames:
			_measuring = true
		return
	_frame_times.append(delta)
	if _frame_times.size() >= MEASURE_WINDOW:
		_measured = true
		_report()

func _report() -> void:
	var total_t := 0.0
	var worst_dt := 0.0
	for dt in _frame_times:
		total_t += dt
		worst_dt = max(worst_dt, dt)
	var avg_fps := float(_frame_times.size()) / total_t
	var floor_fps := 1.0 / worst_dt
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	print("[poc3d-bench] only=%s count=%d anim=%s instances=%d proj_count=%d proj_mm=%s avg_fps=%.1f floor_fps=%.1f frame_ms_floor=%.2f draw_calls=%d primitives=%d vmem_mb=%.1f" % [
		_only if _only != "" else "all", _count, str(_anim_enabled), _total_instances, _proj_count, str(_proj_multimesh), avg_fps, floor_fps, (1000.0 / floor_fps), draw_calls, primitives, vmem / 1048576.0
	])
	if _screenshot:
		var dir := DirAccess.open("res://")
		if dir and not dir.dir_exists("benchmark_results"):
			dir.make_dir("benchmark_results")
		var path := "res://benchmark_results/poc3d_bench_%s_c%d.png" % [(_only if _only != "" else "all"), _count]
		get_viewport().get_texture().get_image().save_png(path)
		print("[poc3d-bench] screenshot: ", path)
	get_tree().quit()

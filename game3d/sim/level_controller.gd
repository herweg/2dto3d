extends Node3D

## La pantalla de juego real — carga el LevelDef del stage actual, corre la
## simulación (sim/*, Vector2 puro, sin ninguna referencia a render — ver
## versionado.md) y sincroniza tres grupos de render cada frame:
## EntityRenderSync/TypedRenderGroup (torres/proyectiles, sin animación,
## MultiMeshInstance3D por type_id) y SharedSkeletonRenderGroup (enemigos,
## animados, esqueleto compartido). Mismo esqueleto de estado (colocación/
## combate), mismo parseo de CLI de dos pasadas, mismo spawner/oro/vidas
## que el resto de las pantallas de este proyecto.
##
## Deuda conocida, no resuelta en este archivo (ver versionado.md): sin VFX
## reales todavía (solo geometría/color plano), sin rotación por instancia
## (torres/enemigos/proyectiles no se orientan a su dirección/movimiento).
##
## Mapeo de coordenadas fijo para todo este puente (una sola decisión,
## consistente en los 3 grupos de render + la geometría de nivel + el
## raycast de colocación): X sim → X 3D, Y sim → Z 3D, altura fija en 0.

const LEVEL_PATHS := [
	"res://data/level_01.tres",
	"res://data/level_02.tres",
	"res://data/level_03.tres",
	"res://data/level_04.tres",
	"res://data/level_05.tres",
]

## MAX_PROJ subido de 4.000 (tope 2D) a 4.500 — el escenario oficial 3D
## (sección 0 de la tarjeta) pide sostener 4.320 proyectiles, por encima
## del tope 2D (dimensionado para el objetivo 2D de 3.600).
const MAX_ENEMIES := 2500
const MAX_PROJ := 4500
const MAX_TOWERS := 150

const STRESS_SPAWN_PER_FRAME := 40
const STRESS_TOWER_SPACING := 70.0

const ENEMY_SPEED := 70.0
const ENEMY_HEALTH := 20.0
const ENEMY_VARIANT := 0
const SPAWN_INTERVAL := 1.2
const GOLD_PER_ROUND := 10

const TOWER_MIN_SPACING := 48.0
const SPATIAL_CELL_SIZE := 48.0

## Mismo set que level_controller.gd (2D) — un tipo se ve del mismo color
## en las dos pantallas mientras conviven.
const TYPE_COLORS := [
	Color(0.30, 0.55, 0.95),  # 0 recta — azul
	Color(0.95, 0.55, 0.15),  # 1 homing — naranja
	Color(0.65, 0.35, 0.85),  # 2 perforante — violeta
	Color(0.15, 0.75, 0.70),  # 3 splash — verde azulado
	Color(0.85, 0.25, 0.25),  # 4 misil ("Mortero") — rojo
	Color(0.90, 0.55, 0.20),  # 5 lanzallamas ("Fuego") — ámbar
	Color(0.95, 0.95, 0.30),  # 6 láser — amarillo
	Color(0.60, 0.60, 0.65),  # 7 riel — gris acero
]

## Assets 3D (fase-3d-tarjetas-pantallas-v1.md sección 0) — calidad
## placeholder, no arte final. scale_fix de monstruo: bug de escala ×100
## del pipeline de origen, sin corregir todavía — ver pivot-3d-poc-v1.md
## sección 6, no parchear distinto de como ya lo hacía poc_3d_bench.gd.
const TOWER_SCENE_PATH := "res://assets3d/tower/tower_m5.glb"
const MONSTER_SCENE_PATH := "res://assets3d/monster/monster_m5.glb"
const MONSTER_SCALE_FIX := 0.01
## 10 maestros — mismo número validado en pivot-3d-poc-v1.md sección 4
## contra el escenario oficial completo (7,14ms quieto / 13,27ms caminando).
const SHARED_SKEL_MASTERS := 10

## Factor de escala del mundo — aparte del scale_fix que corrige el bug de
## origen de monster_m5.glb (pivot-3d-poc-v1.md sección 6). Hallazgo real
## de esta tarjeta (ver fase-3d-motor-log.md): torres/enemigos vienen en
## escala "real" (~1-2 unidades tras scale_fix, la misma escala que usaba
## GRID_SPACING=2.5 en poc_3d_bench.gd), pero el mapeo de coordenadas deja
## el mundo en unidades de sim (obstacle_radius=22, TOWER_MIN_SPACING=48,
## etc.) — sin este factor las mallas quedan del tamaño de un píxel,
## invisibles a la distancia de cámara real del nivel. Calibrado a ojo
## contra obstacle_radius (22) y TOWER_MIN_SPACING (48) por captura, no es
## un número de diseño de arte.
const WORLD_SCALE := 20.0

var _level: LevelDef

var _enemy_store: EnemyStore
var _proj_store: ProjectileStore
var _tower_store: TowerStore

var _hash: SpatialHash
var _proj_system: ProjectileSystem
var _lane_system: LaneEnemySystem
var _tower_system: TowerSystem
var _dot_system: DotSystem

var _enemy_render: SharedSkeletonRenderGroup
var _proj_render: EntityRenderSync
var _tower_render: TypedRenderGroup
var _camera: Camera3D

var _spawn_timer: float = 0.0
var _selected_tower_type: int = 0

enum RoundState { PLACEMENT, COMBAT, ROUND_COMPLETE, ROUND_LOST }
var _round_state: RoundState = RoundState.PLACEMENT

var _max_lives := 20
var _lives := 0
var _leaked_at_round_start := 0
var _lives_label: Label = null
var _enemies_spawned_this_round: int = 0
var _start_button: Button = null
var _test_button: Button = null
var _exit_button: Button = null

var _quit_after: float = -1.0
var _elapsed: float = 0.0
var _shots_taken: Dictionary = {}
var _shot_times: Array = [6.0, 14.0, 30.0]
var _no_screenshot := false

var _stress_test := false
var _stress_towers := 30
var _stress_enemies := 300
var _stress_logger: BenchmarkLogger = null

var _backend_native := true
const STRESS_ENEMY_HEALTH := 600.0

func _load_level_for_stage() -> LevelDef:
	var stage: int = SaveManager.state["stage_index"]
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2 and parts[0] == "stage":
			stage = parts[1].to_int()
	stage = clampi(stage, 0, LEVEL_PATHS.size() - 1)
	return load(LEVEL_PATHS[stage])

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = _load_level_for_stage()

	_enemy_store = EnemyStore.new(MAX_ENEMIES)
	_proj_store = ProjectileStore.new(MAX_PROJ)
	_tower_store = TowerStore.new(MAX_TOWERS)

	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	if ClassDB.class_exists("SimHotPath"):
		_proj_system.native = ClassDB.instantiate("SimHotPath")
	else:
		push_error("[level] SimHotPath no está registrado — ¿falta compilar game3d/rust/? backend=native no va a andar.")
		_backend_native = false
	_lane_system = LaneEnemySystem.new(_enemy_store, _level.waypoints, _level.obstacles, _level.obstacle_radius)
	_tower_system = TowerSystem.new(_tower_store, _enemy_store, _proj_store, _hash)
	_dot_system = DotSystem.new(_enemy_store)

	_setup_lighting()
	_setup_camera()
	_build_level_geometry()
	_setup_render_groups()

	_parse_cli_args()

	if not _stress_test:
		_setup_round_ui()

## Placeholder de iluminación — mismo criterio que poc_3d_bench.gd (una
## sola DirectionalLight3D + ambiente parejo), no es una decisión de
## aspecto final (le toca a Arte).
func _setup_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.12, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.18, 0.18, 0.2)
	e.ambient_light_energy = 0.4
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

## Cámara ortogonal fija (fase-3d-tarjetas-pantallas-v1.md sección 1) —
## mismo ángulo diagonal que poc_3d_bench.gd::_setup_camera(), encuadrada
## contra el área real de la pantalla (_level.background_rect) en vez de
## una grilla de población.
func _setup_camera() -> void:
	var rect: Rect2 = _level.background_rect
	var center := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
	var half_extent: float = maxf(rect.size.x, rect.size.y) * 0.5
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = half_extent * 1.9 + 60.0
	_camera.far = 4000.0
	var cam_pos := center + Vector3(half_extent * 0.7, half_extent * 0.85 + 250.0, half_extent * 0.7)
	add_child(_camera)
	_camera.look_at_from_position(cam_pos, center, Vector3.UP)
	_camera.current = true

## Geometría de nivel que en 2D era _draw() (CanvasItem, no existe en
## Node3D) — carril, zonas de colocación, obstáculos, spawn/meta
## (fase-3d-tarjetas-pantallas-v1.md sección 1). Un plano con color plano
## alcanza como placeholder, mismo criterio que el resto de la tarjeta.
## Estática, construida una sola vez (la geometría de nivel no cambia por
## frame) — a diferencia de los grupos de render de entidades.
func _build_level_geometry() -> void:
	var rect: Rect2 = _level.background_rect
	if _level.background_texture:
		_add_plane(rect, Color.WHITE, -0.05, _level.background_texture)
	else:
		_add_plane(rect, _level.background_color, -0.05)
	for r in _level.buildable_zones:
		_add_plane(r, Color(0.35, 0.35, 0.37, 1.0), 0.01)
	for r in _level.path_rects:
		_add_plane(r, Color(0.29, 0.42, 0.22, 1.0), 0.0)
	for o in _level.obstacles:
		_add_obstacle(o, _level.obstacle_radius)
	_add_marker(_level.spawn_point, Color(0.9, 0.8, 0.2, 1.0))
	_add_marker(_level.goal_point, Color(0.9, 0.2, 0.2, 1.0))

func _add_plane(rect: Rect2, color: Color, y: float, texture: Texture2D = null) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(rect.size.x, rect.size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if texture:
		mat.albedo_texture = texture
		mat.uv1_scale = Vector3(rect.size.x / texture.get_width(), rect.size.y / texture.get_height(), 1.0)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5)
	add_child(mi)

func _add_obstacle(pos: Vector2, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 40.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.24, 0.14, 1.0)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(pos.x, 20.0, pos.y)
	add_child(mi)

func _add_marker(pos: Vector2, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 14.0
	mesh.bottom_radius = 14.0
	mesh.height = 4.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(pos.x, 2.0, pos.y)
	add_child(mi)

## Arma los 3 grupos de render: torres/proyectiles vía MultiMeshInstance3D
## (TypedRenderGroup/EntityRenderSync), enemigos vía esqueleto compartido
## (SharedSkeletonRenderGroup) — ninguna clase intenta las dos técnicas.
func _setup_render_groups() -> void:
	var tower_mesh: Mesh = null
	var tower_mat: Material = null
	var tower_scene: PackedScene = load(TOWER_SCENE_PATH)
	if tower_scene:
		var tmp := tower_scene.instantiate()
		var mi := _find_mesh_instance(tmp)
		if mi:
			tower_mesh = mi.mesh
			tower_mat = mi.get_active_material(0)
		tmp.free()
	if tower_mesh == null:
		push_error("[level] no se pudo extraer malla de " + TOWER_SCENE_PATH)
	_tower_render = TypedRenderGroup.new(TowerStore.TOWER_TYPE_STATS.size(), MAX_TOWERS, tower_mesh, tower_mat, TYPE_COLORS, 0.0, WORLD_SCALE)
	_tower_render.add_all_to(self)

	# Proyectil: primitiva placeholder (cápsula, sin sombreado — no hay
	# asset generado todavía), un solo MultiMesh con color por-instancia
	# (no necesita malla propia por tipo, a diferencia de torres — mismo
	# motivo que separa estas dos técnicas, ver TypedRenderGroup).
	var proj_mesh := CapsuleMesh.new()
	proj_mesh.radius = 4.0
	proj_mesh.height = 16.0
	var proj_mat := StandardMaterial3D.new()
	proj_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	proj_mat.vertex_color_use_as_albedo = true
	_proj_render = EntityRenderSync.new(MAX_PROJ, proj_mesh, proj_mat, 20.0)
	_proj_render.set_type_colors(TYPE_COLORS)
	add_child(_proj_render.get_node3d())

	var monster_scene: PackedScene = load(MONSTER_SCENE_PATH)
	_enemy_render = SharedSkeletonRenderGroup.new(self, monster_scene, MAX_ENEMIES, SHARED_SKEL_MASTERS, MONSTER_SCALE_FIX * WORLD_SCALE)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

func _setup_round_ui() -> void:
	var layer := CanvasLayer.new()
	_start_button = Button.new()
	_start_button.text = "Comenzar"
	_start_button.position = Vector2(20, 20)
	_start_button.size = Vector2(160, 40)
	_start_button.pressed.connect(_start_round)
	_start_button.visible = _round_state == RoundState.PLACEMENT
	layer.add_child(_start_button)

	_test_button = Button.new()
	_test_button.text = "TEST: Finalizar ronda"
	_test_button.position = Vector2(20, 70)
	_test_button.size = Vector2(160, 40)
	_test_button.add_theme_font_size_override("font_size", 12)
	_test_button.self_modulate = Color(1.0, 0.35, 0.1)
	_test_button.pressed.connect(_force_finish_round)
	layer.add_child(_test_button)

	_exit_button = Button.new()
	_exit_button.text = "Salir al menú"
	_exit_button.position = Vector2(20, 120)
	_exit_button.size = Vector2(160, 40)
	_exit_button.pressed.connect(_exit_to_menu)
	layer.add_child(_exit_button)

	_lives_label = Label.new()
	_lives_label.position = Vector2(20, 170)
	layer.add_child(_lives_label)
	_refresh_lives_label()

	add_child(layer)

func _start_round() -> void:
	if _round_state != RoundState.PLACEMENT:
		return
	_round_state = RoundState.COMBAT
	if _start_button:
		_start_button.visible = false
	_lives = _max_lives
	_leaked_at_round_start = _lane_system.leaked_count
	_refresh_lives_label()

func _complete_round() -> void:
	if _round_state != RoundState.COMBAT:
		return
	_round_state = RoundState.ROUND_COMPLETE
	if _start_button:
		_start_button.text = "Ronda completa"
		_start_button.disabled = true
		_start_button.visible = true
	if _test_button:
		_test_button.disabled = true
	SaveManager.add_gold(GOLD_PER_ROUND)
	SaveManager.add_kills(_lane_system.killed_count)
	print("[level] ronda completa — objetivo: %d, muertes: %d, leaks: %d, oro ganado: %d" % [_level.wave_enemy_count, _lane_system.killed_count, _lane_system.leaked_count, GOLD_PER_ROUND])
	_advance_stage_and_continue()

func _advance_stage_and_continue() -> void:
	var was_last: bool = SaveManager.state["stage_index"] >= LEVEL_PATHS.size() - 1
	if not was_last:
		SaveManager.state["stage_index"] += 1
		SaveManager.save_game()
	await get_tree().create_timer(1.5).timeout
	if was_last:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Level.tscn")

func _lose_round() -> void:
	if _round_state != RoundState.COMBAT:
		return
	_round_state = RoundState.ROUND_LOST
	if _start_button:
		_start_button.text = "Derrota"
		_start_button.disabled = true
		_start_button.visible = true
	if _test_button:
		_test_button.disabled = true
	print("[level] derrota — vidas agotadas, muertes: %d, leaks: %d" % [_lane_system.killed_count, _lane_system.leaked_count])

func _check_defeat() -> bool:
	var leaks_this_round := _lane_system.leaked_count - _leaked_at_round_start
	var lives_now := maxi(_max_lives - leaks_this_round, 0)
	if lives_now != _lives:
		_lives = lives_now
		_refresh_lives_label()
	if _lives <= 0:
		_lose_round()
		return true
	return false

func _refresh_lives_label() -> void:
	if _lives_label:
		_lives_label.text = "Vidas: %d" % _lives

func _force_finish_round() -> void:
	if _round_state == RoundState.ROUND_COMPLETE or _round_state == RoundState.ROUND_LOST:
		return
	if _round_state == RoundState.PLACEMENT:
		_round_state = RoundState.COMBAT
		_lives = _max_lives
		_leaked_at_round_start = _lane_system.leaked_count
		_refresh_lives_label()
		if _start_button:
			_start_button.visible = false
	_enemies_spawned_this_round = _level.wave_enemy_count
	while _enemy_store.active_count > 0:
		_enemy_store.release(0)
	_complete_round()

func _exit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _parse_cli_args() -> void:
	# Preset de stress-test elegido en StressMenu.tscn (Tarjeta 4, sin CLI —
	# ver stress_launch_config.gd) — mismo disparador que el flag CLI
	# `stress-test`, consumido una sola vez para no reactivarse solo.
	if StressLaunchConfig.pending:
		var cfg := StressLaunchConfig.consume()
		_stress_test = true
		_stress_towers = cfg["towers"]
		_stress_enemies = cfg["enemies"]
		TowerStore.DEV_RANGE_OVERRIDE = 0.0
		TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0

	for arg in OS.get_cmdline_user_args():
		if arg == "real-stats":
			TowerStore.DEV_RANGE_OVERRIDE = 0.0
			TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
		if arg == "stress-test":
			_stress_test = true
		var parts := arg.split("=")
		if parts.size() == 2:
			match parts[0]:
				"quit-after":
					_quit_after = parts[1].to_float()
				"stress-towers":
					_stress_towers = parts[1].to_int()
				"stress-enemies":
					_stress_enemies = parts[1].to_int()
				"stress-fire-rate":
					TowerStore.DEV_FIRE_RATE_OVERRIDE = parts[1].to_float()
				"no-screenshot":
					if parts[1] == "1":
						_no_screenshot = true
				"backend":
					_backend_native = parts[1] != "gdscript"
				"lives":
					_max_lives = parts[1].to_int()

	if _stress_test:
		_setup_stress_test()

	for arg in OS.get_cmdline_user_args():
		if arg == "place-test-towers":
			_place_test_towers()
		if arg == "place-all-towers":
			_place_all_types_test()
		if arg == "start-round":
			_start_round()
		if arg == "force-finish-round":
			_force_finish_round()
		if arg == "auto-exit-to-menu":
			_exit_to_menu.call_deferred()
		var parts := arg.split("=")
		if parts.size() == 2:
			match parts[0]:
				"place-types":
					_place_types_test(parts[1])

func _setup_stress_test() -> void:
	var row_spacing := TOWER_MIN_SPACING
	var rows := int(640.0 / row_spacing) + 1
	var col_count := ceili(float(_stress_towers) / float(rows))
	var num_types := TowerStore.TOWER_TYPE_STATS.size()
	var placed := 0
	for col in col_count:
		var x := 30.0 + col * TOWER_MIN_SPACING
		for r in rows:
			if placed >= _stress_towers:
				break
			var y := -320.0 + r * row_spacing
			if _place_tower(Vector2(x, y), placed % num_types):
				placed += 1

	var out_path := "res://benchmark_results/level_stress_%d.csv" % Time.get_unix_time_from_system()
	_stress_logger = BenchmarkLogger.new(out_path)
	print("[level] stress test: %d torres colocadas (objetivo %d), rampa a %d enemigos. Log: %s" % [placed, _stress_towers, _stress_enemies, out_path])

func _place_test_towers() -> void:
	var spots := [Vector2(60.0, -320.0), Vector2(60.0, -60.0), Vector2(60.0, 120.0), Vector2(60.0, 300.0)]
	for t in 4:
		_place_tower(spots[t], t)

func _place_all_types_test() -> void:
	var types: Array = []
	for t in TowerStore.TOWER_TYPE_STATS.size():
		types.append(t)
	_place_types(types)

func _place_types_test(csv: String) -> void:
	var types: Array = []
	for s in csv.split(","):
		types.append(s.to_int())
	_place_types(types)

func _place_types(types: Array) -> void:
	var y_start := -320.0
	var y_step := 640.0 / maxf(1.0, float(types.size() - 1))
	for i in types.size():
		_place_tower(Vector2(30.0, y_start + i * y_step), types[i])

func _place_tower(pos: Vector2, tower_type: int = -1) -> bool:
	if not _stress_test and _round_state != RoundState.PLACEMENT:
		return false
	if tower_type == -1:
		tower_type = _selected_tower_type
	if not _level.is_buildable(pos):
		return false
	for i in _tower_store.active_count:
		if _tower_store.positions[i].distance_to(pos) < TOWER_MIN_SPACING:
			return false
	if _tower_store.is_full():
		return false
	# Dirección fija izquierda — mismo criterio que level_controller.gd (2D).
	_tower_store.spawn_typed(pos, tower_type, Vector2.LEFT)
	return true

## Raycast cámara→plano y=0 (exploracion-3d.md sección 2A, patrón exacto) —
## reemplaza get_global_mouse_position() (2D nativo) para colocar torres
## con el mouse bajo Camera3D.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_viewport().get_mouse_position()
		var origin := _camera.project_ray_origin(mouse_pos)
		var dir := _camera.project_ray_normal(mouse_pos)
		if absf(dir.y) > 0.0001:
			var t := -origin.y / dir.y
			if t >= 0.0:
				var hit := origin + dir * t
				_place_tower(Vector2(hit.x, hit.z))
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _selected_tower_type = 0
			KEY_2: _selected_tower_type = 1
			KEY_3: _selected_tower_type = 2
			KEY_4: _selected_tower_type = 3

func _process(delta: float) -> void:
	_elapsed += delta

	if _stress_test:
		_stress_top_up_enemies()
	elif _round_state == RoundState.COMBAT:
		_tick_round_spawner(delta)

	_lane_system.tick(delta)
	_hash.build(_enemy_store)
	if _backend_native:
		_proj_system.tick_native(delta)
	else:
		_proj_system.tick(delta)
	_tower_system.tick(delta)
	_dot_system.tick(delta)

	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	_tower_render.sync(_tower_store.positions, _tower_store.type_id, _tower_store.active_count)

	if _stress_logger:
		_stress_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)

	_maybe_screenshot()
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		if _stress_logger:
			_stress_logger.close()
		print("[level] listo — torres: %d, proyectiles activos: %d, enemigos activos: %d, muertes: %d, leaks: %d, estado: %s, vidas: %d, stage: %d" % [_tower_store.active_count, _proj_store.active_count, _enemy_store.active_count, _lane_system.killed_count, _lane_system.leaked_count, RoundState.keys()[_round_state], _lives, SaveManager.state["stage_index"]])
		get_tree().quit()

func _tick_round_spawner(delta: float) -> void:
	if _check_defeat():
		return
	if _enemies_spawned_this_round < _level.wave_enemy_count:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _enemy_store.active_count < MAX_ENEMIES:
			_spawn_timer = SPAWN_INTERVAL
			var idx := _enemy_store.spawn(_level.spawn_point, ENEMY_SPEED, ENEMY_HEALTH, 0.0, ENEMY_VARIANT)
			if idx != -1:
				_enemy_store.waypoint_index[idx] = 0
				_enemies_spawned_this_round += 1
	elif _enemy_store.active_count == 0:
		_complete_round()

func _stress_top_up_enemies() -> void:
	var spawned := 0
	while _enemy_store.active_count < _stress_enemies and spawned < STRESS_SPAWN_PER_FRAME:
		var idx := _enemy_store.spawn(_random_point_in_path(), ENEMY_SPEED, STRESS_ENEMY_HEALTH, 0.0, ENEMY_VARIANT)
		if idx == -1:
			break
		_enemy_store.waypoint_index[idx] = 0
		spawned += 1

func _random_point_in_path() -> Vector2:
	var r: Rect2 = _level.path_rects[randi() % _level.path_rects.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func _maybe_screenshot() -> void:
	if DisplayServer.get_name() == "headless" or _no_screenshot:
		return
	for t in _shot_times:
		if _elapsed >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			var img := get_viewport().get_texture().get_image()
			var path := "res://benchmark_results/level_screenshot_t%d.png" % int(t)
			img.save_png(path)
			print("[level] screenshot guardado: ", path)

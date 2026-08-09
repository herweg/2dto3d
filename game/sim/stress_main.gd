extends Node2D

## Arnés de benchmark de ingeniería sobre los sistemas REALES de la pantalla 1
## (LaneEnemySystem, ProjectileSystem con los tipos implementados, TowerSystem,
## DotSystem) — no pretende ser jugable, es para encontrar el techo de 60fps
## de esta pantalla concreta y separar el costo de cada pieza. Mismo método
## que benchmark_main.gd del spike de Sprint 2, aplicado al contenido real.
##
## Modos (CLI, vía --):
##   mode=enemies      barre ENEMY_LEVELS, sin proyectiles ni torres
##   mode=projectiles  barre PROJ_LEVELS (spawn sintético, sin torres),
##                      enemigos fijos como blanco de colisión
##   mode=towers       barre TOWER_LEVELS con torres reales disparando
##                      (TowerSystem), enemigos fijos como blanco
##   mode=joint        "verificación de pico conjunto" (director, 08-ago):
##                      2.000 enemigos, 3.000 proyectiles (mezcla realista de
##                      los 5 tipos viajeros — láser/lanzallamas no spawnean
##                      proyectil, ver TOWER_MODE_BEAM), 20 torres reales —
##                      todo ×1.2 (condición del 20% de T4) — TOWER_TYPE_STATS
##                      real (sin overrides de desarrollo), backend nativo
##                      por default.
##   mode=vfx           benchmark de costo de VFX en GPU (docs/diseno-grafico.md
##                      sección 5): mismo piso que mode=joint + una variable de
##                      GPU por corrida, elegida con vfx-test=unit|scenario|
##                      overdraw|tint (ver _setup_vfx()). CORRE EN VENTANA, NO
##                      headless — --headless usa un driver de rendering sin
##                      GPU real, un GPUParticles2D no hace nada ahí (se
##                      confirmó: sin ventana no aparece la línea "Vulkan ...
##                      Using Device" que sí aparece en corridas con ventana).
##   mode=vfx-scale     escalada conservadora → real, con Vulkan real (pedido
##                      explícito 08-ago, en vez de saltar directo al piso de
##                      diseño): barre VFX_SCALE_ENEMY_LEVELS/TOWER_LEVELS
##                      desde 50 enemigos/5 torres hasta 2.400/24, con
##                      "torres normales" (tipos 0-3, no la familia BEAM/riel/
##                      misil). vfx-scale-fx=1 agrega VFX proporcional al
##                      tamaño de cada escalón (mismos emisores/capas que
##                      mode=vfx) — sin el flag, mide población+render real
##                      sola, para tener el punto de comparación limpio.
##   mode=targeting     ¿cuesta el targeting? (pedido explícito 08-ago) — 24
##                      torres a cadencia forzada (TARGETING_FIRE_INTERVAL,
##                      no la real, para maximizar la señal) contra 2.400
##                      enemigos reales, comparando SOLO cómo eligen
##                      dirección: targeting-variant=fixed (dirección fija,
##                      sin buscar nada) vs =nearest (_find_nearest_enemy(),
##                      el mismo método brute-force que ya usa TowerSystem).
##                      No pasa por TowerSystem — es una réplica mínima a
##                      propósito, para que la única diferencia entre las
##                      dos corridas sea la búsqueda de objetivo.
## Parámetros comunes: proj-type=mixed|0-5, tower-type=0-7, backend=gdscript|native,
## level-duration=<seg>, hold-at-peak=<seg>, vfx-test=unit|scenario|overdraw|tint,
## vfx-count=<N> (solo vfx-test=overdraw), vfx-scale-fx=0|1 (solo mode=vfx-scale),
## targeting-variant=fixed|nearest (solo mode=targeting)

const LEVEL_DEF := preload("res://data/level_01.tres")

const MAX_ENEMIES := 7500
const MAX_PROJ := 8000
const MAX_TOWERS := 1500

const ENEMY_LEVELS := [300, 400, 500, 600, 700, 800, 1200, 1800, 2500, 3500, 5000, 7000]
const PROJ_LEVELS := [500, 800, 1100, 1400, 1700, 2000, 3000, 4500, 6000]
const TOWER_LEVELS := [50, 100, 200, 300, 500, 800, 1200]

## "Verificación de pico conjunto" — número real de diseño (director,
## fase2-motor-cristalizado.md) × 1.2 (condición del 20%, definicion-escala-v1.md).
const JOINT_MARGIN := 1.2
const JOINT_ENEMY_TARGET := 2000
const JOINT_PROJ_TARGET := 3000
const JOINT_TOWER_TARGET := 20

const DEFAULT_LEVEL_DURATION := 4.0
const DEFAULT_HOLD_AT_PEAK := 6.0
const SPATIAL_CELL_SIZE := 48.0

const ENEMY_SPEED := 70.0
const FIXED_ENEMY_POP := 400   # población fija usada como blanco en mode=projectiles/towers
const FIXED_ENEMY_HEALTH := 900.0  # tanky — no se filtra por muertes durante la medición
const MAX_SPAWN_PER_FRAME := 300

## Mezcla realista de los proyectiles que "viajan" (recto, homing,
## perforante, splash, misil) — pesos aproximados a cuántas de las ~20-24
## torres de una composición real serían de cada familia. PROJ_ZONE queda
## AFUERA de esta mezcla a propósito — ver ZONE_FIXED_COUNT: una zona no es
## "un proyectil más" en volumen, es un emisor de larga vida que en juego
## real nunca hay más que un puñado activas a la vez (torres con cooldown
## de segundos, no un inyector sintético manteniendo cientos). Meterla en
## esta mezcla infló el benchmark con ~300 zonas simultáneas, cada una
## haciendo hash.query_nearby() por tick — un artefacto de metodología del
## benchmark, no un costo real del juego. Diagnosticado 08-ago: aislada,
## zona sola corre a 7.5-13fps a esta escala; recto/homing solos, 75-80fps.
const REALISTIC_PROJ_WEIGHTS := [32, 22, 14, 22, 10]  # suma 100, índice = proj_type (0-4, sin zona)

## Migración de lanzallamas a TOWER_MODE_BEAM (fase2-benchmark-conjunto.md
## sección 7, 08-ago): ninguna fila de TOWER_TYPE_STATS spawnea PROJ_ZONE ya
## — la torre real que lo hacía ahora resuelve como rectángulo en
## TowerSystem._tick_beam(), sin tocar ProjectileStore. Sostener zonas
## sintéticas acá mediría un mecanismo que el juego real ya no tiene. En 0,
## _top_up_zones() no hace nada — se deja la función en vez de borrarla por
## si PROJ_ZONE vuelve a tener una fuente real (Racimo, categorías D/E/F).
const ZONE_FIXED_COUNT := 0

## Benchmark de VFX (docs/diseno-grafico.md sección 5) — parámetros de los
## 4 escenarios. Ninguno tiene stats congeladas de catálogo todavía (Enjambre
## y Gravedad son categorías C/D deferidas, fase2-benchmark-conjunto.md
## sección 1), así que los conteos son suposiciones explícitas, no datos: ver
## el comentario de cada escenario en _setup_vfx().
const VFX_SWARM_AMOUNT := 40        # partículas por emisor, "a stats máximos"
const VFX_SWARM_LIFETIME := 1.0
const VFX_UNIT_EMITTER_COUNT := 3   # "conteo simultáneo realista" asumido — ~1 torre cada 8, como el resto del catálogo
const VFX_SCENARIO_EMITTER_COUNT := 20  # de los 30 "torretas maxeadas" del escenario 2 — el resto son overdraw, ver abajo
const VFX_SCENARIO_OVERDRAW_COUNT := 10
const VFX_OVERDRAW_BASE := 10       # mismo tope que ZONE_FIXED_COUNT usaba — punto de partida, no arbitrario
const VFX_OVERDRAW_STRESS := 25     # "una corrida adicional por encima del tope" pedida en la sección 5

## mode=vfx-scale — escalones desde lo más conservador (5 torres normales,
## 50 enemigos) hasta el piso de diseño ×1.2 (24 torres, 2.400 enemigos, el
## mismo objetivo que JOINT_*_TARGET). Paralelos por índice: nivel i usa
## VFX_SCALE_ENEMY_LEVELS[i] enemigos y VFX_SCALE_TOWER_LEVELS[i] torres.
const VFX_SCALE_ENEMY_LEVELS := [50, 200, 500, 1000, 1600, 2400]
const VFX_SCALE_TOWER_LEVELS := [5, 8, 12, 16, 20, 24]
const VFX_SCALE_PROJ_RATIO := 1.5  # mismo ratio que JOINT_PROJ_TARGET/JOINT_ENEMY_TARGET (3000/2000)
const VFX_SCALE_TOWER_TYPES := 4   # "torres normales" — cicla tipos 0-3 (recto/homing/perforante/splash), no BEAM/riel/misil

## mode=targeting — ¿cuánto cuesta que la torre "apunte"?
const TARGETING_TOWER_COUNT := 24        # mismo objetivo ×1.2 de siempre
const TARGETING_FIRE_INTERVAL := 0.05    # cadencia forzada — "disparan a discreción", no el fire_rate real
const TARGETING_PROJ_SPEED := 400.0
const TARGETING_PROJ_LIFE := 1.0
const TARGETING_PROJ_DAMAGE := 1.0

var _mode := "enemies"
var _proj_type_arg := "mixed"
var _tower_type_arg := 3  # splash ("las explosivas") por default para mode=towers
var _backend_arg := "gdscript"
var _tower_cycle_modulo := 8  # diagnóstico: 6 = excluir láser/riel (idx 6,7) de la mezcla de mode=joint
var _joint_enemy_override := -1  # diagnóstico: pisa _joint_enemy_target (-1 = usar ×1.2 normal)
var _joint_tower_override := -1  # diagnóstico: pisa _joint_tower_target (-1 = usar ×1.2 normal)
var _level_duration := DEFAULT_LEVEL_DURATION
var _hold_at_peak := DEFAULT_HOLD_AT_PEAK

## A/B de gráficos y animación (ver docs/) — sprite=1 activa sprite animado
## en mode=enemies en vez de color plano, mismo ENEMY_LEVELS, para medir el
## costo real contra el ~5.730 ya conocido del color plano.
var _sprite_arg := false
const SPRITE_SHEET := "res://assets/characters.png"
const SPRITE_ROW := 1  # fila 1 del atlas = goblin (tipo 0)
const SPRITE_ANIM_INTERVAL := 0.2

var _level: LevelDef
var _enemy_store: EnemyStore
var _proj_store: ProjectileStore
var _tower_store: TowerStore
var _hash: SpatialHash
var _lane_system: LaneEnemySystem
var _proj_system: ProjectileSystem
var _tower_system: TowerSystem
var _dot_system: DotSystem
var _enemy_render: EntityRenderSync
var _proj_render: EntityRenderSync
var _tower_render: EntityRenderSync
var _logger: BenchmarkLogger

var _levels: Array = []
var _level_idx := 0
var _level_timer := 0.0
var _elapsed := 0.0
var _hold_timer := 0.0
var _quitting := false
var _shots_taken := {}
var _shot_times: Array = []

var _joint_enemy_target := 0
var _joint_proj_target := 0
var _joint_tower_target := 0
var _joint_ramped := false

var _vfx_test_arg := "unit"
var _vfx_count_arg := -1  # -1 = usar VFX_OVERDRAW_BASE
var _vfx_particle_tex: ImageTexture
var _vfx_overdraw_tex: ImageTexture
var _vfx_tint_material: ShaderMaterial

var _vfx_scale_fx := false  # vfx-scale-fx=1
var _vfx_scale_particles_added := 0
var _vfx_scale_overdraw_added := 0

var _targeting_variant_arg := "nearest"
var _targeting_cooldowns: PackedFloat32Array

## Diagnóstico puntual (09-ago, revisión de Dirección sobre el piso de
## mode=joint) — get_viewport().get_texture().get_image() en
## _maybe_screenshot() es una lectura síncrona de GPU, candidata obvia a
## explicar un dip de fps at momento fijo (t=5.0s, primer elemento de
## _shot_times para mode=joint). no-screenshot=1 lo saltea por completo
## (además del corte ya existente por headless) para poder aislar la
## variable sin tocar nada más del benchmark.
var _no_screenshot_arg := false

## Tarjeta de cierre de Fase 2, punto 4 (plan-fases.md) — ningún banco corrido
## hasta ahora ejercita el camino de render que van a usar las 20 torretas
## con sprite propio: TypedRenderGroup, un MultiMeshInstance2D (y un bind de
## textura) por type_id presente, no uno solo compartido como hace
## _tower_render (EntityRenderSync + set_type_colors()) en el resto de los
## modos. tower-sprite-test=1 reemplaza _tower_render por un
## TypedRenderGroup en mode=joint, reusando torreta_recta_v2.png (ya
## recortado/cuadrado, sección 14 de smoke-test-motor-arte-v1.md) asignado a
## los 8 type_id — misma imagen en los 8, pero 8 binds de textura reales, no
## uno solo, que es el costo que interesa medir. Sin costo de créditos de
## Arte — reusa el placeholder que ya existía para la sección 8.
var _tower_sprite_test_arg := false
var _tower_render_typed: TypedRenderGroup
const TOWER_SPRITE_TEST_TEX := "res://assets/torreta_recta_v2.png"

func _ready() -> void:
	# Sin esto, a poblacion baja (mode=vfx-scale, escalones iniciales) el
	# frame time mide el refresco del monitor (144Hz acá), no el motor — un
	# techo de vsync no es lo mismo que "el motor anda holgado". No aplica
	# en --headless (no hay ventana que vsync-ear).
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_parse_cli_args()
	_level = LEVEL_DEF

	_enemy_store = EnemyStore.new(MAX_ENEMIES)
	_proj_store = ProjectileStore.new(MAX_PROJ)
	_tower_store = TowerStore.new(MAX_TOWERS)
	_hash = SpatialHash.new(SPATIAL_CELL_SIZE)
	_lane_system = LaneEnemySystem.new(_enemy_store, _level.waypoints, _level.obstacles, _level.obstacle_radius)
	_proj_system = ProjectileSystem.new(_proj_store, _enemy_store, _hash)
	_tower_system = TowerSystem.new(_tower_store, _enemy_store, _proj_store, _hash)
	_dot_system = DotSystem.new(_enemy_store)

	if _mode == "joint" or _mode == "vfx" or _mode == "vfx-scale" or _mode == "targeting" or _backend_arg == "native":
		if ClassDB.class_exists("SimHotPath"):
			_proj_system.native = ClassDB.instantiate("SimHotPath")
			_backend_arg = "native"
		else:
			push_error("[stress] backend=native pedido pero SimHotPath no está registrado — ¿falta compilar game/rust/?")
			get_tree().quit(1)
			return

	_enemy_render = EntityRenderSync.new(MAX_ENEMIES, 14.0, Color(0.75, 0.15, 0.15))
	_proj_render = EntityRenderSync.new(MAX_PROJ, 6.0, Color(1.0, 0.9, 0.3))
	var type_colors := [
		Color(0.30, 0.55, 0.95), Color(0.95, 0.55, 0.15), Color(0.65, 0.35, 0.85), Color(0.15, 0.75, 0.70),
		Color(0.85, 0.25, 0.25), Color(0.90, 0.55, 0.20), Color(0.95, 0.95, 0.30), Color(0.60, 0.60, 0.65),
	]
	_proj_render.set_type_colors(type_colors)
	add_child(_enemy_render.get_node2d())
	add_child(_proj_render.get_node2d())

	if _tower_sprite_test_arg:
		_tower_render_typed = TypedRenderGroup.new(TowerStore.TOWER_TYPE_STATS.size(), MAX_TOWERS, 16.0, type_colors)
		var tex := load(TOWER_SPRITE_TEST_TEX)
		for t in TowerStore.TOWER_TYPE_STATS.size():
			_tower_render_typed.set_sprite_for_type(t, tex, tex)
		_tower_render_typed.add_all_to(self)
	else:
		_tower_render = EntityRenderSync.new(MAX_TOWERS, 16.0, Color(0.25, 0.35, 0.55))
		_tower_render.set_type_colors(type_colors)
		add_child(_tower_render.get_node2d())

	if _sprite_arg and _mode == "enemies":
		var atlas := SpriteAtlas.new(SPRITE_SHEET)
		var idle := atlas.crop_frame(0, SPRITE_ROW)
		var walk := atlas.crop_frame(1, SPRITE_ROW)
		_enemy_render.set_sprite(idle, walk, SPRITE_ANIM_INTERVAL)

	match _mode:
		"projectiles":
			_levels = PROJ_LEVELS
		"towers":
			_levels = TOWER_LEVELS
		"joint":
			_setup_joint()
		"vfx":
			_setup_joint()
			_setup_vfx()
		"vfx-scale":
			_setup_vfx_scale()
		"targeting":
			_setup_targeting()
		_:
			_mode = "enemies"
			_levels = ENEMY_LEVELS

	var total_time: float
	if _mode == "joint" or _mode == "vfx" or _mode == "targeting":
		total_time = 4.0 + _hold_at_peak  # la rampa a población fija tarda unos pocos segundos, no 30
	else:
		total_time = _level_duration * _levels.size() + _hold_at_peak
	_shot_times = [total_time * 0.5, total_time * 0.95]

	var tag := _mode
	if _mode == "vfx":
		tag = _mode + "_" + _vfx_test_arg
	elif _mode == "vfx-scale":
		tag = _mode + ("_fx" if _vfx_scale_fx else "_base")
	elif _mode == "targeting":
		tag = _mode + "_" + _targeting_variant_arg
	elif _sprite_arg and _mode == "enemies":
		tag = _mode + "_sprite"
	var out_path := "res://benchmark_results/stress_%s_%d.csv" % [tag, Time.get_unix_time_from_system()]
	_logger = BenchmarkLogger.new(out_path)
	print("[stress] modo=%s backend=%s sprite=%s niveles=%s tipo_proy=%s tipo_torre=%d log=%s" % [_mode, _backend_arg, _sprite_arg, str(_levels), _proj_type_arg, _tower_type_arg, out_path])

## TOWER_TYPE_STATS real (sin overrides de desarrollo) y objetivos ×1.2 —
## ver docs/fase2-plan-proyectiles.md y fase2-motor-cristalizado.md.
func _setup_joint() -> void:
	TowerStore.DEV_RANGE_OVERRIDE = 0.0
	TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
	_joint_enemy_target = _joint_enemy_override if _joint_enemy_override >= 0 else int(round(JOINT_ENEMY_TARGET * JOINT_MARGIN))
	_joint_proj_target = int(round(JOINT_PROJ_TARGET * JOINT_MARGIN))
	_joint_tower_target = _joint_tower_override if _joint_tower_override >= 0 else int(round(JOINT_TOWER_TARGET * JOINT_MARGIN))
	_levels = [_joint_proj_target]  # solo para que _current_target()/_at_final_level() no rompan

## Benchmark de VFX en GPU (docs/diseno-grafico.md sección 5) — agrega UNA
## variable de GPU sobre el piso de _setup_joint(), mismo método que ya
## separó Ruta A/B y aisló PROJ_ZONE: una corrida, una variable.
func _setup_vfx() -> void:
	match _vfx_test_arg:
		"unit":
			# Escenario 1: costo unitario — un tipo de emisor (Gravedad:
			# remolino de partículas siendo absorbidas — el caso "puro" de
			# partículas del catálogo, a diferencia de Enjambre que es más
			# proyectiles simulados que VFX) replicado al conteo simultáneo
			# de ESE tipo de torreta. Sin fila congelada todavía para
			# Gravedad, así que el conteo es una suposición explícita: ~3
			# simultáneas, la misma densidad por tipo que ya usa el resto
			# del catálogo en la composición de 24 torres/8 tipos del
			# benchmark conjunto (fase2-benchmark-conjunto.md sección 3).
			for i in VFX_UNIT_EMITTER_COUNT:
				add_child(_make_swirl_emitter(_vfx_tower_slot(i, VFX_UNIT_EMITTER_COUNT)))
		"scenario":
			# Escenario 2: "30 torretas maxeadas disparando junto" (frase
			# textual de docs-torretas-diseno.md) con VARIOS efectos VFX
			# candidatos a la vez, no uno solo aislado — 20 emisores de
			# partículas (Gravedad/Enjambre) + 10 capas de overdraw
			# (Fuego/Veneno) simultáneas, sumando las 30.
			for i in VFX_SCENARIO_EMITTER_COUNT:
				add_child(_make_swirl_emitter(_vfx_tower_slot(i, VFX_SCENARIO_EMITTER_COUNT)))
			var overdraw_pos := _vfx_tower_slot(0, 1)
			for i in VFX_SCENARIO_OVERDRAW_COUNT:
				add_child(_make_overdraw_layer(overdraw_pos))
		"overdraw":
			# Escenario 3: overdraw dirigido — N capas translúcidas
			# superpuestas EN EL MISMO PUNTO (peor caso real, no disperso),
			# arrancando en el mismo tope que ya usaba ZONE_FIXED_COUNT (10)
			# y una corrida por encima (vfx-count=25) para saber cuánto
			# margen hay antes de que duela, tal como pide la sección 5.
			var n := _vfx_count_arg if _vfx_count_arg > 0 else VFX_OVERDRAW_BASE
			var pos := _vfx_tower_slot(0, 1)
			for i in n:
				add_child(_make_overdraw_layer(pos))
		"tint":
			# Escenario 4: corrida chica de control — Torreta del Caos,
			# un solo shader de tinte sobre una malla, para confirmar que
			# es barato y no necesita la misma cautela que 1-3.
			add_child(_make_tint_quad(_vfx_tower_slot(0, 1)))

## mode=vfx-scale — mismas stats reales que _setup_joint(), pero sin fijar
## un único objetivo: _levels queda en VFX_SCALE_ENEMY_LEVELS para que el
## barrido genérico de _process() (el mismo que ya usan mode=enemies/
## towers/projectiles) avance de escalón en escalón por level-duration.
func _setup_vfx_scale() -> void:
	TowerStore.DEV_RANGE_OVERRIDE = 0.0
	TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
	_levels = VFX_SCALE_ENEMY_LEVELS

## "Torres normales" (tipos 0-3) — mismo top-up incremental que _ensure_towers(),
## pero sin ciclar por los 8 tipos: mode=vfx-scale empieza conservador a
## propósito, sin la familia BEAM/riel/misil todavía.
func _ensure_towers_normales(target: int) -> void:
	var spawned := 0
	while _tower_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _tower_store.active_count
		var col := idx % 40
		var row := idx / 40
		var pos := Vector2(-620.0 + col * 26.0, -350.0 + row * 26.0)
		if _tower_store.spawn_typed(pos, idx % VFX_SCALE_TOWER_TYPES, _fixed_dir_for(pos)) == -1:
			break
		spawned += 1

## Agrega VFX proporcional al tamaño del escalón actual (solo si
## vfx-scale-fx=1) — mismos emisores/capas que _setup_vfx(), mismo ratio
## 20/24 partículas y 10/24 overdraw que ya midió mode=vfx=scenario, ahora
## repartido a lo largo de la rampa en vez de todo de una. Solo agrega la
## diferencia contra lo ya puesto — la población de VFX nunca baja, igual
## que enemigos/proyectiles/torres en este barrido.
func _sync_vfx_scale_fx(towers: int) -> void:
	if not _vfx_scale_fx:
		return
	var target_particles := int(round(towers * float(VFX_SCENARIO_EMITTER_COUNT) / float(JOINT_TOWER_TARGET * JOINT_MARGIN)))
	var target_overdraw := int(round(towers * float(VFX_SCENARIO_OVERDRAW_COUNT) / float(JOINT_TOWER_TARGET * JOINT_MARGIN)))
	var overdraw_pos := _vfx_tower_slot(0, 1)
	while _vfx_scale_particles_added < target_particles:
		add_child(_make_swirl_emitter(_vfx_tower_slot(_vfx_scale_particles_added, target_particles)))
		_vfx_scale_particles_added += 1
	while _vfx_scale_overdraw_added < target_overdraw:
		add_child(_make_overdraw_layer(overdraw_pos))
		_vfx_scale_overdraw_added += 1

## mode=targeting — 24 torres reales ×1.2, cadencia forzada, contra 2.400
## enemigos reales ×1.2 (mismo piso de siempre). No usa TowerSystem —
## _tick_targeting() abajo es una réplica mínima a propósito, para que la
## única diferencia entre targeting-variant=fixed y =nearest sea la línea
## que elige dirección, nada de la maquinaria alrededor.
func _setup_targeting() -> void:
	TowerStore.DEV_RANGE_OVERRIDE = 0.0
	TowerStore.DEV_FIRE_RATE_OVERRIDE = 0.0
	_joint_enemy_target = int(round(JOINT_ENEMY_TARGET * JOINT_MARGIN))
	_joint_proj_target = 0  # sin inyector sintético — solo lo que las torres disparan
	_joint_tower_target = TARGETING_TOWER_COUNT
	_levels = [_joint_enemy_target]

	_targeting_cooldowns.resize(TARGETING_TOWER_COUNT)
	for i in TARGETING_TOWER_COUNT:
		var col := i % 12
		var row := i / 12
		var pos := Vector2(-620.0 + col * 40.0, -350.0 + row * 40.0)
		_tower_store.spawn(pos, 99999.0, TARGETING_FIRE_INTERVAL, TARGETING_PROJ_DAMAGE, 0)
		_targeting_cooldowns[i] = randf() * TARGETING_FIRE_INTERVAL  # desfasa el primer disparo entre torres

## targeting-variant=fixed: dirección constante, cero búsqueda.
## targeting-variant=nearest: TowerSystem._find_nearest_enemy() — el mismo
## brute-force O(enemy_store.active_count) que usa el juego real hoy para
## los tipos que spawnean proyectil.
func _tick_targeting(delta: float) -> void:
	var fixed_variant := _targeting_variant_arg == "fixed"
	for i in TARGETING_TOWER_COUNT:
		_targeting_cooldowns[i] -= delta
		if _targeting_cooldowns[i] > 0.0:
			continue
		_targeting_cooldowns[i] = TARGETING_FIRE_INTERVAL

		var pos := _tower_store.positions[i]
		var dir: Vector2
		if fixed_variant:
			dir = Vector2(-1.0, 0.0)
		else:
			var target := _tower_system._find_nearest_enemy(pos, 99999.0)
			if target == -1:
				continue
			dir = (_enemy_store.positions[target] - pos).normalized()

		_proj_store.spawn(pos, dir * TARGETING_PROJ_SPEED, TARGETING_PROJ_LIFE, TARGETING_PROJ_DAMAGE, ProjectileSystem.PROJ_STRAIGHT)

## Reparte N puntos a lo largo de la fila de torres del benchmark conjunto
## (mismo layout que _ensure_towers()) — para que los emisores de VFX estén
## donde estarían las torres reales, no amontonados en un solo punto salvo
## que el escenario lo pida a propósito (overdraw).
func _vfx_tower_slot(i: int, total: int) -> Vector2:
	var col := i % 40
	var row := i / 40
	return Vector2(-620.0 + col * 26.0, -260.0 - row * 26.0)

func _get_particle_tex() -> ImageTexture:
	if _vfx_particle_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 1.0))
		_vfx_particle_tex = ImageTexture.create_from_image(img)
	return _vfx_particle_tex

func _get_overdraw_tex() -> ImageTexture:
	if _vfx_overdraw_tex == null:
		var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 1.0))
		_vfx_overdraw_tex = ImageTexture.create_from_image(img)
	return _vfx_overdraw_tex

## "Remolino de partículas siendo absorbidas" (Gravedad, #15) — órbita
## alrededor del punto de emisión en vez de dispersión radial simple, para
## que el patrón de movimiento sea el que de verdad estresa el compute de
## partículas (no solo el conteo/overdraw, que ya mide el escenario 3).
func _make_swirl_emitter(pos: Vector2) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 36.0
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.orbit_velocity_min = 0.6
	mat.orbit_velocity_max = 1.4
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	mat.color = Color(0.65, 0.35, 0.85, 0.85)
	p.process_material = mat
	p.texture = _get_particle_tex()
	p.amount = VFX_SWARM_AMOUNT
	p.lifetime = VFX_SWARM_LIFETIME
	p.position = pos
	p.emitting = true
	return p

## Capa translúcida superpuesta (Fuego/Veneno, #11/#13 — "humo negro
## acumulado" / "nube tóxica") — un Sprite2D semitransparente es el caso de
## overdraw puro: cada capa extra es un blend adicional por píxel cubierto,
## sin partículas de por medio (eso ya lo mide "unit"/"scenario").
func _make_overdraw_layer(pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _get_overdraw_tex()
	s.position = pos
	s.modulate = Color(1.0, 0.35, 0.05, 0.35)
	return s

## Torreta del Caos (#20) — un shader de modulación de color sobre una sola
## malla, en vez de 19 variantes de sprite pre-coloreadas. _vfx_tint_material
## queda guardado para que _process() anime hue_shift — "recicla el color...
## en cada disparo" es continuo, no un solo frame.
func _make_tint_quad(pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _get_overdraw_tex()
	s.position = pos
	_vfx_tint_material = ShaderMaterial.new()
	_vfx_tint_material.shader = load("res://render/chaos_tint.gdshader")
	s.material = _vfx_tint_material
	return s

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"mode":
				_mode = parts[1]
			"proj-type":
				_proj_type_arg = parts[1]
			"tower-type":
				_tower_type_arg = parts[1].to_int()
			"backend":
				_backend_arg = parts[1]
			"level-duration":
				_level_duration = parts[1].to_float()
			"hold-at-peak":
				_hold_at_peak = parts[1].to_float()
			"sprite":
				_sprite_arg = parts[1] == "1"
			"tower-cycle":
				_tower_cycle_modulo = parts[1].to_int()
			"joint-enemies":
				_joint_enemy_override = parts[1].to_int()
			"joint-towers":
				_joint_tower_override = parts[1].to_int()
			"vfx-test":
				_vfx_test_arg = parts[1]
			"vfx-count":
				_vfx_count_arg = parts[1].to_int()
			"vfx-scale-fx":
				_vfx_scale_fx = parts[1] == "1"
			"targeting-variant":
				_targeting_variant_arg = parts[1]
			"tower-sprite-test":
				_tower_sprite_test_arg = parts[1] == "1"
			"no-screenshot":
				_no_screenshot_arg = parts[1] == "1"

func _current_target() -> int:
	return _levels[_level_idx]

func _at_final_level() -> bool:
	return _level_idx >= _levels.size() - 1

func _random_point_in_path() -> Vector2:
	var r: Rect2 = _level.path_rects[randi() % _level.path_rects.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func _resolve_proj_type() -> int:
	if _proj_type_arg == "realistic":
		return _weighted_proj_type()
	if _proj_type_arg == "mixed":
		return randi() % 4
	return _proj_type_arg.to_int()

func _weighted_proj_type() -> int:
	var total := 0
	for w in REALISTIC_PROJ_WEIGHTS:
		total += w
	var roll := randi() % total
	var acc := 0
	for t in REALISTIC_PROJ_WEIGHTS.size():
		acc += REALISTIC_PROJ_WEIGHTS[t]
		if roll < acc:
			return t
	return 0

func _top_up_enemies(target: int, health: float) -> void:
	var spawned := 0
	while _enemy_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _enemy_store.spawn(_random_point_in_path(), ENEMY_SPEED, health, 0.0, 0)
		if idx == -1:
			break
		_enemy_store.waypoint_index[idx] = 0
		spawned += 1

func _top_up_projectiles(target: int) -> void:
	var spawned := 0
	while _proj_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var pos := _random_point_in_path()
		var dir := Vector2.from_angle(randf() * TAU)
		var speed := randf_range(250.0, 450.0)
		var ptype := _resolve_proj_type()
		var hits := 3 if ptype == ProjectileSystem.PROJ_PIERCE else 1
		var homing_target := -1
		if ptype == ProjectileSystem.PROJ_HOMING and _enemy_store.active_count > 0:
			homing_target = randi() % _enemy_store.active_count
		var radius := 0.0
		if ptype == ProjectileSystem.PROJ_SPLASH:
			radius = 42.0
		elif ptype == ProjectileSystem.PROJ_ZONE:
			radius = 60.0
		var life := 2.0 if ptype != ProjectileSystem.PROJ_ZONE else 3.0
		var idx := _proj_store.spawn(pos, dir * speed, life, 5.0, ptype, hits, homing_target, radius)
		if idx == -1:
			break
		if ptype == ProjectileSystem.PROJ_MISSILE:
			_proj_store.set_trajectory(idx, pos, pos + dir * randf_range(150.0, 400.0), life)
		spawned += 1

## Sostiene un puñado fijo de zonas activas (no escala con el objetivo de
## proyectiles) — ver nota en ZONE_FIXED_COUNT.
func _top_up_zones() -> void:
	var active := 0
	for i in _proj_store.active_count:
		if _proj_store.type_id[i] == ProjectileSystem.PROJ_ZONE:
			active += 1
	var spawned := 0
	while active + spawned < ZONE_FIXED_COUNT and spawned < 5:
		var pos := _random_point_in_path()
		if _proj_store.spawn(pos, Vector2.ZERO, 3.0, 5.0, ProjectileSystem.PROJ_ZONE, 1, -1, 60.0) == -1:
			break
		spawned += 1

## Mismo criterio que level_controller.gd::_place_tower() (09-ago,
## plan-fases.md) — sin esto, las filas con uses_targeting=false (recto/
## perforante/splash) spawnearían con fixed_dir=ZERO por default, es decir
## proyectiles con velocidad cero, inmóviles. Habría roto en silencio todo
## número de proj_count/fps ya medido con mode=joint desde hace varias
## secciones — se aplica acá también, no solo en la pantalla jugable.
func _fixed_dir_for(pos: Vector2) -> Vector2:
	var dir := (_level.nearest_point_on_path(pos) - pos).normalized()
	return dir if not dir.is_zero_approx() else Vector2.LEFT

func _ensure_towers(target: int, cycle_types: bool = false) -> void:
	var spawned := 0
	while _tower_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var idx := _tower_store.active_count
		var col := idx % 40
		var row := idx / 40
		var pos := Vector2(-620.0 + col * 26.0, -350.0 + row * 26.0)
		var t := (idx % _tower_cycle_modulo) if cycle_types else _tower_type_arg
		if _tower_store.spawn_typed(pos, t, _fixed_dir_for(pos)) == -1:
			break
		spawned += 1

func _process(delta: float) -> void:
	if _quitting:
		return
	_elapsed += delta

	if _mode == "joint" or _mode == "vfx":
		_top_up_enemies(_joint_enemy_target, FIXED_ENEMY_HEALTH)
		_top_up_projectiles(_joint_proj_target)
		_top_up_zones()
		_ensure_towers(_joint_tower_target, true)
		if _vfx_tint_material:
			_vfx_tint_material.set_shader_parameter("hue_shift", fmod(_elapsed * 0.3, 1.0))
	elif _mode == "targeting":
		_top_up_enemies(_joint_enemy_target, FIXED_ENEMY_HEALTH)
		_tick_targeting(delta)
	else:
		_level_timer += delta
		if _level_timer >= _level_duration and not _at_final_level():
			_level_idx += 1
			_level_timer = 0.0

		match _mode:
			"enemies":
				_top_up_enemies(_current_target(), FIXED_ENEMY_HEALTH)
			"projectiles":
				_top_up_enemies(FIXED_ENEMY_POP, FIXED_ENEMY_HEALTH)
				_top_up_projectiles(_current_target())
			"towers":
				_top_up_enemies(FIXED_ENEMY_POP, FIXED_ENEMY_HEALTH)
				_ensure_towers(_current_target())
			"vfx-scale":
				var scale_towers: int = VFX_SCALE_TOWER_LEVELS[_level_idx]
				_top_up_enemies(_current_target(), FIXED_ENEMY_HEALTH)
				_top_up_projectiles(int(round(_current_target() * VFX_SCALE_PROJ_RATIO)))
				_ensure_towers_normales(scale_towers)
				_sync_vfx_scale_fx(scale_towers)

	_lane_system.tick(delta)
	_hash.build(_enemy_store)
	if _backend_arg == "native":
		_proj_system.tick_native(delta)
	else:
		_proj_system.tick(delta)
	if _mode == "towers" or _mode == "joint" or _mode == "vfx" or _mode == "vfx-scale":
		_tower_system.tick(delta)
	_dot_system.tick(delta)

	if _sprite_arg and _mode == "enemies":
		_enemy_render.advance_animation(delta)
	_enemy_render.sync(_enemy_store.positions, _enemy_store.active_count)
	_proj_render.sync(_proj_store.positions, _proj_store.active_count, _proj_store.type_id)
	if _tower_render_typed:
		_tower_render_typed.sync(_tower_store.positions, _tower_store.type_id, _tower_store.active_count)
	else:
		_tower_render.sync(_tower_store.positions, _tower_store.active_count, _tower_store.type_id)

	_logger.tick(delta, _proj_store.active_count, _enemy_store.active_count)
	_maybe_screenshot()

	if _mode == "joint" or _mode == "vfx" or _mode == "targeting":
		if not _joint_ramped:
			if _enemy_store.active_count >= int(_joint_enemy_target * 0.95) and _proj_store.active_count >= int(_joint_proj_target * 0.9) and _tower_store.active_count >= _joint_tower_target:
				_joint_ramped = true
		if _joint_ramped:
			_hold_timer += delta
			if _hold_timer >= _hold_at_peak:
				_finish()
		return

	if _at_final_level():
		_hold_timer += delta
		if _hold_timer >= _hold_at_peak:
			_finish()

func _maybe_screenshot() -> void:
	if DisplayServer.get_name() == "headless" or _no_screenshot_arg:
		return
	for t in _shot_times:
		if _elapsed >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			var img := get_viewport().get_texture().get_image()
			var shot_tag := _mode
			if _mode == "vfx":
				shot_tag = _mode + "_" + _vfx_test_arg
			elif _mode == "vfx-scale":
				shot_tag = _mode + ("_fx" if _vfx_scale_fx else "_base")
			var path := "res://benchmark_results/stress_%s_t%d.png" % [shot_tag, int(t)]
			img.save_png(path)
			print("[stress] screenshot: ", path)

func _finish() -> void:
	_quitting = true
	_logger.close()
	var final_target = _joint_enemy_target if _mode == "targeting" else (_joint_proj_target if (_mode == "joint" or _mode == "vfx") else _levels[_level_idx])
	print("[stress] listo — modo=%s vfx-test=%s backend=%s nivel_final=%d proy=%d enem=%d torres=%d" % [_mode, _vfx_test_arg, _backend_arg, final_target, _proj_store.active_count, _enemy_store.active_count, _tower_store.active_count])
	get_tree().quit()

func _draw() -> void:
	for r in _level.path_rects:
		draw_rect(r, Color(0.29, 0.42, 0.22, 1.0))
	for r in _level.buildable_zones:
		draw_rect(r, Color(0.35, 0.35, 0.37, 1.0))

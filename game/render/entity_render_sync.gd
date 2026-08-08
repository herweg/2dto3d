class_name EntityRenderSync
extends RefCounted

## Un solo multimesh_set_buffer() por grupo visual y por frame — ver
## directorsuggestions.md 2.3. Nada de set_instance_transform_2d() en loop
## (eso es lo que hace hoy POC/scripts/enemy_renderer.gd y lo que este
## patrón reemplaza).

const STRIDE_2D := 8        # Transform2D empaquetado: 8 floats
const STRIDE_2D_COLOR := 12 # + color RGBA (4 floats) — ver set_type_colors()

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance2D
var _buffer: PackedFloat32Array
var _capacity: int
var _stride: int = STRIDE_2D
var _type_colors: Array = []  # vacío = un solo color (modulate), como siempre

## Animación por swap de textura completa (Fase 2 — gráficos y animación).
## No es UV por instancia — es la versión más barata de animar, a medir
## contra el color plano antes de invertir en un shader de atlas
## per-instance. Mutuamente excluyente con set_type_colors() por ahora.
var _idle_tex: Texture2D
var _walk_tex: Texture2D
var _anim_interval: float = 0.2
var _anim_timer: float = 0.0
var _anim_frame: int = 0

func _init(p_capacity: int, quad_size: float, color: Color) -> void:
	_capacity = p_capacity

	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = false
	_multimesh.use_custom_data = false
	_multimesh.mesh = quad
	_multimesh.instance_count = p_capacity
	_multimesh.visible_instance_count = 0

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _multimesh
	_mmi.modulate = color

	_buffer.resize(p_capacity * _stride)

func get_node2d() -> MultiMeshInstance2D:
	return _mmi

## Habilita color por-instancia según type_id (Fase 2 — distinguir tipos de
## torre/proyectil sin arte todavía). Quien no llame esto sigue exactamente
## igual que en el spike: un solo color de grupo vía `modulate`.
func set_type_colors(colors: Array) -> void:
	_type_colors = colors
	# Godot exige instance_count == 0 para poder tocar use_colors.
	_multimesh.instance_count = 0
	_multimesh.use_colors = true
	_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = 0
	_stride = STRIDE_2D_COLOR
	_buffer.resize(_capacity * _stride)
	_mmi.modulate = Color.WHITE

## Asigna los dos frames de animación (idle/caminar) — un solo texture por
## store, no por instancia. Reemplaza el modulate de color plano.
func set_sprite(idle: Texture2D, walk: Texture2D, interval: float = 0.2) -> void:
	_idle_tex = idle
	_walk_tex = walk
	_anim_interval = interval
	_anim_timer = 0.0
	_anim_frame = 0
	_mmi.modulate = Color.WHITE
	_mmi.texture = idle

## Una llamada por store por frame (no por instancia): swap de
## `_mmi.texture` cada `interval` segundos. Godot dibuja todas las
## instancias del MultiMesh con la textura vigente del nodo — el costo no
## escala con la cantidad de instancias.
func advance_animation(delta: float) -> void:
	if _idle_tex == null:
		return
	_anim_timer += delta
	if _anim_timer >= _anim_interval:
		_anim_timer = 0.0
		_anim_frame = 1 - _anim_frame
		_mmi.texture = _walk_tex if _anim_frame == 1 else _idle_tex

## Empaqueta positions[0..count) (+ color por type_ids, si se llamó
## set_type_colors) en el buffer plano y hace una sola escritura a
## RenderingServer. Sin rotación/escala por ahora.
func sync(positions: PackedVector2Array, count: int, type_ids: PackedInt32Array = PackedInt32Array()) -> void:
	if count > _capacity:
		count = _capacity
	var has_colors := _type_colors.size() > 0

	for i in count:
		var p := positions[i]
		var o := i * _stride
		_buffer[o] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = p.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = p.y
		if has_colors:
			var c: Color = _type_colors[type_ids[i] % _type_colors.size()]
			_buffer[o + 8] = c.r
			_buffer[o + 9] = c.g
			_buffer[o + 10] = c.b
			_buffer[o + 11] = c.a

	_multimesh.visible_instance_count = count
	RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _buffer)

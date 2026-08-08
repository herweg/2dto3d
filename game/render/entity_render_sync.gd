class_name EntityRenderSync
extends RefCounted

## Un solo multimesh_set_buffer() por grupo visual y por frame — ver
## directorsuggestions.md 2.3. Nada de set_instance_transform_2d() en loop
## (eso es lo que hace hoy POC/scripts/enemy_renderer.gd y lo que este
## patrón reemplaza).

const STRIDE_2D := 8  # Transform2D empaquetado: 8 floats, sin color/custom data

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance2D
var _buffer: PackedFloat32Array
var _capacity: int

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

	_buffer.resize(p_capacity * STRIDE_2D)

func get_node2d() -> MultiMeshInstance2D:
	return _mmi

## Empaqueta positions[0..count) en el buffer plano y hace una sola
## escritura a RenderingServer. Sin rotación/escala por ahora — el caso
## sintético no la necesita.
func sync(positions: PackedVector2Array, count: int) -> void:
	if count > _capacity:
		count = _capacity

	for i in count:
		var p := positions[i]
		var o := i * STRIDE_2D
		_buffer[o] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = p.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = p.y

	_multimesh.visible_instance_count = count
	RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _buffer)

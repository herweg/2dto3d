class_name EntityRenderSync
extends RefCounted

## Sincroniza un store de entidades (posiciones Vector2 puras, ver
## sim/) contra un MultiMeshInstance3D — un solo
## multimesh_set_buffer() por grupo por frame, nunca set_instance_transform()
## en loop. Formato TRANSFORM_3D (12 floats por instancia — 3 filas de la
## matriz básica + origen, el mismo layout que arma Transform3D internamente).
##
## Mapeo de coordenadas fijo para todo el puente de render (decisión de una
## sola línea, consistente en todo el puente — ver versionado.md): X sim →
## X 3D, Y sim → Z 3D, altura fija en `height`.
##
## Sin rotación por instancia todavía (mismo alcance que el placeholder de
## proyectiles) — deuda conocida, ver versionado.md.

const STRIDE_3D := 12
const STRIDE_3D_COLOR := 16  # + color RGBA (4 floats) — ver set_type_colors()

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance3D
var _buffer: PackedFloat32Array
var _capacity: int
var _height: float
var _scale: float
var _stride: int = STRIDE_3D
var _type_colors: Array = []  # vacío = sin tinte por instancia (material tal cual)

## `p_scale`: factor uniforme aplicado a la malla, aparte de cualquier fix
## de escala propio del asset (ver monster_m5.glb). Necesario porque el
## mapeo de coordenadas (X sim → X 3D, Y sim → Z 3D) deja las mallas en
## escala "real" (~1-2 unidades) dentro de un mundo en unidades de sim
## (cientos/miles, ej. obstacle_radius=22, TOWER_MIN_SPACING=48) —
## descubierto por captura real (ver versionado.md): sin este factor,
## torres/proyectiles quedan del tamaño de un píxel, invisibles a la
## distancia de cámara del nivel.
func _init(p_capacity: int, mesh: Mesh, material: Material, p_height: float = 0.0, p_scale: float = 1.0) -> void:
	_capacity = p_capacity
	_height = p_height
	_scale = p_scale

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = false
	_multimesh.use_custom_data = false
	_multimesh.mesh = mesh
	_multimesh.instance_count = p_capacity
	_multimesh.visible_instance_count = 0

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _multimesh
	if material:
		_mmi.material_override = material

	_buffer.resize(p_capacity * _stride)

func get_node3d() -> MultiMeshInstance3D:
	return _mmi

## Color por-instancia según type_id — para proyectiles, que no necesitan
## sprite/malla distinta por tipo, solo distinguirse a simple vista, así
## que no necesitan un MultiMesh separado por tipo como sí necesitan las
## torres vía TypedRenderGroup. El material asignado debe tener
## `vertex_color_use_as_albedo = true` para que el tinte por instancia se
## vea — responsabilidad de quien arma el material, no de esta clase.
func set_type_colors(colors: Array) -> void:
	_type_colors = colors
	_multimesh.instance_count = 0
	_multimesh.use_colors = true
	_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = 0
	_stride = STRIDE_3D_COLOR
	_buffer.resize(_capacity * _stride)

## Empaqueta positions[0..count) (Vector2: x=X sim, y=Y sim) en el buffer
## plano y hace una sola escritura a RenderingServer. Escala/rotación
## identidad — ver nota de arriba. `type_ids` solo se usa si se llamó
## set_type_colors().
func sync(positions: PackedVector2Array, count: int, type_ids: PackedInt32Array = PackedInt32Array()) -> void:
	if count > _capacity:
		count = _capacity
	var has_colors := _type_colors.size() > 0
	for i in count:
		var p := positions[i]
		var o := i * _stride
		_buffer[o] = _scale
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = p.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = _scale
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = _height
		_buffer[o + 8] = 0.0
		_buffer[o + 9] = 0.0
		_buffer[o + 10] = _scale
		_buffer[o + 11] = p.y
		if has_colors:
			var c: Color = _type_colors[type_ids[i] % _type_colors.size()]
			_buffer[o + 12] = c.r
			_buffer[o + 13] = c.g
			_buffer[o + 14] = c.b
			_buffer[o + 15] = c.a

	_multimesh.visible_instance_count = count
	RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _buffer)

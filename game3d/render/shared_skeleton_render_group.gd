class_name SharedSkeletonRenderGroup
extends RefCounted

## Grupo animado (enemigos) del puente de render 3D — extraído/
## refactorizado de poc_3d_bench.gd::_spawn_shared_skeleton_group() a una
## clase reusable (fase-3d-tarjetas-pantallas-v1.md sección 1, "no copy-
## paste del script de investigación"). MultiMeshInstance3D no anima huesos
## por-instancia (confirmado — pivot-3d-poc-v1.md sección 3); esqueleto
## compartido es la técnica que cierra ese gap (sección 4 del mismo doc,
## 18,53ms → 7,14ms en el escenario oficial): `num_masters` Skeleton3D
## "maestros" completos (con su propio AnimationPlayer, fases repartidas)
## más el resto como MeshInstance3D livianos (mismo mesh/skin del maestro)
## cuyo `skeleton` (NodePath) apunta a uno de los maestros por round-robin
## — la pose se comparte, la posición no.
##
## Diferencia real con la POC, no solo refactor cosmético: allá la
## población era estática (una grilla armada una vez, `walk=1` movía los
## nodos con un stepper propio del script de investigación). Acá las
## entidades activas cambian cada frame (spawn/release de EnemyStore vía
## swap-remove) — por eso esta clase preasigna `capacity` nodos una sola
## vez (mismo espíritu de capacidad fija que EntityRenderSync, para no
## pagar el costo de crear/destruir nodos por spawn/release) y expone
## sync(positions, count) que reposiciona y muestra/oculta slots cada
## frame, en vez de poblar la escena una sola vez.
##
## Mapeo de coordenadas: mismo que el resto del puente — X sim → X 3D,
## Y sim → Z 3D, altura fija en `height`.

var _nodes: Array = []  # Node3D por slot (masters + clones), índice = slot
var _capacity: int
var _height: float

## `scene`: PackedScene del asset rigueado (ej. monster_m5.glb).
## `scale_fix`: escala a aplicar al instanciar (bug de escala del pipeline
## de origen — ver fase-3d-tarjetas-pantallas-v1.md sección 0, no corregir
## distinto de como ya lo hacía poc_3d_bench.gd).
## `num_masters`: cuántas instancias completas (con su propio
## Skeleton3D+AnimationPlayer) arman el resto de los clones livianos.
## `tex_variants`: 0 = sin variedad (todos con la textura original del
## asset); >0 reparte esa cantidad de PNG reales round-robin — mismo
## criterio que poc_3d_bench.gd::_apply_texture_variant(), opcional, no
## requerido por esta tarjeta (ya validado en la POC).
func _init(parent: Node, scene: PackedScene, p_capacity: int, num_masters: int, scale_fix: float, p_height: float = 0.0, tex_variants: int = 0) -> void:
	_capacity = p_capacity
	_height = p_height
	num_masters = clampi(num_masters, 1, p_capacity)

	var master_skeletons: Array = []
	var shared_mesh: Mesh = null
	var shared_skin: Skin = null
	var variant_cache: Dictionary = {}

	for m in num_masters:
		var inst := scene.instantiate()
		inst.scale = Vector3(scale_fix, scale_fix, scale_fix)
		parent.add_child(inst)
		var mesh_inst := _find_mesh_instance(inst)
		if mesh_inst:
			if shared_mesh == null:
				shared_mesh = mesh_inst.mesh
				shared_skin = mesh_inst.skin
			_apply_texture_variant(mesh_inst, m, tex_variants, variant_cache)
		var skel := _find_skeleton(inst)
		master_skeletons.append(skel)
		var ap := _find_animation_player(inst)
		if ap and ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])
			ap.seek(float(m) / float(num_masters) * ap.current_animation_length, true)
		inst.visible = false
		_nodes.append(inst)

	var clone_count: int = p_capacity - num_masters
	for n in clone_count:
		var mi := MeshInstance3D.new()
		mi.mesh = shared_mesh
		mi.skin = shared_skin
		mi.scale = Vector3(scale_fix, scale_fix, scale_fix)
		parent.add_child(mi)
		var master: Skeleton3D = master_skeletons[n % num_masters]
		if master:
			mi.skeleton = mi.get_path_to(master)
		_apply_texture_variant(mi, num_masters + n, tex_variants, variant_cache)
		mi.visible = false
		_nodes.append(mi)

## positions[0..count) → posición 3D de cada slot preasignado; el resto de
## la capacidad queda oculto (visible=false), no liberado — evita el costo
## de crear/destruir nodos por spawn/release, que es justo lo que esta
## técnica ya evita del lado de animación.
func sync(positions: PackedVector2Array, count: int) -> void:
	if count > _capacity:
		count = _capacity
	for i in _capacity:
		var node: Node3D = _nodes[i]
		if i < count:
			var p := positions[i]
			node.position = Vector3(p.x, _height, p.y)
			node.visible = true
		else:
			node.visible = false

func _apply_texture_variant(mesh_inst: MeshInstance3D, idx: int, tex_variants: int, cache: Dictionary) -> void:
	if tex_variants <= 0 or mesh_inst == null:
		return
	var variant_i: int = idx % tex_variants
	if cache.has(variant_i):
		mesh_inst.set_surface_override_material(0, cache[variant_i])
		return
	var base_mat := mesh_inst.get_active_material(0)
	if base_mat == null or not (base_mat is StandardMaterial3D):
		return
	var tex_path := "res://assets3d/monster/variants/variant_%02d.png" % variant_i
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	var mat: StandardMaterial3D = base_mat.duplicate()
	mat.albedo_texture = tex
	if mat.emission_enabled:
		mat.emission_texture = tex
	cache[variant_i] = mat
	mesh_inst.set_surface_override_material(0, mat)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

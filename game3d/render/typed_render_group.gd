class_name TypedRenderGroup
extends RefCounted

## Un MultiMesh no puede llevar material distinto por instancia, así que
## cada type_id necesita su propio EntityRenderSync/MultiMeshInstance3D.
## Usado para torres y proyectiles — sin animación, idénticos por tipo,
## mismo mesh base para todos los tipos (un solo asset real por categoría
## hoy — tower_m5.glb / cápsula placeholder) con un tinte de material por
## type_id para distinguirlos a simple vista (TYPE_COLORS).

var _stores: Array = []  # Array[EntityRenderSync], índice = type_id

## `num_types` fija cuántas sub-instancias existen (puede exceder la
## cantidad de filas usadas hoy en TOWER_TYPE_STATS, para no tocar este
## código cuando el catálogo crezca). `base_material` se duplica y tiñe
## (albedo_color, + emission si está
## habilitada — los materiales "emissive-boosted" de estos assets ignoran
## luz real de escena, ver versionado.md) por
## cada type_id según `tint_colors`; null en `base_material` deja el
## material que traiga la malla, sin tinte.
func _init(num_types: int, capacity_per_type: int, mesh: Mesh, base_material: Material, tint_colors: Array, height: float = 0.0, scale: float = 1.0) -> void:
	_stores.resize(num_types)
	for t in num_types:
		var mat: Material = null
		if base_material:
			mat = base_material.duplicate()
			if tint_colors.size() > 0 and mat is StandardMaterial3D:
				var c: Color = tint_colors[t % tint_colors.size()]
				mat.albedo_color = c
				if mat.emission_enabled:
					mat.emission = c
		_stores[t] = EntityRenderSync.new(capacity_per_type, mesh, mat, height, scale)

## Agrega el nodo de cada sub-store a `parent` — conveniencia para no
## iterar num_types veces en el llamador.
func add_all_to(parent: Node) -> void:
	for store in _stores:
		parent.add_child(store.get_node3d())

## Particiona positions[0..count) por type_ids[i] y hace un sync() por
## sub-store — población objetivo chica y acotada (torres/proyectiles de
## una pantalla jugable, no miles), la alocación por frame no es el costo
## que importa acá.
func sync(positions: PackedVector2Array, type_ids: PackedInt32Array, count: int) -> void:
	var scratch: Array = []
	scratch.resize(_stores.size())
	for t in scratch.size():
		scratch[t] = PackedVector2Array()

	for i in count:
		var t: int = type_ids[i]
		if t < 0 or t >= _stores.size():
			continue
		scratch[t].append(positions[i])

	for t in _stores.size():
		_stores[t].sync(scratch[t], scratch[t].size())

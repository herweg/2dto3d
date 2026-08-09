class_name TypedRenderGroup
extends RefCounted

## Tarjeta de motor confirmada por el director en respuesta a Dirección de
## Arte (docs/diseno-grafico.md sección 8, 08-ago): un MultiMesh no puede
## llevar una textura distinta por instancia, así que 20 torretas con
## sprite propio necesitan un EntityRenderSync por type_id, no uno
## compartido con tinte (que es todo lo que EntityRenderSync.sync() podía
## dar hasta ahora — ver set_type_colors() ahí). Este grupo enruta un
## sync() de grupo a la sub-instancia de cada type_id; el tipo que todavía
## no recibió sprite de Arte sigue viéndose con color plano (fallback), sin
## tocar nada del resto.

var _stores: Array = []  # Array[EntityRenderSync], índice = type_id

## `num_types` fija cuántas sub-instancias existen — puede ser mayor a la
## cantidad de filas usadas hoy en TOWER_TYPE_STATS, para no tener que
## tocar este código cuando el catálogo crezca de 8 a 20.
func _init(num_types: int, capacity_per_type: int, quad_size: float, fallback_colors: Array) -> void:
	_stores.resize(num_types)
	for t in num_types:
		var color: Color = fallback_colors[t % fallback_colors.size()]
		_stores[t] = EntityRenderSync.new(capacity_per_type, quad_size, color)

## Agrega el nodo de cada sub-store a `parent` — conveniencia para no
## iterar num_types veces en el llamador.
func add_all_to(parent: Node) -> void:
	for store in _stores:
		parent.add_child(store.get_node2d())

## Reemplaza el color plano de un type_id por sprite animado — el resto de
## los tipos no se ve afectado, cada uno es un store separado.
func set_sprite_for_type(type_id: int, idle: Texture2D, walk: Texture2D, interval: float = 0.2) -> void:
	_stores[type_id].set_sprite(idle, walk, interval)

## Mirror horizontal de un type_id — ver EntityRenderSync.set_flip_h(). Uso
## previsto: arte que viene preparado apuntando a la izquierda por
## convención, mostrado apuntando a la derecha sin pedir una segunda
## imagen. Estático por tipo, no por instancia — el click-and-drag de
## apuntado (futuro) va a necesitar flip por instancia, distinto de esto.
func set_flip_h_for_type(type_id: int, flip: bool) -> void:
	_stores[type_id].set_flip_h(flip)

## Particiona positions[0..count) por type_ids[i] y hace un sync() por
## sub-store. Asigna un PackedVector2Array por frame por type_id presente —
## a diferencia del hash espacial (docs/fase2-benchmark-conjunto.md), acá
## la población objetivo es chica y acotada (torres de una pantalla
## jugable, no miles), así que la alocación no es el costo que importa.
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

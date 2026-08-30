class_name EntityStore
extends RefCounted

## Store base SoA: arrays paralelos + free-list con swap-remove.
## Ver docs/directorsuggestions.md sección 2.1. Las subclases (ProjectileStore,
## EnemyStore) agregan sus propios arrays y sobrescriben _swap_extra().

var capacity: int = 0
var active_count: int = 0

var positions: PackedVector2Array
var type_id: PackedInt32Array

func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	type_id.resize(capacity)

func is_full() -> bool:
	return active_count >= capacity

func acquire() -> int:
	if is_full():
		return -1
	var idx := active_count
	active_count += 1
	return idx

## Swap-remove: la última entidad activa ocupa el slot liberado, así el loop
## principal siempre recorre 0..active_count sin visitar entradas muertas.
func release(idx: int) -> void:
	var last := active_count - 1
	if idx != last:
		positions[idx] = positions[last]
		type_id[idx] = type_id[last]
		_swap_extra(idx, last)
	active_count -= 1

func _swap_extra(_idx: int, _last: int) -> void:
	pass

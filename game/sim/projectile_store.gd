class_name ProjectileStore
extends EntityStore

var velocities: PackedVector2Array
var ttl: PackedFloat32Array
var damage: PackedFloat32Array

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	velocities.resize(p_capacity)
	ttl.resize(p_capacity)
	damage.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	velocities[idx] = velocities[last]
	ttl[idx] = ttl[last]
	damage[idx] = damage[last]

func spawn(pos: Vector2, vel: Vector2, life: float, dmg: float, variant: int) -> int:
	var idx := acquire()
	if idx == -1:
		return -1
	positions[idx] = pos
	type_id[idx] = variant
	velocities[idx] = vel
	ttl[idx] = life
	damage[idx] = dmg
	return idx

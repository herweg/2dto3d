class_name BurstVfxPool
extends RefCounted

## Pool de GPUParticles2D reusable para efectos "burst" — un tiro por
## evento, no continuos (explosión/chispa/muerte de
## fase3-vfx-exploracion-v1.md; la quemadura es continua, no usa esto — ver
## level_controller.gd). Geometría/color simple, no arte final, mismo
## criterio que ya usó fase2-vfx-benchmark.md
## (stress_main.gd::_make_swirl_emitter()).
##
## Nodos reusados en vez de crear/destruir por evento a propósito: a la
## frecuencia que puede tener "chispa" (cada golpe normal de recto/
## perforante/homing, el más frecuente de los 4), instanciar/liberar un
## GPUParticles2D por evento sería su propio costo de por sí — no el que
## esta tarjeta quiere medir. Round-robin simple: si el pool es chico para
## la frecuencia real, un emisor se reinicia antes de terminar su ráfaga
## anterior (`restart()` lo corta y arranca de nuevo) — visualmente se
## nota, no es un error ni afecta la medición de costo (el nodo existe y
## sigue emitiendo la misma cantidad de partículas).

var _emitters: Array = []
var _next := 0

func _init(parent: Node, pool_size: int, color: Color, amount: int = 12, lifetime: float = 0.4) -> void:
	var tex := _make_particle_tex()
	var mat := _make_material(color)
	for i in pool_size:
		var p := GPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = amount
		p.lifetime = lifetime
		p.explosiveness = 1.0
		p.texture = tex
		p.process_material = mat
		parent.add_child(p)
		_emitters.append(p)

func trigger(pos: Vector2) -> void:
	var p: GPUParticles2D = _emitters[_next]
	_next = (_next + 1) % _emitters.size()
	p.position = pos
	p.restart()
	p.emitting = true

func _make_particle_tex() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _make_material(color: Color) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	mat.color = color
	return mat

extends Node2D

const MAX_GEMS := 300

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance2D
var _pool_ref: Array = []
var _time: float = 0.0

func _ready() -> void:
	add_to_group("xp_gem_renderer")
	_build_multimesh()

func _build_multimesh() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in 8:
		for x in 8:
			if absf(x - 3.5) + absf(y - 3.5) <= 3.5:
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, 10.0)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = MAX_GEMS
	_multimesh.visible_instance_count = 0

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _multimesh
	_mmi.texture = tex
	add_child(_mmi)

func set_pool(pool_array: Array) -> void:
	_pool_ref = pool_array

func _process(delta: float) -> void:
	if _pool_ref.is_empty():
		return
	_time += delta
	var count := 0
	for gem in _pool_ref:
		if count >= MAX_GEMS:
			break
		if not gem.active:
			continue
		var bob := sin(_time * 5.0 + gem.global_position.x * 0.05) * 2.5
		_multimesh.set_instance_transform_2d(
			count,
			Transform2D(0.0, Vector2.ONE, 0.0, gem.global_position + Vector2(0.0, bob))
		)
		_multimesh.set_instance_color(count, Color(1.0, 0.85, 0.1, 1.0))
		count += 1
	_multimesh.visible_instance_count = count

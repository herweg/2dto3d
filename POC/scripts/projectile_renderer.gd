extends Node2D

const MAX_PROJ := 400

var _multimesh: MultiMesh
var _mmi: MultiMeshInstance2D
var _pool_ref: Array = []

func _ready() -> void:
	add_to_group("projectile_renderer")
	_build_multimesh()

func _build_multimesh() -> void:
	var tex := _make_bullet_texture()

	var quad := QuadMesh.new()
	quad.size = Vector2(14.0, 14.0)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = MAX_PROJ
	_multimesh.visible_instance_count = 0

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _multimesh
	_mmi.texture = tex
	add_child(_mmi)

func _make_bullet_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(8.0, 8.0)
	for y in 16:
		for x in 16:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if d <= 6.5:
				img.set_pixel(x, y, Color.WHITE)
			if d <= 2.5:
				img.set_pixel(x, y, Color(1.0, 1.0, 0.8, 1.0))
	return ImageTexture.create_from_image(img)

func set_pool(pool_array: Array) -> void:
	_pool_ref = pool_array

func _process(_delta: float) -> void:
	if _pool_ref.is_empty():
		return
	var count := 0
	for p in _pool_ref:
		if count >= MAX_PROJ:
			break
		if not p.active:
			continue
		_multimesh.set_instance_transform_2d(
			count,
			Transform2D(0.0, Vector2.ONE, 0.0, p.global_position)
		)
		_multimesh.set_instance_color(count, p.color)
		count += 1
	_multimesh.visible_instance_count = count

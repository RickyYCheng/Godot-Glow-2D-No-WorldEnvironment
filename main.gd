extends Node2D

func _process(delta: float) -> void:
	var unit = get_viewport_transform().x + get_viewport_transform().y
	print(unit)
	
	$CanvasLayer/Control/GlowProcess.get_material().set_shader_parameter("unit", unit)
	
	var x = Input.get_axis("ui_left", "ui_right")
	var y = Input.get_axis("ui_up", "ui_down")
	$Icon2.position += Vector2(x, y)
	if Input.is_action_pressed("ui_select"):
		$Icon2.rotation_degrees += 1
	pass

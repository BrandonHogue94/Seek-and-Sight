extends Button

func _on_pressed():
	get_tree().change_scene_to_file("res://Scenes/Cutscene 1/Scene/Cutscene1.tscn")
	print("Swapping Scene")
	

extends Node2D

# Game variables
var current_word = ""
var score = 0
var tower_blocks = []
var word_blocks = []
var used_words = []
var words_in_round = []
var total_words = 5
var is_dragging = false
var dragged_block = null
var original_positions = {}

# First grade sight words - only including words that have audio files available
var sight_words = [
	"a", "about", "after", "all", "an", "and", "are", "as", "at", "back", "be", "because",
	"the", "to", "said", "you", "it", "I", "have", "go", "not", "do", "can", "had", 
	"get", "with", "this", "will", "went", "came", "into", "from", "good", "too", 
	"when", "see", "him", "two"
]

# Audio file paths - you'll need to add these audio files to your project
var word_audio_files = {}

func _ready():
	initialize_game()
	setup_audio_system()
	# setup_accessibility_features()  # TODO: Enable when ready
	next_word()

func initialize_game():
	word_blocks = [
		$WordBlocksArea/WordBlock1,
		$WordBlocksArea/WordBlock2,
		$WordBlocksArea/WordBlock3,
		$WordBlocksArea/WordBlock4,
		$WordBlocksArea/WordBlock5
	]
	
	for block in word_blocks:
		original_positions[block] = block.global_position
	
	generate_round_words()
	
	$TowerArea/TowerDropZone.body_entered.connect(_on_tower_drop_zone_entered)
	$TowerArea/TowerDropZone.body_exited.connect(_on_tower_drop_zone_exited)

func generate_round_words():
	var shuffled_words = sight_words.duplicate()
	shuffled_words.shuffle()
	words_in_round = shuffled_words.slice(0, total_words)
	
	var screen_size = get_viewport().get_visible_rect().size
	var start_y = screen_size.y * 0.2
	var spacing = (screen_size.y * 0.6) / total_words
	
	for i in range(word_blocks.size()):
		if i < words_in_round.size():
			var word = words_in_round[i]
			var block = word_blocks[i]
			
			var label = block.get_node("WordBlockLabel" + str(i + 1))
			if label:
				label.text = word
			
			block.set_meta("word", word)
			block.position = Vector2(0, start_y + i * spacing)
			setup_word_block_interaction(block)

func setup_word_block_interaction(block):
	block.input_pickable = true
	block.monitoring = true
	block.monitorable = true
	
	var input_callable = func(viewport, event, shape_idx): 
		_handle_block_input(block, viewport, event, shape_idx)
	var hover_callable = func():
		_handle_block_hover(block)
	var unhover_callable = func():
		_handle_block_unhover(block)
	
	block.input_event.connect(input_callable)
	block.mouse_entered.connect(hover_callable)
	block.mouse_exited.connect(unhover_callable)

func setup_audio_system():
	$UI/AudioPanel/PlayButton.pressed.connect(_on_play_button_pressed)
	load_word_audio_files()

func load_word_audio_files():
	for word in sight_words:
		var audio_paths = [
			"res://Assets/Audio/Grade Level/" + word.to_upper() + ".wav",
			"res://Assets/Audio/Grade Level/" + word + ".wav",
			"res://Assets/Audio/Grade Level/" + word.capitalize() + ".wav"
		]
		
		var audio_loaded = false
		for audio_path in audio_paths:
			if ResourceLoader.exists(audio_path):
				word_audio_files[word] = load(audio_path)
				audio_loaded = true
				break
		
		if not audio_loaded:
			word_audio_files[word] = null

func next_word():
	if used_words.size() >= words_in_round.size():
		complete_game()
		return
	
	var available_words = words_in_round.filter(func(word): return word not in used_words)
	current_word = available_words[randi() % available_words.size()]
	
	$UI/AudioPanel/CurrentWordLabel.text = current_word
	update_instruction_text("Find and drag: \"" + current_word + "\"")
	play_word_audio(current_word)

func play_word_audio(word):
	if word in word_audio_files and word_audio_files[word] != null:
		$Audio/WordAudio.stream = word_audio_files[word]
		$Audio/WordAudio.play()
	else:
		use_text_to_speech(word)

func use_text_to_speech(word):
	# TODO: Implement TTS or custom audio fallback
	pass

func _on_play_button_pressed():
	play_word_audio(current_word)

func _handle_block_input(block, viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_word_used(block):
				return
			start_dragging(block)

func _handle_block_hover(block):
	if not is_dragging:
		block.scale = Vector2(1.1, 1.1)

func _handle_block_unhover(block):
	if not is_dragging:
		block.scale = Vector2(1.0, 1.0)

func start_dragging(block):
	is_dragging = true
	dragged_block = block
	
	if not original_positions.has(block):
		original_positions[block] = block.global_position
	
	block.modulate = Color.YELLOW
	block.z_index = 1000
	block.scale = Vector2(1.3, 1.3)
	update_instruction_text("Drag to the tower area!")

func stop_dragging():
	if not dragged_block:
		return
	
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var tower_center = Vector2(screen_size.x * 0.75, screen_size.y * 0.5)
	var tower_bounds = Rect2(tower_center - Vector2(200, 300), Vector2(400, 600))
	
	if tower_bounds.has_point(mouse_pos):
		check_word_match(dragged_block)
	else:
		return_to_start(dragged_block)
	
	dragged_block.modulate = Color.WHITE
	dragged_block.z_index = 0
	dragged_block.scale = Vector2(1.0, 1.0)
	
	is_dragging = false
	dragged_block = null

func check_word_match(block):
	var block_word = block.get_meta("word")
	
	if block_word == current_word:
		correct_match(block, block_word)
	else:
		wrong_match(block)

func correct_match(block, word):
	add_block_to_tower(word)
	score += 10
	$UI/AudioPanel/ScoreLabel.text = "Score: " + str(score)
	used_words.append(word)
	hide_word_block(block)
	$Audio/CorrectSound.play()
	show_feedback("Perfect! Great building!", false)
	await get_tree().create_timer(1.5).timeout
	next_word()

func wrong_match(block):
	$Audio/WrongSound.play()
	show_feedback("Try again! Listen carefully!", true)
	return_to_start(block)
	await get_tree().create_timer(1.0).timeout
	play_word_audio(current_word)

func add_block_to_tower(word):
	var tower_block = create_tower_block(word)
	var tower_container = $TowerArea/TowerBlocks
	
	var y_offset = -50 * tower_blocks.size()
	tower_block.position = Vector2(0, y_offset)
	
	tower_container.add_child(tower_block)
	tower_blocks.append(tower_block)
	
	tower_block.scale = Vector2(0, 0)
	var tween = create_tween()
	tween.tween_property(tower_block, "scale", Vector2(1, 1), 0.5)

func create_tower_block(word):
	var block_sprite = Sprite2D.new()
	block_sprite.texture = preload("res://Assets/EllieBlocks1.png")
	
	var scale_factor = 1.0 + (len(word) * 0.05)
	block_sprite.scale = Vector2(scale_factor, 0.6)
	
	var label = Label.new()
	label.text = word
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-80, -20)
	label.size = Vector2(160, 40)
	label.add_theme_color_override("font_color", Color(0.243137, 0.145098, 0.062745, 1))
	
	var font_path = "res://Assets/Chewy-Regular.ttf"
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", 24)
	
	block_sprite.add_child(label)
	
	return block_sprite

func hide_word_block(block):
	var tween = create_tween()
	tween.parallel().tween_property(block, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(block, "scale", Vector2(0.5, 0.5), 0.5)

func return_to_start(block):
	var original_pos = original_positions[block]
	var tween = create_tween()
	tween.tween_property(block, "global_position", original_pos, 0.5)

func show_feedback(message, is_error):
	update_instruction_text(message)
	# TODO: Add additional visual feedback like particles or screen shake if desired

func update_instruction_text(text):
	$UI/InstructionBubble/InstructionText.text = text

func is_word_used(block):
	var word = block.get_meta("word")
	return word in used_words

func complete_game():
	show_feedback("AMAZING WORK! Tower Complete!", false)
	update_instruction_text("Outstanding! You built an amazing tower!\nReady for the next challenge?")
	$UI/NavButtons/NextButton.disabled = false
	$UI/NavButtons/NextButton.text = "Amazing! Next →"

func _process(delta):
	if is_dragging and dragged_block:
		dragged_block.global_position = get_global_mouse_position()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				stop_dragging()

func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("setup_responsive_layout")

func _on_tower_drop_zone_entered(body):
	$TowerArea/TowerDropZone.modulate = Color(0.5, 1.0, 0.5, 0.5)

func _on_tower_drop_zone_exited(body):
	$TowerArea/TowerDropZone.modulate = Color.WHITE

func _on_back_button_pressed():
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").go_to_main_menu()

func _on_next_button_pressed():
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").complete_scene(1, score)
		get_node("/root/SceneManager").go_to_scene2()

func reset_game():
	score = 0
	tower_blocks.clear()
	used_words.clear()
	current_word = ""
	
	for child in $TowerArea/TowerBlocks.get_children():
		child.queue_free()
	
	for block in word_blocks:
		block.modulate = Color.WHITE
		block.scale = Vector2(1.0, 1.0)
		block.global_position = original_positions[block]
	
	$UI/AudioPanel/ScoreLabel.text = "Score: 0"
	$UI/AudioPanel/CurrentWordLabel.text = "Click Play!"
	$UI/NavButtons/NextButton.disabled = true
	$UI/NavButtons/NextButton.text = "Next →"
	
	generate_round_words()
	next_word()

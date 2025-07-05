# Scene3_ToolMatch.gd - Cleaned and Simplified Version
# Attach this script to the Scene3_ToolMatch root node

extends Node2D

var is_dragging = false
var dragged_tool = null
var original_tool_positions = {}
var matches_made = 0
var total_matches = 4
var matched_pairs = {}

func _ready():
	store_original_positions()
	setup_tools()

func store_original_positions():
	var tools = [
		$ToolArea/HammerSlot,
		$ToolArea/WrenchSlot,
		$ToolArea/ScrewdriverSlot,
		$ToolArea/SawSlot
	]
	
	for tool in tools:
		if tool:
			original_tool_positions[tool] = tool.global_position

func setup_tools():
	var tools = [
		$ToolArea/HammerSlot,
		$ToolArea/WrenchSlot,
		$ToolArea/ScrewdriverSlot,
		$ToolArea/SawSlot
	]
	
	for tool in tools:
		if tool:
			tool.input_event.connect(_on_tool_input_event)
			tool.mouse_entered.connect(_on_tool_hover.bind(tool))
			tool.mouse_exited.connect(_on_tool_unhover.bind(tool))

func _on_tool_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			var clicked_tool = find_tool_at_position(mouse_pos)
			if clicked_tool:
				start_dragging(clicked_tool)
		else:
			stop_dragging()

func find_tool_at_position(pos):
	var tools = [
		$ToolArea/HammerSlot,
		$ToolArea/WrenchSlot,
		$ToolArea/ScrewdriverSlot,
		$ToolArea/SawSlot
	]
	
	for tool in tools:
		if tool and pos.distance_to(tool.global_position) < 100:
			return tool
	return null

func _on_tool_hover(tool):
	if not is_dragging and not is_tool_matched(tool):
		var tween = create_tween()
		tween.tween_property(tool, "scale", Vector2(1.2, 1.2), 0.1)

func _on_tool_unhover(tool):
	if not is_dragging:
		var tween = create_tween()
		tween.tween_property(tool, "scale", Vector2(1.0, 1.0), 0.1)

func start_dragging(tool):
	if is_tool_matched(tool):
		return
		
	is_dragging = true
	dragged_tool = tool
	
	tool.modulate = Color.YELLOW
	tool.z_index = 100
	tool.scale = Vector2(1.3, 1.3)

func stop_dragging():
	if not dragged_tool:
		return
		
	var mouse_pos = get_global_mouse_position()
	var word_block = find_word_block_at_position(mouse_pos)
	
	if word_block:
		check_match(dragged_tool, word_block)
	else:
		return_to_start(dragged_tool)
	
	# Reset visual state
	dragged_tool.modulate = Color.WHITE
	dragged_tool.z_index = 0
	dragged_tool.scale = Vector2(1.0, 1.0)
	
	is_dragging = false
	dragged_tool = null

func find_word_block_at_position(pos):
	var word_blocks = [
		$WordArea/WordBlock_Hammer,
		$WordArea/WordBlock_Wrench,
		$WordArea/WordBlock_Screwdriver,
		$WordArea/WordBlock_Saw
	]
	
	for word_block in word_blocks:
		if word_block and pos.distance_to(word_block.global_position) < 100:
			return word_block
	return null

func check_match(tool, word_block):
	var tool_name = get_tool_name(tool)
	var word_name = get_word_name(word_block)
	
	if tool_name == word_name:
		create_successful_match(tool, word_block)
	else:
		show_feedback("Try again! " + tool_name.capitalize() + " doesn't match " + word_name.capitalize())
		return_to_start(tool)

func create_successful_match(tool, word_block):
	# Hide the tool with a nice fade effect instead of repositioning
	var tween = create_tween()
	tween.parallel().tween_property(tool, "modulate:a", 0.0, 0.5)  # Fade out
	tween.parallel().tween_property(tool, "scale", Vector2(0.5, 0.5), 0.5)  # Shrink
	
	# Highlight the matched word block with success color
	var word_sprite = word_block.get_node_or_null("BlockSprite")
	var word_text = word_block.get_node_or_null("WordText")
	
	if word_sprite:
		word_sprite.modulate = Color(0.7, 1.0, 0.7, 1)  # Success green
	
	if word_text:
		# Make the text bolder and more visible
		word_text.modulate = Color(0.2, 0.6, 0.2, 1)  # Dark green
		word_text.add_theme_color_override("font_shadow_color", Color.WHITE)
		word_text.add_theme_constant_override("shadow_offset_x", 2)
		word_text.add_theme_constant_override("shadow_offset_y", 2)
	
	# Mark as matched
	var tool_name = get_tool_name(tool)
	matched_pairs[tool_name] = word_block
	matches_made += 1
	
	if matches_made >= total_matches:
		complete_all_matches()
	else:
		show_feedback("Perfect match! Well done!")

func complete_all_matches():
	show_feedback("OUTSTANDING WORK!\nYou're an amazing engineer!\nReady for your next challenge?")
	
	# Enable next button
	if has_node("UI/NavButtons/NextButton"):
		var next_button = $UI/NavButtons/NextButton
		next_button.disabled = false
		next_button.text = "Amazing! Next →"

func show_feedback(message):
	var instruction_text = get_node_or_null("UI/InstructionBubble/InstructionText")
	if instruction_text:
		instruction_text.text = message
		
		# Reset any previous styling and use the label's natural properties
		instruction_text.modulate = Color.WHITE  # Reset modulate
		instruction_text.add_theme_color_override("font_color", Color(0.55, 0.27, 0.07, 1))  # Brown color
		
		# Ensure proper alignment within the bubble
		instruction_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		instruction_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Reset position and size to use the label's anchors properly
		instruction_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Add some padding so text doesn't touch bubble edges
		var margin = 20
		instruction_text.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, margin)
		
		# Subtle animation that doesn't break positioning
		var original_modulate = instruction_text.modulate
		instruction_text.modulate = Color(1.2, 1.2, 1.2, 1)  # Slightly brighter
		
		var tween = create_tween()
		tween.tween_property(instruction_text, "modulate", original_modulate, 0.3)

func return_to_start(tool):
	var original_pos = original_tool_positions.get(tool, tool.global_position)
	
	var tween = create_tween()
	tween.parallel().tween_property(tool, "global_position", original_pos, 0.5)
	tween.parallel().tween_property(tool, "scale", Vector2(1.0, 1.0), 0.5)
	tween.parallel().tween_property(tool, "modulate", Color.WHITE, 0.3)  # Reset color
	
	tool.z_index = 0

func get_tool_name(tool):
	var name = tool.name.to_lower()
	if "hammer" in name:
		return "hammer"
	elif "wrench" in name:
		return "wrench"
	elif "screwdriver" in name:
		return "screwdriver"
	elif "saw" in name:
		return "saw"
	return ""

func get_word_name(word_block):
	var name = word_block.name.to_lower()
	if "hammer" in name:
		return "hammer"
	elif "wrench" in name:
		return "wrench"
	elif "screwdriver" in name:
		return "screwdriver"
	elif "saw" in name:
		return "saw"
	return ""

func is_tool_matched(tool):
	var tool_name = get_tool_name(tool)
	return tool_name in matched_pairs

func _process(delta):
	if is_dragging and dragged_tool:
		dragged_tool.global_position = get_global_mouse_position()

# Navigation button handlers
func _on_back_button_pressed():
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").go_to_scene2()

func _on_next_button_pressed():
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").complete_scene(3, 100)
		get_node("/root/SceneManager").go_to_scene4()

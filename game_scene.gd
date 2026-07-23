extends Node2D

var current_clicks: int = 51
var current_state = 4

var current_block: Button = null
var drag_offset: Vector2 = Vector2.ZERO

#state 0 1-10 normal clicking
#state 1 11-25 button moves away
#state 2 26-40 fake buttons that subtract points
#state 3 41-50 sort numbers 
#state 4 51-60 maths questions to increment 
#state 5 61-72 humming invisible button 
#state 6 73-84 slider 
#state 7 85-94 bouncer
#state 8 95-98 button locked in centre dodge bullets
#state 9 final click

@onready var label = $Counter
@onready var button = $Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# update dragging 
	if current_block != null:
		current_block.position = get_global_mouse_position() - drag_offset

	# update sound based on distance from button
	
	if current_state == 5:
		var btn_center = button.position + (button.size / 2)
		var distance = get_global_mouse_position().distance_to(btn_center)
		
		var max_distance = 800.0 
		
		var linear_volume = 1.0 - clamp(distance / max_distance, 0.0, 1.0)
		
		if linear_volume > 0.01:
			hum_player.volume_db = linear_to_db(linear_volume)
		else:
			hum_player.volume_db = -80.0 # mute

func update_state_logic() -> void:
	if current_clicks >= 11 and current_clicks <= 25:
		current_state = 1
	elif current_clicks >= 26 and current_clicks <= 40:
		current_state = 2 
	elif current_clicks >= 41 and current_clicks <= 50:
		clear_fake_buttons() #clean up state 2
		current_state = 3
		spawn_sorting_puzzle()
	elif current_clicks >= 51 and current_clicks <= 60:
		current_state = 4
	elif current_clicks >= 61 and current_clicks <= 72:
		maths_popup.hide() # clean up state 4
		current_state = 5
		start_invisible_button()
	elif current_clicks == 73 and current_clicks <= 84:
		hum_player.stop() #clean up state 5
		button.modulate.a = 1.0 
		current_state = 6
		
		start_slider_state()
		
func updateCounter() -> void:
	label.text = str(current_clicks) + " / 100"

func _on_button_pressed() -> void:
	
	if current_state == 4:
		maths_popup.show()
		load_next_maths_question()
		return # stop standard clicking
	
	current_clicks += 1 
	
	updateCounter()
	update_state_logic()
	
	match current_state:
		0:
			pass
		1:
			move_button_randomly()
		2:
			pass
			#move_button_randomly()
			#spawn_fake_buttons(3)
		5:
			move_button_randomly()
			
func _on_fake_pressed() -> void:
	current_clicks -= 1 
	updateCounter()

# logic for each state

func getRandomButtonCoords() -> Array:
	var screen_size = get_viewport_rect().size
	var new_x = randf_range(0, screen_size.x - button.size.x)
	var new_y = randf_range(0, screen_size.y - button.size.y)
	
	return [new_x, new_y]

#state 1

func move_button_randomly() -> void:
	var coords = getRandomButtonCoords()
	
	button.position = Vector2(coords[0], coords[1])
	
#state 2
	
func clear_fake_buttons() -> void:
	for node in get_tree().get_nodes_in_group("fake_buttons"):
		node.queue_free()
	
func spawn_fake_buttons(amount: int) -> void:
	
	clear_fake_buttons()
	
	for i in range(amount):
		var fake_btn = Button.new()
		fake_btn.text = "Click Me"
	
		fake_btn.add_theme_font_size_override("font_size", button.get_theme_font_size("font_size"))
		
		var coords = getRandomButtonCoords()
		fake_btn.position = Vector2(coords[0], coords[1])
	
		fake_btn.add_to_group("fake_buttons")
		fake_btn.pressed.connect(_on_fake_pressed)	
		
		add_child(fake_btn)

#state 3 

func createBlock(num: int, index: int) -> Button:
	var block = Button.new()
	block.text = str(num)
		
	block.set_meta("num_value", num)
	block.add_theme_font_size_override("font_size", 32)
		
	var start_x = 100 + (index * 80)
	var start_y = randf_range(250, 350)
	block.position = Vector2(start_x, start_y)
		
	block.add_to_group("sort_blocks")
		
	block.button_down.connect(_on_block_down.bind(block))
	block.button_up.connect(_on_block_up)
	
	return block
	
func _on_block_down(block: Button) -> void:
	current_block = block
	drag_offset = get_global_mouse_position() - block.position
	block.move_to_front()

func _on_block_up() -> void:
	current_block = null
	check_sort_order() 

func spawn_sorting_puzzle() -> void:
	button.hide()
	
	var numbers = [41, 42, 43, 44, 45, 46, 47, 48, 49, 50]
	numbers.shuffle()
	
	for i in range(numbers.size()):
		var block = createBlock(numbers[i], i)
		
		add_child(block)
		
func check_sort_order() -> void:
	var blocks = get_tree().get_nodes_in_group("sort_blocks")
	
	blocks.sort_custom(func(a, b): return a.position.x < b.position.x)
	
	var is_sorted = true

	for i in range(blocks.size() - 1):
		if blocks[i].get_meta("num_value") > blocks[i + 1].get_meta("num_value"):
			is_sorted = false
			break
			
	if is_sorted:
		print("solved state 3")
		
		for block in blocks:
			block.queue_free()
		
		current_clicks = 50
		updateCounter()
		
		button.show()
		button.position = get_viewport_rect().size / 2 

#state 4

@onready var maths_popup = $MathsPopup
@onready var question_label = $MathsPopup/QuestionLabel
@onready var question_image = $MathsPopup/QuestionImage
@onready var answer_input = $MathsPopup/AnswerInput

var current_maths_index: int = 0
var maths_questions: Array = [
	{"type": "text", "q": "2+2", "a": "4"},
	{"type": "text", "q": "10+20", "a": "30"},
	{"type": "text", "q": "8-3", "a": "5"},
	{"type": "text", "q": "5x5", "a": "25"},
	{"type": "text", "q": "3+3+3", "a": "9"},
	{"type": "text", "q": "49 / 7", "a": "7"},
	{"type": "text", "q": "12x12", "a": "144"},
	{"type": "image", "q": "res://maths/eq.png", "a": "5"},
	{"type": "image", "q": "res://maths/trig.png", "a": "1"},
	{"type": "image", "q": "res://maths/int.png", "a": "1"},
]

func load_next_maths_question() -> void:
	var current_q = maths_questions[current_maths_index]
	
	if current_q["type"] == "text":
		question_label.show()
		question_image.hide()
		question_label.text = current_q["q"]
	elif current_q["type"] == "image":
		question_label.hide()
		question_image.show()
		question_image.texture = load(current_q["q"])

func _on_submit_button_pressed() -> void:
	var typed_answer = answer_input.text.strip_edges().to_lower()
	var correct_answer = maths_questions[current_maths_index]["a"].to_lower()
	
	if typed_answer == correct_answer:
		current_clicks += 1
		updateCounter()
		current_maths_index += 1
		answer_input.text = "" 
		
		if current_maths_index < maths_questions.size() and current_clicks <= 60:
			load_next_maths_question()
		else:
			maths_popup.hide()
			update_state_logic()
	else:
		answer_input.text = ""

#state 5

@onready var hum_player = $HumPlayer

func start_invisible_button() -> void:
	button.show() 
	#button.modulate.a = 0.0 
	hum_player.play()
	move_button_randomly()
	
#state 6

@onready var slider = $CalibrationSlider

func start_slider_state() -> void:
	print("slider state")
	button.hide()
	slider.show()
	
	slider.value = current_clicks

func _on_calibration_slider_value_changed(value: float) -> void:
	if current_state == 6:
		var target_score = current_clicks + 1
		var int_value = int(value)
		
		if int_value == target_score:
			current_clicks += 1
			updateCounter()
						
			if current_clicks >= 84:
				slider.hide()
				update_state_logic()
				
		elif int_value > target_score: #snap back if too forwards
			slider.value = current_clicks
			
		elif int_value < current_clicks: # snap back if too backwards
			slider.value = current_clicks

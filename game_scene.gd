extends Node2D

var current_clicks: int = 85
var current_state = 7

var center_x = 0 
var center_y = 0
var screen_bottom = 0
var screen_right = 0

var current_block: Button = null
var drag_offset: Vector2 = Vector2.ZERO

var button_velocity_y: float = 0.0
var button_velocity_x: float = 0.0
var gravity: float = 1500.0
var bounce_y_strength: float = -850.0 #negative goes up
var bounce_x_strength: float = 0

var projectile_scene = preload("res://projectile.tscn")
var active_projectiles: Array = []
var projectile_time: float = 0

var confetti_scene = preload("res://confetti.tscn")
var confetti_node: Node2D

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
@onready var background = $Background
@onready var gameoverscreen = $GameOver

var colour_themes: Array[Dictionary] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	center_x = (get_viewport_rect().size.x / 2) - (button.size.x / 2) 
	center_y = (get_viewport_rect().size.y / 2) - (button.size.y / 2) 
	screen_bottom = get_viewport_rect().size.y - button.size.y
	screen_right = get_viewport_rect().size.x - button.size.x
	
	colour_themes = [
		# state 0
		{ "background": Color("#232f72"), "text": Color("#65DCD5"), "button": Color("#43637e") },
		
		# state 1 
		{ "background": Color("#F8B2B2"), "text": Color("#403D88"), "button": Color("#8B639B") },
		
		# state 2 
		{ "background": Color("#001B79"), "text": Color("#ED5AB3"), "button": Color("#FF90C2") },
		
		# state 3 
		{ "background": Color("#FAE7CB"), "text": Color("#FA6781"), "button": Color("#59B292") },
		
		# state 4 maths state
		{ "background": Color("#F4F6F9"), "text": Color("#433D46"), "button": Color("#A7DBE8") },
		
		# state 5 
		{ "background": Color("#FE81D4"), "text": Color("#FFEABB"), "button": Color("#FFEABB") },
		
		# state 6 no theme needed slider
		{ "background": Color("#F4F6F9"), "text": Color("#433D46"), "button": Color("#C4C6CD") },
		
		# state 7 
		{ "background": Color("#00E0BA"), "text": Color("#91008D"), "button": Color("#FF3483") },
		
		# state 8 
		{ "background": Color("#333D6D"), "text": Color("#FFFFFF"), "button": Color("#723EC3") },
		
		#state 9
		{ "background": Color("#232f72"), "text": Color("#65DCD5"), "button": Color("#43637e") },
	]
	
	gameoverscreen.hide()
	
	label.position.x = (get_viewport_rect().size.x / 2) - (label.size.x / 2) 
	
	apply_theme(0)
	position_button_central()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#confetti
	
	if confetti_node:
		confetti_node.position = get_global_mouse_position()
	
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
			
	if current_state == 7:
		handle_collisions(delta)
	
	if current_state == 8:
		projectile_time += delta 
		
		if projectile_time >= 0.25:
			spawn_projectile()
			projectile_time = 0.0
			
		move_projectile(delta)
		
func apply_theme(state: int) -> void:
	if state < 0 or state >= colour_themes.size():
		return
		
	var theme = colour_themes[state]
	
	background.color = theme["background"]

	label.add_theme_color_override("font_color", theme["text"])
	
	var button_style = button.get_theme_stylebox("normal") as StyleBoxFlat
	
	if button_style:
		var styles: Array = ["normal", "hover", "pressed"]
		
		for i in styles:
			var style = button.get_theme_stylebox(i) as StyleBoxFlat
		
			if not style:
				style = StyleBoxFlat.new()
				button.add_theme_stylebox_override(i, style)
		
			if i == "normal":
				style.bg_color = theme["button"]
			elif i == "hover":
				style.bg_color = theme["button"].lightened(0.2)
			elif i == "pressed":
				style.bg_color = theme["button"].darkened(0.2) 
				
			style.set_border_width_all(0)

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
		maths_popup.show()
		load_next_maths_question()
		
	elif current_clicks >= 61 and current_clicks <= 72:
		maths_popup.hide() # clean up state 4
		current_state = 5
		start_invisible_button()
	elif current_clicks >= 73 and current_clicks <= 84:
		hum_player.stop() #clean up state 5
		button.modulate.a = 1.0 
		current_state = 6
		
		start_slider_state()
	elif current_clicks >= 85 and current_clicks <= 94:
		current_state = 7
	elif current_clicks >= 95 and current_clicks <= 98:
		button_velocity_y = 0
		button_velocity_x = 0
		
		current_state = 8
	elif current_clicks == 99:
		current_state = 9
		
		clear_projectiles()
		position_button_central()
	elif current_clicks == 100:
		game_ended()
		
	apply_theme(current_state)
		
func updateCounter() -> void:
	label.text = str(current_clicks) + " / 100"
	
func position_button_central() -> void:
	button.position.x = center_x
	button.position.y = center_y

func _on_button_pressed() -> void:
	
	if current_state == 4:
		maths_popup.show()
		load_next_maths_question()
		return # stop standard clicking
	
	current_clicks += 1 
	
	$ClickSound.play()
	
	updateCounter()
	update_state_logic()
	
	match current_state:
		0:
			pass
		1:
			move_button_randomly()
		2:
			move_button_randomly()
			spawn_fake_buttons(3)
		5:
			move_button_randomly()
		7:
			bounce_x_strength = randf_range(-500, 500)
			
			button_velocity_y = bounce_y_strength # bounce upwards
			button_velocity_x = bounce_x_strength
		8:	
			move_button_randomly()
		9:
			position_button_central()
			
func _on_fake_pressed() -> void:
	#current_clicks -= 1 
	#updateCounter()
	pass

func start_looping_confetti() -> void:
	if not confetti_node:
		confetti_node = confetti_scene.instantiate()
		gameoverscreen.add_child(confetti_node)
		
		# Start emitting
		var particle_node = confetti_node.get_node("ConfettiParticle")
		particle_node.emitting = true
	
func game_ended() -> void:
	gameoverscreen.show()
	button.hide()
	label.hide()
	
	# handle confetti
	
	start_looping_confetti()
		

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
	
	#setup theme
	
	var theme = colour_themes[current_state]
	
	block.focus_mode = Control.FOCUS_NONE
	
	var styles: Array = ["normal", "hover", "pressed"]
	for i in styles:
		var style = StyleBoxFlat.new()
		
		if i == "normal":
			style.bg_color = theme["button"]
		elif i == "hover":
			style.bg_color = theme["button"].lightened(0.2)
		elif i == "pressed":
			style.bg_color = theme["button"].darkened(0.2)
			
		style.set_border_width_all(0)
		block.add_theme_stylebox_override(i, style)
	
	#handle positioning
		
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
		position_button_central()

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
	{"type": "text", "q": "2x=10", "a": "5"},
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
<<<<<<< HEAD
	#button.modulate.a = 0.0 
=======
	button.modulate.a = 0.0 
>>>>>>> ed6132b (fresh commit)
	hum_player.play()
	move_button_randomly()
	
#state 6

@onready var slider = $CalibrationSlider

func start_slider_state() -> void:
	button.hide()
	slider.show()
	
	slider.value = current_clicks

func _on_calibration_slider_drag_ended(value_changed: bool) -> void:
	if current_state == 6:
		var target_score = current_clicks + 1
		var int_value = int(slider.value)
		
		if int_value == target_score:
			current_clicks += 1
			updateCounter()
						
			if current_clicks >= 84:
				slider.hide()
				update_state_logic()
				
		else: # snap back
			slider.value = current_clicks
			
#state 7

func handle_collisions(delta: float) -> void:
		button_velocity_y += gravity * delta #gravity pulls downwards
		
		button.position.y += button_velocity_y * delta
		button.position.x += button_velocity_x * delta
		
		#hits floor
		
		if button.position.y >= screen_bottom:
			button.position.y = screen_bottom

			button_velocity_y = 0.0 
			
			if current_clicks > 85:
				#current_clicks -= 1
				updateCounter()
			
		# hits walls
		
		if button.position.x <= 0:
			button.position.x = 0
			button_velocity_x *= -1 # reverse direction 
			
		if button.position.x >= screen_right:
			button.position.x = screen_right
			button_velocity_x *= -1 # reverse direction 

#state 8 

func spawn_projectile() -> void:
	var bullet = projectile_scene.instantiate()
	
	var screen_x = get_viewport_rect().size.x
	
	bullet.position = Vector2(randf_range(0, screen_x), -30)
	
	var mouse_pos = get_global_mouse_position()
	
	var direction = (mouse_pos - bullet.position).normalized()
	
	add_child(bullet)
	
	active_projectiles.append({
		"node": bullet,
		"velocity": direction * 500.0
	})
	
func move_projectile(delta: float) -> void:
	for i in range(active_projectiles.size() -1, -1, -1):
		var current = active_projectiles[i]
		
		var bullet = current["node"]
		
		bullet.position += current["velocity"] * delta
			
		var bullet_center = bullet.position 
		var distance_to_mouse = bullet_center.distance_to(get_global_mouse_position())
			
		if distance_to_mouse < 15.0: 
			if current_clicks > 94:
				current_clicks -= 1
				updateCounter()
				
			bullet.queue_free()
			active_projectiles.remove_at(i)
				
		elif bullet.position.y > get_viewport_rect().size.y + 50 or bullet.position.x < -50 or bullet.position.x > get_viewport_rect().size.x + 50:
			bullet.queue_free()
			active_projectiles.remove_at(i)
	
func clear_projectiles() -> void:
	for i in active_projectiles:
		i["node"].queue_free()
	
	active_projectiles.clear()	

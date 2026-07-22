extends Node2D

var current_clicks: int = 0
var current_state = 0 

var current_block: Button = null
var drag_offset: Vector2 = Vector2.ZERO

#state 0 1-10 normal clicking
#state 1 11-25 button moves away
#state 2 26-40 fake buttons that subtract points
#state 3 41-50 sort numbers 
#state 4 51-60 maths questions to increment 
#state 5 61 fake crash, close button increments 
#state 6 62-72 humming invisible button 
#state 7 73-85 bouncing button
#state 8 86-94 error type in commands
#state 9 95-98 button locked in centre dodge bullets
#state 10 99 button shatters, reassamble for 100 

@onready var label = $Counter
@onready var button = $Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if current_block != null:
		current_block.position = get_global_mouse_position() - drag_offset

func update_state_logic() -> void:
	if current_clicks >= 11 and current_clicks <= 25:
		current_state = 1
	elif current_clicks >= 26 and current_clicks <= 40:
		current_state = 2 
	elif current_clicks >= 41 and current_clicks <= 50:
		clear_fake_buttons()
		current_state = 3
		spawn_sorting_puzzle()
		
func updateCounter() -> void:
	label.text = str(current_clicks) + " / 100"

func _on_button_pressed() -> void:
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

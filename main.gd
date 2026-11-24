extends Node2D
# Farm Snake - Step 2: the farming twist.
#
# Rules:
# - Eat a SEED BAG (tan square) to get seeds.
# - While you have seeds, your tail plants one in each square it leaves.
# - Seeds sprout, then ripen into pumpkins after GROW_TIME seconds.
# - Eat a RIPE pumpkin for big points and growth.
# - Run over an unripe sprout and you trample it (gone, no points).
# - Ripe pumpkins wither away if you wait too long.
# - Step 3: day/night cycle. Crops only grow (and wither) during the day.
# - Step 4: pixel-art sprites (in the art/ folder) and a saved high score.

const CELL := 32
const COLS := 20
const ROWS := 15
const STEP_TIME := 0.15

const GROW_TIME := 5.0     # seconds from seed to ripe
const WITHER_TIME := 13.0  # seconds from seed until a ripe pumpkin rots away
const SEEDS_PER_BAG := 5
const START_SEEDS := 5

const DAY_LENGTH := 20.0   # seconds of daylight
const NIGHT_LENGTH := 10.0 # seconds of night (crops don't grow)
const FADE_TIME := 2.0     # seconds for dusk/dawn to fade

# "user://" is a safe per-user folder Godot gives every game for save files.
const SAVE_PATH := "user://highscore.save"

# Sprites. preload() loads them once when the script starts.
const GRASS := [
	preload("res://art/grass_0.png"),
	preload("res://art/grass_1.png"),
	preload("res://art/grass_2.png"),
]
const SOIL := preload("res://art/soil.png")
const SPROUT_SMALL := preload("res://art/sprout_small.png")
const SPROUT_BIG := preload("res://art/sprout_big.png")
const PUMPKIN := preload("res://art/pumpkin.png")
const PUMPKIN_ROTTEN := preload("res://art/pumpkin_rotten.png")
const SEED_BAG := preload("res://art/seed_bag.png")
const SNAKE_BODY := preload("res://art/snake_body.png")
const HEAD_UP := preload("res://art/snake_head_up.png")
const HEAD_DOWN := preload("res://art/snake_head_down.png")
const HEAD_LEFT := preload("res://art/snake_head_left.png")
const HEAD_RIGHT := preload("res://art/snake_head_right.png")

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var food := Vector2i.ZERO        # the seed bag
var crops := {}                  # Dictionary: grid cell (Vector2i) -> age in seconds (float)
var seeds := 0
var grow := 0
var timer := 0.0
var score := 0
var game_over := false
var clock := 0.0   # time into the current day/night cycle
var day := 1
var high_score := 0
var new_record := false


func _ready() -> void:
	randomize()
	# Keep pixel art crisp instead of blurry when it's scaled up 2x.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_high_score()
	reset_game()


func load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		high_score = file.get_32()


func save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_32(high_score)


func end_game() -> void:
	game_over = true
	new_record = score > high_score
	if new_record:
		high_score = score
		save_high_score()
	queue_redraw()


func reset_game() -> void:
	snake = [Vector2i(5, 7), Vector2i(4, 7), Vector2i(3, 7)]
	direction = Vector2i.RIGHT
	next_direction = direction
	crops.clear()
	seeds = START_SEEDS
	grow = 0
	score = 0
	timer = 0.0
	game_over = false
	new_record = false
	clock = 0.0
	day = 1
	spawn_food()
	queue_redraw()


func spawn_food() -> void:
	while true:
		var spot := Vector2i(randi() % COLS, randi() % ROWS)
		if not snake.has(spot) and not crops.has(spot):
			food = spot
			return


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event.is_action_pressed("ui_accept"):
			reset_game()
		return

	var new_dir := next_direction
	if event.is_action_pressed("ui_up"):
		new_dir = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		new_dir = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		new_dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		new_dir = Vector2i.RIGHT

	if new_dir != -direction:
		next_direction = new_dir


func _process(delta: float) -> void:
	if game_over:
		return

	# Advance the day/night clock.
	clock += delta
	if clock >= DAY_LENGTH + NIGHT_LENGTH:
		clock -= DAY_LENGTH + NIGHT_LENGTH
		day += 1

	# Age every crop - but only during the day. Remove the ones that have withered.
	# (crops.keys() makes a copy, so it's safe to erase while looping.)
	if not is_night():
		for cell in crops.keys():
			crops[cell] += delta
			if crops[cell] >= WITHER_TIME:
				crops.erase(cell)

	timer += delta
	if timer >= STEP_TIME:
		timer -= STEP_TIME
		step()

	queue_redraw()  # redraw every frame so crops visibly grow


func is_night() -> bool:
	return clock >= DAY_LENGTH


func darkness() -> float:
	# 0.0 = full daylight, 1.0 = full night, with a smooth fade at dusk and dawn.
	var total := DAY_LENGTH + NIGHT_LENGTH
	if clock < DAY_LENGTH - FADE_TIME:
		return 0.0
	if clock < DAY_LENGTH:
		return (clock - (DAY_LENGTH - FADE_TIME)) / FADE_TIME  # dusk
	if clock < total - FADE_TIME:
		return 1.0
	return (total - clock) / FADE_TIME  # dawn


func is_ripe(cell: Vector2i) -> bool:
	return crops.has(cell) and crops[cell] >= GROW_TIME


func step() -> void:
	direction = next_direction
	var head: Vector2i = snake[0] + direction

	var off_board := head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS
	if off_board or snake.has(head):
		end_game()
		return

	snake.insert(0, head)

	if head == food:
		# Seed bag: a few points, a little growth, more seeds.
		score += 1
		grow += 1
		seeds += SEEDS_PER_BAG
		spawn_food()
	elif crops.has(head):
		if is_ripe(head):
			# Harvest!
			score += 3
			grow += 1
		# Ripe or not, the crop is gone now (harvested or trampled).
		crops.erase(head)

	if grow > 0:
		grow -= 1
	else:
		var old_tail: Vector2i = snake.pop_back()
		# The tail just left this square: plant a seed there if we have one.
		if seeds > 0:
			crops[old_tail] = 0.0
			seeds -= 1


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * CELL, cell.y * CELL, CELL, CELL)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)


func _draw() -> void:
	# Grass: pick one of 3 variants per square, based on its position,
	# so the pattern looks random but doesn't flicker between frames.
	for x in COLS:
		for y in ROWS:
			var variant: int = (x * 7 + y * 13) % GRASS.size()
			draw_texture_rect(GRASS[variant], cell_rect(Vector2i(x, y)), false)

	# Crops: soil underneath, then the plant on top
	for cell in crops.keys():
		var age: float = crops[cell]
		var rect := cell_rect(cell)
		draw_texture_rect(SOIL, rect, false)
		if age < GROW_TIME * 0.5:
			draw_texture_rect(SPROUT_SMALL, rect, false)
		elif age < GROW_TIME:
			draw_texture_rect(SPROUT_BIG, rect, false)
		elif age < WITHER_TIME - 3.0:
			draw_texture_rect(PUMPKIN, rect, false)
		else:
			draw_texture_rect(PUMPKIN_ROTTEN, rect, false)  # about to wither

	# Seed bag
	draw_texture_rect(SEED_BAG, cell_rect(food), false)

	# Snake: body first, head last so it's on top
	for i in range(snake.size() - 1, 0, -1):
		draw_texture_rect(SNAKE_BODY, cell_rect(snake[i]), false)
	draw_texture_rect(head_texture(), cell_rect(snake[0]), false)

	# Night overlay: a dark blue layer that fades in and out
	var dark := darkness()
	if dark > 0.0:
		draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0.05, 0.05, 0.2, 0.55 * dark))

	# HUD (drawn last so it stays readable at night)
	var font := ThemeDB.fallback_font
	var time_label := "Night" if is_night() else "Day"
	var hud := "Score: %d    Best: %d    Seeds: %d    %s %d" % [score, high_score, seeds, time_label, day]
	draw_rect(Rect2(0, 0, COLS * CELL, 34), Color(0, 0, 0, 0.45))  # dark strip behind the text
	draw_string(font, Vector2(8, 24), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

	if game_over:
		draw_rect(Rect2(120, 190, 400, 100), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(120, 230), "Game over - press Enter", HORIZONTAL_ALIGNMENT_CENTER, 400, 28)
		if new_record:
			draw_string(font, Vector2(120, 270), "New high score!", HORIZONTAL_ALIGNMENT_CENTER, 400, 24, Color("f1c453"))


func head_texture() -> Texture2D:
	if direction == Vector2i.UP:
		return HEAD_UP
	elif direction == Vector2i.DOWN:
		return HEAD_DOWN
	elif direction == Vector2i.LEFT:
		return HEAD_LEFT
	return HEAD_RIGHT

extends Node2D

const EnemyScene = preload("res://scenes/Enemy.tscn")
const TowerScene = preload("res://scenes/Tower.tscn")

var base_health := 20
var max_base_health := 20
var max_towers := 6
var money := 100
var enemy_health_mult := 1.0
var enemy_speed_mult := 1.0
const TOWER_COST := 50

var path := []
const PATH_WIDTH := 240
const PATH_COLOR := Color(0.55, 0.27, 0)
const GRASS_COLOR := Color(0.2, 0.8, 0.2)
const BASE_BAR_BG := Color(0.1, 0.1, 0.1)
const BASE_BAR_FG := Color(0.0, 0.7, 0.1)

var towers := []
var enemies := []

var round_num := 1
var enemies_to_spawn := 0
var enemies_alive := 0
const SPAWN_INTERVAL := 0.8
var spawn_timer := 0.0
var waiting_next_round := false
var boss_count := 0

enum EnemyShape { CIRCLE, SQUARE, TRIANGLE, DIAMOND }

var EnemyTypes = [
	{"shape": EnemyShape.CIRCLE,   "color": Color(1, 0.2, 0.2),   "speed": 80.0, "health": 3, "size": 24, "reward": 7},
	{"shape": EnemyShape.SQUARE,   "color": Color(0.9, 0.1, 0.1), "speed": 65.0, "health": 4, "size": 33, "reward": 11},
	{"shape": EnemyShape.TRIANGLE, "color": Color(0.8, 0.05, 0.05), "speed": 95.0, "health": 2, "size": 39, "reward": 4},
	{"shape": EnemyShape.DIAMOND,  "color": Color(1, 0.3, 0.3),   "speed": 50.0, "health": 5, "size": 27, "reward": 15}
]

func _ready():
	randomize()
	set_process(true)
	_generate_path()
	start_round()
	
	var panel = Panel.new()
	panel.position = Vector2(820, 40)
	panel.size = Vector2(320, 250)
	panel.z_index = -100

	# StyleBoxFlat para fondo y bordes redondeados
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.18)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)


	# Usa nombres de archivos PNG con transparencia
	_add_icon_and_label("heart.png", "BaseLabel", Vector2(2000, 60))   # Vida base
	_add_icon_and_label("fist.png", "RoundLabel", Vector2(2000, 120))  # Ronda actual
	_add_icon_and_label("tower.png", "TowerLabel", Vector2(2000, 180)) # Torres colocadas
	_add_icon_and_label("coin.png", "MoneyLabel", Vector2(2000, 240))  # Dinero
	_add_icon_and_label("bolt.png", "DiffLabel", Vector2(2000, 300))   # Dificultad, multiplicadores

func _add_icon_and_label(icon_file, label_name, pos: Vector2):
	var tex = load("res://assets/%s" % icon_file)
	var img = TextureRect.new()
	img.texture = tex
	img.position = pos
	img.set_size(Vector2(28, 28))   # Icono más pequeño y nítido
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.modulate = Color(1, 1, 1, 1)  # Por si acaso
	add_child(img)

	var lbl = Label.new()
	lbl.name = label_name
	lbl.position = pos + Vector2(36, 0)  # Más pegado al icono
	lbl.add_theme_font_size_override("font_size", 32)  # Letra más proporcionada al icono
	lbl.add_theme_color_override("font_color", Color(0,0,0))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos = event.position
		if not is_on_path(pos) and not is_on_tower(pos):
			if towers.size() >= max_towers:
				print("¡No puedes colocar más torres! (Máximo: %d)" % max_towers)
				return
			if money < TOWER_COST:
				print("¡No tienes suficiente dinero! ($%d necesario)" % TOWER_COST)
				return
			place_tower(pos)
			money -= TOWER_COST

func is_on_path(pos: Vector2) -> bool:
	for i in range(path.size() - 1):
		var A = path[i]; var B = path[i+1]
		var seg = Geometry2D.get_closest_point_to_segment(pos, A, B)
		if pos.distance_to(seg) < PATH_WIDTH * 0.5:
			return true
	return false

func is_on_tower(pos: Vector2) -> bool:
	for t in towers:
		if t.position.distance_to(pos) < 84:
			return true
	return false

func place_tower(pos: Vector2):
	if towers.size() >= max_towers:
		print("¡No puedes colocar más torres! (Máximo: %d)" % max_towers)
		return
	var tower = TowerScene.instantiate()
	tower.position = pos
	add_child(tower)
	towers.append(tower)

func _generate_path():
	var size = get_viewport_rect().size
	var w = size.x; var h = size.y
	var quarter = w * 0.25; var half = w * 0.5; var three_q = w * 0.75
	var ym = h * 0.5; var yu = h * 0.25; var yd = h * 0.75
	path = [
		Vector2(0, ym), Vector2(quarter, ym), Vector2(quarter, yu),
		Vector2(half, yu), Vector2(half, yd), Vector2(three_q, yd),
		Vector2(three_q, ym), Vector2(w, ym)
	]

func start_round():
	waiting_next_round = false
	enemies_to_spawn = 10 + (round_num - 1) * 2
	enemies_alive = 0
	spawn_timer = 0.0
	if round_num % 10 == 0:
		enemies_to_spawn += 1

func _process(delta):
	# Spawneo de enemigos uno a uno
	if enemies_to_spawn > 0:
		spawn_timer += delta
		if spawn_timer >= SPAWN_INTERVAL:
			spawn_timer = 0.0
			spawn_enemy()
	elif enemies_alive <= 0 and not waiting_next_round:
		waiting_next_round = true
		await_next_round()
	queue_redraw()

	# ACTUALIZA LOS LABELS DE UI ICON
	if has_node("BaseLabel"):
		$BaseLabel.text = "Base: %d" % base_health
	if has_node("RoundLabel"):
		$RoundLabel.text = "Round: %d" % round_num
	if has_node("TowerLabel"):
		$TowerLabel.text = "Towers: %d / %d" % [towers.size(), max_towers]
	if has_node("MoneyLabel"):
		$MoneyLabel.text = "Money: $%d" % money
	if has_node("DiffLabel"):
		$DiffLabel.text = "HP: x%.2f  SPD: x%.2f" % [enemy_health_mult, enemy_speed_mult]

	# Enemigos
	enemies.clear()
	for child in get_children():
		if child is Node2D and child.has_method("update_enemy") and child.path.size() > 0:
			child.update_enemy(delta)
			enemies.append(child)
	# Torres
	for t in towers:
		t.update_tower(delta, enemies)

func await_next_round():
	await get_tree().create_timer(1.5).timeout
	round_num += 1
	if (round_num-1) % 10 == 0 and round_num > 1:
		max_towers += 2
		enemy_health_mult *= 1.20
		enemy_speed_mult  *= 1.10
	start_round()

func spawn_enemy():
	var is_boss = false
	if round_num % 10 == 0 and enemies_to_spawn == 1:
		is_boss = true

	var e = EnemyScene.instantiate()
	if is_boss:
		boss_count += 1
		var def = EnemyTypes[0]
		var boss_size = def["size"] * 3
		var boss_health = int(def["health"] * 6 * pow(1.15, boss_count-1))
		var boss_speed = def["speed"] * 1.2 * pow(1.15, boss_count-1)
		e.shape_type = def["shape"]
		e.draw_color = Color(1, 0.6, 0.6)
		e.speed = boss_speed
		e.health = boss_health
		e.max_health = boss_health
		e.size = boss_size
		e.damage = 7 + boss_count
		e.reward = int(boss_health * 3)
	else:
		var def = EnemyTypes[randi() % EnemyTypes.size()]
		e.shape_type = def["shape"]
		e.draw_color = def["color"]
		e.speed      = def["speed"] * enemy_speed_mult
		e.health     = int(def["health"] * enemy_health_mult)
		e.max_health = e.health
		e.size       = def["size"]
		e.damage     = 1
		e.reward     = def["reward"]

	var p0 = path[0]
	var p1 = path[1]
	var dir = (p1 - p0).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var jitter_amount = randf_range(-PATH_WIDTH * 0.5, PATH_WIDTH * 0.5)
	var jitter = perp * jitter_amount
	var epath := []
	for p in path:
		epath.append(p + jitter)
	e.path = epath
	e.position = epath[0]
	e.path_index = 0
	add_child(e)
	enemies_to_spawn -= 1
	enemies_alive += 1

func base_hit(damage: int):
	base_health = max(base_health - damage, 0)

func enemy_dead(enemy):
	enemies_alive -= 1
	money += enemy.reward

func _draw():
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), GRASS_COLOR)
	for i in range(path.size() - 1):
		var A = path[i]; var B = path[i + 1]
		var dir = (B - A).normalized()
		var perp = Vector2(-dir.y, dir.x) * (PATH_WIDTH * 0.5)
		var quad = PackedVector2Array([A + perp, A - perp, B - perp, B + perp])
		var cols = PackedColorArray([PATH_COLOR, PATH_COLOR, PATH_COLOR, PATH_COLOR])
		draw_polygon(quad, cols)
	var vw = get_viewport_rect().size.x
	var bar_w = vw * 0.3
	var bar_h = 24
	var mx = 10; var my = 10
	draw_rect(Rect2(mx, my, bar_w, bar_h), BASE_BAR_BG)
	var ratio = float(base_health) / float(max_base_health)
	draw_rect(Rect2(mx, my, bar_w * ratio, bar_h), BASE_BAR_FG)

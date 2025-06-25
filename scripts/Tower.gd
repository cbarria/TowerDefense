extends Node2D

var tower_range := 300.0     # Antes 100.0
var fire_rate := 1.0
var fire_timer := 0.0

var last_shot_target: Node2D = null
var last_shot_time: float = 0.0
const SHOT_DISPLAY_TIME := 0.1

func update_tower(delta: float, enemies: Array):
	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0
		shoot(enemies)
	if last_shot_target and (Time.get_ticks_msec() / 1000.0 - last_shot_time > SHOT_DISPLAY_TIME):
		last_shot_target = null
	queue_redraw()

func shoot(enemies: Array):
	var target = null
	var min_d = tower_range
	for e in enemies:
		var d = position.distance_to(e.position)
		if d < min_d:
			min_d = d
			target = e
	if target:
		target.hit(1)
		last_shot_target = target
		last_shot_time = Time.get_ticks_msec() / 1000.0
		queue_redraw()

func _draw():
	var s = 72  # Antes 18
	draw_rect(Rect2(-s/2, -s/2, s, s), Color(0,0,1))
	draw_circle(Vector2.ZERO, tower_range, Color(0,0,1,0.16))
	if last_shot_target:
		draw_line(Vector2.ZERO, last_shot_target.position - position, Color(0.2,0.6,1), 12) # Antes 3

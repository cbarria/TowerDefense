extends Node2D

enum EnemyShape { CIRCLE, SQUARE, TRIANGLE, DIAMOND }

var speed := 100
var health := 3
var max_health := 3
var size := 8
var damage := 1
var shape_type := EnemyShape.CIRCLE
var draw_color := Color(1, 0, 0)
var reward := 0


var path := []
var path_index := 0

func _ready():
	max_health = health
	queue_redraw()

func update_enemy(delta: float):
	if path_index < path.size():
		var target = path[path_index]
		position += (target - position).normalized() * speed * delta
		if position.distance_to(target) < 10:
			path_index += 1
	else:
		get_parent().base_hit(damage)
		get_parent().enemy_dead(self)
		queue_free()

func hit(dmg: int):
	health -= dmg
	if health <= 0:
		get_parent().enemy_dead(self)
		queue_free()
	else:
		queue_redraw()

func _draw():
	var s = size * 1.3
	match shape_type:
		EnemyShape.CIRCLE:
			draw_circle(Vector2.ZERO, s, draw_color)
		EnemyShape.SQUARE:
			draw_rect(Rect2(-s/2, -s/2, s, s), draw_color)
		EnemyShape.TRIANGLE:
			var pts = PackedVector2Array([
				Vector2(0, -s),
				Vector2(s,  s),
				Vector2(-s, s)
			])
			draw_polygon(pts, PackedColorArray([draw_color, draw_color, draw_color]))
		EnemyShape.DIAMOND:
			var pts = PackedVector2Array([
				Vector2(0, -s),
				Vector2(s,  0),
				Vector2(0,  s),
				Vector2(-s, 0)
			])
			draw_polygon(pts, PackedColorArray([draw_color, draw_color, draw_color, draw_color]))
	# Barra de HP encima
	var bar_w = s * 2
	var bar_h = 6
	var x = -bar_w / 2
	var y = -s - bar_h - 2
	draw_rect(Rect2(x, y, bar_w, bar_h), Color(0.5, 0, 0))
	var fill_ratio = clamp(float(health) / float(max_health), 0, 1)
	draw_rect(Rect2(x, y, bar_w * fill_ratio, bar_h), Color(0, 1, 0))

extends SceneTree
## 야만인 고기 먹기 사진: 앞·옆에서 본 남의 먹기(들어 올림·우걱우걱), 1인칭 먹기 2장, 3인칭 어깨 너머 먹기
## 화면 필요: godot --path . --resolution 1280x720 -s tests/screenshot_meat.gd -- tag=now
## 결과: tests/screenshots/meat_<tag>.png (한 장에 6칸)

var M: Node
var G: Node
var tag := "now"
const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const EAT := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const AT := Vector3(0, 0, 16)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "tag":
			tag = kv[1]
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.ai_enabled = false
	G.mode = "ffa"
	G.third_person = true
	G.chosen_cls = "barbarian"
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func phys(n: int) -> void:
	for i in n:
		await physics_frame


func grab() -> Image:
	var img := root.get_texture().get_image()
	img.resize(640, 360)
	return img


func put(e, pos: Vector3, cls: String, yaw: float) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = -0.05
	e.velocity = Vector3.ZERO


func eat(e) -> void:
	e.meat_cd = 0.0
	e.scripted_input = EAT
	await phys(2)
	e.scripted_input = IDLE


func _run() -> void:
	await frames(20)
	var p = M.player
	var bots: Array = M.combat.ents.filter(func(e): return e != p)
	var sub = bots[0]
	for i in range(1, bots.size()):
		bots[i].spawn_at(Vector3(300, -80, 300))
		bots[i].alive = false
		bots[i].process_mode = Node.PROCESS_MODE_DISABLED
	var shots: Array[Image] = []
	# 1·2: 앞에서 본 남의 먹기 (들어 올린 직후 / 우걱우걱 중) — 내 몸이 안 가리게 1인칭으로 구경
	G.third_person = false
	put(p, AT, "archer", 0.0)
	put(sub, AT + Vector3(0, 0, -2.6), "barbarian", PI)
	await frames(30)
	await eat(sub)
	await frames(6)
	shots.append(grab())
	await frames(14)
	shots.append(grab())
	# 3: 옆에서 본 먹기
	put(p, AT + Vector3(2.6, 0, -2.6), "archer", PI / 2)
	await frames(40)
	await eat(sub)
	await frames(10)
	shots.append(grab())
	# 4: 3인칭 어깨 너머 내가 먹기
	sub.spawn_at(Vector3(300, -80, 300))
	sub.alive = false
	G.third_person = true
	put(p, AT, "barbarian", 0.0)
	await frames(30)
	await eat(p)
	await frames(10)
	shots.append(grab())
	# 5·6: 1인칭 먹기 (올라옴 / 우걱우걱)
	G.third_person = false
	await frames(40)
	await eat(p)
	await frames(5)
	shots.append(grab())
	await frames(12)
	shots.append(grab())
	var sheet := Image.create(1280, 1080, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	sheet.save_png("res://tests/screenshots/meat_%s.png" % tag)
	print("saved res://tests/screenshots/meat_%s.png" % tag)
	quit()

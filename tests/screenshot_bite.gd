extends SceneTree
## 흡혈귀 물기 효과 사진 (부채꼴·유령 틀니·조준점 빨간 고리): 3인칭 물기 2장(막 문 순간·조금 뒤), 1인칭 물기, 허공 물기, 옆에서 본 남의 물기, 1인칭 범위 안 조준점
## 화면 필요: godot --path . --resolution 1280x720 -s tests/screenshot_bite.gd -- tag=now
## 결과: tests/screenshots/bite_<tag>.png (한 장에 6칸)

var M: Node
var G: Node
var tag := "now"
const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const BITE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
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
	G.chosen_cls = "vampire"
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
	e.burn_wait = 999.0


func bite(e) -> void:
	e.cd = 0.0
	e.scripted_input = BITE
	await phys(2)
	e.scripted_input = IDLE


func _run() -> void:
	await frames(20)
	var p = M.player
	var bots: Array = M.combat.ents.filter(func(e): return e != p)
	var tgt = bots[0]
	var vb = bots[1]
	for i in range(2, bots.size()):
		bots[i].spawn_at(Vector3(300, -80, 300))
		bots[i].alive = false
		bots[i].process_mode = Node.PROCESS_MODE_DISABLED
	vb.spawn_at(Vector3(300, -80, 300))
	vb.alive = false
	var shots: Array[Image] = []
	# 1·2: 3인칭 물기 (막 문 순간 / 0.15초 뒤)
	put(p, AT, "vampire", 0.0)
	put(tgt, AT + Vector3(0.3, 0, -2.6), "archer", PI)
	await frames(30)
	await bite(p)
	await frames(1)
	shots.append(grab())
	await frames(8)
	shots.append(grab())
	# 3: 1인칭 물기
	G.third_person = false
	tgt.hp = 100.0
	await frames(30)
	await bite(p)
	await frames(2)
	shots.append(grab())
	# 4: 1인칭, 범위 안 조준점 (안 묾)
	await frames(30)
	shots.append(grab())
	# 5: 3인칭 허공 물기 (범위 끝 옅은 틀니)
	G.third_person = true
	tgt.spawn_at(Vector3(300, -80, 300))
	tgt.alive = false
	await frames(30)
	await bite(p)
	await frames(2)
	shots.append(grab())
	# 6: 옆에서 본 남(봇)의 물기 — 나는 궁수로 6m 옆에서 봄
	put(tgt, AT + Vector3(0, 0, -2.6), "archer", PI)
	vb.alive = true
	put(vb, AT, "vampire", 0.0)
	put(p, AT + Vector3(6.5, 0, -1.3), "archer", PI / 2)
	await frames(30)
	await bite(vb)
	await frames(2)
	shots.append(grab())
	var sheet := Image.create(1280, 1080, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	sheet.save_png("res://tests/screenshots/bite_%s.png" % tag)
	print("saved res://tests/screenshots/bite_%s.png" % tag)
	quit()

extends SceneTree
## 포병 봄바드 외형 사진 8칸: 멀리서 본 대포 · 쏘는 순간(점화 불꽃·포구 연기) · 1인칭 평소·쏘는 순간·우클릭 조준 ·
## 3인칭 어깨 너머 쏘기 · 폭발 순간(돌 파편) · 폭발 조금 뒤(흙먼지) ·
## 1인칭 R 장전 (포탄 넣기 · 꽂을대 밀기 · 빼기 · 장전하며 우클릭)
## 화면 필요: godot --path . --resolution 1280x720 -s tests/screenshot_bombard.gd -- tag=now
## 결과: tests/screenshots/bombard_<tag>.png (2열 × 6줄)

var M: Node
var G: Node
var tag := "now"
const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const AIM := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const RELOAD := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "reload": true}
const RELOAD_AIM := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "reload": true, "aim": true}
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
	G.third_person = false
	G.chosen_cls = "cannoneer"
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


func put(e, pos: Vector3, cls: String, yaw: float, pitch := -0.05) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = pitch
	e.velocity = Vector3.ZERO


func shoot(e) -> void:
	e.cn_load = 1.0
	e.cd = 0.0
	e.scripted_input = FIRE
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
	# 1: 멀리서 (14m, 옆모습) — 한눈에 중세 대포로 보이나
	put(p, AT, "archer", 0.0)
	put(sub, AT + Vector3(5, 0, -10), "cannoneer", -PI / 2 + 0.3)
	await frames(40)
	shots.append(grab())
	# 2: 쏘는 순간 (5m, 비스듬히 앞) — 점화 구멍 불꽃 + 포구 연기
	put(sub, AT + Vector3(-2.5, 0, -5), "cannoneer", PI / 2 + 0.5, 0.15)
	await frames(30)
	await shoot(sub)
	await frames(4)
	shots.append(grab())
	sub.spawn_at(Vector3(300, -80, 300))
	sub.alive = false
	# 3·4·5: 1인칭 평소 / 쏘는 순간 / 우클릭 조준
	put(p, AT, "cannoneer", 0.0)
	await frames(40)
	shots.append(grab())
	await shoot(p)
	await frames(6)
	shots.append(grab())
	await frames(240)
	p.scripted_input = AIM
	await frames(30)
	shots.append(grab())
	p.scripted_input = IDLE
	# 6: 3인칭 어깨 너머 쏘기
	G.third_person = true
	put(p, AT, "cannoneer", 0.0)
	await frames(40)
	await shoot(p)
	await frames(5)
	shots.append(grab())
	# 7·8: 폭발 (7m 앞 땅) — 순간 / 조금 뒤
	G.third_person = false
	put(p, AT, "archer", 0.0, -0.25)
	await frames(30)
	M.combat.cannon.explode(p, AT + Vector3(0, 0.1, -7))
	await frames(4)
	shots.append(grab())
	await frames(18)
	shots.append(grab())
	# 9~12: 1인칭 R 장전 — 게이지를 정해 두고 R을 20프레임 눌러 자세를 잡은 뒤 찍음 (그동안 약 0.08 더 참)
	put(p, AT, "cannoneer", 0.0)
	await frames(30)
	for st in [[0.04, RELOAD], [0.295, RELOAD], [0.42, RELOAD], [0.6, RELOAD_AIM]]:
		p.cn_load = st[0]
		p.scripted_input = st[1]
		await phys(20)
		await frames(2)
		shots.append(grab())
		p.scripted_input = IDLE
		await frames(20)
	var sheet := Image.create(1280, 2160, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	sheet.save_png("res://tests/screenshots/bombard_%s.png" % tag)
	print("saved res://tests/screenshots/bombard_%s.png" % tag)
	quit()

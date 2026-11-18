extends SceneTree
## 병과 하나 자세히 보기 (새 병과 확인용): 다른 캐릭터로 서 있는 모습 3방향 + 걷는 중 + 내 1인칭(평소·우클릭)·3인칭 어깨 너머
## 화면 필요: godot --path . --resolution 1280x720 -s tests/screenshot_class.gd -- cls=cannoneer tag=now
## 결과: tests/screenshots/class_<cls>_<tag>.png (한 장에 6칸)

var M: Node
var G: Node
var cls := "cannoneer"
var tag := "now"
const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] == "cls":
			cls = kv[1]
		elif kv.size() == 2 and kv[0] == "tag":
			tag = kv[1]
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.ai_enabled = false
	G.mode = "ffa"
	G.third_person = true
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func grab() -> Image:
	var img := root.get_texture().get_image()
	img.resize(640, 360)
	return img


func _run() -> void:
	await frames(20)
	var p = M.player
	var subj = null
	for e in M.combat.ents:
		if e != p:
			if subj == null:
				subj = e
			else:
				e.spawn_at(Vector3(300, -80, 300))
				e.alive = false
				e.process_mode = Node.PROCESS_MODE_DISABLED
	var at := Vector3(-25, 0, 18)
	subj.next_cls = cls
	subj.spawn_at(at)
	subj.invuln = 0.0
	subj.scripted_input = IDLE
	subj.yaw = 0.0
	subj.pitch = 0.15
	p.spawn_at(Vector3(300, -60, 300))
	p.alive = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	M.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	cam.current = true
	var shots: Array[Image] = []
	var look: Vector3 = at + Vector3(0, 0.8, 0)
	for d: Vector3 in [Vector3(1, 0.25, -1), Vector3(1, 0.15, 0), Vector3(-0.6, 0.35, 1)]:
		await frames(20)
		cam.look_at_from_position(look + d.normalized() * 4.2, look)
		await frames(3)
		shots.append(grab())
	# 걷는 중 (바퀴가 구름)
	subj.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	await frames(25)
	var lp: Vector3 = subj.global_position + Vector3(0, 0.8, 0)
	cam.look_at_from_position(lp + Vector3(1, 0.2, 0).normalized() * 4.2, lp)
	await frames(2)
	shots.append(grab())
	cam.current = false
	# 내 화면: 1인칭 + 우클릭, 3인칭 어깨 너머
	subj.spawn_at(Vector3(300, -80, 300))
	subj.alive = false
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.next_cls = cls
	p.spawn_at(at)
	p.alive = true
	p.invuln = 0.0
	p.yaw = PI / 2
	p.pitch = -0.05  # 조금 아래 — 궤적이 앞 땅에 떨어지게
	M.hud.visible = true
	G.third_person = false
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
	p.cam.current = true
	await frames(40)
	shots.append(grab())
	G.third_person = true
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
	await frames(8)
	p.scripted_input = IDLE
	await frames(10)
	shots.append(grab())
	var sheet := Image.create(1280, 1080, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	sheet.save_png("res://tests/screenshots/class_%s_%s.png" % [cls, tag])
	print("saved class_%s_%s.png" % [cls, tag])
	quit()

extends SceneTree
## 급회전 넘어짐 기준 (사용자 요청 — 빠를수록 잘 넘어지고 느릴수록 덜 넘어지게, GameData.TRIP):
## 병과마다 걷기·달리기로 속도를 다 올린 뒤 반대쪽(180°)을 눌러서, 실제 속도 ≥ min_speed일 때만 넘어지는지.
## 꺾은 각도: 빠르면(야만인 달리기 9.0) 100°만 꺾어도 넘어지고, 느리면(궁수 달리기 6.9) 100°로는 안 넘어짐.
## godot --headless --fixed-fps 60 --path . -s tests/test_trip.gd

var main: Node
var G: Node
var p
var fails := 0
const SPOT := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = false
	G.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	G.ai_enabled = false
	_run()


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func inp(f: float, r := 0.0, sprint := false) -> Dictionary:
	return {"f": f, "r": r, "jump": false, "crouch": false, "sprint": sprint}


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## 앞으로 1.2초 달려 속도를 다 올린 뒤 각도 deg만큼 꺾은 쪽을 0.2초 누름 → [넘어졌나, 꺾기 직전 속도]
func turn(cls: String, sprint: bool, deg: float) -> Array:
	if p.cls != cls:
		p.set_class(cls)
	p.spawn_at(SPOT)
	p.invuln = 0.0
	p.yaw = -PI / 2  # -x 방향 (넓은 곳)
	p.pitch = 0.0
	p.velocity = Vector3.ZERO
	p.fall_t = 0.0
	p.trip_cd = 0.0
	p.fast_t = 0.0
	p.scripted_input = inp(1.0, 0.0, sprint)
	await frames(72)
	var v: float = Vector2(p.velocity.x, p.velocity.z).length()
	var a := deg_to_rad(deg)
	p.scripted_input = inp(cos(a), sin(a), false)
	var tripped := false
	for i in 12:
		await physics_frame
		tripped = tripped or p.fall_t > 0
	p.scripted_input = inp(0.0)
	await frames(50)
	return [tripped, v]


func _run() -> void:
	await frames(20)
	p = main.player
	for b in main.combat.ents:
		if b != p:
			b.spawn_at(Vector3(300, -80, 300))
			b.alive = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
	var T: Dictionary = G.TRIP
	var min_v := float(T.min_speed)
	# 기준 함수: 느리면 120°, 빠르면 95°
	check("기준 각도: %.1fm/s → %.0f°, %.1fm/s 이상 → %.0f°" % [min_v, T.angle_slow, T.fast_speed, T.angle_fast],
		absf(rad_to_deg(acos(p.trip_dot(min_v))) - float(T.angle_slow)) < 0.1 and absf(rad_to_deg(acos(p.trip_dot(20.0))) - float(T.angle_fast)) < 0.1, "")
	# 병과별 걷기·달리기 → 반대로 (180°)
	var expect_walk := {"barbarian": true, "vampire": true, "archer": false, "bard": false, "cleric": false, "crossbow": false, "cannoneer": false}
	var expect_run := {"barbarian": true, "vampire": true, "archer": true, "bard": true, "cleric": true, "crossbow": true, "cannoneer": false}
	for cls in expect_walk:
		for run in [false, true]:
			var r: Array = await turn(cls, run, 180.0)
			var want: bool = (expect_run if run else expect_walk)[cls]
			check("%s %s %.2fm/s → %s" % [cls, "달리기" if run else "걷기", r[1], "넘어짐" if want else "안 넘어짐"],
				r[0] == want and (float(r[1]) >= min_v) == want, "넘어짐=%s" % r[0])
	# 빠를수록 덜 꺾어도 넘어짐: 100° 꺾기
	var fast: Array = await turn("barbarian", true, 100.0)
	check("야만인 달리기(%.1f) 100° 꺾기 → 넘어짐" % fast[1], fast[0], "")
	var slow: Array = await turn("archer", true, 100.0)
	check("궁수 달리기(%.1f) 100° 꺾기 → 안 넘어짐" % slow[1], not slow[0], "")
	var slow2: Array = await turn("archer", true, 130.0)
	check("궁수 달리기(%.1f) 130° 꺾기 → 넘어짐" % slow2[1], slow2[0], "")
	# 둔화되면 실제 속도가 줄어서 덜 넘어짐 (성수 웅덩이 ×0.35 — 야만인 걷기 6.7 → 2.3)
	if p.cls != "barbarian":
		p.set_class("barbarian")
	p.spawn_at(SPOT)
	p.yaw = -PI / 2
	p.velocity = Vector3.ZERO
	p.trip_cd = 0.0
	p.scripted_input = inp(1.0)
	for i in 72:
		p.slow_t = 0.5
		await physics_frame
	p.scripted_input = inp(-1.0)
	var t2 := false
	for i in 12:
		p.slow_t = 0.5
		await physics_frame
		t2 = t2 or p.fall_t > 0
	check("둔화된 야만인은 반대로 꺾어도 안 넘어짐", not t2, "")
	print("ALL PASS" if fails == 0 else "FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

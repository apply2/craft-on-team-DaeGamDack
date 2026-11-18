extends SceneTree
## 히트박스 따라가기 + 눈에 띄는 화살 자동 테스트 (사용자 요청)
## - 몸이 흔들리면(걷기·달리기·춤) 머리·몸 판정이 모델을 따라가는지, 가만히 서면 원래 자리인지, 끄면 예전 그대로인지
## - 날아가는 화살·볼트: 빛 꼬리·크기 키우기, 꽂히면 원래 모습
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_hitbox.gd

var main: Node
var G: Node
var C
var p
var dm
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const RUN := {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": true}
const SPOT := Vector3(-25, 0, 18)


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = true
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	G0.ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func put(e, pos: Vector3, cls: String, yaw: float) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0
	e.velocity = Vector3.ZERO


## 고정 판정 머리 자리 (예전 계산)
func static_head(e) -> Vector3:
	return e.global_position + Vector3(0, e.mount_h + (1.1 if e.crouch else 1.62), 0)


## 모델에서 보이는 머리 자리를 캐릭터 실제(물리) 위치 기준으로 (보간 차이 빼고)
func visual_head(e) -> Vector3:
	return e.global_position + (e.model.head.global_position - e.model.global_position) + Vector3(0, e.mount_h, 0)


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	C = main.get_node("Combat")
	p = main.get_node("Player")
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], Vector3(60 + i * 3, 0, -60), "archer", 0.0)
	put(p, Vector3(60, 0, 60), "archer", 0.0)
	# 모델 머리 원점은 판정 머리보다 0.04m 위 (1.66 vs 1.62) — 그 차이는 그대로 두고 비교
	var rest: Vector3 = dm.model.neck.position + dm.model.head.position - Vector3(0, 1.62, 0)

	# ── 1. 가만히 서 있으면 원래 자리 ──
	put(dm, SPOT, "barbarian", 0.0)
	await wait(60)
	check("가만히 서면 판정이 원래 자리", dm.head_c().distance_to(static_head(dm)) < 0.02 and dm.model.hb_a.length() < 0.02,
		"머리 %.3f 엉덩이 %.3f" % [dm.head_c().distance_to(static_head(dm)), dm.model.hb_a.length()])

	# ── 2. 달리면 몸이 흔들리고 판정이 따라감 ──
	for cls in ["barbarian", "archer", "crossbow", "cleric", "bard"]:
		put(dm, SPOT, cls, 0.0)
		dm.scripted_input = RUN
		var max_sway := 0.0     # 고정 판정이었다면 보이는 머리와 벌어지는 거리
		var max_err := 0.0      # 따라가는 판정과 보이는 머리 차이
		for i in 100:
			await wait(1)
			if not dm.alive or dm.fall_amt() > 0:
				continue
			var vh: Vector3 = visual_head(dm) - rest
			max_sway = maxf(max_sway, vh.distance_to(static_head(dm)))
			max_err = maxf(max_err, vh.distance_to(dm.head_c()))
		check("%s 달리기: 판정 머리 = 보이는 머리" % cls, max_err < 0.03 and max_sway > 0.08,
			"고정 판정이면 최대 %.2fm 어긋남 → 지금 %.3fm" % [max_sway, max_err])
		dm.scripted_input = IDLE

	# ── 3. 흔들린 머리를 정확히 쏘면 머리에 맞음 ──
	put(dm, SPOT, "archer", 0.0)
	dm.scripted_input = RUN
	var best := 0.0
	var hit_on := false
	var hit_off := true
	for i in 120:
		await wait(1)
		var vh: Vector3 = visual_head(dm) - rest
		var off := Vector2(vh.x - static_head(dm).x, vh.z - static_head(dm).z).length()
		if off > best and dm.fall_amt() == 0.0:
			best = off
			# 옆에서 보이는 머리 가운데를 지나가는 선분
			var side := Vector3(vh.x - static_head(dm).x, 0, vh.z - static_head(dm).z).normalized()
			var tan := side.cross(Vector3.UP)
			var o: Vector3 = vh - tan * 3.0 + side * (G.HEAD_R * 0.5)  # 머리 가운데에서 바깥쪽으로 반지름 절반 비켜서
			var r: Dictionary = C.hit_test(o, tan * 6.0, dm, 0.0)
			hit_on = not r.is_empty() and r.head
			G.hitbox_follow = false
			var r2: Dictionary = C.hit_test(o, tan * 6.0, dm, 0.0)
			hit_off = not r2.is_empty() and r2.head
			G.hitbox_follow = true
	dm.scripted_input = IDLE
	check("흔들려 옆으로 간 머리 가장자리를 쏘면 머리", hit_on, "머리가 옆으로 %.2fm (예전 판정이면 머리 %s)" % [best, "맞음" if hit_off else "빗나감"])

	# ── 4. 춤추면 엉덩이 흔들기를 따라감 ──
	put(dm, SPOT, "archer", 0.0)
	await wait(10)
	dm.dance_t = 2.0
	var max_hip := 0.0
	for i in 60:
		await wait(1)
		dm.dance_t = maxf(dm.dance_t, 1.0)
		max_hip = maxf(max_hip, dm.model.hb_b.length())
	dm.dance_t = 0.0
	check("춤추면 몸 판정도 흔들림", max_hip > 0.1, "어깨 최대 %.2fm" % max_hip)

	# ── 5. 끄면 예전 고정 판정 ──
	dm.scripted_input = RUN
	await wait(30)
	G.hitbox_follow = false
	var same: bool = dm.head_c().is_equal_approx(static_head(dm)) and dm.body_a().is_equal_approx(dm.global_position + Vector3(0, 0.4, 0))
	G.hitbox_follow = true
	check("hitbox_follow = false면 예전 고정 판정", same, "")
	check("옮겨 가는 거리는 최대 %.1fm" % G.HITBOX_FOLLOW.max, dm.model.hb_head.length() <= G.HITBOX_FOLLOW.max + 1e-4, "%.2f" % dm.model.hb_head.length())
	dm.scripted_input = IDLE

	# ── 6. 눈에 띄는 화살 ──
	put(dm, Vector3(60, 0, -60), "archer", 0.0)
	put(p, SPOT, "archer", 0.0)
	await wait(5)
	for kind in ["bow", "crossbow"]:
		var F: Dictionary = G.ARROW_FLIGHT[kind]
		p.yaw = 0.0
		p.pitch = -0.25  # 앞쪽 땅에 꽂히게
		await wait(2)
		var n0: int = C.projectiles.size()
		p.cd = 0.0
		C.fire(p, kind, 1.0)
		var pr: Dictionary = C.projectiles[n0]
		var m: Node3D = pr.mesh
		var tr = m.get_node_or_null("Trail")
		check("%s: 빛 꼬리가 붙음" % kind, tr != null, "")
		await wait(1)
		var first_len: float = tr.scale.z if tr and tr.visible else 0.0
		var body: Node3D = m.get_child(0)
		var want := lerpf(1.0, float(F.scale), clampf(float(pr.travel) / float(F.grow), 0, 1))
		check("%s: 처음 %.0fm는 원래 크기에서 자라남 (1인칭 눈앞 가림 방지)" % [kind, F.grow], absf(body.scale.x - want) < 1e-3, "%.2f (%.2fm 날아감)" % [body.scale.x, pr.travel])
		var max_len := 0.0
		var max_scale := 0.0
		var stuck := false
		for i in 120:
			await physics_frame
			if not C.projectiles.has(pr):
				stuck = true
				break
			if tr.visible:
				max_len = maxf(max_len, tr.scale.z)
			max_scale = maxf(max_scale, body.scale.x)
		check("%s: 꼬리가 자람 (날아간 거리만큼, 최대 %.1fm)" % [kind, F.len], max_len > first_len and max_len <= float(F.len) + 1e-3, "%.2f → %.2f" % [first_len, max_len])
		check("%s: 날아가며 %.1f배로 커짐" % [kind, F.scale], max_scale > 1.2 and max_scale <= float(F.scale) + 1e-3, "%.2f" % max_scale)
		var w: Dictionary = C.world_arrows.back() if not C.world_arrows.is_empty() else {}
		var ok: bool = stuck and not w.is_empty() and w.m == m and m.get_node_or_null("Trail") == null and body.scale.is_equal_approx(Vector3.ONE)
		check("%s: 땅에 꽂히면 꼬리 없이 원래 크기" % kind, ok, "꽂힘 %s" % stuck)
		check("%s: 꽂힌 화살은 원래 재질" % kind, (body as MeshInstance3D).material_override == load("res://scripts/meshes.gd").shared_vc_mat(), "")

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

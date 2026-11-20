extends SceneTree
## 포병 발사음 확인 (진짜 오디오 장치 필요 — 헤드리스면 소리가 꺼져서 안 됨):
##   godot --path . --resolution 1280x720 -s tests/check_shot_audio.gd
## 내 발사음(위치 없음) · 가까운/먼(55m) 봇 발사음(3D)의 실제 플레이어 값, 연속 발사 때 서로 다른 플레이어가 동시에 나는지,
## 3D 감쇠로 들리는 크기(dB)를 출력한다. "SHOT OK" / "SHOT FAIL"

var main: Node
var G: Node
var fails := 0


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.ai_enabled = false
	G.mode = "ffa"
	G.chosen_cls = "cannoneer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	_run()


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func _run() -> void:
	for i in 40:
		await physics_frame
	var S = root.get_node("Sfx")
	check("오디오 켜짐 (헤드리스 아님)", S.enabled)
	var cam := root.get_camera_3d()
	var me = main.player
	# 내 발사음
	S.play_shot("cannon", me.global_position, true)
	await process_frame
	var mine: Array = S._pool.filter(func(p): return p.playing and p.stream and p.stream.resource_path.ends_with("artillery_fire_bmat.ogg"))
	check("내 발사음: 위치 없는 플레이어 · 0dB · SFX 버스", mine.size() == 1 and absf(mine[0].volume_db) < 0.01 and mine[0].bus == &"SFX",
		"n=%d db=%s" % [mine.size(), str(mine[0].volume_db) if mine.size() else "-"])
	# 남의 발사음: 가까이(8m)·멀리(55m)
	var fwd := -cam.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	for d in [8.0, 55.0]:
		var pos: Vector3 = cam.global_position + fwd * float(d)
		S.play_shot("cannon", pos, false)
		await process_frame
		var p3: AudioStreamPlayer3D = null
		for q in S._pool3d:
			if q.playing and q.global_position.distance_to(pos) < 0.01:
				p3 = q
		var dist: float = cam.global_position.distance_to(pos)
		# Godot inverse distance: db = volume_db + linear_to_db(unit_size / 거리), max_db로 자름
		var heard := minf(p3.volume_db + linear_to_db(p3.unit_size / dist), p3.max_db) if p3 else -99.0
		check("남의 발사음 %.0fm: 3D · inverse · unit 10 · 80m · SFX · 들리는 크기 %.1fdB" % [d, heard],
			p3 != null and p3.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and p3.unit_size == 10.0
			and p3.max_distance == 80.0 and p3.bus == &"SFX" and heard > -15.0)
	# 연속 발사: 8발을 0.1초 간격 → 모두 서로 다른 플레이어로 동시에 (앞 소리가 다 끝난 뒤 시작)
	for k in 200:
		await process_frame
	for i in 8:
		S.play_shot("cannon", cam.global_position + fwd * (10.0 + i), false)
		for k in 6:
			await process_frame
	var busy: int = S._pool3d.filter(func(q): return q.playing).size()
	check("연속 8발: 3D 플레이어 8개가 겹쳐 나는 중 (앞 소리를 끊지 않음)", busy == 8, "playing %d" % busy)
	print("SHOT OK" if fails == 0 else "SHOT FAIL %d" % fails)
	quit()

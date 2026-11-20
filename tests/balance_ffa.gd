extends SceneTree
## 개인전 밸런스 분석 (사용자 요청): 봇 7명이 병과 하나씩 맡아(죽어도 병과 고정) 개인전을 여러 판 돌리고 병과별 성적을 모은다.
## 판마다 병과↔봇 자리를 돌려서 자리 운을 없앰. 나는 구경 (메뉴 뒤 구경과 같은 상태).
## 실행 (헤드리스, 화면 필요 없음 — 실제 시간보다 훨씬 빨리 돎):
##   godot --headless --fixed-fps 60 --path . -s tests/balance_ffa.gd -- matches=10 secs=240 items=1 diff=normal tag=now
## 결과: 표를 출력하고 tests/balance/ffa_<tag>.json에 저장
## 여러 개를 동시에 돌린 뒤 합치기: ... -s tests/balance_ffa.gd -- merge=a1,a2,a3 tag=a (판 수·통계를 더해서 같은 표)
##   items=0이면 특수 아이템(저격총·AK·말·닭·황금 붕어빵)을 안 나오게 → 병과끼리만 비교

var M: Node
var G: Node
var C
var matches := 10
var secs := 240.0
var items := true
var diff := "normal"
var tag := "now"
var merge := ""
var speed := 0.0      # > 0이면 --fixed-fps 없이 Engine.time_scale로 빨리 (화면 프레임 한 번에 물리 여러 번)

var classes: Array = []
var st := {}          # 병과 → 통계
var mk := {}          # 죽인 병과 → {죽은 병과: 수}
var md := {}          # 때린 병과 → {맞은 병과: 피해}
var by_kind := {}     # 병과 → {처치 무기: 수}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"matches": matches = int(kv[1])
			"secs": secs = float(kv[1])
			"items": items = kv[1] != "0"
			"diff": diff = kv[1]
			"tag": tag = kv[1]
			"speed": speed = float(kv[1])
			"merge": merge = kv[1]
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.difficulty = diff
	G.ai_enabled = true
	if merge != "":
		_merge()
		quit()
		return
	if speed > 0:
		Engine.max_physics_steps_per_frame = 64
		Engine.time_scale = speed
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	_run()


func _blank() -> Dictionary:
	return {"kills": 0, "deaths": 0, "suicides": 0, "dealt": 0.0, "taken": 0.0, "self": 0.0, "burn": 0.0,
		"alive_t": 0.0, "lives": 0, "heads": 0, "first": 0, "wins": 0, "place_sum": 0.0}


func _own(c: String, kind: String) -> bool:
	var w: String = G.CLASSES[c].weapon
	return kind == w or (c == "bard" and kind == "fanfare") or (c == "vampire" and kind == "bat")


func _no_items() -> void:
	var it = C.items
	it.sniper_timer = 9999.0
	it.ak_timer = 9999.0
	it.horse_timer = 9999.0
	it.fish_timer = 9999.0
	it.chicken_timer = 9999.0
	if not it.chickens.is_empty():
		for c in it.chickens:
			(c.body as Node).queue_free()
		it.chickens.clear()


func _run() -> void:
	for i in 5:
		await physics_frame
	C = M.get_node("Combat")
	classes = (G.CLASS_ORDER as Array).duplicate()
	for c in classes:
		st[c] = _blank()
		mk[c] = {}
		md[c] = {}
		by_kind[c] = {}
		for c2 in classes:
			mk[c][c2] = 0
			md[c][c2] = 0.0
	C.killed.connect(_on_kill)
	C.dealt.connect(_on_dealt)
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	if bots.size() != classes.size():
		push_warning("봇 %d명 · 병과 %d개 — 앞에서부터 짝지음" % [bots.size(), classes.size()])
	var t0 := Time.get_ticks_msec()
	var frames := int(secs * 60.0)
	var dt := 1.0 / 60.0
	for m in matches:
		C.clear_match_objects()
		if not items:
			_no_items()
		for i in bots.size():
			var b = bots[i]
			b.bot_cls_fixed = true
			b.next_cls = classes[(i + m) % classes.size()]  # 판마다 자리 돌림
			b.kills = 0
			b.deaths = 0
			b.alive = false
		for b in bots:
			C.spawn(b)
			st[b.next_cls].lives += 1
		for f in frames:
			if speed > 0 and Engine.time_scale != speed:  # 메뉴 정리 등이 1로 되돌릴 수 있어서
				Engine.time_scale = speed
			await physics_frame
			if not items and f % 60 == 0:
				_no_items()
			for b in bots:
				if b.alive:
					st[b.cls].alive_t += dt
		# 판 순위 (처치 많은 순, 같으면 죽음 적은 순)
		var order: Array = bots.duplicate()
		order.sort_custom(func(x, y): return x.kills > y.kills or (x.kills == y.kills and x.deaths < y.deaths))
		for r in order.size():
			var c: String = order[r].cls
			st[c].place_sum += r + 1
			if r == 0:
				st[c].wins += 1
		print("판 %d/%d 끝 (%.0f초 걸림) 1등 %s %d킬" % [m + 1, matches, (Time.get_ticks_msec() - t0) / 1000.0, G.CLASSES[order[0].cls].name, order[0].kills])
	_report()
	quit()


## 따로 돌린 결과 JSON들을 더해서 표 하나로
func _merge() -> void:
	matches = 0
	for t in merge.split(","):
		var txt := FileAccess.get_file_as_string("res://tests/balance/ffa_%s.json" % t)
		var d: Dictionary = JSON.parse_string(txt)
		if classes.is_empty():
			classes = (G.CLASS_ORDER as Array).duplicate()
			for c in classes:
				st[c] = _blank()
				mk[c] = {}
				md[c] = {}
				by_kind[c] = {}
				for c2 in classes:
					mk[c][c2] = 0
					md[c][c2] = 0.0
		matches += int(d.matches)
		secs = float(d.secs)
		diff = str(d.diff)
		items = bool(d.items)
		for c in classes:
			for k in st[c]:
				st[c][k] += d.stats[c][k]
			for c2 in classes:
				mk[c][c2] += int(d.kills[c][c2])
				md[c][c2] += float(d.damage[c][c2])
			for k in d.by_kind[c]:
				by_kind[c][k] = int(by_kind[c].get(k, 0)) + int(d.by_kind[c][k])
	_report()


func _on_kill(v, a, kind: String, head: bool) -> void:
	if not v.is_bot:
		return
	var vc: String = v.cls
	st[vc].deaths += 1
	if a == null or a == v or not a.is_bot:
		st[vc].suicides += 1
		return
	var ac: String = a.cls
	st[ac].kills += 1
	if head:
		st[ac].heads += 1
	mk[ac][vc] += 1
	var k := kind if not _own(ac, kind) else "병과 무기"
	by_kind[ac][k] = int(by_kind[ac].get(k, 0)) + 1


func _on_dealt(v, a, amt: float, kind: String) -> void:
	if not v.is_bot:
		return
	st[v.cls].taken += amt
	if kind == "burn":
		st[v.cls].burn += amt
		return
	if a == null or not a.is_bot:
		return
	if a == v:
		st[v.cls].self += amt
		return
	st[a.cls].dealt += amt
	md[a.cls][v.cls] += amt


func _report() -> void:
	var mins := matches * secs / 60.0
	print("")
	print("== 개인전 밸런스: %d판 × %.0f초 · 난이도 %s · 특수 아이템 %s ==" % [matches, secs, diff, "있음" if items else "없음"])
	print("병과      분당킬  분당죽음  K/D   분당피해  분당받음  평균생존  1등  평균순위  자멸  헤드샷%")
	var rows: Array = classes.duplicate()
	rows.sort_custom(func(x, y): return st[x].kills > st[y].kills)
	for c in rows:
		var s: Dictionary = st[c]
		var life: float = s.alive_t / maxf(1.0, float(s.deaths + matches))  # 판 끝에 살아 있던 목숨까지 셈
		print("%-8s  %5.2f  %6.2f  %5.2f  %7.1f  %7.1f  %6.1f초  %3d  %6.2f  %4d  %5.0f%%" % [
			G.CLASSES[c].name, s.kills / mins, s.deaths / mins, float(s.kills) / maxf(1.0, float(s.deaths)),
			s.dealt / mins, s.taken / mins, life, s.wins, s.place_sum / matches, s.suicides,
			100.0 * s.heads / maxf(1.0, float(s.kills))])
	print("")
	print("상성 (줄 = 죽인 병과, 칸 = 죽은 병과. 숫자 = 처치 수)")
	var head := "          "
	for c in classes:
		head += "%-6s" % str(G.CLASSES[c].name).substr(0, 3)
	print(head)
	for c in classes:
		var line := "%-8s  " % G.CLASSES[c].name
		for c2 in classes:
			line += "%-6d" % mk[c][c2]
		print(line)
	print("")
	print("처치 무기 (병과 무기 / 특수 아이템)")
	for c in classes:
		print("%-8s %s" % [G.CLASSES[c].name, str(by_kind[c])])
	if st.has("vampire"):
		print("흡혈귀 화상으로 받은 피해: 분당 %.1f (받은 피해의 %.0f%%)" % [st.vampire.burn / mins, 100.0 * st.vampire.burn / maxf(1.0, st.vampire.taken)])
	var out := {"matches": matches, "secs": secs, "diff": diff, "items": items, "stats": st, "kills": mk, "damage": md, "by_kind": by_kind}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/balance"))
	var fa := FileAccess.open("res://tests/balance/ffa_%s.json" % tag, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	print("saved res://tests/balance/ffa_%s.json" % tag)

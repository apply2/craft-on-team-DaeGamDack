extends SceneTree
## 쟁탈전 밸런스 분석 (사용자 요청): 5대5 쟁탈전을 봇 10명으로 여러 판 돌리고 병과별 성적을 모은다.
## 나(Player)에게도 봇 AI를 붙여 블루 한 자리를 맡김. 판마다 팀마다 서로 다른 병과 5개를 무작위로 (죽어도 병과 고정).
## 스탯은 쟁탈전용 (GameData.MODE_STATS.control이 덮인 것 — Main._start_control이 적용).
## 실행 (헤드리스, 화면 필요 없음):
##   godot --headless --fixed-fps 60 --path . -s tests/balance_control.gd -- matches=2 items=1 diff=normal tag=now seed=1
## 결과: 표를 출력하고 tests/balance/ctrl_<tag>.json에 저장
## 여러 개를 동시에 돌린 뒤 합치기 (seed를 다르게!): ... -s tests/balance_control.gd -- merge=a1,a2,a3 tag=a

var M: Node
var G: Node
var C
var matches := 2
var items := true
var diff := "normal"
var tag := "now"
var merge := ""
var seed_n := 1
var max_secs := 900.0  # 한 판 상한 (3라운드 × 4분 + 라운드 사이)

var classes: Array = []
var st := {}          # 병과 → 통계
var sides := {"blue": 0, "red": 0, "draw": 0}  # 판 승리 팀 (맵 좌우 치우침 확인)
var game_secs := 0.0  # 모든 판 합친 경기 시간
var rounds := 0
var _rteam := {}      # 이번 판: 병과 → [팀...] (라운드 승패를 병과에 나눠 줌)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"matches": matches = int(kv[1])
			"items": items = kv[1] != "0"
			"diff": diff = kv[1]
			"tag": tag = kv[1]
			"merge": merge = kv[1]
			"seed": seed_n = int(kv[1])
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.difficulty = diff
	G.ai_enabled = true
	G.mode = "control"
	classes = (G.CLASS_ORDER as Array).duplicate()
	for c in classes:
		st[c] = _blank()
	if merge != "":
		_merge()
		quit()
		return
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	_run()


func _blank() -> Dictionary:
	return {"slots": 0, "mins": 0.0, "kills": 0, "deaths": 0, "suicides": 0, "dealt": 0.0, "taken": 0.0, "heal_dmg": 0.0,
		"alive_t": 0.0, "cap_t": 0.0, "rounds": 0, "round_wins": 0, "matches": 0, "match_wins": 0, "heads": 0}


func _no_items() -> void:
	var it = C.items
	it.sniper_timer = 9999.0
	it.ak_timer = 9999.0
	it.horse_timer = 9999.0
	it.fish_timer = 9999.0


func _run() -> void:
	await physics_frame
	await physics_frame
	C = M.get_node("Combat")
	var p = M.get_node("Player")
	p.ai = load("res://scripts/bot_ai.gd").new()  # 나도 봇처럼 (Player._read_input은 ai가 있으면 AI 입력을 씀)
	C.killed.connect(_on_kill)
	C.dealt.connect(_on_dealt)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 7919 + 13
	var t0 := Time.get_ticks_msec()
	var dt := 1.0 / 60.0
	for m in matches:
		# 팀마다 서로 다른 병과 5개 (블루 첫 자리 = 나)
		var n := int(G.MODES.control.team_size)
		var picks := {}
		for t in ["blue", "red"]:
			var pool: Array = classes.duplicate()
			var arr: Array = []
			for i in n:
				arr.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
			picks[t] = arr
		G.chosen_cls = picks.blue[0]
		var bots: Array = M.bots
		for i in n * 2 - 1:  # Main._start_control: 앞 4명 블루, 다음 5명 레드
			var b = bots[i]
			b.bot_cls_fixed = true
			b.next_cls = picks.blue[i + 1] if i < n - 1 else picks.red[i - (n - 1)]
		M.start_match()
		await physics_frame
		var mode = M.mode
		if not items:
			_no_items()
		mode.round_over.connect(_on_round)
		var ents: Array = C.ents.duplicate()
		_rteam.clear()
		for e in ents:
			var c: String = e.next_cls if e.next_cls != "" else e.cls
			if e.cls != c and e.alive:
				c = e.cls
			st[c].slots += 1
			st[c].matches += 1
			(_rteam.get_or_add(c, []) as Array).append(e.team)
		var f := 0
		while f < int(max_secs * 60.0):
			await physics_frame
			f += 1
			if not items and f % 60 == 0:
				_no_items()
			for e in ents:
				if e.alive:
					st[e.cls].alive_t += dt
			if mode.phase == "over" or M.state == "ended":
				break
		var secs := f * dt
		game_secs += secs
		for e in ents:
			st[e.cls].cap_t += e.cap_time
			st[e.cls].mins += secs / 60.0
		var w: String = mode.match_winner
		sides[w if w != "" else "draw"] += 1
		for c in _rteam:
			for t in _rteam[c]:
				if t == w:
					st[c].match_wins += 1
		print("판 %d/%d 끝 (게임 %.0f초, %.0f초 걸림) %s 승리 %d:%d · 블루 %s / 레드 %s" % [m + 1, matches, secs, (Time.get_ticks_msec() - t0) / 1000.0,
			w if w != "" else "무승부", mode.wins.blue, mode.wins.red, _names(picks.blue), _names(picks.red)])
		if M.state == "ended":  # 결과 화면 연출(느린 화면)을 되돌리고 다음 판
			M.menu.show_screen("")
			Engine.time_scale = 1.0
	_report()
	quit()


func _names(a: Array) -> String:
	return ",".join(a.map(func(c): return str(G.CLASSES[c].name)))


func _on_round(w: String) -> void:
	rounds += 1
	for c in _rteam:
		for t in _rteam[c]:
			st[c].rounds += 1
			if t == w:
				st[c].round_wins += 1


func _on_kill(v, a, kind: String, head: bool) -> void:
	st[v.cls].deaths += 1
	if a == null or a == v:
		st[v.cls].suicides += 1
		return
	st[a.cls].kills += 1
	if head:
		st[a.cls].heads += 1


func _on_dealt(v, a, amt: float, kind: String) -> void:
	st[v.cls].taken += amt
	if a == null or a == v:
		return
	st[a.cls].dealt += amt


## 따로 돌린 결과 JSON들을 더해서 표 하나로
func _merge() -> void:
	matches = 0
	for t in merge.split(","):
		var fa := FileAccess.open("res://tests/balance/ctrl_%s.json" % t, FileAccess.READ)
		if fa == null:
			push_warning("없음: " + t)
			continue
		var d: Dictionary = JSON.parse_string(fa.get_as_text())
		matches += int(d.matches)
		game_secs += float(d.game_secs)
		rounds += int(d.rounds)
		items = bool(d.items)
		diff = str(d.diff)
		for k in sides:
			sides[k] += int(d.sides.get(k, 0))
		for c in classes:
			for k in st[c]:
				st[c][k] += d.stats[c].get(k, 0)
	_report()


func _report() -> void:
	print("")
	print("== 쟁탈전 밸런스: %d판 (평균 %.1f분, 라운드 %d) · 난이도 %s · 특수 아이템 %s · 판 승리 블루 %d / 레드 %d / 무승부 %d ==" % [
		matches, game_secs / 60.0 / maxf(1.0, matches), rounds, diff, "있음" if items else "없음", sides.blue, sides.red, sides.draw])
	print("병과      출전  분당킬  분당죽음  K/D   분당피해  분당받음  평균생존  거점(초/분)  라운드승률  판승률  자멸  헤드샷%")
	var rows: Array = classes.duplicate()
	rows.sort_custom(func(x, y): return _rwr(x) > _rwr(y))
	for c in rows:
		var s: Dictionary = st[c]
		var mins: float = maxf(0.01, s.mins)
		var life: float = s.alive_t / maxf(1.0, float(s.deaths + s.slots))
		print("%-8s  %4d  %5.2f  %6.2f  %5.2f  %7.1f  %7.1f  %6.1f초  %8.1f  %8.0f%%  %5.0f%%  %4d  %5.0f%%" % [
			G.CLASSES[c].name, s.slots, s.kills / mins, s.deaths / mins, float(s.kills) / maxf(1.0, float(s.deaths)),
			s.dealt / mins, s.taken / mins, life, s.cap_t / mins, 100.0 * _rwr(c),
			100.0 * s.match_wins / maxf(1.0, float(s.matches)), s.suicides, 100.0 * s.heads / maxf(1.0, float(s.kills))])
	var out := {"matches": matches, "game_secs": game_secs, "rounds": rounds, "diff": diff, "items": items, "sides": sides, "stats": st}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/balance"))
	var fa := FileAccess.open("res://tests/balance/ctrl_%s.json" % tag, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	print("saved res://tests/balance/ctrl_%s.json" % tag)


func _rwr(c: String) -> float:
	return float(st[c].round_wins) / maxf(1.0, float(st[c].rounds))

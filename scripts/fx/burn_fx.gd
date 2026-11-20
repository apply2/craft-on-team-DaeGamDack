class_name BurnFx
extends Node3D
## 흡혈귀 햇빛 화상 연출 (사용자 요청 새 병과) — Combat 아래 BurnFx 노드. 보기만 함 (판정과 무관, 친구대전에서도 안 보냄).
## 살아 있는 흡혈귀마다 몸 둘레에서 작은 불꽃이 피어올라 꺼지고, 그 위로 회색 연기가 올라간다 → 멀리서도 흡혈귀인 걸 알 수 있게.
## 불꽃·연기는 MultiMesh 하나씩 (그리기 2번, 전체 VAMP_FX.pool개까지). 수치는 GameData.VAMP_FX.
## 1인칭인 나는 내 몸 둘레엔 안 뿌림 (화면을 가림) — 내 화면은 hud BurnEdge가 맡음.

var combat: Combat

var _flame: MultiMeshInstance3D
var _smoke: MultiMeshInstance3D
var _fl: Array[Dictionary] = []   # {p, v, life, max, size, col}
var _sm: Array[Dictionary] = []
var _acc := {}                    # 캐릭터 → [불꽃 쌓인 시간, 연기 쌓인 시간]


static func _mat(add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	return m


func _make(mesh: Mesh, add: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = int(GameData.VAMP_FX.pool)
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-400, -60, -400), Vector3(800, 200, 800))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat(add)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ready() -> void:
	_flame = _make(Meshes.stone(), true)
	_smoke = _make(Meshes.stone(), false)


## 시작할 때 셰이더를 미리 데울 재질 (처음 흡혈귀가 나올 때 멈칫하지 않게)
func keep_mats() -> Array:
	return [_flame.material_override, _smoke.material_override]


func clear() -> void:
	_fl.clear()
	_sm.clear()
	_acc.clear()
	_flame.multimesh.visible_instance_count = 0
	_smoke.multimesh.visible_instance_count = 0


func _process(dt: float) -> void:
	if not combat:
		return
	var F: Dictionary = GameData.VAMP_FX
	var cols: Array = F.flame_cols
	for e in combat.ents:
		if not e.alive or e.cls != "vampire":
			continue
		if e.is_local and not combat.tp_on():
			continue
		var a: Array = _acc.get(e, [0.0, 0.0])
		var base := e.global_position + Vector3(0, e.mount_h, 0)
		var r := float(F.flame_r)
		a[0] += dt
		while a[0] >= float(F.flame_every):
			a[0] -= float(F.flame_every)
			var ang := randf_range(0, TAU)
			var p := base + Vector3(cos(ang) * r * randf_range(0.4, 1.0), randf_range(0.3, 1.9), sin(ang) * r * randf_range(0.4, 1.0))
			_add(_fl, p, Vector3(randf_range(-0.2, 0.2), float(F.flame_up) * randf_range(0.7, 1.3), randf_range(-0.2, 0.2)),
				float(F.flame_life) * randf_range(0.7, 1.2), float(F.flame_size) * randf_range(0.6, 1.3), GameData.col(int(cols[randi() % cols.size()])))
		a[1] += dt
		while a[1] >= float(F.smoke_every):
			a[1] -= float(F.smoke_every)
			var p2 := base + Vector3(randf_range(-0.25, 0.25), randf_range(1.4, 2.1), randf_range(-0.25, 0.25))
			var sc := GameData.col(int(F.smoke_col))
			sc.a = float(F.smoke_alpha)
			_add(_sm, p2, Vector3(randf_range(-0.15, 0.15), float(F.smoke_up) * randf_range(0.7, 1.2), randf_range(-0.15, 0.15)),
				float(F.smoke_life) * randf_range(0.8, 1.2), float(F.smoke_size) * randf_range(0.7, 1.3), sc)
		_acc[e] = a
	for e in _acc.keys():  # 죽었거나 사라진 캐릭터
		if not is_instance_valid(e) or not combat.ents.has(e) or not e.alive:
			_acc.erase(e)
	_draw(_fl, _flame.multimesh, dt, true)
	_draw(_sm, _smoke.multimesh, dt, false)


func _add(list: Array[Dictionary], p: Vector3, v: Vector3, life: float, size: float, col: Color) -> void:
	if list.size() >= int(GameData.VAMP_FX.pool):
		list.pop_front()
	list.append({"p": p, "v": v, "life": life, "max": life, "size": size, "col": col, "rot": randf_range(0, TAU)})


func _draw(list: Array[Dictionary], mm: MultiMesh, dt: float, flame: bool) -> void:
	var i := 0
	while i < list.size():
		var q: Dictionary = list[i]
		q.life -= dt
		if q.life <= 0:
			list.remove_at(i)
			continue
		q.p += (q.v as Vector3) * dt
		i += 1
	var n := list.size()
	for k in n:
		var q: Dictionary = list[k]
		var t: float = q.life / q.max   # 1 → 0
		var sc: float
		if flame:  # 불꽃: 세로로 길쭉하게 피었다가 작아지며 꺼짐
			sc = float(q.size) * minf(1.0, (1.0 - t) * 6.0) * (0.3 + 0.7 * t)
		else:      # 연기: 점점 커지며 흐려짐
			sc = float(q.size) * (0.6 + (1.0 - t) * 1.4)
		var b := Basis(Vector3.UP, q.rot).scaled(Vector3(sc, sc * (1.8 if flame else 1.0), sc) if sc > 0.001 else Vector3.ONE * 0.001)
		mm.set_instance_transform(k, Transform3D(b, q.p))
		var c: Color = q.col
		c.a = (t if flame else c.a * t)
		mm.set_instance_color(k, c)
	mm.visible_instance_count = n


## 테스트용
func count() -> int:
	return _fl.size() + _sm.size()

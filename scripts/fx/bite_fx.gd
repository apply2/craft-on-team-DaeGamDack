class_name BiteFx
extends Node3D
## 흡혈귀 물기 효과 (사용자 요청 — "공격 범위가 안 보임"). Combat 아래 BiteFx 노드. 보기만 함 (판정과 무관, 친구대전에서도 안 보냄 —
## 남이 문 것도 Vampire.bite_fx가 각자 부름). 수치는 GameData.BITE_FX.
##   부채꼴: 물 때 발밑에서 바라보는 쪽 바닥으로 빨간 부채꼴이 휙 펼쳐졌다 사라짐 → 물기 범위(거리·각도)가 그대로 보임
##     (눈높이에 수평으로 두면 1인칭에선 선으로만 보여서 바닥에 깖)
##   유령 틀니: 문 자리(빗나가면 범위 끝)에 커다란 반투명 틀니가 흡혈귀 쪽을 보고 "딱!" 다물렸다 커지며 사라짐
## 노드는 pool개씩 미리 만들어 돌려 씀 (재질도 노드마다 하나 — 흐려지는 정도가 달라서)

var _fans: Array[Dictionary] = []   # {m: MeshInstance3D, mat, t, life}
var _jaws: Array[Dictionary] = []   # {g, up, lo, mats: [tooth, gum], t, a, base}
var _fan_i := 0
var _jaw_i := 0
static var _fan_mesh: ArrayMesh


## vc = 정점 색을 씀 (부채꼴). 밝은 흙길 위에서 하얗게 날아가지 않게 더하기 합성은 안 씀
static func _glow(vc: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.vertex_color_use_as_albedo = vc
	return m


## 반지름 1, 앞(-Z)을 보는 부채꼴. 안쪽은 옅고 끝 테두리(rim)는 진하게 (정점 색 알파)
static func fan_mesh() -> ArrayMesh:
	if _fan_mesh:
		return _fan_mesh
	var F: Dictionary = GameData.BITE_FX.fan
	var half := deg_to_rad(float(GameData.WEAPONS.teeth.half_angle))
	var n := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cin := GameData.col(int(F.col))
	var c0 := Color(cin.r, cin.g, cin.b, 0.12)
	var c1 := Color(cin.r, cin.g, cin.b, 0.75)
	var cr := GameData.col(int(F.rim_col))
	var r0 := 1.0 - float(F.rim)
	for i in n:
		var a0 := lerpf(-half, half, float(i) / n)
		var a1 := lerpf(-half, half, float(i + 1) / n)
		var p0 := Vector3(sin(a0), 0, -cos(a0))
		var p1 := Vector3(sin(a1), 0, -cos(a1))
		# 안쪽 (가운데 투명 → 테두리 앞 빨강)
		for v in [[Vector3.ZERO, c0], [p0 * r0, c1], [p1 * r0, c1]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
		# 끝 테두리 띠 (밝게)
		for v in [[p0 * r0, cr], [p0, cr], [p1, cr], [p0 * r0, cr], [p1, cr], [p1 * r0, cr]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	_fan_mesh = st.commit()
	return _fan_mesh


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var B: Dictionary = GameData.BITE_FX
	for i in int(B.pool):
		var m := MeshInstance3D.new()
		m.mesh = fan_mesh()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _glow(true)
		m.material_override = mat
		m.visible = false
		add_child(m)
		_fans.append({"m": m, "mat": mat, "t": 99.0})
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var mats: Array[StandardMaterial3D] = []
		var mk := func(hex: int) -> Material:
			var mm := _glow(false)
			mm.albedo_color = GameData.col(hex)
			mats.append(mm)
			return mm
		var j := WeaponModels.make_teeth(root, mk)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_jaws.append({"g": root, "up": j.up, "lo": j.lo, "mats": mats, "t": 99.0, "a": 1.0, "base": Basis()})


## 시작할 때 셰이더를 미리 데울 재질
func keep_mats() -> Array:
	return [(_fans[0].mat as Material), (_jaws[0].mats as Array)[0]]


## 물기 한 번: feet(발밑) 바닥에 dir 쪽 부채꼴, at에 유령 틀니. hit = 적을 물었나 (아니면 옅게)
func bite(feet: Vector3, dir: Vector3, at: Vector3, hit: bool) -> void:
	var B: Dictionary = GameData.BITE_FX
	if dir.length_squared() < 1e-6:
		return
	dir = dir.normalized()
	var reach := float(GameData.WEAPONS.teeth.range) + GameData.BODY_R
	var f: Dictionary = _fans[_fan_i]
	_fan_i = (_fan_i + 1) % _fans.size()
	f.t = 0.0
	f.reach = reach
	var flat := Vector3(dir.x, 0, dir.z)
	f.basis = _look(flat if flat.length_squared() > 1e-4 else Vector3.FORWARD)
	(f.m as MeshInstance3D).position = feet + Vector3(0, float(B.fan.y), 0)
	(f.m as MeshInstance3D).visible = true
	var j: Dictionary = _jaws[_jaw_i]
	_jaw_i = (_jaw_i + 1) % _jaws.size()
	j.t = 0.0
	j.a = float(B.jaw.alpha) if hit else float(B.jaw.miss_alpha)
	j.base = _look(dir)  # -Z = 문 방향 → 틀니 앞(+Z)은 흡혈귀 쪽을 봄
	(j.g as Node3D).position = at
	(j.g as Node3D).visible = true
	_tick_fan(f)
	_tick_jaw(j)


static func _look(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(dir, up)


func _process(dt: float) -> void:
	for f in _fans:
		if (f.m as MeshInstance3D).visible:
			f.t += dt
			_tick_fan(f)
	for j in _jaws:
		if (j.g as Node3D).visible:
			j.t += dt
			_tick_jaw(j)


func _tick_fan(f: Dictionary) -> void:
	var F: Dictionary = GameData.BITE_FX.fan
	var t: float = f.t
	if t >= float(F.life):
		(f.m as MeshInstance3D).visible = false
		return
	var g := clampf(t / float(F.grow), 0.0, 1.0)
	var r: float = float(f.reach) * (0.35 + 0.65 * (1.0 - pow(1.0 - g, 3.0)))  # 휙 펼쳐짐
	var w := 0.25 + 0.75 * g  # 좁았다가 원뿔 각도까지 벌어짐
	(f.m as MeshInstance3D).basis = (f.basis as Basis) * Basis.from_scale(Vector3(r * w, 1, r))
	var fade := 1.0 - clampf((t - float(F.grow)) / (float(F.life) - float(F.grow)), 0.0, 1.0)
	(f.mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, float(F.alpha) * fade)


func _tick_jaw(j: Dictionary) -> void:
	var J: Dictionary = GameData.BITE_FX.jaw
	var t: float = j.t
	if t >= float(J.life):
		(j.g as Node3D).visible = false
		return
	var snap := float(J.snap)
	var open := 1.0 - smoothstep(0.0, snap, t)
	(j.up as Node3D).rotation.x = -open * float(J.open_up)
	(j.lo as Node3D).rotation.x = open * float(J.open_lo)
	var k := clampf((t - snap) / (float(J.life) - snap), 0.0, 1.0)
	var sc := float(J.scale) * (0.85 + 0.15 * minf(1.0, t / snap) + float(J.pop) * k)
	(j.g as Node3D).basis = (j.base as Basis) * Basis.from_scale(Vector3.ONE * sc)
	var a: float = float(j.a) * (1.0 - k * k)
	for m: StandardMaterial3D in j.mats:
		m.albedo_color.a = a


func clear() -> void:
	for f in _fans:
		(f.m as MeshInstance3D).visible = false
	for j in _jaws:
		(j.g as Node3D).visible = false


## 테스트용: 지금 보이는 부채꼴·틀니 수
func count() -> int:
	return _fans.filter(func(f): return (f.m as MeshInstance3D).visible).size() + _jaws.filter(func(j): return (j.g as Node3D).visible).size()

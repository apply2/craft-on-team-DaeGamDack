class_name Cannon
extends Node3D
## 포병 대포 (사용자 요청 새 병과 — HTML에 없음). 수치는 GameData.WEAPONS.cannon·CLASSES.cannoneer.
## Combat 아래 "Cannon" 노드. 하는 일:
##   - explode(): 포탄이 터짐 → 폭발 효과·소리·화면 흔들림, 범위 피해(벽에 막히면 없음, 거리에 따라 줄어듦), 포탄 점프
##   - 우클릭 탄도 조준: 내 화면에 예상 궤적 점선 + 착탄 지점 고리 (보기만 함)
## 발사·재장전은 Combat.weapon_update / fire, 날아가는 건 Combat.update_projectiles (다른 투사체와 같은 판정).
## 친구대전: 포탄은 "f" 사건으로 모두의 화면에 만들어지고, 터지면 각자 자기 캐릭터(방장이면 + 봇)만 피해를 판정한다
##   (damage()가 is_remote를 걸러냄). 포탄 점프는 쏜 사람 컴퓨터에서만.

var combat: Combat
var _dots: MultiMeshInstance3D   # 예상 궤적 점
var _ring: MeshInstance3D        # 착탄 지점 고리 (반지름 = 폭발 반경)
var _dot_mat: StandardMaterial3D
var last_blast := Vector3.INF    # 마지막 폭발 자리 (테스트용)
var aim_hit: Variant = null      # 지금 탄도 조준이 가리키는 착탄 지점 (없으면 null)


func _ready() -> void:
	var W: Dictionary = GameData.WEAPONS.cannon
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_mat.no_depth_test = true  # 벽 너머로 넘어가는 궤적도 보이게
	_dot_mat.render_priority = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Meshes.puff()
	mm.instance_count = int(W.aim_dots)
	mm.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = mm
	_dots.material_override = _dot_mat
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dots.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dots.top_level = true
	add_child(_dots)
	_ring = MeshInstance3D.new()
	_ring.mesh = Meshes.flat_ring()
	_ring.material_override = combat._flat_mat(GameData.HOLY.rim_mine, 0.75, 4)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)


## 범위 피해: 몸(캡슐 겉면)까지 거리 d → blast_max에서 blast_min으로 선형. 반경 밖이면 0
static func blast_dmg(d: float) -> float:
	var W: Dictionary = GameData.WEAPONS.cannon
	var r := float(W.blast)
	if d > r:
		return 0.0
	return lerpf(float(W.blast_max), float(W.blast_min), clampf(d / r, 0.0, 1.0))


## 폭발 지점 pt에서 v까지: {d: 몸 겉면까지 거리, axis: 몸 가운데 선의 가장 가까운 점, ad: 그 점까지 거리}
static func reach(pt: Vector3, v: PlayerController) -> Dictionary:
	var a := v.body_a()
	var ab := v.body_b() - a
	var sp := Combat.seg_point(a, ab, pt)
	var axis := a + ab * float(sp.t)
	var ad := sqrt(float(sp.dist2))
	return {"d": maxf(0.0, ad - v.body_r()), "axis": axis, "ad": ad}


## 포탄이 터짐. direct = 직격당한 사람 (이미 WEAPONS.cannon.dmg를 받았으니 범위 피해는 빼고)
func explode(owner: PlayerController, pt: Vector3, direct: PlayerController = null) -> void:
	var W: Dictionary = GameData.WEAPONS.cannon
	var r := float(W.blast)
	last_blast = pt
	_fx(pt)
	for v in combat.ents:
		if not v.alive or v == direct:
			continue
		var R := reach(pt, v)
		var d: float = R.d
		if d > r:
			continue
		# 벽 뒤면 안 맞음: 몸 가운데 선이나 머리 중 하나라도 트여 있어야 함
		if not combat.los(pt, R.axis) and not combat.los(pt, v.head_c()):
			continue
		var f := clampf(d / r, 0.0, 1.0)
		var dmg := blast_dmg(d)
		if v == owner:
			dmg *= float(W.self_mul)
		var off := Vector3(v.global_position.x - pt.x, 0, v.global_position.z - pt.z)
		var dir := off.normalized() if off.length_squared() > 1e-4 else Vector3.ZERO
		combat.damage(v, owner, dmg, "cannon", false, dir, R.axis, 1.0 - f)
		if v == owner and v.alive and not v.is_remote and float(R.ad) <= float(W.jump_r):
			blast_jump(v, dir)


## 발사 반동: 조준 반대쪽으로 recoil, 땅에 있으면 위로 recoil_up + recoil_t초 동안 미끄러지게. 세로 성분은 ±recoil_vmax.
## 내 컴퓨터가 판정하는 캐릭터(나·내 봇)만 부른다. 말 위에선 없음
static func fire_recoil(e: PlayerController, dir: Vector3) -> Vector3:
	var W: Dictionary = GameData.WEAPONS.cannon
	if e.mounted > 0:
		return Vector3.ZERO
	var r := -dir.normalized() * float(W.recoil)
	if e.grounded:
		r.y += float(W.recoil_up)
		e.recoil_t = float(W.recoil_t)
	var vm := float(W.recoil_vmax)
	r.y = clampf(r.y, -vm, vm)
	e.velocity += r
	e.kb_air = true  # 떠 있는 동안 속도 상한을 풀어 둠 (둔화·느린 걸음이 반동 속도를 안 깎게). 착지하면 풀림
	if e.grounded and r.y > 0:
		e.grounded = false
		e.sliding = false
	return r


## 포탄 점프: 위로 세게 + 폭발 반대쪽으로 조금. 착지할 때까지 공중 조작이 줄어든다 (player.blast_air)
static func blast_jump(e: PlayerController, away: Vector3) -> void:
	var W: Dictionary = GameData.WEAPONS.cannon
	if e.mounted > 0:  # 말 위에선 안 뜸
		return
	e.velocity.y = maxf(e.velocity.y, float(W.jump_up))
	e.velocity.x += away.x * float(W.jump_side)
	e.velocity.z += away.z * float(W.jump_side)
	e.grounded = false
	e.blast_air = true
	e.jumped = false  # 포탄 점프 착지는 '점프 착지 넘어짐'에 안 걸림
	e.sliding = false


## 폭발 효과: 작은 주황 섬광 + 돌 파편 + 흙먼지·흙 조각 + 고리, 소리, 내 화면 흔들림 (가까울수록 크게)
## 효과 노드 수는 예전(33)과 비슷하게 (웹 그리기 호출) — 개수는 CANNON_LOOK.fx
func _fx(pt: Vector3) -> void:
	var W: Dictionary = GameData.WEAPONS.cannon
	var F: Dictionary = GameData.CANNON_LOOK.fx
	var fx := combat.fx
	fx.puff(pt, 0xfff2b0, 0.45, int(F.flash_n))
	fx.puff(pt, 0xff9a2e, 0.6, int(F.fire_n))
	fx.smoke(pt + Vector3(0, 0.3, 0), int(F.dust), float(F.dust_size), int(F.dust_n), Vector3.UP, 2.5, float(F.dust_life))
	fx.rocks(pt, int(F.rock), Vector3.UP, int(F.rock_n), 9.0)
	fx.chunks(pt, int(F.dirt), Vector3.UP, int(F.dirt_n), 8.0)
	fx.ring(pt, 0xffb347, float(W.blast), 0.35)
	Sfx.play("boom", pt)
	var me := combat.me
	if me and me.alive and me.is_local:
		var S: Dictionary = W.shake
		var dd := me.global_position.distance_to(pt)
		var k := clampf((float(S.far) - dd) / (float(S.far) - float(S.near)), 0.0, 1.0)
		if k > 0:
			me.shake = maxf(me.shake, float(S.max) * k)


## 발사 효과 (보기만): 점화 구멍에서 불꽃 + 포구에서 짙은 회백색 연기가 크게 퍼짐. 친구 포탄(remote_fire)도 같음.
## 3인칭으로 보이는 대포는 모델의 진짜 포구·점화 구멍 자리에서. 내 1인칭은 연기를 앞쪽 멀리·옅게 (조준을 가리지 않게),
## 불꽃은 1인칭 손 화면(ViewModel)이 따로 그림
func fire_fx(e: PlayerController, pos: Vector3, dir: Vector3) -> void:
	var F: Dictionary = GameData.CANNON_LOOK.fx
	var fx := combat.fx
	var fp := e.is_local and not combat.tp_on()
	var muzzle := pos
	var touch := Vector3.INF
	var bar: Node3D = e.model.barrel if e.model and e.model.barrel and e.model.barrel.is_visible_in_tree() else null
	if bar and not fp:
		var L: Dictionary = GameData.CANNON_LOOK
		muzzle = bar.global_transform * Vector3(0, 0, float(L.barrel_len) + 0.1)
		touch = bar.global_transform * Vector3(0, float(L.barrel_r) + 0.04, 0.06)
	if fp:
		fx.smoke(pos + dir * float(F.fp_ahead), int(F.smoke), float(F.smoke_size), int(F.smoke_n), dir, float(F.smoke_speed), float(F.smoke_life), float(F.fp_alpha))
	else:
		fx.smoke(muzzle + dir * 0.6, int(F.smoke), float(F.smoke_size), int(F.smoke_n), dir, float(F.smoke_speed), float(F.smoke_life))
		fx.puff(muzzle, 0xffb347, 0.2, 2)
		if touch != Vector3.INF:
			fx.puff(touch, int(F.spark), float(F.spark_size), int(F.spark_n))


## 우클릭 탄도 조준 (내 화면만): 실제로 쏠 때와 같은 자리·방향에서 궤적을 따라가 점을 찍고, 닿는 곳에 고리
func _process(_dt: float) -> void:
	var e := combat.me
	var W: Dictionary = GameData.WEAPONS.cannon
	if not e or not e.alive or not e.is_local or e.wep != "cannon" or not e.aim_held or e.fall_t > 0 or not e.cam:
		_dots.multimesh.visible_instance_count = 0
		_ring.visible = false
		aim_hit = null
		return
	var L := combat.local_launch(e, "cannon")
	# 포탄과 똑같은 적분 (Combat.update_projectiles: 위치 += 속도·dt 다음에 속도.y -= 중력·dt)을 닫힌 식으로:
	#   n프레임 뒤 위치 = p0 + v0·n·dt - (0, g·dt²·n(n-1)/2, 0)  → 속도·중력이 바뀌어도 착탄 지점이 실제 폭발과 같다
	var p0: Vector3 = L.pos
	var v0: Vector3 = (L.dir as Vector3) * float(W.speed)
	var g := float(W.grav)
	var fdt := 1.0 / float(Engine.physics_ticks_per_second)
	var every := maxi(1, int(W.aim_every))
	var last_n := int(ceil(float(W.fuse) / fdt))
	var pts: Array[Vector3] = [p0]
	var hit: Variant = null
	var prev := p0
	var n := 0
	while n < last_n:
		n = mini(n + every, last_n)
		var q := p0 + v0 * (n * fdt) - Vector3(0, g * fdt * fdt * n * (n - 1) / 2.0, 0)
		var tw := combat.world_ray(prev, q - prev)
		if tw <= 1:
			hit = prev + (q - prev) * tw
			pts.append(hit)
			break
		pts.append(q)
		prev = q
	if hit == null:  # 아무 데도 안 닿으면 fuse초에 공중에서 터지는 곳
		hit = prev
	aim_hit = hit
	var ready := e.cn_t <= 0
	_dot_mat.albedo_color = Color(GameData.col(0xffd27a if ready else 0xc9c9c9), 0.85 if ready else 0.5)
	# 점은 궤적 길이를 따라 고르게
	var mm := _dots.multimesh
	var cnt := mini(int(W.aim_dots), pts.size())
	for i in cnt:
		var idx := int(round(float(i) / float(maxi(1, cnt - 1)) * float(pts.size() - 1)))
		var sz := 0.05 + 0.03 * float(i) / float(maxi(1, cnt))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sz), pts[idx]))
	mm.visible_instance_count = cnt
	var hp: Vector3 = hit
	_ring.global_position = Vector3(hp.x, hp.y + 0.05, hp.z)
	_ring.scale = Vector3.ONE * float(W.blast)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.75 if ready else 0.35
	_ring.visible = true

class_name Vampire
## 흡혈귀 (사용자 요청 새 병과 — HTML에 없음). 수치는 GameData.CLASSES.vampire·WEAPONS.teeth·WEAPONS.bat·BURN.
## Trumpet처럼 상태는 PlayerController에 두고 여기엔 규칙만 (static).
##   물기(좌클릭): 눈에서 range 안, 조준 원뿔 안의 가장 가까운 적 1명. 맞히면 피해 + 회복 heal.
##   박쥐 돌진(우클릭): player._dash_move가 움직이고, Combat이 이동 다음에 tick()으로 부딪힘 판정.
##   화상: Combat._tick_timers가 burn()을 부른다 (내 컴퓨터가 정하는 캐릭터만).
## 친구대전: 물기·돌진은 저격총처럼 공격자 컴퓨터가 판정해서 사건("bt"·"bd")을 보내고, 맞은 쪽이 damage()를 적용한다.
##   회복은 공격자 컴퓨터가 바로 (체력은 상태로 맞춰짐). 화상은 흡혈귀 자기 컴퓨터가.


## 무기 칸과 상관없이 매 물리 프레임 (Combat.weapon_update 앞부분): 재사용 대기, 돌진 부딪힘
static func tick(combat: Combat, e: PlayerController, dt: float) -> void:
	e.bat_cd = maxf(0.0, e.bat_cd - dt)
	if e.dash_seg:
		e.dash_seg = false
		_dash_hits(combat, e)


## 공격 (춤·넘어짐·스폰룸 검사를 통과했을 때만 — Combat.weapon_update의 "teeth")
static func update(combat: Combat, e: PlayerController, held: bool) -> void:
	if e.dash_t > 0:  # 돌진 중엔 공격 못 함
		return
	if e.aim_held and e.bat_cd <= 0 and e.mounted <= 0:
		start_dash(combat, e)
		return
	if held and e.cd <= 0:
		bite(combat, e)


# ── 물기 ─────────────────────────────────────────────────────
## 물 대상: 조준선과 몸(엉덩이 → 머리) 선분의 가장 가까운 점이 range 안이고, 원뿔 안이거나 조준선이 몸에 닿으면.
## 벽 너머는 안 됨. 여럿이면 가장 가까운 한 명
static func bite_target(combat: Combat, e: PlayerController) -> PlayerController:
	var W: Dictionary = GameData.WEAPONS.teeth
	var R := float(W.range)
	var eye := e.eye_pos()
	var ad := e.aim_dir()
	var half := deg_to_rad(float(W.half_angle))
	var best: PlayerController = null
	var bd := INF
	for v in combat.ents:
		if v == e or not v.alive or Combat.ally(e, v):
			continue
		var a := v.body_a()
		var h := v.head_c()
		if eye.distance_to(a) > R + 3.0:
			continue
		var pts := Geometry3D.get_closest_points_between_segments(eye, eye + ad * R, a, h)
		var pv: Vector3 = pts[1]
		var to := pv - eye
		var br := v.body_r()
		var d := to.length() - br
		if d > R:
			continue
		var touch := (pts[0] as Vector3).distance_to(pv) <= br  # 조준선이 몸에 닿음
		if not touch and ad.angle_to(to) > half:
			continue
		if not combat.los(eye, pv):
			continue
		if d < bd:
			bd = d
			best = v
	return best


## 이 적을 물면 피를 빨 수 있나 (무적·스폰 무적·쟁탈전 라운드 사이엔 피해가 안 들어가니 회복도 없음)
static func can_feed(combat: Combat, v: PlayerController) -> bool:
	return v.alive and v.invuln <= 0 and v.star_t <= 0 and not (combat.mode and combat.mode.no_damage())


static func bite(combat: Combat, e: PlayerController) -> void:
	var W: Dictionary = GameData.WEAPONS.teeth
	e.cd = float(W.cd)
	var v := bite_target(combat, e)
	var fed := v != null and can_feed(combat, v)
	if combat.mp() and not e.is_remote:  # 나 (방장이면 내 봇도). 맞은 쪽 컴퓨터가 피해를 적용
		combat.net.event(["bt", v.peer if v else 0, fed], e)
	bite_fx(combat, e, v, fed)
	if v:
		combat.damage(v, e, float(W.dmg), "teeth", false, _flat_dir(e, v), _bite_pt(e, v))
	if fed:
		heal(combat, e, float(W.heal))


## 무는 모습·소리·피 (친구가 문 것도 — Combat.remote_bite)
static func bite_fx(combat: Combat, e: PlayerController, v: PlayerController, fed: bool) -> void:
	e.fire_anim = 1.0
	if e.is_local:
		e.vm_kick = 0.5
	Sfx.play("bite", e.global_position)
	# 범위가 보이게: 빨간 부채꼴 + 문 자리(빗나가면 범위 끝)에 유령 틀니가 딱 (BiteFx)
	var eye := e.eye_pos()
	var ad := e.aim_dir()
	var at := _bite_pt(e, v) if v else eye + ad * float(GameData.WEAPONS.teeth.range)
	if combat.bite_fx:
		combat.bite_fx.bite(e.global_position + Vector3(0, e.mount_h, 0), ad, at, v != null)
	if v:
		var VF: Dictionary = GameData.VAMP_FX
		combat.fx.chunks(_bite_pt(e, v), int(VF.blood_col), _flat_dir(e, v), int(VF.blood), 3.5)
		combat.fx.ring(_bite_pt(e, v), int(VF.blood_col), float(GameData.BITE_FX.ring), 0.25)
	if fed:
		heal_num(combat, e)


static func heal(combat: Combat, e: PlayerController, amt: float) -> void:
	e.hp = minf(float(GameData.class_hp(e.cls)), e.hp + amt)
	if not e.is_remote:
		heal_num(combat, e, amt)


## 처치 보너스: 흡혈귀가 처치하면 kill_heal 회복 (Combat.kill·remote_kill — 처치를 세는 컴퓨터에서만. 자멸은 안 옴)
static func on_kill(combat: Combat, a: PlayerController) -> void:
	if a.cls != "vampire" or not a.alive:
		return
	heal(combat, a, float(GameData.WEAPONS.teeth.kill_heal))


## 머리 위 초록 "+15" — 내 흡혈귀거나 내 카메라 근처일 때만 (봇끼리 싸우는 먼 곳까지 숫자가 뜨지 않게)
static func heal_num(combat: Combat, e: PlayerController, amt := -1.0) -> void:
	var me := combat.me
	if e.is_local or (me and me.global_position.distance_to(e.global_position) < 20.0):
		combat.num.emit(e.global_position + Vector3(0, e.mount_h + 2.2, 0), "+%d" % int(amt if amt > 0 else float(GameData.WEAPONS.teeth.heal)), "heal")


static func _flat_dir(e: PlayerController, v: PlayerController) -> Vector3:
	var d := Vector3(v.global_position.x - e.global_position.x, 0, v.global_position.z - e.global_position.z)
	return d.normalized() if d.length_squared() > 1e-4 else Vector3(-sin(e.yaw), 0, -cos(e.yaw))


static func _bite_pt(e: PlayerController, v: PlayerController) -> Vector3:
	return v.global_position + Vector3(0, v.mount_h + 1.1, 0) - _flat_dir(e, v) * v.body_r()


# ── 박쥐 돌진 ────────────────────────────────────────────────
static func start_dash(combat: Combat, e: PlayerController) -> void:
	var B: Dictionary = GameData.WEAPONS.bat
	var pm := deg_to_rad(float(B.pitch_max))
	var p := clampf(e.pitch, -pm, pm)
	e.dash_dir = Vector3(-sin(e.yaw) * cos(p), sin(p), -cos(e.yaw) * cos(p))
	e.dash_t = float(B.time)
	e.bat_cd = float(B.cd)
	e.grounded = false
	e.sliding = false
	dash_fx(combat, e)


static func dash_fx(combat: Combat, e: PlayerController) -> void:
	Sfx.play("bat", e.global_position)
	combat.fx.puff(e.global_position + Vector3(0, 1.0, 0), 0x2a2430, 0.35, 6)


## 돌진으로 움직인 선분(몸 가운데 높이)에 처음 걸린 적: 피해 + 멈춤 + 물기 1회 회복 + 물기 재사용 초기화
static func _dash_hits(combat: Combat, e: PlayerController) -> void:
	var B: Dictionary = GameData.WEAPONS.bat
	var up := Vector3(0, 1.0, 0)
	var o := e.dash_prev + up
	var d := e.global_position + up - o
	var best: PlayerController = null
	var bs := INF
	for v in combat.ents:
		if v == e or not v.alive or Combat.ally(e, v):
			continue
		var a := v.body_a()
		var r := Combat.seg_seg(o, d, a, v.head_c() - a)
		var rr := v.body_r() + float(B.r)
		if r.dist2 < rr * rr and float(r.s) < bs:
			bs = r.s
			best = v
	if not best:
		return
	var fed := can_feed(combat, best)
	if combat.mp():
		combat.net.event(["bd", best.peer, fed], e)
	var dir := Vector3(e.dash_dir.x, 0, e.dash_dir.z).normalized()
	combat.damage(best, e, float(B.dmg), "bat", false, dir, _bite_pt(e, best))
	e.global_position = o + d * bs - up  # 부딪힌 자리에서 멈춤
	e.dash_t = 0.0
	e.velocity = Vector3(0, minf(e.velocity.y, 0.0), 0)
	bite_fx(combat, e, best, false)
	if fed:
		heal(combat, e, float(GameData.WEAPONS.teeth.heal))
		e.cd = 0.0  # 물기 재사용 바로


# ── 햇빛 화상 ────────────────────────────────────────────────
## 내 컴퓨터가 정하는 흡혈귀만 (Combat._tick_timers). damage()를 안 거쳐서 마지막 공격자 기록이 안 덮임
static func burn(combat: Combat, e: PlayerController, dt: float) -> void:
	var T: Dictionary = GameData.BURN
	if e.burn_wait > 0:
		e.burn_wait -= dt
		return
	if e.star_t > 0 or (combat.mode and combat.mode.no_damage()):
		return
	e.burn_snd -= dt
	if e.burn_snd <= 0:
		e.burn_snd = float(T.snd_every)
		Sfx.play("burn", e.global_position)
	e.burn_acc += dt
	while e.burn_acc >= float(T.tick) - 1e-6:
		e.burn_acc -= float(T.tick)
		e.hp -= float(T.dmg)
		if e.hp <= 0:
			combat.kill(e, burn_killer(combat, e), "burn", false, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
			return


## 화상으로 죽으면 누가 처치했나: credit초 안에 때린 사람이 있으면 마지막으로 때린 사람, 아니면 자멸(자기)
static func burn_killer(combat: Combat, e: PlayerController) -> PlayerController:
	var lh := e.last_hit
	var a: Variant = lh.get("by")
	if a is PlayerController and is_instance_valid(a) and a != e and combat.ents.has(a) \
			and combat.clock - float(lh.get("t", -1e9)) <= float(GameData.BURN.credit):
		return a
	return e

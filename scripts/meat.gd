class_name Meat
## 야만인 우클릭 "고기 먹기" (사용자 요청 — HTML에 없음). 수치는 GameData.WEAPONS.meat.
## 상태는 PlayerController(meat_cd·eat_t)에 두고 여기엔 규칙만 (static, Trumpet·Vampire처럼).
##   돌멩이를 들고 있을 때 우클릭: 재사용 대기가 끝났으면 바로 heal 회복 + 상태이상 풀기, eat_t초 동안 먹는 모습 (돌 못 던짐)
##   춤추는 중·성수 웅덩이 안에서도 먹을 수 있다 (공격이 아니라서 — 풀려고 먹는 거니까). 넘어진 동안은 손을 못 써서 안 됨
## 친구대전: 회복·풀기는 먹은 사람 컴퓨터에서 (체력은 상태로 맞춰짐), 다른 사람 화면엔 사건 "eat"로 모습·소리만.


## 매 물리 프레임 (Combat.weapon_update 앞부분): 재사용 대기·먹는 시간
static func tick(e: PlayerController, dt: float) -> void:
	e.meat_cd = maxf(0.0, e.meat_cd - dt)
	e.eat_t = maxf(0.0, e.eat_t - dt)


## 먹을 수 있나: 야만인이 돌멩이를 들고, 살아 있고, 넘어지지 않았고, 대기가 끝났을 때
static func can_eat(e: PlayerController) -> bool:
	return e.cls == "barbarian" and e.wep == "stone" and e.alive and e.fall_t <= 0 and e.swap_t <= 0 and e.meat_cd <= 0


static func try_eat(combat: Combat, e: PlayerController) -> bool:
	if not e.aim_held or not can_eat(e):
		return false
	eat(combat, e)
	return true


static func eat(combat: Combat, e: PlayerController) -> void:
	var W: Dictionary = GameData.WEAPONS.meat
	e.meat_cd = float(W.cd)
	e.hp = minf(float(GameData.class_hp(e.cls)), e.hp + float(W.heal))
	cleanse(e)
	eat_fx(combat, e)
	if combat.mp() and not e.is_remote:  # 나 (방장이면 내 봇도) → 남의 화면엔 모습·소리만
		combat.net.event(["eat"], e)


## 상태이상 풀기: 춤(+ 쌓이던 춤 게이지), 성수 둔화, 봇 경직. 넘어짐은 이동 규칙이라 안 건드림
static func cleanse(e: PlayerController) -> void:
	e.dance_t = 0.0
	e.dance_log.clear()
	e.dance_by.clear()
	e.slow_t = 0.0
	e.stagger = 0.0


## 먹는 모습·소리·부스러기·초록 "+30" (친구가 먹은 것도 — Combat.remote_eat)
static func eat_fx(combat: Combat, e: PlayerController) -> void:
	var W: Dictionary = GameData.WEAPONS.meat
	e.eat_t = float(W.eat_t)
	if e.is_local:
		e.vm_kick = 0.3
	Sfx.play("nyam", e.global_position)
	if not (e.is_local and not combat.tp_on()):  # 내 1인칭 화면에선 부스러기가 눈앞을 가려서 안 뿌림
		var mouth := e.eye_pos() + Vector3(-sin(e.yaw), 0, -cos(e.yaw)) * 0.35 - Vector3(0, 0.15, 0)
		combat.fx.chunks(mouth, int(W.color), Vector3(-sin(e.yaw), 0.6, -cos(e.yaw)), 4, 1.6)
	var me := combat.me  # +30은 나·가까운 아군만 (상대가 먹는 건 안 보여 줌 — 사용자 요청)
	if e.is_local or (me and Combat.ally(me, e) and me.global_position.distance_to(e.global_position) < 20.0):
		combat.num.emit(e.global_position + Vector3(0, e.mount_h + 2.2, 0), "+%d" % int(W.heal), "heal")

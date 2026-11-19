# 중세난장판 — Godot 이식 프로젝트

Krunker.io를 참고한 중세풍 **병맛 브라우저 FPS**를 Godot으로 옮기는 프로젝트.
원본은 HTML 파일 하나(Three.js)로 만든 프로토타입이고, `reference/arrow-arena.html`에 그대로 들어 있다.
**규칙·수치·느낌의 기준은 언제나 이 HTML이다.** 헷갈리면 HTML 코드를 읽고 그대로 따라 한다.

- 엔진: **Godot 4.7** (4.7.2-stable에서 확인)
- 언어: **GDScript만 사용** — C#으로 짜면 웹으로 내보낼 수 없다
- 렌더러: **Compatibility** (웹 내보내기 대상)
- 물리: Jolt, 60Hz, 물리 보간(physics interpolation) 켬
- 1인 개발. 사용자는 한국어로 대화하고, 코드 주석·UI 문구도 한국어로 쓴다.

---

## 작업 규칙

1. **한 번에 한 단계씩.** 아래 로드맵 순서대로 진행한다. 단계가 끝나면 테스트를 돌리고, 사용자가 직접 플레이해서 손맛을 확인한 뒤 다음 단계로 간다.
2. **수치는 `scripts/game_data.gd`에만 둔다.** 다른 파일에 숫자를 직접 쓰지 말고 `GameData.WEAPONS.bow.full`처럼 가져온다. 사용자가 밸런스를 바꾸라고 하면 이 파일만 고친다.
3. **HTML 동작을 그대로 옮긴다.** 새 아이디어로 바꾸지 않는다. 바꾸고 싶으면 먼저 사용자에게 묻는다.
4. **좌표계가 같다.** Three.js와 Godot 모두 Y가 위, -Z가 앞인 오른손 좌표계다. 위치·회전 숫자를 그대로 쓰면 된다.
   - 회전 순서: Three는 `'YXZ'`, Godot Node3D 기본도 YXZ다.
   - 카메라 FOV: 둘 다 세로 기준이다.
   - 메시 크기: Three의 `BoxGeometry(1,1,1)`은 Godot `BoxMesh.size=(1,1,1)`과 같다.
   - 구·원기둥은 Godot 기본 크기가 다르다. Godot `SphereMesh` 기본 반지름은 0.5라서 radius=1, height=2로 맞춰 쓴다. 원기둥(`CylinderMesh`)도 반지름 1, 높이 1로 맞춘다.
   - 지오메트리 자체를 미리 돌려 구운 경우(`roofGeo.rotateY`)는 부모 노드로 크기를, 자식 노드로 회전을 나눈다. `world_builder.gd`의 `roof()` 참고.
5. **이름 대응.** HTML의 camelCase를 snake_case로 바꾼다 (`fallT` → `fall_t`, `kbT` → `kb_t`, `hasSniper` → `has_sniper`). 엔티티 필드 이름을 맞춰두면 HTML 코드를 옮기기 쉽다.
6. **타입을 적는다.** Dictionary에서 꺼낸 값처럼 Variant인 값에는 `:=`를 쓰지 말고 `var x: float = ...`로 쓴다. 그렇지 않으면 컴파일 오류가 난다.
7. **테스트.** 이동·전투 규칙을 바꾸면 `tests/`에 헤드리스 테스트를 추가하거나 고치고 돌린다. 테스트 실행 방법은 맨 아래에 있다.
8. 그래픽은 지금처럼 **기본 도형 조합**으로 만든다 (TABS 느낌의 흐물흐물 캐릭터). 외부 3D 모델은 사용자가 요청할 때만 쓴다.

---

## 현재 상태 — 1~10단계 + 4.5단계(음유시인) + 7.5단계(쟁탈전) 완료

```
project.godot          설정 (오토로드 GameData, Jolt, Compatibility, 폰트)
scenes/main.tscn       Main(main.gd) ─ World(world_builder.gd) ─ Combat(combat.gd) ─ Player(player.tscn) ─ HUD(hud.gd) (+ 코드로 봇 7명, Menu(menu.gd))
scenes/player.tscn     CharacterBody3D + 원기둥 충돌(r 0.38, h 1.75, 원점=발) + Camera3D
scripts/game_data.gd   ★ 모든 수치·병과·무기·난이도·색. 키 설정도 여기서 코드로 등록함
scripts/world_builder.gd  맵 전체 (HTML buildWorld 1:1). 충돌 상자는 aabbs 배열에도 저장. 꾸미기 도구(box style·fbox·집 골조·성벽·잔디)도 여기 — 아래 "맵 꾸미기"
scripts/mat_styles.gd  맵 무늬 재질 (class MatStyles). GameData.MAT_STYLES → ShaderMaterial (캐시), 땅 재질(흙길 목록)
shaders/               맵 무늬 셰이더 (벽돌·성벽돌·판자·회벽·기와·나무껍질·건초·줄무늬 천·불꽃·땅·잔디). 공용 함수 world_lib.gdshaderinc
scripts/combat.gd      무기(weapon_update·_bow_update·fire), 투사체(update_projectiles), 화살 꽂힘(stick_arrow·world_arrows), 성수 웅덩이(shatter·update_zones)·착지 지점 표시(aim_mk), 피격 판정(hit_test), damage, impact_fx, kill, 투구 날림, 스폰 지점, 재생·부활 타이머. 모든 캐릭터는 ents에 등록. 캐릭터 이동 뒤에 돈다(process_physics_priority)
scripts/fx.gd          맞은 효과 puff·ring·chunks (Combat 아래 Fx 노드)
scripts/meshes.gd      공용 도형: 정십이면체 돌멩이, 고리, 연기 구, 상자, 활대(도넛 조각 arc), 단위 원기둥·원뿔·구, 바닥 원판(disc)·얇은 고리(flat_ring)
scripts/weapon_models.gd  무기·화살·성수병 모양 (HTML makeArrow·makeWeapon·arcMesh·stick). 캐릭터 손·뷰모델·날아가는 화살이 같이 씀
scripts/viewmodel.gd   1인칭 손·무기 (HTML buildVM·updateVM). 따로 된 SubViewport(시야각 60)로 찍어 HUD 맨 아래에 덮음. 지금은 돌멩이·활·석궁·성수
scripts/player.gd      캐릭터 하나(나·봇 공용, is_local로 구분. 봇은 ai가 입력을 만듦). Quake식 이동, 달리기, 슬라이드, 점프, 급회전 넘어짐, 계단 오르기, 1·3인칭 카메라
scripts/derp_model.gd  흐물 캐릭터 몸 + 애니메이션 (뒤뚱 걸음, 젤리 출렁, 굴러다니는 눈, 넘어지면 만세)
scripts/main.gd        경기 흐름 (HTML startMatch·endMatch·startMenuSim·pauseGame·goMenu). state = menu / playing / paused / ended, 남은 시간, 20킬 종료
scripts/hud.gd         경기 중 화면 (HTML updateHUD, 모양은 시안 Hud — 아래 "경기 화면 HUD"): 시간·1위, 킬피드, 병과·체력, 무기, 속도, 조준점(움직이면 벌어짐), banner, 조준점 아래 자막(pop_msg), 데미지 숫자, 사망 자막, 점수판(Tab)
scripts/menu.gd        메뉴 (메인·난이도·병과·설정·친구대전 자리·나가기), 일시정지, 결과 화면, 아래쪽 알림 상자(toast)
scripts/ui_kit.gd      메뉴·HUD 공용 조각 (HTML CSS의 .panel·.primary·.ghost·.navbtn·병과 카드·난이도 카드·점수판, 병과 아이콘 SVG) + 마을 게시판 재료 (Board·Face·KitButton·tilted·쇠못) — 아래 "UI: 마을 게시판 스타일"
tests/test_movement.gd 이동 자동 테스트 (HTML과 같은 값이 나오는지)
tests/test_trip.gd     급회전 넘어짐 기준: 병과별 걷기·달리기 → 넘어짐 여부, 속도별 꺾는 각도, 둔화
tests/test_combat.gd   피격·피해·투구·재생·부활·스폰 자동 테스트
tests/test_stone.gd    돌멩이·투사체·맞은 효과 자동 테스트
tests/test_bow.gd      활 당기기·세기·후들거림·손 미끄러짐·꽂힘·반동 자동 테스트
tests/test_hitbox.gd   히트박스 따라가기(선 자세 = 원래 자리, 달리기 5병과·춤·머리 가장자리 명중·끄기) + 눈에 띄는 화살(꼬리·크기·꽂히면 원래대로) 자동 테스트
tests/screenshot_arrows.gd 날아가는 화살·볼트 예전/지금 사진 → tests/screenshots/arrows_*.png (화면 있어야 함: godot --path . --fixed-fps 60 --resolution 1280x720 -s tests/screenshot_arrows.gd)
tests/test_close_range.gd 근거리 명중: 1·3·10m × 활 최소/풀·석궁 × 1·3인칭 × 조준점 5곳 표, 0.6m, 첫 프레임 눈→손 판정, 터널링, F9 디버그 표시 자동 테스트
tests/test_crossbow.gd 석궁 발사·장전 4초·75 피해·헤드샷 한 방·경직·장전 자세 자동 테스트
tests/test_holy.gd     성수 충전·재충전·포물선·웅덩이 피해·둔화·착지 표시·테두리 색 자동 테스트
scripts/bot_ai.gd      봇 머리 (HTML botUpdate·aimSolve). 대상 고르기·반응·조준 오차·앞질러 쏘기·포물선·무빙·끼임 탈출·웅덩이 피하기
tests/test_bot.gd      봇 조준 계산·앞질러 쏘기·대상·반응·회전 속도·활 당기기·오차 범위·시야·끼임·맞으면 반격·웅덩이 탈출 자동 테스트
tests/test_match.gd    메뉴 구경·병과 고르면 시작·시간·점수판 순서·킬피드·사망 화면·일시정지·다음 부활 병과·4분/20킬 종료·결과·메뉴 복귀 자동 테스트
scripts/items.gd       특수 아이템 (Combat 아래 Items 노드. HTML updateChickens·updateSniper·updateAK·updateHorses·lanceCheck). 닭 돌아다니기·잡기, 저격총·AK 빛기둥·줍기·떨어뜨림, 말 등장·탑승·창 찌르기·짓밟기·달아남. 알림은 banner 신호
tests/test_items.gd    닭 잡기·던지기·넘어짐, 저격총 줍기·즉사·한 발씩·Q 전환·스코프·떨어뜨림, AK 거리 감쇠·연사·퍼짐·탄창, 말 탑승·창 70·멀리 날림·7초 뒤 내림·짓밟기, 봇 줍기 자동 테스트
scripts/trumpet.gd     음유시인 트럼펫 (4.5단계, class_name Trumpet). 원뿔 판정(in_cone·reaches), 숨·삑사리·헐떡임(update), 팡파레(try_fanfare), 듣는 쪽 피해·춤(update_victims·_dance_tick)
scripts/fx/bard_fx.gd  트럼펫 공격 이펙트 (Combat 아래 BardFx 노드, 보기만 함). 날아가는 음표·음파 고리·틱 음표·춤 게이지·춤(조명·색종이)·면역·팡파레·삑사리·숨 참. 음표·색종이는 MultiMesh 풀
scripts/fx/star_fx.gd  황금 붕어빵 무적 반짝임 (Combat 아래 StarFx 노드, 보기만 함). 몸 금색↔흰색 덮어씌우기·별 반짝이·금가루 꼬리(MultiMesh)·금빛(가까운 2명)
tests/test_fish.gd     황금 붕어빵: 등장 자리·먹기·8초 무적·막는 것·몸박치기·반짝임·HUD·뷰모델·무적 BGM·봇·친구대전 비트 자동 테스트
tests/test_bard_fx.gd  트럼펫 이펙트: 풀 상한(한 명 24·전체 120)·원뿔 안 퍼짐·벽 튕김·1인칭 비켜 감·고리 주기·게이지 1→3·춤 조명·면역·팡파레·삑사리·숨 참·정리 자동 테스트
scripts/cannon.gd      포병 대포 (class Cannon, Combat 아래 "Cannon" 노드): 폭발 explode(범위 피해·벽 차단·거리 감소·포탄 점프 blast_jump), 효과·흔들림, 우클릭 탄도 조준(궤적 점 MultiMesh + 착탄 고리)
tests/test_cannon.gd   포병: 스탯·달리기 없음·느린 가속·낮은 점프, 한 발·R 꾹 장전 4초(안 누르면 안 참·떼면 멈춤·이어서·장전 중 못 쏨·안내·철컥·감속 30%·우클릭과 안 겹침·공중·봇), 발밑 사격(피해 1/3·높이 뜸), 직격 100, 범위 80→25, 넉백 감소, 벽 차단, 같은 팀, 자멸, 넓은 판정, 탄도 조준, 공중 폭발 자동 테스트
scripts/vampire.gd     흡혈귀 규칙 (class Vampire, static): 물기 bite·bite_target, 박쥐 돌진 start_dash·_dash_hits, 햇빛 화상 burn·burn_killer, 회복 heal
scripts/fx/burn_fx.gd  흡혈귀 몸의 불꽃·연기 (Combat 아래 BurnFx 노드, MultiMesh 2개, 보기만 함)
scripts/fx/bite_fx.gd  흡혈귀 물기 효과 (Combat 아래 BiteFx 노드, 보기만 함): 바닥 빨간 부채꼴(범위) + 문 자리 유령 틀니
tests/screenshot_bite.gd 물기 효과 사진 6칸 → tests/screenshots/bite_<tag>.png (화면 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_bite.gd -- tag=now)
scripts/meat.gd        야만인 우클릭 고기 먹기 (class Meat, static): tick·can_eat·try_eat·eat·cleanse(상태이상 풀기)·eat_fx
tests/test_meat.gd     고기 먹기: 30 회복·8.3초 재사용·최대 체력·춤/둔화/경직 풀기·먹는 동안 못 던짐·넘어짐/저격총/다른 병과 안 됨·HUD·봇 자동 테스트
tests/screenshot_meat.gd 고기 먹기 사진 6칸 → tests/screenshots/meat_<tag>.png (화면 있어야 함)
tests/test_vampire.gd  흡혈귀: 스탯·화상 1.5초 뒤 시작·14.5초에 죽음·화상 사망은 언제나 자멸·물기 20+15·최대 체력 상한·원뿔·한 명·벽·아군·무적·돌진 9m·±20°·적중 멈춤·재사용·벽·비네트·불꽃·봇 자동 테스트
tests/screenshot_bombard.gd 포병 봄바드 사진 12칸 (1인칭 R 장전 4장 포함) → tests/screenshots/bombard_<tag>.png (화면 있어야 함)
tests/screenshot_class.gd 병과 하나 자세히 (3방향·걷는 중·1인칭 우클릭·3인칭): godot --path . --resolution 1280x720 -s tests/screenshot_class.gd -- cls=cannoneer tag=now
scripts/trumpet_voice.gd  연주 멜로디 (AudioStreamGenerator, 톱니파+비브라토+로우패스). 음유시인 모델마다 하나
tests/test_bard.gd     원뿔 안/밖·벽 차단·피해 주기·누적 0.95초 춤·1.5초 창·3.5초 면역·넘어짐 우선·숨 소진·삑사리·팡파레·봇 오차·베레모·볼·숨 막대 자동 테스트
scripts/ragdoll.gd     죽으면 쓰러지는 몸 (HTML makeRagdoll·stepRagdoll·poseRagdoll). 점 8개 Verlet + world.aabbs 충돌. 모델의 머리·몸통·팔·다리를 떼어 와서 돌림
scripts/music.gd       배경음악 (오토로드 Music). AudioStreamPlayer 둘로 크로스페이드, 내 병과·경기 여부로 곡 고름 — 아래 "오디오"
scripts/ui/model_stage.gd 병과 화면 큰 액자·카드 그림 (SubViewport에 DerpModel 하나. set_active로 계속 그림, portrait(k)로 한 번 찍기)
scripts/ui/result_stage.gd 결과 화면 왼쪽 3D 무대 (직교 카메라 — 배치 px ↔ m 그대로, RESULT_UI.stage.ppm). setup([{cls, team, at, yaw, lie, mood}])
scripts/ui/menu_crowd.gd  메인 메뉴 오른쪽 병과 무리 (SubViewport·투명 배경·자기 World3D에 DerpModel 4개, 가짜 플레이어 Pose로 animate). 메인이 안 보이면 렌더·애니메이션 끔
scripts/ui/lobby_page.gd   친구대전 대기실 (커스텀 게임식 — 아래 "대기실"). 스타일은 ui/lobby_theme.tres만, 누른 건 act(op, arg) 신호
scripts/ui/lobby_theme.gd  대기실 Theme 만들기 (GameData.LOBBY_UI·UI → Theme). ui/lobby_theme.tres = 저장본 (tests/make_lobby_theme.gd로 다시 만듦)
scripts/ui/settings_panel.gd + scenes/ui/settings_panel.tscn  설정 본문 (감도·시점·볼륨 3개·조작키). 메인 메뉴 설정·일시정지 설정이 같이 씀
default_bus_layout.tres  오디오 버스 Master ─ Music · SFX
audio/                 BGM ogg (루프 음원) + 결과 화면 효과음
audio/sfx/             사용자가 만든 효과음 21개 (앞뒤 무음 자르고 크기 맞춤 — 다시 가공하지 말 것, 크기는 GameData.SFX_GAIN으로만). 아래 "효과음"
tests/test_music.gd    병과 → 곡·크로스페이드·같은 그룹 이어서·메뉴 곡·버스·루프·설정 저장/불러오기·볼륨 dB·음소거·설정 패널 자동 테스트
scripts/sfx.gd         효과음 (오토로드 Sfx). FILES(audio/sfx/ 파일, 무작위·음높이 흔들기) + RECIPES(HTML WebAudio 합성을 PCM으로 구움). 플레이어 32개(쉬는 것부터), play()→번호·stop(번호), 반복 소리 loop()·loop_stop(). 결과 화면 stinger
scripts/net.gd         친구대전 (Main 아래 Net 노드, HTML MP). 온라인: WebRTC 방(방장 = peer 1)·방 코드로 들어가기(신호는 NetSignal), 상태 30Hz, 사건(f·sn·ak·ln·h·k), 방장 경기 시간·아이템·줍기 허락
scripts/net_signal.gd  친구대전 신호 (class NetSignal). Supabase Realtime 방 채널(Phoenix JSON 1.0.0)을 WebSocketPeer로 직접 — join·broadcast·heartbeat
addons/webrtc_native/  PC용 WebRTC (godotengine/webrtc-native 1.2.2 GDExtension, Windows·Linux x86_64만 넣음). 웹은 브라우저 것을 써서 안 씀 (exclude_tags web)
tests/mock_signal.gd   테스트용 가짜 신호 서버 (Supabase Realtime 흉내, 127.0.0.1)
tests/test_net.gd      친구대전: Main 둘을 한 프로세스에 띄워 진짜 WebRTC로 잇고 서버 설정 없음·채널 거절·없는 방·방·대기실·시작·위치·투사체·저격총·처치 수·줍기 허락·끝·나가기 자동 테스트
tests/test_net_control.gd 친구대전 쟁탈전: 모드·팀 나누기·팀 바꾸기·빈자리 봇·봇 따라가기·봇↔친구 피해·처치 수·거점 열림·점령·라운드·경기 끝·대기실 복귀·개인전 다시 자동 테스트
tests/test_fx.gd       효과음 합성·소리 나는 곳, 히트스톱, 래그돌(쓰러짐·뼈 길이·무기별 날아감·7초 뒤 사라짐), 흔들림, 붉은 테두리, 피격 방향, 죽음 카메라, 병과 의상 자동 테스트
fonts/DoHyeon-Regular.ttf  HTML과 같은 '도현' 폰트 (OFL 라이선스)
fonts/NotoSans-Bold-sub.ttf, NotoSansSymbols2-sub.ttf  도현에 없는 · … ⚠ 세 글자만 담은 대체 폰트 (OFL, fonts/OFL-Noto.txt). GameData가 시작할 때 도현의 fallbacks로 붙인다
fonts/Gaegu-Bold-sub.woff2  '개구' Bold 손글씨 (OFL, fonts/OFL-Gaegu.txt). 완성형 2350자 + 영문·숫자만. `UiKit.SCRIBBLE` — 한마디·쪽지·팁에만, 한 화면에 1~2곳. fallbacks = Noto 둘 + 도현 (GameData._setup_font_fallbacks)
export_presets.cfg     웹 내보내기 설정 (Web, 스레드 없음 → 아무 정적 호스팅에서 돎). 결과는 export/web/ (git에 안 올림)
scripts/maps/map_control.gd  쟁탈전 맵 "성곽 우물 광장" (class MapControl extends WorldBuilder). 블루 절반(z+)만 _half(side)로 짓고 side=-1로 뒤집어 레드. 스폰룸 문 막(적만 막힘)·거점 표시(_build_live)·내비 메시 굽기(_bake_nav)·팀별 스폰/갈래 길/감시 지점
scripts/modes/control_mode.gd 쟁탈전 규칙 (class ControlMode). 라운드·잠김·점령·경합·점수·연장전·안전장치·스폰룸 회복·공격 금지. Combat.mode에 걸림 (개인전은 null)
scripts/ui/control_hud.gd     쟁탈전 HUD (Hud 아래): 방패 점수판(라운드 동그라미)·거점 메달·% 막대·상태 쪽지, 거점 표지판 "거점 16m", 아군 ▼+이름, 조준한 적 이름(`aimed_at` — 개인전 `Hud.AimName`도 씀), 거점 화살표, 죽었을 때 병과 고르기
tests/test_control.gd  쟁탈전: 5:5·팀 색·점령 속도·게이지 빼기·감소·경합·점수·연장전·4분·2선승·팀킬 없음·부활 5초·스폰룸 회복/공격 금지·거울 대칭·3갈래 내비·문 막·봇 점령·라운드 흐름·메뉴 복귀 자동 테스트
tests/test_result_fx.gd 결과 화면 연출: 개인전 1~3등 승리·4등 패배, 쟁탈전 승패·무승부, 문구 목록, 헤드리스 효과음, 느린 화면 되돌림 자동 테스트
tests/test_map_deco.gd 맵 꾸미기: 충돌 상자·스폰 지문이 꾸미기 전과 같음, 장식 충돌 없음, 잔디가 상자·흙길 위에 없음·높이 ≤0.25, 고정 시드, 그래픽 품질·저장·설정 버튼 자동 테스트
tests/balance_ffa.gd   개인전 밸런스 분석: 봇 7명이 병과 하나씩(고정) 여러 판 → 병과별 분당 처치·K/D·피해·생존·순위·자멸·상성표·처치 무기 → tests/balance/ffa_<tag>.json (items=0 아이템 끔, merge=로 합침)
tests/balance_control.gd 쟁탈전 밸런스 분석: 봇 10명(나도 봇 AI) 5:5, 판마다 팀마다 다른 병과 5개 무작위(seed=) → 병과별 분당 처치·K/D·피해·생존·거점 시간·라운드/판 승률·블루/레드 승리 → tests/balance/ctrl_<tag>.json (merge=로 합침)
tests/perf_profile.gd  봇 경기 FPS·1% 최저·그리기 호출·삼각형 (메뉴·개인전·쟁탈전, 화면 필요: godot --path . --resolution 1280x720 -s tests/perf_profile.gd -- tag=now secs=20)
tests/perf_break.gd    그리기 호출이 어디서 나오나 (같은 장면을 멈춰 두고 그림자·잔디·소품·캐릭터·HUD·맵을 하나씩 끔, 화면 필요)
tests/perf_hud.gd      HUD 그리기 호출을 노드별로 (화면 필요) / tests/perf_model.gd 병과별 캐릭터 조각·삼각형 수 (화면 필요)
tests/perf_cpu.gd      스크립트 CPU 시간 (물리 프레임 한 번, 봇 AI 켬/끔, 헤드리스: godot --headless --path . -s tests/perf_cpu.gd)
tests/perf_maps.gd     두 맵 같은 카메라 5곳 사진(deco_<tag>_*.png) + 봇 경기 FPS·드로우콜 (화면 있어야 함: godot --path . --resolution 1280x720 -s tests/perf_maps.gd -- tag=after quality=normal secs=30)
tests/screenshot_held.gd 손에 든 무기 크기 비교 사진 (병과 5 + 저격총·AK·닭·말, 4m·8m·20m + 내 어깨 너머) + 조준점 가림 %
tests/screenshot_control.gd   쟁탈전 맵 위에서 본 사진 → tests/screenshots/ (화면 있어야 함: godot --path . --resolution 1400x760 -s tests/screenshot_control.gd)
reference/arrow-arena.html 원본
reference/ui_design/    UI 시안 "마을 게시판 스타일" (README.md·Guide.jpg 먼저. .jpg = 완성 모습, .html = 좌표·크기·색. 1920×1080 기준 → 게임은 ×0.667). .gdignore로 임포트 안 함
tests/test_ui_kit.gd   UI 재료: 팔레트·HUD 상수·개구·Board 재질 3개·이정표·seed 나뭇결·기울기 한도·버튼 3종(Button 그대로)·고름·마우스 올림·설정 패널 자동 테스트
tests/screenshot_hud.gd 경기 화면 HUD 사진 hud_<tag>_control·ffa·death_<가로>.png + 가운데 40% 겹침 검사 (화면 있어야 함: godot --path . --resolution 1920x1080 -s tests/screenshot_hud.gd -- mode=control)
tests/make_lobby_theme.gd  ui/lobby_theme.tres 다시 만들기 (LOBBY_UI·UI 색을 바꾸면 돌릴 것: godot --headless --path . -s tests/make_lobby_theme.gd)
tests/screenshot_ui.gd  UI 사진 ui_<tag>_main·settings·diff·mode·class·exit·friend·lobby_control·lobby_ffa·toast·pause·pause_settings·kit.png (화면 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_ui.gd -- tag=after)
tests/screenshot_captions.gd 자막(배경 없는 글자) 사진 cap_<tag>_sky·ground·wall(_death)_<가로>.png (화면 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_captions.gd)
tests/screenshot_result.gd 결과 화면 사진 result_<tag>_ffa_win·ffa_lose·ctrl_win·ctrl_lose_<가로>.png (화면 있어야 함, 시안 Result*.jpg와 비교)
```

실행하면 메인 메뉴가 뜨고, 뒤에서 봇 7명이 싸우는 걸 맵을 빙 도는 카메라로 보여준다 (나는 구경, HTML startMenuSim).
AI대전 → 난이도 → 병과(클릭 또는 1~4) → 바로 경기. 4분이 지나거나 누가 20킬을 하면 결과 화면 (한 판 더 / 병과 다시 고르기 / 메인 메뉴).
경기 중 Esc(또는 창 포커스 잃음) = 일시정지 (`SceneTree.paused`, 다음 부활 병과 고르기, "설정" 버튼 → 감도·시점·볼륨), Tab = 점수판, V = 시점, 클릭하면 마우스 다시 잠금.
- 일반대전은 "추후 업데이트 될 내용입니다." 알림. 나가기: PC는 바로 끄고, 웹은 HTML처럼 "게임을 종료했어요" 페이지.
- 설정(병과·난이도·감도·시점·볼륨)은 `user://settings.cfg`에 저장 (HTML localStorage 대신). 테스트는 `GameData.save_enabled = false`.
- 경기 중 1~4로 병과 바꾸기와 F1~F3 난이도 키는 지웠다 (HTML에도 없음). 병과는 일시정지에서 다음 부활부터.
- 킬피드·사망 화면·20킬 종료는 `Combat.killed` 신호를 Main이 받아 처리한다. 처치·알림 문구(HTML popMsg/killPop)는 `hud.pop_msg`.
1번(야만인)으로 좌클릭하면 돌멩이를 던진다 (누르고 있으면 0.4초마다 연사).
2번(궁수)은 좌클릭을 누르고 있으면 활을 당기고 놓으면 쏜다. 3번(석궁병)은 좌클릭하면 바로 쏘고, 마우스 휠을 아래로 50칸 굴려 감아야 다시 쏜다 (사용자 요청 — 예전엔 4초 자동 장전. 누르고 있으면 다 감는 대로 쏨). 우클릭은 조준(카메라가 다가오고 확대).
- 석궁 장전 모션: 1인칭은 세우기 → 시위 세 번 끊어 당기기 → 걸쇠 → 볼트 끼우기 → 조준 자세, 3인칭은 석궁을 내리고 왼팔로 당긴다. 진행도는 휠로 감은 만큼(`xb_show`). 장전 소리(칸마다 끼릭·걸쇠·볼트)는 Combat이 낸다 (3인칭·봇도 들림).
- 화살은 사람에 맞으면 머리·몸에 꽂히고, 벽·땅에 맞으면 10초 꽂혀 있다.
- 반동: 3인칭은 팔·상체가 튕기고(`rec`), 1인칭은 화면·손이 튕긴다(`v_rec`, 조준은 그대로).
- 오른쪽 아래 무기 칸에 상태 문구, 조준점 둘레에 당기기 고리가 뜬다 (HTML `#weapon`, `#ring`).
4번(성직자)은 좌클릭으로 성수를 던진다 (3개까지, 3초마다 1개 참, 0.4초 간격). 던질 곳에 금색 고리로 착지 지점이 뜬다.
- 깨지면 반경 3m 웅덩이가 3초 남고, 안에 있는 다른 사람은 0.15초 뒤부터 0.5초마다 8 피해 + 속도 ×0.35. 던진 사람은 안 맞는다.
- 임시 즉발 사격(`DEBUG_SHOT`)은 지웠다.
- 봇: `Combat.register`가 `BotAI`를 붙이고, 봇의 `_read_input`이 `ai.update()`로 {wish(월드 방향), jump, crouch, sprint, fire}를 만든다. 그 뒤는 사람과 같은 movement·weapon_update.
- 봇 수치는 `GameData.BOT`(공통)와 `DIFF`(난이도). 봇도 가까운 말·저격총·AK를 주우러 간다 (`BOT.item_seek`·`horse_seek`).
- HTML처럼 끼이면 점프하는데, 공중에선 끼임 시간이 줄어서 "아무 방향 탈출"은 머리 위가 막혔을 때 정도만 나온다 (HTML도 같음).
- `scripted_input`이 비어 있지 않으면 AI보다 먼저 쓰인다. 테스트는 `GameData.ai_enabled = false`로 봇을 세워 둔다.
- 공격 입력은 player.gd가 `fire_held`에 담고, Combat이 이동 다음에 `weapon_update()`로 처리한다. `scripted_input`에 `"fire": true`를 넣으면 테스트·봇도 쏠 수 있다.
- 3인칭에선 화면 가운데가 가리키는 곳으로 던진다 (HTML `playerAimDir`/`tpAim` → `Combat.tp_aim`·`local_launch`).
- 맞히면 조준점에 X 표시(처치면 빨간색)가 뜬다 — HTML `hitmark`.
- **킬 마커** (사용자 요청, 오버워치처럼 — HTML엔 없음): 내가 막타를 치면 조준점 가운데 해골 (`Combat.kill_mark(head)` → `hud.kill_mark` → `Hud.KillSkull`).
  1.3배로 튀어나와 0.1초에 원래 크기 → 0.5초 그대로 → 0.25초 흐려짐. 흰색, 헤드샷이면 빨강.
  반투명: 가장 진할 때 불투명도 0.6 (`kill_skull.alpha`, 사용자 요청), 흐려질 땐 0.6 → 0. 빨간 해골·그림 파일도 같음. 연속 킬이면 처음부터. 시간은 실제 시간 (히트스톱에 안 느려짐).
  내가 막타일 때만 (`a.is_local and a != v` — 자살·낙사·봇끼리·내가 죽은 건 아님, 아군은 damage()에서 막혀 처치가 안 생김). 친구대전은 `remote_kill`에서 내가 막타면 내 화면에만.
  수치·색은 `GameData.HUD_UI.kill_skull`. 그림: `res://ui/kill_skull.png`(흰색 해골·투명 배경, 128×128 권장)가 있으면 그걸 색으로 물들여 그림, 없으면 도형으로 그린 임시 해골.
  소리는 원래 `kill` 합성 그대로 — `audio/sfx/kill.ogg`를 넣고 `Sfx.FILES`에 더하면 바뀐다.
- 1인칭 손 모델(뷰모델)은 무기 8개 다 있다 (마상창은 아래에 말 머리가 보임). 스코프를 보면 숨는다.
- 특수 아이템 (7단계): 수치는 `GameData.ITEM`·`WEAPONS`·`HORSE_*`.
  - 저격총·AK·말은 정해진 지점(`SNIPER_SPOTS`·`HORSE_SPOTS`)에 빛기둥과 함께 나타나고 40초 뒤 사라진다. 경기 시작 때 닭 2마리.
  - 저격총은 누를 때마다 한 발 (대기 중에 누르고 있으면 안 나감, HTML 그대로). 우클릭 스코프는 3인칭이어도 1인칭 화면(시야 24).
  - Q(`swap` 액션)로 원래 무기와 바꾼다. 죽으면 저격총·AK는 남은 탄과 함께 25초 떨어져 있고, 말은 내리고, 닭은 놓는다.
  - 화면 위 안내 줄: 아이템까지 거리·남은 시간, 남이 들고 있으면 경고. 오른쪽 아래에 Q 안내.
- 캐릭터끼리는 충돌하지 않는다 (월드=1층, 캐릭터=2층). HTML도 캐릭터는 월드 상자하고만 부딪힌다.
- 연출 (8단계): 수치는 `GameData.HITSTOP`·`SHAKE`·`HURT`·`DMG_DIR`·`RAGDOLL`·`RAGDOLL_KICK`·`DEATH_CAM`.
  - 죽으면 `Combat.kill`이 모델을 래그돌로 바꾸고(`v.ragdoll`) 모델은 지운다. 부활할 때 `set_class`가 새로 만든다. 죽음 카메라는 래그돌 골반을 따라간다.
  - 히트스톱은 `Engine.time_scale = 0.12`로 한다. 남은 시간은 실제 시간으로 줄이고, 경기 시계도 실제 시간대로 간다. 일시정지·메뉴로 가면 바로 푼다.
  - 내가 맞으면 화면 흔들림(`player.shake`), 붉은 테두리(`hud.on_hurt`), 때린 쪽 붉은 호(`hud.dmg_dir`) — Combat의 `hurt`·`dmg_dir` 신호.
  - 효과음: `Sfx.play(이름, 위치)`. 위치가 있으면 경기 중에만 나고 거리에 따라 작아진다. 헤드리스에선 소리 없이 `Sfx.played`에 이름만 쌓인다 (테스트용). 자세한 건 아래 "효과음".
  - 병과 의상은 HTML makeModel 그대로 (`derp_model.gd`의 `_build_outfit`·`_build_robe`·`_build_head_extras`).

**HTML과 다른 점 (의도한 것)**
- 충돌은 HTML의 직접 만든 AABB 대신 Godot 물리(`move_and_slide`)를 쓴다.
- 0.56m 이하 턱은 `try_step()`이 자동으로 올려준다.
  비스듬히 걸으면 벽에 미끄러져 턱 쪽으로 가는 양이 0에 가까우므로, 검사할 때 벽 안쪽으로 `STEP_PROBE`(0.12m) 더 밀어 본다 (사용자 요청 — 거점 단상을 점프 없이).
- 속도·가속·마찰·넘어짐 공식은 HTML과 같다.
- 단색 환경광은 HTML의 HemisphereLight를 근사한 것이다.
- 내가 쏘는 투사체·히트스캔은 화면 가운데 조준선 위로 나간다 (`Combat.local_launch`, 사용자 요청 — 좌하탄 고침).
  HTML은 눈에서 조준점으로 쏴서 3인칭이면 조준점이 멀 때 조준선보다 왼쪽 0.85m·아래 0.6m로 지나갔다.
  3인칭은 카메라 조준선에서 눈에 가장 가까운 점부터 조준선 그대로, 1인칭은 손 자리에서 조준점으로. 성수 착지 표시도 같은 계산. 중력 낙하는 그대로.
- **초근접 명중 보정** (사용자 피드백 "가까이서 화살·볼트가 안 맞음", `Combat.local_launch`·`_sweep`):
  - 방향은 언제나 나가는 자리 → 조준점. 예전엔 조준점이 1m 안이면 조준선과 나란히 쏴서 1인칭은 손 위치(오른쪽 0.16m)만큼,
    3인칭은 눈에서 카메라 방향 그대로(내려다보면 발밑으로) 나가 빗나갔다.
  - 조준점이 나가는 자리보다 가까우면(`FIRE_NEAR`) 판정 시작점 `from`(1인칭 = 눈, 3인칭 = 조준선 위 눈 깊이)에서 조준점으로 쏜다.
  - 투사체 첫 프레임은 `from` → 나가는 자리 구간을 먼저 판정 (눈과 손 사이에 있는 적). 그 뒤는 예전처럼 매 프레임 이전 위치 → 다음 위치 선분 판정 (터널링 없음).
  - 친구대전 "f" 사건은 pos·vel만 보낸다 (초근접이면 pos = from이라 친구 쪽도 같은 판정).
  - 10m에서 가장 약한 화살(28m/s)은 0.9m 떨어져서 몸 가장자리를 겨누면 아래로 지나간다 — 의도한 포물선.
- **히트박스가 흐물 몸을 따라감** (사용자 요청 "몸은 흔들리는데 히트박스는 그대로라 맞히기 어려움", 수치 `GameData.HITBOX_FOLLOW`):
  - `DerpModel.animate` 끝의 `_measure_hitbox()`가 선 자세 대비 머리(`hb_head`)·엉덩이(`hb_a`)·어깨(`hb_b`)가 옮겨 간 만큼을 잰다 (upper·neck 회전·위치 = 걸음 출렁·젤리·기울기·춤·말 위 자세).
    `player.head_c`·`body_a`·`body_b`가 원래 자리 + 그만큼 (`_hb`). 모델 뿌리 기준이라 물리 위치에 더해도 보간 지연과 상관없음.
  - 가만히 서 있으면 0 (예전과 똑같음). 누운 자세(fall_amt > 0.5)는 예전 계산. 눈 위치(쏘는 자리·카메라)는 안 움직임.
  - 비용: 캐릭터마다 화면 프레임에 행렬 몇 번 (재 보니 1.3µs/명). `GameData.hitbox_follow = false`면 예전 고정 판정.
  - 달리기 시작·멈춤 때 젤리 출렁임으로 머리가 0.6~0.95m까지 벗어난다 — 예전엔 그만큼 빗나갔음 (`test_hitbox`).
  - 친구대전: 투사체는 맞는 쪽이 자기 모델 자세로 판정한다. 보이는 자세는 받은 속도로 같은 계산이라 거의 같고, 무작위 출렁임만 조금 다를 수 있다.
- **날아가는 화살·볼트 눈에 띄게** (사용자 요청, 수치 `GameData.ARROW_FLIGHT`, 보기만 — 판정·속도 그대로):
  - `WeaponModels.add_flight_fx`: 화살이 그늘을 안 타고(unshaded) 날아가며 `scale`배로 커짐(처음 `grow` m 동안 자라서 1인칭 눈앞을 안 가림),
    뒤에 반투명 빛 꼬리(8각 원뿔 메시 하나, 활 금빛·석궁 주황, 길이 = min(len, 속도×time, 날아간 거리)). 매 프레임 `flight_tick`.
  - 꽂히면(사람·벽·땅) `end_flight_fx`로 꼬리 떼고 원래 크기·재질. 친구 화살(`remote_fire`)도 같음. 그리기 호출은 날아가는 화살마다 +1.
- **명중 판정 디버그 표시** (`scripts/fx/hit_debug.gd`, Combat 아래 HitDebug): **F9**로 켜고 끔 (`GameData.debug_hits`, 기본 꺼짐, 저장 안 함, 색·시간 `HIT_DEBUG`).
  모든 캐릭터 히트박스(머리 구·몸 캡슐), 쏜 자리(판정 시작점 하늘색 → 나가는 자리 초록, 조준점 분홍), 프레임마다 판정한 선분(노랑), 맞은 곳(사람 빨강·벽 회색). 벽 뒤도 보임.
- 3인칭 손에 든 무기는 HTML보다 크다 (`GameData.HELD_SCALE`, 사용자 요청 — 잘 안 보여서. 보기만, 판정 그대로).
  DerpModel 무기 그룹(원점 = 손잡이, 트럼펫은 마우스피스)에 배율을 걸고, 마상창은 탄 사람 말만 `Items.held_lance`로 굵기만(길이 그대로, 창끝 tip배).
  뷰모델·투사체·맵 진열 아이템은 그대로. 내 캐릭터만 다르게: `HELD_SCALE_SELF` (닭 1.0 — 어깨 너머 화면에서 조준점을 가려서).
  비교 사진: `godot --path . --resolution 1280x720 -s tests/screenshot_held.gd -- tag=after` → tests/screenshots/held_<tag>_4m·8m·20m·self.png (+ 조준점 가림 % 출력)
- 저격총·AK·말이 나타날 때 알림은 제목만 띄운다. 그 아래 설명 문구는 사용자 요청으로 뺐다 (줍거나 올라탈 때 알림은 그대로).

---

## 로드맵 (이 순서대로)

HTML에서 볼 함수는 줄 번호와 함께 적었다. 줄 번호는 원본 기준이라 약간 어긋날 수 있으니 함수 이름으로 찾는다.

| 단계 | 내용 | HTML 참고 |
|---|---|---|
| ✅ 1 | 이동·카메라·맵 | `movement` 810, `trip` 837, `integrate` 856, `updateCamera` 1881, `buildWorld` 425, `makeModel` 549, `animModel` 1330 |
| ✅ 2 | **피격 판정·데미지 기초**: 머리/몸 판정, `damage()`, 넉백, 투구 날아감, 체력 재생, 죽음·3초 뒤 리스폰, 스폰 지점 고르기 | `hitTest` 950, `damage` 1024, `kill` 1078, `knockHelmet` 1097, `spawn` 793, `simulate` 1870(재생) |
| ✅ 3 | **돌멩이** (야만인): 투사체 시스템(중력·월드 충돌·사람 충돌), 던지는 팔 모션, 맞은 효과(조각·링·숫자) | `fire` 923, `updateProjectiles` 958, `impactFx` 1049 |
| ✅ 4 | **활·석궁·성수**: 활 당기기·후들거림·손 미끄러짐, 석궁 장전, 성수 충전 3개·웅덩이·둔화, 1인칭 무기 모델(뷰모델), 반동 | `weaponUpdate` 898, `shatter`/`updateZones` 875, `buildVM` 1391, `updateVM` 1449 |
| ✅ 4.5 | **음유시인** (HTML에 없는 새 병과): 트럼펫 연주 원뿔·숨 게이지·삑사리, 춤 디버프, 팡파레, 베레모·볼 부풀기·춤 모션·음표, 뷰모델, AudioStreamGenerator 멜로디, 숨 막대 HUD, 봇 AI, 친구대전 연동, 테스트 — 아래 "음유시인 명세" | 없음 (새로 만듦) |
| ✅ 5 | **봇 AI + 난이도**: 대상 고르기, 반응 시간, 조준 오차, 앞질러 쏘기(lead), 포물선 계산, 끼임 탈출 | `botUpdate` 1255, `aimSolve` 1313, `DIFF` |
| ✅ 6 | **매치 흐름 + 메뉴 + HUD**: 메인메뉴(일반대전 토스트 / AI대전 → 난이도 → 병과 → 바로 시작 / 친구대전 / 설정 / 나가기), 4분·20킬, 킬피드, 점수판(Tab), 사망 화면, 일시정지, 결과 화면 | `startMatch` 1632, `endMatch` 1650, `updateHUD` 1575, HTML 상단 CSS/마크업 |
| ✅ 7 | **특수 아이템**: 닭(잡기·던지기·맞으면 넘어짐), 대물 저격총, AK-47, 기사의 말+마상창 | `updateChickens` 1114, `updateSniper` 1220, `updateAK`, `updateHorses` 1184, `lanceCheck` 1176 |
| ✅ 7.5 | **쟁탈전** (HTML에 없는 새 모드, 5대5 거점 점령): AI대전 + 친구대전(빈자리 봇). 아래 "쟁탈전 명세" | 없음 (새로 만듦) |
| ✅ 8 | **연출**: 죽으면 래그돌, 히트스톱, 화면 흔들림, 피격 방향 표시, 병과별 의상 디테일, 효과음 | `makeRagdoll` 664, `sfx` 747 |
| ✅ 9 | **친구대전 (멀티플레이)** — 같은 와이파이(ENet)로 만들었다가 온라인(WebRTC + Supabase 신호)으로 바꿈. 아래 "멀티플레이" | `MP` 1713 이하 |
| ✅ 10 | 웹 내보내기 + 최적화 | — |

각 단계의 완료 기준: 테스트 통과 + 사용자가 플레이해서 HTML 버전과 느낌이 같다고 확인.

---

## 게임 규칙 명세

수치는 전부 `game_data.gd`에 있다. 여기서는 **동작**을 설명한다.

### 이동 (완료)
- 걷기 속도 = `BASE_SPEED × 병과 speed × 무기 배율`이다.
  - 무기 배율: 저격총 0.9, AK 0.95
  - Shift로 달리면 ×1.35. 앞으로 갈 때만, 공격·조준·앉기 중엔 안 됨
  - 성수 웅덩이 안이면 ×0.35, 닭을 들고 있으면 ×1.05
- 땅 마찰은 6.5, 넉백 중엔 2, 슬라이드 중엔 0.7, 넘어져 있을 땐 0.9다.
- 가속은 땅 12, 공중 80이다. 공중 제어의 최대 속도는 1.1이라 공중에선 방향만 살짝 바뀐다.
- 수평 속도 상한은 최대속도의 2.4배다. 넉백 중엔 최소 32까지 허용한다.
- **슬라이드**: 최대속도의 55% 이상으로 달리다 Ctrl/C를 누른 순간 시작한다.
  - 0.8초 동안 미끄러지고, 시작할 때 속도 +3.2(최대속도 2배까지)
  - 다시 쓰려면 1.1초 기다려야 함
- **급회전 넘어짐** (사용자 요청으로 기준을 바꿈 — 예전 HTML은 "자기 최고 걷기속도의 75%"라 느린 병과도 똑같이 넘어졌음. 수치 `GameData.TRIP`, 함수 `player.trip_dot`):
  **실제 속도**가 5.3m/s(`min_speed`, 사용자 요청 5.8 → 5.3) 이상이었던 뒤 0.25초 안에 많이 꺾은 쪽을 누르면 넘어진다. 빠를수록 덜 꺾어도 넘어짐:
  5.3m/s에선 120° 이상, 9.0m/s(`fast_speed`) 이상에선 95° 이상 (사이는 속도에 비례). 둔화되면 실제 속도가 줄어서 덜 넘어진다.
  지금 병과로 (속도 +8% 뒤): 포병(3.77)은 안 넘어짐, 성직자(걷기 5.25)·석궁병(달리기 6.02)은 달릴 때만, 야만인·흡혈귀·궁수(걷기 5.54)·음유시인(걷기 5.51)은 걸어도 넘어짐. `tests/test_trip.gd`가 병과마다 확인 (병과 속도를 바꾸면 이 표도 볼 것).
  - 키를 바꾸는 틈에 속도가 줄어도 넘어지게 하려고 0.25초 창을 둔다.
  - 넘어진 상태로 0.6초 동안 미끄러지고, 그동안 입력이 막힌다.
  - 일어난 뒤 0.5초 동안은 다시 넘어지지 않는다.
- **착지 넘어짐**: 점프하고 착지할 때 20% 확률로 넘어진다 (`LAND_TRIP`, 사용자 요청으로 다시 넣음). 말 위에선 없음. "착지하다 넘어짐!"
  - 테스트는 `GameData.land_trip_override = 0.0`으로 끈다 (무작위라서). 1.0이면 무조건 넘어짐.
- 정지 넘어짐은 사용자 요청으로 **제거됨**. 다시 넣지 말 것.

### 병과
| 병과 | 무기 | 속도 배율 | 체력 | 특징 |
|---|---|---|---|---|
| 야만인 | 돌멩이 | 1.2348 (달리기 9.0 m/s. 예전 1.372 · 10.0) | 90 (사용자 요청으로 100→90) | 짐승 해골 투구. 우클릭 고기 먹기 (아래 "무기") |
| 궁수 | 활 | 1.026 (걷기 5.54 m/s. 예전 1.0556 → 0.95 → +8% 사용자 요청) | 100 | 빨간 갑옷 |
| 석궁병 | 석궁 | 0.8262 (예전 0.85 → 0.765 → +8%. 휠로 감는 중 ×0.75) | 110 | 파란 갑옷 |
| 성직자 | 성수 | 0.972 (예전 1.0 → 0.9 → +8%) | 100 | 체력 재생 2배 (초당 20) |
| 음유시인 (4.5단계) | 트럼펫 | 1.0206 (예전 1.05 → 0.945 → +8%) | 95 | 적을 춤추게 만드는 방해형. 깃털 베레모 (투구와 같은 규칙으로 날아감) |
| 흡혈귀 (사용자 요청) | 틀니 | 1.125 (예전 1.25) | 130 (120→150→120→135→125→130 밸런스, 회복도 130까지) | 햇빛에 초당 10씩 탐, 자연 회복 없음, 물어서 회복. 창백한 피부·올백 머리·높은 깃 망토·송곳니 — 아래 "흡혈귀 명세" |
| 포병 (사용자 요청) | 대포 | 0.756 (사용자 요청 0.65→0.7→+8%. 달리기 없음, 가속 6, 점프 높이 0.4배) | 130 (사용자 요청 200→150→130) | 통나무 바퀴 봄바드에 앉은 탱커. 몸 판정 1.4배. 둔화 절반만. 케틀 햇 — 아래 "포병 명세" |

- **모드별 스탯** (사용자 요청 — 쟁탈전은 개인전과 캐릭터 스탯을 따로): `game_data.gd`의 `CLASSES_BASE`·`WEAPONS_BASE`·`BURN_BASE`·`DANCE_BASE` = 개인전 수치.
  게임은 언제나 `var CLASSES`·`WEAPONS`·`BURN`·`DANCE`를 읽는다. `GameData.apply_mode_stats(m)`이 *_BASE를 복사하고 `MODE_STATS[m]`을 안쪽까지 덮어씀 (`_merged`).
  Main: `_start_control`·`_mp_start_control` → "control", `_use_ffa`(개인전·메뉴) → "ffa". 쟁탈전 밸런스는 **`MODE_STATS.control`에 바꿀 값만** 적는다 (개인전 수치는 안 건드림).
  병과 화면 숫자(`class_stats`)는 고른 모드(`GameData.mode`) 스탯으로 셈. 수치 표 4개 말고 다른 상수(ITEM·BOT 등)는 아직 모드별이 아님.
  **지금 쟁탈전 스탯** (사용자 요청, 시뮬 c0 뒤): 흡혈귀 체력 150·화상 초당 6(`BURN.dmg` 1.5)·물기 17, 포병 장전 3.5초, 석궁 휠 30칸, 성수 둔화 58%(slow 0.42), 음유시인 체력 90, 성직자 체력 95. 나머지는 개인전과 같음.
- **밸런스 (사용자 요청, 개인전 시뮬 `tests/balance_ffa.gd` 결과)**: 사람도 조준이 어렵다고 해서 포병 말고 모든 병과 이동 속도 ×0.9. 흡혈귀는 20% 너프 (물기 28→22, 체력 150→120→135→125→130, 물기 22→20, 화상 유예 3→1.5초). 야만인 돌멩이 10→11. 야만인은 우클릭 고기 먹기 추가. 그 뒤 야만인·흡혈귀 말고 모든 병과(포병 포함) 이동 속도 +8% (사용자 요청).
  수치를 바꾸면 `godot --headless --fixed-fps 60 --path . -s tests/balance_ffa.gd -- matches=5 items=0 tag=x`를 여러 개 동시에 돌리고 `merge=x1,x2,... tag=x`로 합쳐 전후를 비교한다 (봇끼리라 원거리 병과는 사람보다 덜 맞힘 — 해석 주의).

### 피해 공통
- 머리 판정: 투구를 쓰고 있으면 ×1.5. 첫 헤드샷에 투구가 날아가고, 그 뒤로는 맨머리라 ×2.0이다.
- 넉백은 맞은 방향으로 수평으로 밀고 살짝 띄운다.
  - 헤드샷이면 넉백 ×1.25, 띄우기 ×1.15
  - 말 탄 대상은 넉백 ×0.2
  - 맞으면 `kb_t` 0.45초 동안 마찰이 줄고 속도 상한이 풀린다 (AK는 0.12초). 봇은 경직 0.3초, 석궁에 맞으면 0.5초.
- 체력 재생: 5초 동안 안 맞으면 초당 10씩 찬다 (성직자는 20).
- 리스폰은 3초 뒤다.
  - 다른 사람에게서 가장 먼 스폰 지점 4곳 중 하나를 고른다.
  - 스폰 직후 1.2초 무적이다.
  - 봇은 죽을 때 35% 확률로 병과를 바꾼다.

### 무기
- **돌멩이**: 피해 11 (사용자 요청 10→11 밸런스), 0.4초마다 연사.
  - 속도 32, 사거리 15m (넘으면 사라짐)
- **고기 먹기** (야만인 우클릭, 사용자 요청 — HTML에 없음. `WEAPONS.meat`, `scripts/meat.gd`): 돌멩이를 들고 우클릭하면 바로 30 회복(최대 체력까지) + 상태이상 풀기, 재사용 8.3초 (사용자 요청 6→9.7→8.3).
  - 푸는 것: 춤(+ 쌓이던 춤 게이지 `dance_log`), 성수 둔화 `slow_t`, 봇 경직 `stagger`. 넘어짐은 안 풂 (넘어진 동안은 못 먹음). 춤추는 중·웅덩이 안에서도 먹을 수 있다 (공격이 아니라서). 체력이 꽉 차도 먹어짐.
  - 0.6초(`eat_t`) 동안 왼손 고기를 입에 대고 우걱우걱 — 그동안 돌은 안 던짐. 3인칭 `derp_model.meat`, 1인칭 뷰모델 `_meat`(왼쪽 아래에서 올라옴), 소리 `nyam`, 초록 "+30"(나·가까운 아군만 — 상대가 먹는 건 안 보임, 사용자 요청), 부스러기(내 1인칭 땐 안 뿌림).
  - HUD: 무기 칸 "· 우클릭 고기 먹기" / "· 고기 N초" / "냠냠...", 조준점 고리 = 재사용 대기. 저격총·AK를 들면 우클릭은 그 무기 조준.
  - 봇: 체력 < 최대 × `BOT.meat_hp`(0.5)이거나 춤·둔화 중이면 먹음. 친구대전: 먹은 사람 컴퓨터가 회복·풀기 → 사건 "eat"로 남의 화면엔 모습·소리 (체력은 상태로).
- **활** (사용자 요청으로 버프 — "계속 압박하는 무기"): 누르고 있으면 당긴다. 1초에 끝까지 당겨지고(1.5→1.0), 놓으면 쏜다.
  - 차지 비율 = `GameData.bow_t(당긴 시간)`: 0.15초(`min_charge`)에서 0, 1초에서 1. 피해 15~50, 속도 28~72를 이 비율로 보간 (예전 35~55·42~72).
  - 0.15초보다 빨리 놓으면 거기까지 마저 당긴 뒤 최소 세기로 쏜다 (`bow_release`). 예전엔 0.08초 미만이면 안 나갔음.
  - 다시 쏘려면 0.3초 기다려야 함 (1.0→0.3). 짧게 끊어 쏘면 0.45초마다 한 발 (1.4초에 3발).
  - **R = 당기기 취소** (`cancel_draw`, 우클릭은 조준이라 R로 정함). 화살은 안 나가고, 공격 키를 한 번 뗄 때까지 다시 안 당긴다 (`draw_block`).
  - 끝까지 당기면 내 화면에 `bow_full` 소리 + 조준점 고리가 초록으로 바뀌고 번쩍 퍼진다 (`ChargeRing.flash`).
  - 화살은 중력 14로 포물선, 날아가는 방향을 본다. 약하게 쏠수록 느려서 더 크게 휜다.
  - 끝까지 당긴 채로 1초가 넘으면 조준이 후들거린다.
  - 3초가 되면 손이 미끄러져 엉뚱한 방향으로 나간다 ("손이 미끄러졌다!").
- **석궁**: 피해 75 (헤드샷이면 한 방). 속도 100, 중력 2 (사용자 요청 6→2: 거의 직선).
  - **휠 장전** (사용자 요청 — 예전 4초 자동 장전은 없앰): 쏘면 0칸, 마우스 휠을 **아래로**(사용자 요청 — 위로는 완전히 무시, `wind_dir` "down"/"up"으로 바꿀 수 있음) `notches`(50칸, 사용자 요청으로 10→25→35→50)칸 굴려야 다시 쏜다.
    - 한 칸으로 치는 최소 간격 `notch_gap` 0.04초 (사용자 요청 0.15→0.04, 가장 빨라도 50칸 ≈ 2초). player.gd가 **실제 시간(ms)**으로 재서 그 안에 온 휠은 버림 (프리스핀 휠·터치패드 막기).
    - 중간에 멈춰도 진행도 유지, 다 감았으면 휠 무시, 쏜 직후 `cd` 0.25초는 휠 안 먹음. 넘어지거나 춤춰도 감을 수 있다 (공격이 아니라서).
    - **감는 중 이동 속도 ×0.75** (`reload_speed`, 사용자 요청 0.9→0.75). '감는 중' = 마지막 휠 칸 뒤 `reload_window`(0.3초) 동안 (`player.wind_t`) —
      칸 사이에 속도가 튀지 않게. 다 감으면 바로 풀리고, 멈추고 0.3초 지나도 풀림 (진행도는 유지). 쏘기만 하고 안 감으면 안 느려짐. 달리기 등과 곱연산.
    - 부활하면 장전된 채 (예전에도 부활 = cd 0). 다른 병과는 휠 동작 없음 (`wind` 액션은 석궁을 들었을 때만 `wind_req`).
    - 코드: 입력 `player.wind_req` → `Combat._xbow_wind`(칸 세기) → `_xbow_anim`(나·봇·친구: 칸이 늘면 `xbow_click`, 모션 진행도 `xb_show`가 `show_rate`로 따라감, 걸쇠 0.63·볼트 0.86에서 소리).
    - 1인칭·3인칭 장전 모션은 `xb_show`를 본다 (감다 멈추면 모션도 거기서 멈춤). HUD: 조준점 고리 = 감은 칸 + 아래 "6/50", 무기 칸 "휠을 굴려 감기 · 6/50칸".
    - 봇: 난이도별 초당 `DIFF.xbow_wind`칸 (10 / 13 / 16 → 50칸에 5 / 3.8 / 3.1초). 친구대전: 상태 배열 끝(17번)에 `xb_wind`.
    - `xbow_click`은 합성 자리 소리. `audio/sfx/xbow_click.ogg`를 넣고 `Sfx.FILES`에 더하면 파일로 바뀐다 (RECIPES에선 지울 것).
  - 장전 중엔 화면이 위로 들리는 모션이 나온다. 아래로 내리면 화면을 가려서 바꿨다.
- **성수** (성직자): 최대 3개까지 들고 있고, 3초마다 1개씩 찬다. 한 번 던지면 0.4초 기다린다.
  - 땅에 닿으면 깨지면서 반경 3m 웅덩이가 3초 동안 남는다.
  - 웅덩이 안에서는 0.5초마다 피해 8을 받고 65% 느려진다 (속도 ×0.35, 사용자 요청으로 75%→65% 너프).
  - 던진 사람이 자기 웅덩이에 닿아 있으면 초당 4 회복 (`WEAPONS.holy.heal`, 사용자 요청으로 2→4). 쟁탈전은 같은 팀도. 웅덩이가 겹쳐도 한 번만.
  - 내 웅덩이는 테두리가 금색, 적 웅덩이는 빨간색이다.
  - 던질 곳에 착지 지점 표시가 뜬다.
- **대물 저격총** (특수): 맵에 가끔 빛기둥과 함께 나타나고, 닿으면 바로 줍는다.
  - 히트스캔, 맞으면 즉사. 5발 쏘면 사라진다. 한 발 쏘면 1초 기다린다.
  - 우클릭하면 스코프 조준. Q로 원래 무기와 바꾼다. 들고 있으면 속도 ×0.9.
  - 죽으면 그 자리에 남은 탄과 함께 떨어진다.
- **AK-47** (특수, Krunker 돌격소총 기준): 피해 23 (30m 넘으면 줄어서 80m에서 18), 0.12초마다 연사, 25발 쓰면 사라짐.
  - 그냥 쏘면 0.03 퍼짐. 움직이거나 공중이면 더 퍼지고, 오래 쏠수록 더 퍼진다 (최대 +0.05).
  - 우클릭하면 0.006 퍼짐에 1.6배 확대. 들고 있으면 속도 ×0.95, 꺼내는 데 0.3초.
  - 저격총과 AK 중 하나만 들 수 있다.
- **닭**: 맵에 돌아다니고(최대 4마리), 닿으면 잡는다. 클릭하면 던진다.
  - 맞으면 피해 1에 무조건 넘어진다. 던진 닭은 다시 돌아다닌다.
  - 잡고 있으면 속도 ×1.05.
- **황금 붕어빵** (특수, 사용자 요청 — HTML에 없음): 수치는 `GameData.ITEM.golden_fish`·`WEAPONS.star`·`STAR_FX`·`BGM.star`.
  - 등장: 15~25초마다 40% 확률. 맵에 하나만, 누가 무적이면 안 나옴, 40초 뒤 사라짐. SNIPER_SPOTS 중 다른 특수 아이템과 12m 이상 떨어진 곳.
    금색 빛기둥 + 바닥 고리, 배너 "황금 붕어빵이 나타났다!" / "먹으면 8초 동안 무적". 친구대전은 저격총처럼 방장이 만들고 먹기를 허락 ("gf").
  - 닿으면 바로 먹고 **8초 무적** (사용자 요청으로 5→8초. 들고 다니지 않음, 또 먹으면 8초로 다시). "냠!" + 차임, "황금 붕어빵! 8초 무적". 봇·친구가 먹으면 배너 + 그 자리에서 작게 차임.
  - 무적이 막는 것: 모든 피해·넉백(`damage()` 맨 앞), 닭·말 몸통에 넘어짐, 성수 둔화, 음유시인 춤. 내가 급회전·착지로 넘어지는 건 그대로.
  - 몸박치기: 무적 중에 적과 몸이 닿으면 피해 20 + 큰 넉백 (`WEAPONS.star`, 같은 적은 0.5초에 한 번). 친구에겐 "st" 사건 → 친구 쪽이 판정.
  - 연출 (`scripts/fx/star_fx.gd`): 몸 전체 금색↔흰색 번쩍(초당 8번, `material_overlay` — 캐릭터마다 따로 만든 재질이라 공유 재질은 안 건드림),
    별 반짝이가 튀어 올라 사라지고 움직이면 금가루 꼬리, 금빛 OmniLight3D(4m, 카메라에서 가까운 2명만). 끝나기 1초 전부터 초당 16번 + 중간중간 꺼짐.
    1인칭은 금색 비네트 두근 + 테두리 반짝이(hud `StarEdge`) + 뷰모델도 번쩍. HUD 위 가운데에 금색 막대 + "무적 3.2초".
  - BGM: 내가 먹으면 `Music.play_override("star", 0.2)`로 메탈 곡, 끝나면 `end_override(0.8)`로 원래 곡을 **멈췄던 자리부터** (원래 곡은 소리를 줄인 뒤 일시정지).
    경기가 끝나면 바로 복구. 남이 먹었을 땐 안 바뀜.
  - 봇: 40m 안이면 주우러 감 (저격총과 같은 우선순위). 무적이면 거리 유지 없이 가장 가까운 적에게 달려듦. 무적인 적은 대상으로 안 고르고 10m 안이면 도망.
  - 친구대전: 상태 비트 4096 = 무적 (남의 화면에서도 반짝임). 피해는 맞는 쪽이 자기 무적을 보고 막는다.
- **기사의 말 + 마상창**: 닿으면 7초 동안 탄다. 속도 20.5 m/s.
  - 창끝(앞 1.2~3.5m)에 걸리면 피해 70에 아주 멀리 날아간다 (넉백 28, 띄우기 9). 같은 대상은 0.8초에 한 번만 맞는다.
  - 말 몸통에 치이면 넘어진다. 말 위에선 넘어지지 않고 앉기도 안 된다.
  - 시간이 끝나면 말이 달아난다.

- **트럼펫** (음유시인, 4.5단계): 좌클릭을 누르는 동안 연주, 우클릭은 팡파레 (조준 확대 없음).
  - 연주: 앞쪽 원뿔(12m, 반각 25°) 안의 적에게 0.25초마다 피해 3 (초당 12, 사용자 요청으로 6→12). 벽 뒤엔 안 들림. 넉백 없음, 피해 숫자는 성수처럼 작게.
  - 숨: 최대 3초 연주, 안 불면 초당 1.5초씩 회복. 다 쓰면 "숨이 찼다!" — 1초 동안 연주 못 하고 이동 ×0.8.
  - 삑사리: 연주를 시작할 때마다 5% 확률. "삑사리!" — 0.8초 동안 연주 안 됨.
  - 팡파레: 앞쪽 3.5m, 반각 45° 안의 적에게 피해 15, 넉백 9, 띄우기 3. 재사용 6초. "빠바밤!"
  - **춤 디버프**: 원뿔 안에 1.5초 동안 누적 0.95초(`DANCE.need`, 사용자 요청 0.75 → 0.95) 이상 있으면 2초 동안 춤춘다. 이동 ×0.6, 조준 흔들림(플레이어 카메라 좌우 출렁, 봇 조준 오차 ×2.5). **공격은 못 한다** (사용자 요청으로 '공격 가능'에서 바꿈 — 모든 병과·특수무기: 연주·팡파레·던지기·쏘기 다 막고 당기던 활은 놓침, 말 위 창도 안 찌름. `Combat.weapon_update`).
    - 조작은 뺏지 않는다 (맞는 쪽이 너무 짜증 나지 않게 — 바꾸지 말 것).
    - 끝나면 같은 대상은 3.5초(`DANCE.immune`, 사용자 요청 3 → 3.5) 동안 다시 안 춘다. 넘어짐이 우선 — 넘어지면 춤은 멈추고 남은 시간은 사라진다.

### 봇 난이도
| | 반응(초) | 조준 오차 배율 | 헤드샷 노림 | 앞질러 쏘기 | 사격 확률 |
|---|---|---|---|---|---|
| 쉬움 | 1.0~1.5 | 1.5 | 0% | 0~0.4 | 0.5 |
| 보통 | 0.7~1.1 | 1.0 | 3% | 0.1~0.6 | 0.65 |
| 어려움 | 0.4~0.7 | 0.6 | 10% | 0.4~0.9 | 0.85 |

- 봇은 0.3~0.55초마다 생각한다.
  - 65m 안에서 대상을 고른다. 안 보이는 대상은 거리 ×2.4로 계산하고, 현재 대상은 6m 보너스를 준다.
  - 생각할 때마다 조준 오차를 새로 굴린다.
- 사용자 피드백으로 봇 정확도를 **두 번 낮췄다.** 너무 잘 맞히지 않게 유지할 것.

### 매치
- AI대전: 봇 7명과 개인전. 4분이 지나거나 누군가 20킬을 하면 끝난다.
- 메인메뉴: 일반대전(누르면 "추후 업데이트 될 내용입니다." 토스트), AI대전(난이도 → 병과 → 즉시 입장), 친구대전, 설정(감도·시점), 나가기.

### 조작
| 동작 | 키 |
|---|---|
| 이동 | WASD |
| 달리기 | 왼쪽 Shift |
| 슬라이드 | 왼쪽 Ctrl 또는 C |
| 점프 | Space |
| 공격 | 좌클릭 |
| 조준 (음유시인은 팡파레) | 우클릭 |
| 포병 장전 (꾹) · 활 당기기 취소 | R |
| 특수무기 전환 | Q |
| 시점 전환 (기본 3인칭 어깨 너머) | V |
| 점수판 | Tab |
| 마우스 풀기·일시정지 | Esc |

마우스 감도 공식은 `감도 × 0.0021 × (현재FOV/85)`이다.

---

## 음유시인 명세 (4.5단계 — 구현됨)

수치는 `GameData.CLASSES.bard`·`WEAPONS.trumpet`·`DANCE`·`BOT.bard_*`에 있다. HTML에 없는 새 병과라 이 명세가 기준이다.
- **구현 메모**:
  - 연주는 `Combat.weapon_update` → `Trumpet.update`(연주자 쪽 숨), 피해·춤은 `Trumpet.update_victims`(듣는 쪽마다). 친구대전 규칙과 같은 코드로 돈다.
  - 팡파레는 따로 `WEAPONS.fanfare` (damage()가 WEAPONS[kind]로 넉백을 찾아서). 트럼펫 틱은 넉백·경직·맞는 소리 없음, 숫자는 성수처럼 작게.
  - 명세에 없어서 정한 값: `DANCE.sway`·`sway_hz`(내 화면 출렁), `spin_every`·`spin_t`(회전), `note_every`(음표), `TRUMPET_SND`(멜로디·음색), `TRUMPET_LOOK`(색). 병과 카드 `pips`는 [3,1,2,5].
  - 봇은 다른 병과처럼 음유시인을 고른다 (`wip` 표시는 지웠다. 다시 미완성 병과를 넣을 땐 `"wip": true`면 봇이 안 고름).
  - 테스트는 `GameData.squeak_override`(0 = 삑사리 안 남, 1 = 무조건)로 삑사리 확률을 고정한다.
  - 친구대전: 상태 비트 1024 = 연주 중, 2048 = 춤추는 중 (4096 = 황금 붕어빵 무적). 팡파레는 "fan" 사건.
- **콘셉트**: 중세 음유시인인데 악기가 트럼펫 (시대에 안 맞는 병맛, AK-47과 같은 노선). 혼자 잡는 힘은 약하고, 춤추는 적을 맞히기 쉽게 만들어 주는 게 핵심.
- **모델**: 보라 조끼, 노란 타이츠, 갈색 신발.
  - 투구 자리에 긴 깃털 달린 납작한 베레모 (헤드샷이면 날아감, `helm` 노드).
  - 화려한 옷 (사용자 요청, `derp_model._bard_outfit`, 색은 `TRUMPET_LOOK`): 조끼 앞 금·청록 마름모, 하얀 주름 깃, 부푼 금빛 어깨, 보라·금 들쭉날쭉 밑단, 금 허리띠+보석, 빨간 망토(금 테, 쟁탈전은 팀 강조색), 등에 류트, 베레모에 청록 깃털+금 브로치.
  - 3인칭은 두 손으로 트럼펫을 입에 댄다. 연주 중엔 볼이 빵빵해지고(볼 구체 1.0→1.6, `WEAPONS.trumpet.cheek`) 몸이 리듬에 맞춰 까딱거린다.
  - 춤 모션: 팔 만세 흔들기 + 엉덩이 좌우 + 가끔 한 바퀴 회전. 머리 위에 음표 파티클.
- **뷰모델**: 화면 오른쪽 아래에 금색 트럼펫 나팔 끝. 연주하면 나팔이 떨린다.
- **소리**: AudioStreamGenerator로 톱니파 + 비브라토 + 로우패스.
  - 연주하는 동안 "도-미-솔-미-도-솔-도" 같은 웃긴 멜로디를 반복한다. 음마다 ±20센트씩 음정이 틀어진다.
  - 팡파레는 짧은 3음 상승, 삑사리는 높은 음으로 '삑' 하고 꺾인다.
- **HUD**: 숨 게이지를 성수 충전 칸 위치에 가로 막대로 표시.
- **봇 AI**:
  - 대상이 11m 안이고 보이면 연주하고, 원뿔 반각 안에 대상이 들어오게 돌아선다.
  - 대상이 3.5m 안이면 팡파레를 쓴다.
  - 숨이 0.5초 남으면 멈추고 거리를 벌려 숨을 회복한다. 선호 거리는 8m.
  - 춤추는 봇은 조준 오차 ×2.5 (`DANCE.bot_err`).
- **친구대전**:
  - 맞은 사람 쪽에서 판정한다. 연주자의 위치·yaw·pitch와 "연주 중" 비트를 받아, 내가 원뿔 안에 있는지 직접 계산한다.
  - 춤 상태도 내 쪽에서 관리한다.
  - 팡파레는 사건 하나로 보내고, 맞은 사람 쪽에서 판정한다.
- **테스트** (`tests/`에 추가): 원뿔 안/밖, 벽 뒤 차단, 누적 0.95초면 춤, 3.5초 면역, 숨 소진.

### 공격 이펙트 (구현됨 — `scripts/fx/bard_fx.gd`, 수치는 `WEAPONS.trumpet.fx`)
- **원칙**: 보기만 한다 (판정 영향 없음). 친구대전에서도 안 보내고, 동기화된 `playing`·`dance_t`를 보고 각자 만든다.
  - 기본 도형 음표: ♪ = 구 머리 + 상자 기둥 + 상자 깃발, ♫ = 기둥 둘 + 가로대. Label3D 글자 금지 (폰트에 없을 수 있음).
  - 그림자 없음, unshaded, 색 밝기 ×`glow`. GPUParticles 대신 MultiMesh 풀 (♪·♫·작은 음표·색종이 각각 그리기 한 번).
- **1. 연주 음표**: 0.08초마다 나팔 끝에서 1개 (20% ♫), 14m/s, 좌우 꿀렁·빙글. 원뿔(25°) 안에 고르게 퍼뜨림 → 퍼지는 모양 = 공격 범위.
  - 0.1초 톡 튀어나오고, 사거리 75%부터 흐려짐. 벽은 생길 때 한 번 레이로 재 두고, 닿으면 작게 튕기고 사라짐.
  - 색 금·분홍·하늘·연두. 한 명 24개, 전체 120개 (넘으면 오래된 것부터).
- **2. 음파 고리**: 0.25초마다 나팔 끝에서 조준 방향으로 퍼짐, 반지름 = 거리×tan25° (12m에서 5.6m), 0.4초.
- **3. 맞은 적**: 틱마다 머리 위 작은 음표 (+ 기존 dot 숫자). 춤 게이지 = 머리 둘레 도는 음표 1→2→3개 (누적/`DANCE.need`).
  - 춤 시작: 색종이 20, "춤춰라!"(hud 숫자 스타일 `dance` — **춤을 건 음유시인 화면에만**, `Trumpet.caused_by`. 사용자 요청), 디스코 조명(반투명 원뿔, 0.2초마다 색), 음표 3개 빙글. 끝나면 조명이 위로 빨려 올라감.
  - 면역 3.5초 동안 회색 음표 1개가 비스듬히. 게이지·면역은 판정하는 쪽만 알아서 친구 캐릭터에겐 안 그림.
- **4. 팡파레**: 땅에 깔린 원판 충격파(3.5m, 0.25초. 눈높이면 옆에서 선으로만 보여서 땅에 깜), 큰 음표 12개 부채꼴, 색종이 10, 흙먼지, 1인칭이면 흔들림 0.2. 맞은 적은 큰 음표가 튕겨 나옴.
- **5. 삑사리**: 찌그러진 회색 음표(기둥 꺾임)가 비틀거리며 떨어짐 + 회색 연기 + "삑!".
- **6. 숨 참**: 땀방울 3개, 하얀 김, 볼이 0.3초 동안 0.7배까지 쪼그라듦 (`derp_model.deflate`).
  - 삑사리·숨 참은 연주자 컴퓨터에서만 계산하므로 친구대전에선 친구의 삑사리·숨 참이 내 화면엔 안 보인다.
- **7. 1인칭**: 내 음표는 카메라 앞 1m부터, 조준점 둘레(화면 높이 8%)는 비켜 감, 불투명도 60%. 내 머리 둘레 효과는 안 그림.
  - 내가 춤추면 분홍 테두리 + 테두리를 도는 음표 (hud `DanceEdge`, 원·막대로 직접 그림) + 카메라 까딱 (player `_update_camera`).
- 성능: 8명이 동시에 연주해도 1280×720에서 프레임 3.1ms → 4.3ms, 그리기 호출 515 → 558 (PC 측정).

## 포병 명세 (사용자 요청 새 병과 — HTML에 없음)

수치는 `GameData.CLASSES.cannoneer`·`WEAPONS.cannon`. 코드는 `scripts/cannon.gd` + Combat(발사·재장전·투사체) + player(이동) + derp_model(`_build_carriage`·`_anim_carriage`) + viewmodel(`cannon`).
- **이동**: `no_sprint`(Shift 무시), 땅 가속 `accel` 6(기본 12 — 마찰 6.5보다 작아서 실제 최고 걸음은 명목 4.08보다 조금 느린 약 3.77m/s), 점프 속도 = JUMP_V × √`jump`(0.4 → 높이 0.4배), 몸통 판정 반지름 ×`hit_r` 1.4 (`player.body_r()` — hit_test·디버그 표시가 씀). 낙하 피해는 게임에 없음.
- **둔화 50%** (사용자 요청 — 처음엔 면역이었다가 바꿈, `slow_resist` 0.5, `player.slow_resist()`): 남이 거는 둔화(성수 ×0.35·춤 ×0.6)를 곱해 합친 뒤 최종 둔화량의 절반만 받음
  (성수 → ×0.675, 춤 → ×0.8, 둘 다 → ×0.605). 웅덩이 피해·춤(공격 금지)·자기 조준 감속은 그대로. "면역" 표시는 없앰.
- **넉백 속도 보호** (사용자 요청, 모든 병과): 넉백으로 뜨면 `player.kb_air` — 착지할 때까지 속도 상한이 (최고 속도×2.4, 32) 중 큰 값이라 둔화·느린 병과여도 날아가는 속도가 안 잘림 (예전엔 kb_t 0.45초가 끝나면 둔화된 최고 속도×2.4로 잘렸음). 포탄 점프(`blast_air`)도 같음.
- **포탄** (사용자 요청 밸런스: 속도 26→32·재장전 5→4·반경 4.5→3.5→2.5·공중 폭발 4→5초): 32m/s, 중력 14(사람 22보다 작게 — 아치가 김, 평지 최대 사거리 약 73m). 무엇에든 닿으면 터지고, 5초(`fuse`, 투사체 수명)가 지나면 공중에서 터짐.
  - 직격 = `dmg` 100 그대로 (범위 피해는 안 더함). 범위 2.5m: 몸(캡슐 겉면)까지 거리로 80 → 25 선형 (`Cannon.blast_dmg`).
  - 폭발 지점에서 몸 가운데 선·머리 둘 다 벽에 막히면 범위 피해 없음 (`combat.los`). 벽에 맞은 폭발은 0.12m 앞으로 당겨서 잼.
  - 넉백 kb 6·up 4에 `damage(..., kb_mul)` = 1 - 거리/반경.
  - **R 꾹 장전** (사용자 요청 — 예전 4초 자동 재장전은 없앰): 쏘면 게이지 `player.cn_load` 0, 대포를 들고 **R(`reload` 액션)을 누르고 있는 동안만** `reload` 4초에 걸쳐 참 (`player.cn_reloading()`).
    떼면 그대로 멈추고 다시 누르면 이어서. 다 차기 전엔 좌클릭이 안 나가고, 누른 순간 내 화면에 "R키를 꾹 눌러 장전" (`Combat.toast`). 다 차면 `clank` + 조준점 고리 번쩍(`ChargeRing.flash`).
    공중·춤·넘어짐·스폰룸에서도 장전됨 (공격이 아니라서). 부활하면 장전된 채. 다른 무기(저격총·AK)를 들고 있으면 안 참.
    R은 궁수 `cancel_draw`와 같은 키 (사용자가 고름 — 병과마다 따로 동작, 포병은 활을 못 듦). 설정 화면 조작키에 "R 포병 장전 (꾹) · 활 당기기 취소".
  - **감속**: 장전하는 동안(R + 덜 참) 이동 ×`reload_slow` 0.7. 우클릭 조준 ×`aim_slow` 0.7과 겹쳐도 둘 중 작은 쪽 하나만 (최대 30%, `player.max_speed`). 다 찬 뒤 R을 눌러도 안 느려짐.
  - HUD: 조준점 고리 = 게이지 (누르는 중 금색, 떼면 회색으로 멈춤), 무기 칸 "R키를 꾹 눌러 장전 · N초" / "장전 중 · N초".
  - 1인칭 장전 모션 (`viewmodel._reload_pose`): 포신을 끌어당겨 포구를 오른쪽 위로 세우고(`CN_RL_*`), 게이지 0~0.25 돌 포탄을 포구에 넣고, 그 뒤 긴 꽂을대(밀대 + 쥔 손)로 세 번 밀었다 뺌. 진행도 = 게이지라 떼면 모션도 멈춤. 린스톡은 숨김. 3인칭 모습은 그대로.
  - 봇: 장전 안 됐으면 R을 누름 (`bot_ai` "reload", 그동안 쏘지 않음).
- **포탄 점프**: 자기 폭발은 ×`self_mul`(1/3, 발밑이면 약 27). 몸 가운데 선까지 `jump_r` 2.5m 안이면 위로 22m/s(사용자 요청 20→22) + 폭발 반대쪽 5m/s.
  착지할 때까지 `player.blast_air` = 중력 ×`air_grav` 0.75(사용자 요청 — 일반 점프·낙하는 그대로, 공중에서 또 포탄 점프해도 유지) → 약 14.7m·2.7초 뜸,
  공중 가속 ×`air_ctrl` 0.3, 속도 상한 풀림, 착지 넘어짐 없음. 말 위에선 안 뜸.
- **발사 반동** (사용자 요청, `Cannon.fire_recoil` — Combat.fire에서 `not is_remote`만): 쏜 방향 반대로 `recoil` 8m/s(사용자 요청 6→10→8). 땅에 있으면 위로 `recoil_up` 2 + `recoil_t` 0.3초 동안 땅 마찰 `recoil_fric` 2(속도 상한도 풀림).
  세로 성분은 ±`recoil_vmax` 4로 자름 (발밑 사격이면 위로 4 → 그다음 포탄 점프 22). 공중도 같음, 말 위는 없음. 반동도 `kb_air`를 켜서 떠 있는 동안 속도 상한·둔화에 안 잘림.
  화면 반동: `player.cam_kick_t` → `cam_kick_now()` = 위로 `cam_kick` 0.06rad까지 빨리 올라갔다 `cam_kick_t` 0.2초에 정확히 0 (실제 시간, 조준 방향 그대로). 그래서 `RECOIL.cannon.vrec`은 0 (몸 반동 rec는 그대로).
- **맵 경계** (포탄 점프로 성벽을 넘어가서 추가, 모든 캐릭터): `WorldBuilder.invisible_bounds` — 바깥 성벽 자리에 땅부터 `MAP_BOUNDS.ceil`(40m)까지 보이지 않는 벽 + 천장.
  충돌 층 `WorldBuilder.BOUND_LAYER`(16)는 캐릭터 mask에만 (player._ready·Main._use_ffa·set_team) → 투사체·레이·내비·래그돌(aabbs)·맵 지문은 그대로. 맵을 새로 만들면 build()에서 부를 것.
- **지붕 경사면** (사용자 요청 — 포탄 점프로 지붕에 올라가도 못 서 있고 흘러내림, 모든 캐릭터): `WorldBuilder.roof()`가 보이는 사각뿔 그대로 충돌(`_roof_col`, ConvexPolygon)을 `roofs`(그룹 "roof")에 넣는다.
  층은 `BOUND_LAYER` → 투사체·레이·내비·래그돌·맵 지문은 예전처럼 지붕을 지나감. `player._integrate`: 지붕에 닿아 있으면 `floor_max_angle`을 `ROOF.floor_deg`(8°)로 줄여 지붕을 벽으로 → 중력으로 미끄러짐, grounded도 아님(착지 넘어짐 없음).
  두 지붕이 맞닿은 V자 골(쟁탈전 시장 블록 옆)에 끼어 멈추면 `_roof_unstick`이 골을 따라 `ROOF.push` 3m/s로 밀어냄. 테스트: test_cannon(개인전 지붕 18곳)·test_control(쟁탈전 16곳).
  - `damage()`에서 a == v는 아군 막기에 안 걸린다 (`ally`가 원래 a != b). 자기 포탄으로 죽으면 `kill`이 처치 +0 (자멸, 킬피드는 공격자 = 자기).
  - 내 포탄에 내가 맞은 건 히트마크·숫자·맞힘 소리 없음 (`impact_fx`의 `mine`이 a != v).
- **우클릭 탄도 조준**: 실제 발사와 같은 `local_launch` + 포탄과 똑같은 프레임 적분(닫힌 식, `aim_every` 프레임마다 벽·땅 레이)으로 궤적 점 28개 + 착탄 고리(반지름 = 폭발 반경, 장전 중엔 흐리게).
  속도·중력을 바꿔도 착탄 지점 = 실제 폭발 자리 (`Cannon.aim_hit` vs `last_blast`, 차이는 벽에서 당기는 0.12m뿐 — `test_cannon`). 아무 데도 안 닿으면 고리는 fuse초 공중 폭발 자리. 확대 `AIM_CAM.cannon`(75/1.3, 85/1.3), 이동 ×`aim_slow` 0.7. 1인칭은 포신을 내려 궤적이 보이게.
- **모습 — 14~15세기 봄바드** (사용자 요청, 보기만 — 판정·포탄 반지름·수치 그대로. 색·크기는 `GameData.CANNON_LOOK`):
  3인칭 = 모델 뿌리에 포가(`carriage`, 몸 출렁임과 따로): 거친 두꺼운 나무 판자 받침 + 뒤쪽 앉는 자리 + 꼬리 기둥, 바큇살 없는 통나무 단면 바퀴 2개(`wheels`, 나이테·껍질 테, 바라보는 쪽 속도로 굴러감).
  포신(`barrel` = weapons.cannon, 조준 높이를 따라 들리고 쏘면 뒤로) = 짧고 굵은 8각 철판 통(`Meshes.prism`, 반지름 0.155·길이 0.92) + 밝은 쇠고리 5개 + 두꺼운 포구 테·큰 구경 + 뒤 위 점화 구멍, 밧줄로 받침에 묶음.
  사람은 받침 위에 걸터앉음. 말을 타면 포가는 숨김. 초록 누빈 천 갑옷(갬비슨, 사용자 요청 — 개인전 색)·가죽 앞치마·챙 넓은 케틀 햇(헤드샷이면 날아감, 띠 = 팀 색). 오른손에 긴 린스톡(`linstock`, 끝에 불붙은 심지) — 쏘면 팔을 내려 점화 구멍을 찍음. 팀 색 = 갬비슨·모자 띠.
  1인칭 = 화면 아래 가운데 굵은 포신 윗면·쇠고리 (화면 아래 25% 안, 쏠 때도 — `test_cannon`이 꼭짓점을 투영해 확인), 오른쪽 아래에 린스톡 쥔 손.
  쏘면 막대를 시계 방향(오른쪽 → 아래 → 왼쪽 위)으로 휘둘러 점화 구멍을 콕 + 불꽃 (위로 돌리면 조준점을 가려서 — 이것도 test_cannon이 확인). 반동 `VM_KICK.cannon` 0.15.
  포탄 = 울퉁불퉁한 회색 돌(`Meshes.stone`, 보이는 크기 `ball` 0.21 — 판정 `radius` 0.2 그대로). 쏠 때(`Cannon.fire_fx`) 점화 구멍 불티 + 포구 짙은 회백색 연기(`Fx.smoke`, 내 1인칭이면 앞쪽에 옅게).
  폭발 = 작은 섬광·불덩이 + 돌 파편(`Fx.rocks`)·흙 조각·흙먼지 연기·고리 + `boom` + 화면 흔들림(4m 안 최대 → 26m에서 0).
  사진: `godot --path . --resolution 1280x720 -s tests/screenshot_bombard.gd -- tag=now` → tests/screenshots/bombard_<tag>.png (멀리·쏘는 순간·1인칭 평소/쏘기/조준·3인칭 쏘기·폭발 2장)
- **소리**(임시 합성, `Sfx.RECIPES`): `cannon`(발사) · `boom`(폭발) · `clank`(재장전). 파일로 바꾸려면 `audio/sfx/`에 넣고 `Sfx.FILES`에 같은 이름을 더한 뒤 RECIPES에서 지움.
- **봇**: 성수처럼 대상 발밑에 떨어질 각도를 훑어서 찾음, `BOT.cannon_min` 4.5m 안이면 안 쏨, 선호 거리 16m, 쟁탈전 역할 = 거점.
- **친구대전**: 포탄은 "f" 사건 (`Net.WEPS` 끝에 "cannon" — 번호는 뒤에만 더함). 장전 게이지는 상태 배열 18번 `cn_load` (남의 화면 게이지·철컥).
  **방장 검사** (사용자 요청 "발사 가능 여부는 방장이 판정" — 사용자가 '쏜 쪽 판정 + 방장 검사'를 고름): 친구 포탄은 `Net.event_host`로 방장에게만 → 방장 `_ev`가 `cannon_ok`
  (받은 상태 게이지 ≥ 1 - `NET.cannon_tol` 0.15, 지난 포탄 뒤로 빈 게이지를 봤나 `net_cn_block`)면 자기 화면에 만들고 `_relay`로 다른 친구들에게 (who = 쏜 친구 id), 아니면 버림.
  쏜 친구 화면엔 바로 나감 (지연 없음). 방장·방장 봇의 포탄은 예전처럼 모두에게. 터지면 각자 자기 캐릭터(방장은 + 봇)만 피해 판정, 포탄 점프는 쏜 사람 컴퓨터만. 체력은 상태로.
- **UI**: 병과 카드가 늘면 5장 너비에 맞춰 줄어듦 (`menu._build_class`). 숫자키는 class_1~7. 병과 아이콘 `UiKit.ICONS.cannoneer`, 킬피드 `WEAPON_ICONS.cannon`.

## 흡혈귀 명세 (사용자 요청 새 병과 — HTML에 없음)

수치는 `GameData.CLASSES.vampire`·`WEAPONS.teeth`·`WEAPONS.bat`·`WEAPONS.burn`·`BURN`·`VAMP_FX`. 규칙 코드는 `scripts/vampire.gd` (Trumpet처럼 static), 상태는 player.gd (`dash_t`·`dash_dir`·`bat_cd`·`burn_wait`·`burn_acc`).
- **스탯**: 체력 130 (120→150→120→135→125→130 밸런스, 모든 회복이 130까지), 속도 1.125 (모든 병과 ×0.9 밸런스), 자연 재생 0 (`class_regen` — 재생이 있으면 화상을 상쇄해서). 스폰룸 회복(쟁탈전)은 그대로 받는다.
- **햇빛 화상** (`Vampire.burn`, Combat._tick_timers에서 내 컴퓨터가 정하는 흡혈귀만): 스폰 뒤 `grace` 1.5초는 안 탐 (사용자 요청 3→1.5), 그 뒤 0.25초마다 2.5 (초당 10) → 가만히 있으면 14.5초(1.5 + 130/10)에 죽음.
  - `damage()`를 안 거침. 화상으로 죽으면 **언제나 자멸** (처치 +0, 킬피드 공격자 = 자기, 무기 `burn`). 사용자 요청 — 예전엔 5초(`credit`) 안에 때린 사람이 처치를 가져갔는데 버그로 봄.
  - 황금 붕어빵 무적·쟁탈전 피해 없는 때(`mode.no_damage()`)엔 안 탐. 다른 회복(물기·스폰룸)은 받고 화상은 계속.
- **물기** (좌클릭, `teeth`): 눈에서 3.0m(몸 겉면까지), 조준 원뿔 반각 40°(사용자 요청으로 2.3m·30°에서 넓힘. 조준선이 몸에 닿으면 원뿔 밖이어도), 벽 너머 안 됨, 가장 가까운 한 명. 20 피해 고정 (밸런스 28→22→20) (헤드샷 배율·투구 날림 없음), 0.5초 간격.
  - **범위가 보이게** (사용자 요청 "범위가 작고 안 보임", `BiteFx`, 수치 `GameData.BITE_FX`): 물 때마다 발밑에서 바라보는 쪽 바닥으로 빨간 부채꼴(반지름 = 범위 + 몸 두께, 반각 그대로)이 휙 펼쳐졌다 사라지고,
    문 자리(빗나가면 범위 끝)에 커다란 반투명 유령 틀니가 흡혈귀 쪽을 보고 딱 다물렸다 커지며 사라짐 (빗나가면 옅게), 맞히면 빨간 고리. 남의 물기도 보임 (친구대전은 `remote_bite`가 같은 함수).
    부채꼴은 눈높이에 두면 1인칭에서 선으로만 보여서 바닥에 깖, 밝은 흙길에서 하얗게 날아가서 더하기 합성은 안 씀.
  - **처치 회복** (사용자 요청, `teeth.kill_heal` 30): 흡혈귀가 처치하면 무기 상관없이 +30 (물어 죽이면 15 + 30, 130까지, 초록 "+30").
    `Vampire.on_kill` — `Combat.kill`·`remote_kill`에서 처치를 세는 컴퓨터(`not a.is_remote`)에서만 → 친구대전·방장 봇도 한 번만, 체력은 상태로.
  - 조준점: 물 수 있는 적이 범위 안에 있으면 고리가 빨갛게 꽉 차고 아래 "물기!" (`Vampire.bite_target` — 판정과 같은 계산), 무기 칸 "물 수 있음!".
  - 적에게 피해가 들어가면(`can_feed` — 살아 있고 스폰 무적·붕어빵 무적·라운드 사이가 아님) +15 회복 + 머리 위 초록 "+15" (`num` 스타일 `heal`, 나·가까운 아군만 — 상대 흡혈귀의 회복 숫자는 안 보임, 사용자 요청). 벽·허공·아군은 회복 없음.
  - 봇은 틀니에 맞아도 경직 없음 (물기 연타로 묶이지 않게).
- **박쥐 돌진** (우클릭, `bat`): 바라보는 쪽으로 9m를 0.3초 (위아래 ±20°로 자름), 재사용 7초. 돌진 중엔 공격 못 함, 말 위에선 안 됨.
  - 이동은 `player._dash_move` (벽에 막히면 끝, 끝나면 속도를 걷기 속도·위 `end_vy`로 자름). 부딪힘은 Combat이 이동 다음에 `Vampire.tick` → `_dash_hits` (움직인 선분 vs 몸, 반지름 + `r`).
  - 처음 걸린 적: 20 피해 + 약한 넉백, 그 자리에서 멈춤, 물기 1회로 쳐서 +15 회복 + 물기 재사용 바로.
- **모습**: 창백한 피부(`skin`), 올백 검은 머리(`helm` 자리 — 헤드샷이면 가발처럼 날아감), 높은 깃(겉 검정·안 빨강), 망토(따로 노드 `cape`, 속도에 따라 펄럭), 빨간 입술·송곳니.
  손에 큰 틀니(`WeaponModels.make_teeth`, 3인칭 `jaws` 위·아래 턱이 물 때 딱). 돌진 중엔 팔을 펼치고 앞으로 기욺. 몸에서 늘 작은 불꽃·연기 (`BurnFx`, 1인칭인 내 몸은 안 뿌림).
  1인칭: 오른쪽 아래 틀니 옆모습, 물면 다물리며 앞으로. 내 체력이 `low_hp` 40 이하면 화면 가장자리 붉게 일렁이는 비네트 + 불꽃 혀 (hud `BurnEdge`). 왼쪽 아래 쪽지 "화상까지 N초"/"햇빛에 타는 중".
  무기 칸 "물면 20 피해 + 15 회복 · 우클릭 박쥐 돌진", 조준점 고리 = 돌진 재사용.
- **소리** (임시 합성 `Sfx.RECIPES`): `bite`(딱!) · `bat`(돌진 휙) · `burn`(지글, 0.5초마다). 파일로 바꾸려면 `audio/sfx/`에 넣고 `Sfx.FILES`에 더한 뒤 RECIPES에서 지움.
- **봇** (`bot_ai.gd`): 거리 유지 없이 달라붙음, 3.5~8.5m(`BOT.bat_min`·`bat_max`)이고 돌진이 차 있으면 우클릭 돌진, `fire_range.teeth` 2.9m에서 묾. 쟁탈전 역할 = 거점.
- **친구대전**: 물기·돌진은 저격총처럼 **문 쪽**이 판정해서 사건 `"bt"`·`"bd"` [표적 id, fed]를 보냄 → 맞은 쪽 `Combat.remote_bite`가 피해, 모두 모습·소리. 회복은 흡혈귀 컴퓨터가 바로, 화상도 흡혈귀 컴퓨터가 → 체력은 상태로 맞춰짐 (`test_net`).
  상태 비트 8192 = 돌진 중 (남의 화면 돌진 자세). `Net.WEPS` 끝에 "teeth"·"bat"·"burn".
- **UI**: 병과 카드 7번째 (숫자키 7), 아이콘 `UiKit.ICONS.vampire`, 킬피드 `WEAPON_ICONS.teeth`·`bat`·`burn`.

## 쟁탈전 명세 (7.5단계 — 구현됨, 사용자 요청. AI대전 + 친구대전)

수치는 전부 `GameData.MODES.control`. 개인전(ffa)은 그대로 — `GameData.mode`("ffa"/"control", 설정 파일에 저장)로 고른다.
- **메뉴**: AI대전 → 난이도 → **모드**(개인전 / 쟁탈전 5:5, menu `mode` 페이지) → 병과 → 시작. 메뉴 뒤 구경은 늘 개인전 맵.
- **Main**: 쟁탈전이면 `_start_control()` — 맵을 `MapControl`로 바꾸고(안 쓰는 맵은 remove_child), 봇 9명(나 + 블루 4 vs 레드 5), `ControlMode`를 `combat.mode`·`hud.mode`에 건다.
  메뉴로 가면 `_use_ffa()`가 되돌림 (팀 "", 봇 7명, 개인전 맵). 봇은 `_bot_total()`명 만들어 두고 안 쓰는 건 `_bench`.
- **팀**: `player.team`. 같은 팀이면 `Combat.ally()` → 투사체·히트스캔 통과, damage() 맨 앞에서 막음, 성수·트럼펫·닭·마상창·몸박치기 안 맞음. 성수 테두리는 우리 팀 파랑/적 빨강.
  팀 색: `DerpModel.new(cls, team)` → `GameData.team_paint`가 `MODES.control.paint`(병과 원래 색 → body/accent/dark/pale)로 바꿈. 실루엣(투구·소품)은 그대로.
  스폰룸 문 막: 블루 문 = 충돌 층 값 4, 레드 문 = 8. 캐릭터 mask = 1 | 상대 팀 문 (`Main.set_team`).
- **라운드**: 시작하면 모두 자기 스폰룸, 거점 중립·15초 잠김(회색). 거점은 18m 정사각형(±`cap_half` 9, 높이 4 안 — 사용자 요청으로 원 r7 → 네모), 1명 8초·2명 ×1.5·3명+ ×2, 상대 게이지는 먼저 0으로, 빈 거점은 초당 1/8 감소, 양 팀이 있으면 멈춤(경합). 주인 팀이 혼자 있으면 상대 게이지를 빼냄.
  점수: 주인 팀 % +1 / 0.9초 (뺏겨도 유지). 99%에서 적이 원 안이면 멈추고 연장전 → 적이 다 나가면 바로 100% 승리. 연장전에 점령하면 넘어감. 4분 넘으면 % 높은 팀(같으면 주인).
  3판 2선승. 라운드 사이 6초(피해·공격 없음) → 다음 라운드, 끝나면 6초 뒤 결과 화면(`menu.open_end_control`).
- **스폰룸**: 초당 100 회복, 안에선 아무도 공격 못 함 (`ControlMode.no_attack` — Combat.weapon_update). 부활 5초 (개인전 3초 그대로).
- **맵**: x -32~32, z -64~64, 거울 대칭. 블루 = +z(남쪽). 스폰룸 z 52~64 → 집결 마당 → 3갈래(왼쪽 시장 골목 / 가운데 큰길 / 오른쪽 성벽 길 높이 3) → 광장(거점 (0,0) 네모 단상 18m+우물+낮은 벽 4, 감시탑 고지 x 20~32 높이 3 + 아치 통로, 신전 폐허 x -32~-14).
  아이템은 z=0 줄 4곳(`item_spots`), 말은 양 팀 마당 옆에 두 마리 동시(`Items.horses`), 황금 붕어빵은 거점 원 안엔 안 나옴. 지붕은 팀 색과 안 헷갈리게 회색·갈색.
- **봇** (`BotAI.control_move`): 말·아이템 주우러 갈 때도 쟁탈전 맵은 내비 경로(`seek_move` → `nav_step`) — 직선이면 스폰룸 왼쪽 벽 구석에 박혔음 (버그, `test_control`). 아군은 대상 아님, 적 스폰룸 문 앞(16m)의 적은 안 쫓음. 부활하면 병과 가중치로 갈래를 골라(`lane_weight`) 갈래 지점을 지난 뒤 내비 경로(`MapControl.nav_path`)로.
  역할: 야만인·성직자·음유시인 = 거점, 궁수·석궁병 = 감시 지점. 잠김 = 갈래 끝에서 대기, 중립 = 거점 역할만 거점, 우리 거점 = 앞의 2명만 원 안, 뺏김·경합·연장전 = 다 거점으로(싸우면서도).
  가까운(14m) 적이 보이면 원래 싸움 움직임. 조준·반응·난이도 규칙은 그대로.
- **HUD**: 위 가운데 "블루 1 : 0 레드"·% 막대·거점 아이콘(주인 색 + 점령 고리)·상태 문구(거점 열림까지 N초 / 경합 중! / 연장전! / ○○팀 점령 중 N%). 개인전 시계는 숨김.
  배너 + 뿔나팔(`Sfx "horn"`): 라운드 N / 거점이 열렸습니다! / ○○팀이 거점을 점령했습니다! / 거점을 빼앗겼습니다! / 연장전! / 라운드 승리!·패배 / ○○팀 승리!
  Tab 점수판은 팀별(이름·병과·처치·죽음·거점 시간 `cap_time`), 킬피드 이름은 팀 색. 죽어 있는 동안 1~5키(또는 버튼)로 다음 부활 병과.
- **BGM**: 개인전과 같은 규칙 (음유시인이면 match_bard).

### 친구대전 쟁탈전 (구현됨, 사용자 요청)
- **대기실**: 아래 "멀티플레이 → 대기실" (방장이 모드·팀·봇 자리를 room으로 관리). 쟁탈전은 블루|레드 팀마다 5칸.
- **봇**: 방장 컴퓨터의 봇 (`Main.mp_pick_bots` — **대기실 봇 자리대로**, 예전처럼 빈자리를 저절로 채우지 않음). 봇 id는 음수 (`b.peer = -(i+1)`, `Main.bot_by_id`).
  방장이 명단 `_roster`([[id, 이름, 병과, 팀]], reliable, 시작 알림보다 먼저)와 상태 `_bots`(30Hz, 4명씩 나눠서 — MTU)를 보낸다. 친구 쪽에선 봇이 `is_remote` 캐릭터.
  대기실로 돌아가면 빈 명단을 보내 친구 쪽 봇 캐릭터를 지우고, 방장 봇은 `_bench` (봇 자리는 room에 그대로).
- **판정**: '내 컴퓨터가 판정하는 캐릭터' = `not is_remote` (나 + 방장이면 봇). `damage()`는 `mp() and v.is_remote`면 안 깎는다.
  사건은 `net.event(x, 누구)` → `_ev(x, who)`: 봇 일이면 봇 id를 같이 보냄 (방장만 보낼 수 있음). 표적 id는 `Net.mine(id)`로 내 캐릭터·내 봇을 찾음.
  처치 수: 죽인 쪽이 `not is_remote`면 그 컴퓨터가 셈 (방장 봇 처치는 방장이). 팡파레 사건은 내 봇도 맞음.
- **규칙**: 방장 `ControlMode`가 돌고 `snapshot()`을 `_cm`으로 10Hz (`NET.ctrl_hz`). 친구는 `follower = true` → `apply_snapshot()`이 값을 받고,
  바뀐 것(거점 열림·점령·빼앗김·연장전·라운드 끝·경기 끝)을 보고 배너·뿔나팔을 직접 띄우고, 새 라운드면 내 캐릭터만 스폰룸으로(`_begin_round`는 is_remote를 건너뜀).
  거점 인원은 방장이 받은 위치로 셈. 스폰룸 회복·공격 금지·부활 5초·거점 시간(cap_time)은 각자. 경기 끝은 방장이 `phase == "over"`를 보고 알림 (킬·시간 제한 없음).
- 말 두 마리: 두 번째 말은 `"hb"`로 보이고 줍기 허락도 따로. 말 등장은 `combat.mode`가 있으면 두 마리 (예전엔 `GameData.mode`를 봤음).
- 경기 중에 들어온 친구는 봇을 다시 나누지 않는다 (그 팀이 6명이 될 수 있음). 대기실 자리에선 봇 하나가 빠지고 다음 판부터 반영.

## 오디오 (BGM·볼륨 — 사용자 요청으로 추가, HTML엔 BGM 없음)

- **오토로드**: `GameData` → `Sfx`(효과음) → `Music`(배경음악, `scripts/music.gd`). 오토로드라 씬이 바뀌어도 음악이 안 끊기고, 일시정지 중에도 돈다.
- **버스** (`default_bus_layout.tres`): `Master` 아래에 `Music`·`SFX`.
  - BGM은 Music 버스, 효과음(Sfx 풀·트럼펫 멜로디)은 SFX 버스. 새 소리를 넣으면 `bus = "SFX"`.
- **곡 목록**: `GameData.BGM = {"match": silly, "match_bard": edm_v2, "menu": silly, "star": metal_heavy_loop}`. 페이드 시간은 `GameData.MUSIC`.
  - menu는 지금 match와 같은 파일이다 (나중에 메뉴 전용 곡으로 바꿀 자리).
  - 둘 다 루프 음원이라 불러올 때 `stream.loop = true`로 끊김 없이 반복한다.
- **함수**: `Music.play_bgm(key, fade_sec := 1.5)`, `Music.stop_bgm(fade_sec := 1.0)`.
  - 잠깐 덮어쓰는 곡: `Music.play_override(key, fade)` / `end_override(fade)` (황금 붕어빵의 "star"). 원래 곡은 소리만 줄였다가 일시정지 → 끝나면 그 자리부터 이어서. 다른 아이템에도 쓸 수 있다.
  - 같은 **파일**이 이미 나오고 있으면 다시 시작하지 않는다 (키가 달라도 됨). 막 빠지던 곡으로 돌아가면 그 자리에서 다시 키운다.
- **곡 고르기** (`Music.track_for(병과, 경기 중)`):
  - 경기 중(playing·paused·ended)이고 **내** 병과가 `bard`(그리고 `CLASSES`에 있을 때)면 `match_bard`, 아니면 `match`.
  - 메뉴(대기실 포함)면 `menu`.
  - 병과가 바뀌면 `PlayerController.class_changed` 신호 → `Music.on_class_changed`. Main이 **내 캐릭터 신호만** 이어서 친구대전에서도 내 병과 기준.
  - 경기 시작·메뉴 복귀는 `Main._set_state` → `Music.set_match`.
  - 음유시인 ↔ 다른 병과면 1.5초 크로스페이드. 같은 그룹 안(궁수 → 석궁병)은 그대로 이어서 재생.
- 게임을 켜면 메뉴 곡을 1초 페이드인. **웹**은 브라우저가 클릭 전엔 소리를 막아서 첫 클릭·키 입력 뒤에 시작한다 (`Music._input`).
- **볼륨 설정**: 설정 화면(메인 메뉴 설정·일시정지 → 설정)에 슬라이더 3개 (0~100%, 옆에 %).
  - 전체(Master) 기본 80%, 배경음악(Music) 70%, 효과음(SFX) 80% — `GameData.VOL_DEFAULT`.
  - `linear_to_db`로 버스에 바로 적용하고, 0%면 그 버스를 음소거 (`GameData.apply_volumes`).
- **설정 파일**: `user://settings.cfg` (`GameData.settings_path`). `[game]`에 병과·난이도·감도·시점·닉네임, `[audio]`에 master·music·sfx.
  - 테스트는 `settings_path`를 다른 파일로 바꿔서 내 설정을 안 건드린다.

## 효과음 (사용자가 만든 파일 — `audio/sfx/`, `scripts/sfx.gd`)

- `Sfx.FILES`(이름 → 파일 목록)에 있으면 파일, 없으면 `RECIPES` 합성. 둘에 같은 이름이 있으면 안 됨 (`test_fx`가 확인).
- 파일 소리 연결:

| 소리 이름 | 파일 | 언제 |
|---|---|---|
| `throw` | `stone_whoosh.ogg` | 돌멩이 던지기 |
| `bow` | `stone_whoosh.ogg` | 활 쏘기 — **활 쏘기 소리 = 돌 던지기 소리 (사용자 요청)** |
| `bow_draw` | `bow_draw.ogg` | 활 당기기 시작 (2.95초, 놓거나 쏘면 `reset_charge`가 `Sfx.stop(snd_bow)`) |
| `thunk` | `arrow_thunk.ogg` | 화살·볼트·돌이 벽·땅에 맞음 |
| `xbow` | `xbow.ogg` | 석궁 쏘기 |
| `xbow_crank` | `xbow_crank.ogg` | (지금 안 씀 — 휠 장전은 칸마다 합성 `xbow_click`) |
| `xbow_latch` | `xbow_latch.ogg` | 석궁 장전 — 걸쇠 |
| `holy_throw` | `holy_throw.ogg` | 성수 던지기 |
| `glass` | `glass_0.ogg`, `glass_1.ogg` | 성수병 깨짐 (무작위, 같은 걸 연달아 안 고름) |
| `ak` · `sniper` | `ak.ogg` · `sniper.ogg` | AK 한 발 · 저격총 |
| `thud_heavy` · `thud` | `body_hit.ogg` | 세게 맞음 · 맞음 (같은 파일을 작게 0.6·높게 1.15) |
| `clang` | `clang.ogg` | 투구 날아감 |
| `squeak` · `fanfare` · `gasp` | 같은 이름 .ogg | 트럼펫 삑사리 · 팡파레 · 헐떡임 |
| `cluck` · `horn` · `nyam` · `neigh` | 같은 이름 .ogg | 닭 · 쟁탈전 뿔나팔 · 황금 붕어빵 · 말 울음 |
| `gallop` | `gallop_loop.ogg` | 말 달리는 동안 계속 (반복 소리) |

- 합성 그대로: `bite`·`bat`·`burn`(흡혈귀)·`trip`·`hit`·`head`·`kill`·`hurt`·`pickup`·`chime`·`bell`·`slide`·`slip`·`jump`·`sizzle`·`reload`(성수 한 병 참)·`seat`(볼트 끼우기)·`stamp`. 결과 화면 `play_stinger`는 따로.
- **크기·음높이 조절**은 `game_data.gd`만: `SFX_GAIN`(소리별 크기 배율, 기본 1) · `SFX_PITCH`(소리별 음높이 배율). 크기 = `vol_at(위치)` × `SFX_GAIN` × `SFX_VOL`.
  파일 소리는 칠 때마다 음높이 ±`PITCH_JITTER`(0.04), 음악인 `SFX_NO_JITTER`(fanfare·horn)는 안 흔듦.
- **거리·남의 소리** (사용자 요청, `GameData.SFX_DIST`, `Sfx.vol_at`): 1/(1+(거리/8)^1.5) — 8m 절반, 50~80m에서 0까지 (HTML 1/(1+거리/9)보다 거리감이 큼).
  내 캐릭터 자리(0.5m 안)에서 난 소리 = 내 소리, 그 밖(적·아군·봇, 먼 곳에 꽂힌 내 화살)은 ×0.7. 위치 없는 소리(맞힘·처치·아야·UI)는 그대로. 트럼펫 멜로디도 같은 규칙.
- `play()`는 번호를 돌려줌 (안 났으면 0). `stop(번호)`는 그 소리가 아직 그 플레이어에서 나고 있을 때만 끈다. 플레이어는 쉬는 것부터, 다 바쁘면 가장 오래된 것.
- **반복 소리** `Sfx.loop(owner, 이름, 위치, 음높이)`: 매 물리 프레임 부른다 (owner마다 전용 플레이어, 크기·음높이만 갱신). 안 부르면 다음 `_process`에서 저절로 꺼짐,
  `loop_stop(owner)`로 바로 끔, 일시정지면 멈췄다 이어서, `Sfx.playing`이 false면 전부 끔. 헤드리스는 시작할 때 `played`에 한 번만.
  말: `Items.gallop_sfx` — 속도 > `GALLOP.min_speed`일 때, 음높이 = 속도/`HORSE_SPEED`로 `pitch_min`~`pitch_max`. 내 말·봇 말·친구 말 모두, `dismount`에서 끔.
- **석궁 장전 소리** (휠 장전): `Combat._xbow_anim` — 휠 한 칸마다 `xbow_click`, 모션 진행도 `xb_show`가 `XBOW_RELOAD_SND` latch(0.63) → `xbow_latch`, seat(0.86) → `seat`. 3인칭·봇·친구도 들림.
  `xbow_crank.ogg`(시위 끊어 당기기)는 지금 안 쓴다 (휠 장전으로 바뀌며 칸마다 끼릭으로 대신함).

## 멀티플레이 (9단계 — 구현됨, 온라인: WebRTC + Supabase 신호)

처음엔 같은 와이파이 ENet(PC 전용)이었다. 사용자 요청으로 **온라인**으로 바꿨다 — 웹·PC 어디서든, 웹과 PC가 섞여도 된다. 무료로 가볍게 (서버를 따로 안 띄움).
- **구조**: 방장 컴퓨터(브라우저)가 `WebRTCMultiplayerPeer.create_server()` = peer 1, 친구는 `create_client(번호)`. ENet 때처럼 별 모양 (친구끼리는 방장이 중계 — server relay).
  RPC·상태·사건 코드는 ENet 때 그대로다. 바뀐 건 연결 만들기뿐.
- **신호** (`NetSignal`, `scripts/net_signal.gd`): Supabase Realtime의 방 채널 `realtime:jnp-코드`에 들어가서 broadcast로만 주고받는다 (DB 안 씀).
  - 순서: 친구 `hi`(sid, `hi_every`마다 다시) → 방장 `id`(sid, 번호 2,3,… 늘기만 함) → 방장이 offer `sdp` → 친구 answer `sdp` ↔ 서로 `ice`. 모든 신호에 from·to.
  - 설명(SDP)보다 먼저 온 ICE 후보는 모아 뒀다가 넣는다. 친구는 연결되면 채널을 닫고, 방장은 방이 열린 동안 남아 있다 (끊기면 3초 뒤 다시 들어감).
  - 꽉 찼으면(`max_players`) `full`. 방장이 대답 안 하면 `find_timeout` 뒤 "찾지 못했어요", 번호를 받고 `connect_timeout` 안에 안 이어지면 `Net.NO_LINK` 안내.
  - Supabase 무료: 동시 접속 200·초당 메시지 100 — 신호만 오가서 충분하다 (테스트 한 판에 신호 약 20개).
- **설정**: `GameData.NET.supabase_url`·`supabase_key`(publishable 공개 키 — 게임에 들어가도 됨, service_role·secret 키는 절대 넣지 말 것), STUN `NET.ice`(구글 무료).
  - Supabase 프로젝트 지역은 Mumbai (신호만 지나가서 게임 중 렉과 상관없음). Realtime 설정에서 공개 채널(public access)이 켜져 있어야 한다.
  - TURN(중계 서버)은 없다 → 학교·회사 와이파이 같은 막힌 망에선 직접 연결이 안 될 수 있다. 자주 그러면 그때 TURN을 붙이거나 전용 서버로.
- **PC 버전**: Godot 본체엔 WebRTC가 없어서 `addons/webrtc_native`(GDExtension)가 맡는다. Windows exe로 내보내면 exe 옆에 `libwebrtc_native...dll`이 같이 나온다 → **둘을 같이** 줘야 한다. 없으면 `Net.NO_RTC` 안내.
- **대기실** (사용자 요청 — 오버워치·롤 커스텀 게임식, `scripts/ui/lobby_page.gd`):
  - **방장이 진짜 상태 `Net.room`**({ver, md, map, slots: [{id, bot, n, c, t, rdy, diff}]})을 들고, 바뀔 때마다 `_room`으로 통째로 모두에게. 친구는 `Net.ask(op, arg)` → `_req` → 방장 `_apply_req`가 검사해서 반영.
    누구나: hi(들어올 때 이름·병과)·cls·team·ready. 방장만(친구가 보내면 무시): mode·map·bot_add(팀)·bot_del(id)·bot_set([id, 병과("" = 무작위), 난이도]). 거절은 `_notice` → 그 사람 화면 알림.
    팀·모드·봇·준비는 대기실(`mst == "lobby"`)에서만, 병과는 언제나 (다음 부활부터).
  - 자리: 개인전 최대 `NET.max_players`(10, 사람+봇), 쟁탈전 팀마다 `team_size`(5). 들어올 때 꽉 찼으면 봇 하나를 빼고 자리를 줌 (쟁탈전은 사람이 적은 팀, 그 팀 봇부터). 사람만 10이면 신호 단계에서 `full`. 나가면 자리 비움.
    모드를 쟁탈전으로 바꾸면 사람 먼저·봇 다음으로 적은 팀에 번갈아 넣음 (방장 = 블루). 개인전으로 바꾸면 팀만 지움 (봇 그대로).
  - **준비**: 방장 말고 모든 사람이 준비해야 `host_start` (버튼 "게임 시작 (준비 N/M)"). 대기실로 돌아오면 준비만 초기화.
  - 봇은 방장만 넣고 뺌 (+ 봇 추가 / X), 봇마다 병과(랜덤 = 죽을 때 35% 바꿈, 고르면 `bot_cls_fixed`)·난이도(`player.bot_diff` → `BotAI.diff_of`). AI는 방장 컴퓨터에서만. **친구대전 개인전에도 봇**을 넣을 수 있다 (닭은 없음).
  - 맵은 `GameData.ROOM_MAPS` (모드마다 지금은 하나씩 — 맵이 늘면 여기에 더하면 드롭다운에 나옴).
  - 그리기: Main `_render_lobby`가 view(dict)를 만들어 `menu.render_lobby(view)` → `LobbyPage.render`. 자리 목록이 바뀌었을 때만 다시 만든다.
- 일시정지해도 게임은 안 멈춘다. 20킬·시간 종료는 방장이 판단해 알린다.
- **경기가 끝나면** (사용자 요청): 결과 화면 `NET.lobby_return`(10초, "대기실로 돌아가는 중 · N초") → 방장이 `go_lobby` + `_mt{st: lobby}` → 친구도 대기실 (알림이 늦으면 +`lobby_grace` 3초에 스스로).
  연결·팀·봇·병과는 그대로, 준비만 초기화. 다음 판은 방장이 대기실에서 [게임 시작]을 눌러야만. 결과 화면의 '한 판 더'·'병과 다시 고르기'는 친구대전에선 숨김, '메인 메뉴' → '방 나가기'.
  클라는 시작을 못 일으킴: `start_match`(친구대전)는 아무것도 안 하고, `_mt` 자동 시작은 대기실 페이지에 있을 때만. 테스트는 `GameData.end_wait_override`로 시간을 줄임.
- 남의 캐릭터는 `is_remote`(player.gd `_physics_process`를 안 돎), Net `_apply_remote`가 받은 상태를 따라간다.
- Combat `damage()`는 친구대전에서 **내 캐릭터만** 깎는다. 남을 맞히면 그쪽 컴퓨터가 판정해 "h"/"k" 사건을 보낸다. 처치 수는 죽인 사람이 "k"를 받고 스스로 센다.
- 아이템은 방장만 생성·떨어뜨림. 친구가 닿으면 `net.request` → 방장이 `grants`에 적어 `_it`로 알려줌 (HTML seq/grant).
- **HTML과 다른 점**: 방장이 나가면 방이 끝난다 (HTML은 다음 사람이 방장을 이어받음).
- 수치는 `GameData.NET`. 테스트: `GameData.signal_url_override`(가짜 서버 주소, "off" = 설정 없음)·`ice_override`(빈 배열 = STUN 없이).

### 처음 설계 메모

HTML 버전은 claude.ai의 방(room) 기능 위에서 돌아서 **Godot에선 쓸 수 없다.** 새로 만든다.
- (옛 메모) 웹 빌드는 `WebSocketMultiplayerPeer`를 쓴다 — 실제로는 WebRTC로 정했다 (위).
- 방 코드 4자리로 들어가려면 **사람을 이어주는 중계 서버가 필요하다.** 선택지는 Nakama 같은 오픈소스 서버를 직접 띄우거나 W4 Cloud 같은 서비스를 쓰는 것이다.
  - 어떤 걸 쓸지는 그 단계에서 사용자와 정한다.
- 권한 구조는 HTML과 같게 한다.
  - 방장: 매치 시간·종료, 특수 아이템 생성과 줍기 승인
  - 투사체: 맞은 사람 쪽에서 판정
  - 저격총·AK·마상창: 쏜 사람 쪽에서 판정
- 동기화는 30Hz로 한다. 위치·속도·yaw/pitch·상태 비트(앉기·슬라이드·달리기·투구·특수무기)·넘어짐·체력·무기를 보내고, 사건(발사·명중·처치)은 따로 보낸다.

---

## 맵 꾸미기 (사용자 요청 — HTML엔 없음)

TABS 느낌 로우폴리 + 굵은 줄눈·또렷한 모양. **겉모양만** 바꿨다: 충돌 상자·엄폐물 크기·스폰·아이템 자리는 그대로 (`test_map_deco`가 꾸미기 전 지문과 비교).
- **무늬 재질**: `box(x,y,z,w,h,d,색,collide,shadow, style)` / `mesh(…, style)`. style은 `GameData.MAT_STYLES`의 키, 기본 `""`은 예전 단색.
  - 무늬는 셰이더가 월드 좌표(m)로 계산 (이미지 없음) → 상자 크기와 상관없이 벽돌 크기가 같다. 가장 큰 법선 축으로 투영, 줄눈은 fwidth로 부드럽게, 멀면 평균색으로 녹임.
  - 바탕색은 상자 색(정점 색 — 셰이더 안 COLOR는 이미 선형). 같은 style은 `_merge_static`이 (style, 그림자, 작은 소품)마다 메시 하나로 합친다.
  - 셰이더 uniform 값 = MAT_STYLES의 값 (0x 정수 = 색). 색·크기를 바꾸려면 game_data.gd만 고치면 된다.
- **땅**: `ground_plane()` + `grass_ground` 셰이더. 흙길은 상자 대신 `path_rect(cx, cz, w, d)` → 셰이더가 마스크로 그림 (가장자리 노이즈, 긴 길엔 바퀴 자국·자갈). 최대 24개.
- **장식 도구** (전부 충돌 없음, 벽에서 10cm 이하): `fbox(면 위 점, 밖 법선, u, y, 크기, 색, style, off, rot)`, `fsph`, `house_faces`(창문·문·골조), `_timber`, `_window`, `_door`, `quoins`/`quoin_corner`, `eaves`, `chimney`(DECO.chimney_chance), `tower_deco`.
  - 집: 빨간 지붕 = 나무 골조(회벽 plaster), 파란 지붕(`house(…, true)`) = 벽돌집. 쟁탈전은 갈래 집 블록·시장 아래 블록 = 골조, 시장 위 블록 = 벽돌.
- **성벽** `castle_wall(안쪽 면 가운데, 안쪽 법선, 길이, 높이, 두께, 색, 범위)`: 충돌은 `col_box`로 원래 상자 그대로.
  겉 몸통의 안쪽 면만 `DECO.recess`(0.5m) 들여 그리고 12m마다 버팀벽(앞면 = 충돌 면). 꼭대기 흉벽은 원래 두께 + 띠돌·받침돌.
  → 버팀벽 사이 칸에선 보이는 벽보다 0.5m 앞에 충돌 면이 있다 (화살이 벽 0.5m 앞 허공에 꽂혀 보일 수 있음).
  칸(`_bays`)마다 화살 구멍·덩굴, `_wall_props()`가 횃불(DECO.torches개, flame 셰이더 — 빛 없이 발광만)·현수막(개인전 금색, 쟁탈전 `banner_cols` 팀 색). 앞이 막힌 칸(쟁탈전 성벽 길)은 뺀다.
- **잔디·들꽃·자갈** (`_build_scatter`): MultiMesh, 16m 덩어리마다 하나(멀리 40m 넘으면 덩어리째 숨김, 그림자 없음). 잔디 포기 = 가는 잎 3장 부채꼴(`_blade_mesh`), 바람은 `grass_blade` 셰이더.
  충돌 상자·흙길·`_no_grass`(돌바닥·스폰룸)·맵 밖은 피한다. 들꽃·자갈은 흙길 가장자리와 성벽 밑. 배치는 `_drng`(시드 `DECO.seed`) → 친구대전에서도 같은 모양.
  `scatter_items`에 배치값을 남김 (헤드리스는 MultiMesh 값을 못 읽어서 테스트가 씀).
- **그래픽 품질** (`GameData.GFX`, 설정 화면 "그래픽" 낮음/보통/높음, `[video] quality` 저장, 기본 보통): `GameData.set_gfx(q)` → `gfx_changed` →
  맵 `apply_gfx()`(잔디 `visible_instance_count`·작은 소품 `clutter_nodes` 보이기), Main `_apply_gfx()`(태양 그림자 끔/130m/220m).
  작은 소품 = `_clutter = true`인 동안 만든 조각 (덧문·꽃 상자·덩굴·횃불·현수막) + 들꽃·자갈.
- 굴뚝 연기·나비/새는 **아직 안 함** (사용자가 나중에 말하면).

## UI 스타일 — 마을 게시판 (규칙 요약. 새 화면·새 UI는 이걸 따른다)

시안 `reference/ui_design/` (Guide.jpg가 규칙, 1920×1080 → 게임은 ×0.667). 광장 게시판에 대충 못질해 붙인 공고문 느낌.
- **색** (`GameData.UI`, `UiKit.c(키)`): 잉크 `ink` 0x2b1d12(모든 외곽선·양피지 위 글자), 양피지 `parch` 0xf4e4bc, 나무 `wood`/`wood_hi`/`wood_lo`,
  금칠 `gilt`/`gilt_hi`/`gilt_lo`, 형광펜 `marker` 0xffd84a(강조·고름·내 줄·알림), 체력 `hp`, 팀 `blue`·`red`(팀 글자색은 `MODES.control.teams.*.ink`).
  나무판 위 글자 = `cream`(+ 잉크 외곽선), 양피지 위 보조 글자 = `brown`·`faded`. 색 숫자는 game_data.gd에만.
- **재질 3개뿐**: 나무(`wood` — 간판·제목·HUD 나무판), 양피지(`parch` — 설명·쪽지·큰 판·보조 버튼), 금칠(`gilt` — **주요 버튼 하나만**). 테이프·나사 대신 쇠못·밧줄.
  큰 판 = 양피지 + 못 4 (`menu._big_board`), 페이지 제목 = 밧줄에 매달린 나무 간판 (`menu._head2`), 알림 = 양피지 쪽지 + 못 1.
- **`UiKit.Board`** (PanelContainer, `_draw`로 직접 그림 — 텍스처·셰이더 없음): `Board.new(kind, pad)` + nails 0/1/2/4, ropes, rope_len, arrow(이정표), tilt(배경만 ±3°), paint(바탕색), ring(형광펜 테 = 고름), bands(위 색 띠).
  버튼은 `UiKit.primary`(금칠)·`ghost`/`back`(양피지)·`_kit_button` → `KitButton`(Button 그대로, `selected` = 형광펜). 눌리는 판은 `board_tap`/`sign_tap` + `Face`(마우스 올림 들림·누름).
  Container 자식은 rotation이 초기화되니 기울일 땐 `UiKit.tilted(ctrl, deg)`로 감싼다. 숫자 있는 판은 안 기울인다.
- **글꼴**: 본문·제목 = 도현 (+ Noto 대체 폰트 · … ⚠). 손글씨 개구 = `UiKit.scribble` — 한마디·쪽지·팁·결과 문구에만, 한 화면에 1~2곳.
  나무판 위 = `UiKit.wood_text`(크림 + 잉크 외곽선 `outline_for`), 양피지 위 = 잉크. 줄 높이가 커서 판이 높아지면 `UiKit.trim_font`.
  **새 글자를 쓰면** `test_ui_kit`의 글꼴 검사가 도현·Noto(전체 문자열)와 개구(손글씨 문구)에 다 있는지 본다 (웹에선 없는 글자가 □). 긴 줄표(—)는 폰트에 없으니 "-"를 쓴다.
- **말투** (Guide "말투"): 농담은 제목·한마디에만, 수치·조작 안내는 정확하고 짧게. 나가기 = "도망가기", 불러오는 중 = "돌 줍는 중..."(웹 `export_presets.cfg` head_include), "돌멩이".
- **HUD 규칙**: 가운데 40%는 비움(조준점·고리·맞힘 X·쪽지·배너·사망 쪽지만), 정보는 네 모서리 + 위 가운데, 모서리 판 높이 1080p 120px(게임 80) 이하,
  팀 = 색 + 글자 + 방패 귀퉁이 모양. `test_match`가 확인한다. 자세한 건 아래 "경기 화면 HUD".
- **자막(잠깐 뜨는 글자)은 배경 없이 외곽선+그림자만. 배경판은 고정 HUD 패널·메뉴에만.** `UiKit.caption(l)` (수치 `UI_KIT.caption`: 큰 글자 외곽선 10~14, 작은 글자 6~8, 잉크 그림자 0.8). 배너·조준점 아래 자막·데미지 숫자·춤춰라!·삑!·무적 남은 시간·아이템 안내 줄·사망 자막. 사진: `tests/screenshot_captions.gd` (하늘·바닥·성벽).

## UI: 마을 게시판 스타일 (사용자 요청 — 화면별 기록)

시안: `reference/ui_design/` (Guide = 규칙). 광장 게시판에 대충 못질해 붙인 공고문. **재질은 나무·양피지·금칠 셋뿐**, 테이프·나사 대신 쇠못·밧줄.
- **1단계 (완료)**: 공용 재료만 `ui_kit.gd`에 만들고 설정 패널에만 입힘. 다른 화면은 primary·ghost·back·navbtn이 새 모양을 쓰면서 자동으로 따라왔고, 배치는 아직 예전 그대로.
- 색: `GameData.UI` (ink·parch·wood/_hi/_lo·gilt/_hi/_lo·marker·hp·blue·red + 글자용 cream·cream_dim·brown·faded, 어두운 판용 dust·sky). 옛 키(gold·line·mute·blood…)는 없앴다.
  hud.gd 상수(PARCH·GOLD·BLOOD·MOSS·MUTE·STEEL·INK·SHADOW)는 const라 값을 한 번 더 적었다 — test_ui_kit가 같은지 확인.
- 판 모양 수치: `GameData.UI_KIT` (외곽선·그림자·모서리·나뭇결·쇠못·밧줄·이정표 끝·글자 외곽선·마우스 올림). 시안 px × 0.667.
- `UiKit.Board` (PanelContainer, `_draw`로 그림 — 텍스처·셰이더 없음): kind "wood"(그라데이션 + 판자 이음선 + seed 고정 물결 결·옹이, 위 밝은 띠) / "parch"(왼쪽 위 밝게·오른쪽 아래 누렇게·가장자리 그늘) / "gilt".
  잉크 외곽선은 판 안쪽, 아래로 단단한 그림자. 옵션 nails 0/1(위 가운데)/2/4, arrow(이정표, 오른쪽 여백에 UI_KIT.arrow_tip), ropes(위로 밧줄 2개), tilt(배경만, ±3° 한도), paint(바탕색 바꾸기).
- 버튼: `KitButton`(Button 그대로 — text·pressed·disabled). Button 글자는 투명, 판 안의 `caption`이 같은 글자를 그린다. `selected = true` → 형광펜 바탕.
  `primary` = 금칠 판(쇠못 2, 잉크 글자, 화면에 하나), `ghost`·`back` = 양피지, `navbtn` = 이정표 Tap(hero는 금칠). 고른 표시는 `selected`로 (예전 stylebox 덮어쓰기·modulate 대신).
  `Face`: host 위를 덮는 빈 Control. 안의 판을 Tween으로 움직여서(마우스 올림 = 살짝 들리고 -1°, 이정표는 오른쪽으로 7px, 누름 = 그림자 쪽으로 꾹) Container가 rotation을 되돌리지 않는다.
- 기울이기: Container 자식은 rotation·scale이 초기화된다 → `UiKit.tilted(ctrl, deg)`로 감싸서 넣는다. ±3° 이하, **숫자 있는 판은 안 기울인다**.
- 글자: 나무판 위 = `UiKit.wood_text(l, size)` (cream + 잉크 외곽선 `outline_for(size)` 3~9 + 아래 그림자), 양피지 위 = 잉크색. 개구 = `UiKit.scribble(...)`.
- 사진으로 확인: `tests/screenshot_ui.gd` (설정·메인·재료 견본).
- **메인 메뉴 (완료, 시안 Main)**: `menu._build_main` — 화면 전체 Control에 시안 좌표(×0.667)로 놓음. 수치·문구는 `GameData.MAIN_MENU`, 버전은 `GameData.VERSION`.
  - 뒤는 맵 도는 구경 카메라 그대로, 화면 전체 그늘(`_screen`의 bg, meta "bg") 대신 왼쪽만 어둡게. 다른 페이지로 가면 bg를 다시 켬 (`show_page`).
  - 왼쪽 위: 밧줄에 매달린 나무 간판 "중세난장판"(쇠못 4, -2°) + 양피지 "일단 던져."(개구, +3°). 예전 영어·설명 문단은 뺐다.
  - 세로 나무 기둥 + 이정표 5개(`_nav_sign`, `UiKit.sign_tap`): 일반대전(빨간 도장 "준비 중" → 알림) / AI대전(가장 큼·개구 "멍청한 봇이랑 한판") / 친구대전("친구를 넘어뜨리자") / 설정 / 도망가기(양피지 = 나가기).
    아이콘은 `UiKit.NAV_ICONS` SVG 문자열 (칼·로봇·사람 둘·톱니·문 화살표). 마우스 올리면 오른쪽으로 7px(시안 10px)·-1° + 판이 금칠 노랑 (`Face.hover_paint`, 사용자 요청 — 예전엔 AI대전만 늘 금칠).
  - 오른쪽 위 "오늘의 팁"(못 1, +2.5°): `MAIN_MENU.tips`에서 메인을 열 때마다 하나. 줄 바꿈은 \n으로 직접 (개구가 브라우저보다 넓어서 자동 줄바꿈이면 한 글자만 넘어감).
    규칙에 맞게 고친 것: 활은 "끝까지 당긴 채 3초"(slip_t는 다 당긴 뒤부터 셈), 성수는 "남이 던진" 웅덩이만 느려짐. 규칙이 바뀌면 팁도 고칠 것.
  - 오른쪽 병과 무리: `menu_crowd.gd` (야만인·궁수·음유시인·성직자, 느린 대기 = 몸 좌우·고개 까딱). `Menu._process`가 메인이 보일 때만 `set_active(true)`.
  - 왼쪽 아래 "v0.4 · 온라인 친구대전 지원".
  - 사진: `tests/screenshot_ui.gd`가 main·main_hover를 찍고 팁마다 줄 수(OK/WRAP!)를 출력한다.
- **병과 선택 (완료, 시안 ClassSelect)**: `menu._build_class` — 화면 전체 Control(시안 좌표 1280×720 가운데 맞춤), 배경 `UiKit.Wall`(판자벽). 수치·문구는 `GameData.CLASS_PAGE`.
  - 메뉴 그늘을 끄는 페이지 = `Menu.FULL_PAGES` (main·class).
  - 위 양피지 "누가 나갈래?"(못 2, -1.5°), 오른쪽 벽에 작게 "AI대전 · 난이도 · 모드"(`_class_sub`).
  - 왼쪽 큰 액자: `scripts/ui/model_stage.gd` (SubViewport 하나에 고른 병과 DerpModel, 천천히 좌우). 병과 화면이 보일 때만 그림 (`Menu._process`).
    빨간 "합격" 도장(14°) — 다른 카드를 고르면 Tween으로 쾅 + `Sfx "stamp"`.
  - 오른쪽 정보 양피지(못 4): 이름(형광펜 밑줄) + "무기: X", 개구 한마디(`CLASS_PAGE.lines`), 점선, 체력·속도·사거리 막대 + 숫자, 한 줄 설명(`blurbs`, {cd}처럼 무기 값 채움).
    숫자는 `GameData.class_stats(k)`: 속도 = 걷기 / 달리기(×SPRINT), 사거리 = `weapon_reach` (눈높이 1.62m에서 수평으로 쏴 땅에 닿는 거리, range 상한. 트럼펫은 range). 막대 = 병과 중 최대값 대비. 시안 숫자보다 실제 값 우선.
  - 아래 카드 5장(양피지·못 1·기울기 다름·잉크 숫자 1~5): 그림은 `ModelStage.portrait(k)`로 한 번만 찍은 텍스처 (헤드리스면 없음). 고른 카드 = `Board.ring` 형광펜 테, 마우스 올리면 들림.
  - **카드를 누르면 고르기만** (`pick_class_card`), 금칠 "이놈으로 출전"(못 4)이 `select_class`. 숫자키 1~5는 예전처럼 바로 시작. "← 뒤로" = 모드 페이지.
  - 대기실·일시정지의 작은 병과 카드(mini)는 예전 `UiKit.class_card` + `_fill_cards` 그대로.
- **난이도·모드 페이지**: 같은 양피지 카드(`menu._fill_pick`, `GameData.PICK_CARDS`, 못 1, 위쪽 색 띠 `Board.bands`). 누르면 고르기(형광펜 테), 금칠 "다음"으로 저장하고 넘어감.
  쟁탈전 카드 띠는 블루|레드. 배치(제목·뒤로)는 아직 예전 `_sheet`/`_pagehead`.
- 사진: `tests/screenshot_ui.gd`가 diff·mode·class도 찍는다.
- **경기 화면 HUD (완료, 시안 Hud)**: 수치는 `GameData.HUD_UI`. 기능·계산은 그대로, 그리는 것만 바꿈.
  - 규칙 (Guide): 가운데 40%는 비움(조준점·고리·맞힘 X·조준점 아래 쪽지·배너·사망 쪽지만), 정보는 네 모서리 + 위 가운데, 모서리 판 높이 80 이하(1080p 120px), 팀 = 색 + 글자 + 방패 귀퉁이.
    `test_match`가 가운데 40% 겹침·판 높이를 확인한다. 판에 줄을 더하면 이 테스트를 볼 것.
  - 개인전 위 가운데(`_topbar`): 밧줄 나무 꼬리표 = 남은 시간, 아래 양피지 = 1위 (강조는 [bgcolor] 형광펜).
  - 쟁탈전 위 가운데(`ControlHud.Top`, 직접 그림): 꼬리표 "쟁탈전 · N판", 블루 방패(오른쪽 아래 귀퉁이 둥글게)·레드 방패(거울) + 이긴 판 동그라미(rounds_to_win개, 이기면 형광펜),
    가운데 메달 = 바깥 고리 주인 색 + 점령 중인 팀 색 부채꼴(cap_prog), 안쪽 양피지 깃발 = 주인 색(중립 dust, 잠김 회색), 아래 % 막대 둘 + 양피지 상태 쪽지(경합·연장전은 빨간 글자).
  - 월드: 거점 위 나무 표지판 "거점 Nm"(아래 띠 = 주인 색, 조준점에 가까우면 흐려짐 `sign.fade_r`), 화면 밖이면 가장자리 화살표. 아군 = 이름 + 팀 색 ▼.
  - **조준한 적 닉네임** (사용자 요청, 개인전): 조준점이 적 몸(가슴 1m ~ 머리 위 `HUD_UI.aim_name.lift`)을 가리키고 벽에 안 가렸으면 그 적 머리 위에 이름 (배경 없이 잉크 외곽선, 여럿이면 가장 가까운 한 명).
    `Hud.AimName` — 판정은 쟁탈전 적 이름과 같은 `ControlHud.aimed_at`. 쟁탈전에선 숨기고 ControlHud가 팀 색으로 그림. 내가 죽었거나 구경 중이면 안 뜸.
  - 킬피드: 양피지 줄 "공격자 [무기 아이콘] 피해자 [헤드샷 꼬리표]", 이름은 팀 `ink` 색(개인전 잉크), 나는 "나" + 형광펜 밑줄, 내가 낀 줄은 형광펜 테(`Board.ring`).
    무기 아이콘 = `UiKit.WEAPON_ICONS` (SVG, kind별 11개, 모르는 kind는 돌멩이). 무기를 새로 넣으면 아이콘도 넣을 것.
  - 왼쪽 아래: 둥근 나무 액자(`Hud.Medal`, 병과 색 동그라미 + 병과 아이콘) + 나무판(이름 `_cls`·체력 숫자·`Hud.HpBar`). 25% 이하면 막대 빨갛게 깜빡, 재생 중엔 초록 빛.
    투구 없음·성수 젖음·다음 부활 병과는 판 위 작은 양피지 쪽지(`_cls_note`).
  - 오른쪽 아래: 양피지 칸(못 2) = 무기 아이콘 + 이름(형광펜 밑줄) + 상태 한 줄(+ 음유시인 숨 막대), 위에 Q 안내, 맨 아래 "속도 · Esc 메뉴 · Tab 점수판".
  - 특수 아이템 안내 줄·무적 막대는 위 가운데 점수판 바로 아래(`_notes`). 속도는 가운데 아래에서 오른쪽 아래로 옮김.
  - 사망 = 배경 없는 자막: 개구 "넘어졌다... 다시?"(양피지색) + "X에게 당했다" + 무기·부활. Tab 점수판 = 나무판(못 4). pop_msg = 조준점 아래 금색 자막 (배경 없음).
  - 글자 줄 높이가 커서(대체 폰트) 판이 높아지면 `UiKit.trim_font`로 위아래 빈 줄을 줄인다.
- **결과 화면 (완료, 시안 Result*.jpg 4장)**: `menu._build_end`, 배치 수치는 `GameData.RESULT_UI`. 연출(아래 "결과 화면 승리·패배 연출")은 그대로.
  - 왼쪽 위: 밧줄에 매달린 나무 제목 판 "1등!"/"6등..."(지면 바랜 색 `lose_paint`, 긴 제목은 작은 글씨·왼쪽으로) + 쪽지(이기면 노랑·개구). 쟁탈전 승리는 판 대신 팀 깃발 `Pennant` "블루팀 / 승리!" + 라운드 동그라미 `RoundDots`.
    쟁탈전 패배 = "우물을 빼앗겼다..." + 쪽지 끝 동그라미 + 작은 깃발 "레드팀 승리"(`_end_winner`), 버튼 "우물 되찾기".
  - 왼쪽 무대 `result_stage.gd`: 개인전 승리 = 나무 시상대 2·1·3 위에 1~3등, 개인전 패배 = 쓰러진 나 + 개구 "(넘어짐 N회)"(죽은 횟수), 쟁탈전 = 나무 발판 위 우리 팀 5명. 내 머리 위 "나" 꼬리표.
  - 오른쪽 양피지 결과판(못 4): 개인전 = 순위·이름·병과·처치·죽음 (내 줄 = 이기면 형광펜, 지면 하늘색 + 잉크 테),
    쟁탈전 = 블루·레드 라운드/처치/우물 차지 시간 + 우리 팀 줄 + MVP(거점 시간 가장 긴 사람, 0이면 처치왕) 또는 "거점 위에 서 있던 시간: 나 N초".
  - 오른쪽 아래: 양피지 "메인 메뉴"·"병과 다시 고르기" + 금칠 `_end_again`. 결과 화면 뒤 그늘은 옅게(`bg_a`).
- **남은 화면 (완료)**: 수치는 `GameData.PAGE_UI`. 제목은 모두 매달린 나무 간판(`_head2`), 내용은 양피지 큰 판 + 못 4(`_big_board`).
  - 일시정지: 판 안에 병과 카드 5장(작은 양피지 카드 `_fill_cards`, 못 1, 고름 = 형광펜 테) + 금칠 계속하기 + 양피지 설정·메뉴로 나가기. 일시정지 → 설정은 설정 패널 그대로.
  - 나가기 안내(웹): "도망 성공!" + 정확한 안내 + 금칠 "다시 하러 가기". 친구대전: 양피지 글자 칸(`_field`), 금칠 방 만들기, 양피지 참가.
  - 대기실 (**예외 — 사용자 요청으로 "게시판 색 + 정갈한 배치"**): 기울기·못·밧줄 없이 Container로 반듯하게, 나무판은 제목 간판 하나만. 색은 게시판 팔레트(`GameData.UI`) 그대로.
    스타일은 `ui/lobby_theme.tres` 하나 (`LobbyTheme.build()` ← `GameData.LOBBY_UI`, 글자 크기 3단계 title·body·small). 노드엔 `theme_type_variation`만 쓰고 `add_theme_*_override` 안 함.
    `test_ui_kit`가 저장본 = GameData 값인지, 색이 전부 팔레트인지 확인. 수치를 바꾸면 `tests/make_lobby_theme.gd`를 다시 돌릴 것.
    주의: Label 변형과 Button 변형 이름이 겹치면 Label이 Button의 stylebox를 그린다 (그래서 버튼은 `SmallButton`).
  - 알림(toast): 아래 가운데 양피지 쪽지 + 못 1, 나타날 때 위에서 살짝 떨어지며 못을 축으로 흔들림 (`PAGE_UI.toast.wobble`).
- 옛 `UiKit.class_card`(어두운 병과 카드)는 지웠다. `score_table`·`team_table`(크림 글자)은 Tab 점수판(나무판)만 쓴다.

## 결과 화면 승리·패배 연출 (사용자 요청 — HTML엔 없음)

수치·문구는 `GameData.RESULT`·`RESULT_LINES`·`STINGER`. 코드는 `menu.gd`의 결과 부분 (`_show_end`·`_play_end_fx`·`_end_fx_reset`).
- 판정: 개인전 1~3등 = 승리(제목 "N등!"), 4등부터 패배("N등..."). 쟁탈전은 내 팀 = 이긴 팀이면 승리("블루팀 승리!"), 아니면 "패배...". 무승부는 연출·소리 없이 예전 그대로.
- 문구: 목록에서 무작위로 골라 제목 판 아래 노란 쪽지(-3°). 패배면 '한 판 더' → "복수하러 간다".
- 소리: `Sfx.play_stinger("victory"/"defeat")` (전용 플레이어, SFX 버스, 헤드리스에선 `last_stinger`만 남김). BGM은 0.3초 만에 줄고, 효과음이 끝나면(`Sfx.stinger_done`) 메뉴 곡이 1.5초 페이드인.
- 승리: 0초 `Engine.time_scale` 0.3을 실제 0.6초 → 0.3초 제목 판이 떨어져 통통·좌우 흔들 → 0.5초 효과음 + 금빛 햇살(`Sunburst`) + 색종이(CPUParticles2D, 쟁탈전은 팀 색+금).
- 패배: 0초 뒤 화면 회색(화면 텍스처 셰이더) → 0.3초 판이 떨어져 오른쪽 못이 빠지고 10° 기울어짐 → 0.5초 효과음 → 0.6초 먹구름(`Clouds`)·비.
- 1.4초부터 점수판 줄이 0.06초 간격으로 펼쳐지고 그 뒤 버튼. Tween은 `_track()` (time_scale 무시).
- 결과 화면을 떠나면(`show_screen`이 end가 아니면) 입자·Tween·time_scale·효과음을 다 되돌린다.
- 히트스톱은 자기가 늦춘 time_scale만 되돌린다 (`Combat._hs_on`) — 결과 화면 느린 화면을 덮어쓰지 않게. Music 페이드는 실제 시간.
- 쪽지 글꼴은 개구 (`UiKit.scribble`).

## 웹 내보내기 (10단계)

```bash
godot --headless --path . --export-release "Web" export/web/index.html
cd export/web && python -m http.server 8060   # 브라우저로 http://localhost:8060 (파일을 바로 열면 안 됨)
```
- 웹 템플릿은 `%APPDATA%/Godot/export_templates/4.7.2.stable/`에 web_nothreads_release/debug.zip만 깔려 있다 (전체 1.3GB 대신 필요한 것만 받음).
- 스레드 없는(nothreads) 빌드라 COOP/COEP 헤더가 필요 없다 → GitHub Pages·itch.io에 그대로 올리면 된다.
- 웹에서도 친구대전이 된다 (WebRTC는 브라우저 것). Web 프리셋은 `addons/webrtc_native/*`를 빼고 내보낸다 (안 빼면 브라우저 콘솔에 확장 못 찾음 오류). 올리는 곳: Vercel (`npx vercel deploy export/web --prod`) 또는 GitHub Pages·itch.io — README "웹으로 올리기".
- 웹에선 Esc를 브라우저가 가져가 마우스 잠금만 풀린다 → 잠금이 풀리면 일시정지 (`main._check_web_lock`, HTML pointerlockchange).
- 웹엔 시스템 폰트가 없어서 폰트에 없는 글자는 □로 나온다. UI 글자를 새로 넣으면 도현·대체 폰트에 있는지 확인할 것.
- 최적화: 움직이지 않는 맵 조각은 `world_builder._merge_static()`이, 캐릭터의 관절별 조각은 `derp_model._merge()`가 `Meshes.merge()`로 정점 색 메시 하나로 합친다.
  그리기 호출이 경기 중 약 1300 → 200으로 줄었다. 맵·캐릭터에 조각을 더하면 자동으로 합쳐진다 (눈동자·볼은 안 합침).
  합친 메시는 정점 색 재질(`Meshes.vertex_color_mat`)을 쓴다. 캐릭터 번쩍임은 그 재질도 같이 바뀐다.
- **최적화 2차** (사용자 요청 — 측정: `tests/perf_profile.gd`, 1280×720 Intel Arc 내장 그래픽):
  메뉴 180 → 284 FPS (그리기 호출 1135 → 559), 개인전 251 → 319 (620 → 479), 쟁탈전 178 → 266 (774 → 587).
  - 1인칭 손 화면(`viewmodel.gd`의 화면 크기 SubViewport, MSAA 2배)은 **보일 때만** 그린다. 예전엔 3인칭(기본)·메뉴·죽음 중에도 매 프레임 그렸다.
  - 손에 든 무기도 그룹 안 조각끼리 합친다 (트럼펫 13 → 1). 반투명 재질(성수병 유리)은 안 합친다 (`_merge_node`).
  - **2D는 `UiKit.Tris`로 한 번에**: Compatibility 렌더러는 draw_colored_polygon·draw_polyline·draw_circle(부드럽게)을 하나하나 따로 그린다.
    `Board`는 외곽선·바탕·결·띠·못을 크기·종류·색이 바뀔 때만 삼각형 한 묶음(`_geo.tris`)으로 만들고, 그릴 땐 밧줄·고름 테·그림자 + 그 묶음을 한 번에 (판 하나 40~60번 → 1~2번).
    쇠못(`add_nail`)·쟁탈전 위 점수판(`ControlHud.Top`, 80 → 33번, 남은 건 글자)도 같은 방식. 부드러운 테두리는 바깥 1px을 투명으로 흐리게 해서 흉내 냄 (사진 비교 차이 0.1~0.5%).
    **새 HUD·UI 도형을 그릴 땐 draw_* 여러 번 대신 `UiKit.Tris`에 모아 `draw(self)` 한 번.** 볼록 다각형은 `poly`, 오목하면 `Geometry2D.triangulate_polygon` + `raw`.
  - 남은 큰 것: 캐릭터(한 명 15~25번 + 그림자, 삼각형 1.3만~2.5만), 그림자 패스(약 160번), 외곽선·그림자 있는 글자(줄마다 8~20번).
  - CPU(스크립트)는 물리 프레임 한 번에 0.5~1.5ms (봇 AI 절반) — `tests/perf_cpu.gd`. `Performance`의 TIME_* 값은 여러 물리 스텝을 묶어 세서 믿지 말 것.
- **웹 렉 대응** (사용자 피드백 "웹에서 메뉴부터 뚝뚝 끊김"):
  - **F3 = 성능 표시** (`scripts/ui/perf_hud.gd`, Main 아래 PerfHud, 저장 안 함): FPS·가장 느린 프레임, 평균 프레임·물리 한 번 시간·한 프레임에 물리 몇 번, 그리기 호출·삼각형, 3D 해상도·MSAA, 그래픽 카드 이름.
    웹은 브라우저가 "WebKit WebGL"로 가려서 `WEBGL_debug_renderer_info`로 진짜 이름을 물어본다. SwiftShader·llvmpipe 같은 소프트웨어면 "하드웨어 가속이 꺼져 있어요" 경고 (`PERF_HUD.soft_gpu`).
  - **3D 해상도** (설정 화면 "해상도" 100/85/70/50%, `GameData.RES_SCALES`, `[video] scale`): `Viewport.scaling_3d_scale` (Compatibility는 bilinear만). 글자·HUD는 그대로 선명.
    웹에서 직접 고른 적이 없으면(`res_scale_saved`) 브라우저 화면 점 수로 자동 (`auto_res_scale` — `WEB_PERF.auto_mpix` 190만 점 이하: 720p 100%, 1080p 85%, 1440p 70%, 4K 50%). 브라우저 화면은 창 전체 × 화면 배율이라 PC 창 1280x720보다 점이 몇 배 많다.
  - **MSAA**는 그래픽 품질에 따라 (`GFX.*.msaa`, 웹은 `web_msaa` — 보통까지 끔). 예전엔 project.godot의 2배가 늘 켜져 있었다.
  - 웹은 `Engine.max_physics_steps_per_frame = WEB_PERF.max_physics_steps`(3): 느린 프레임 뒤에 물리를 8번까지 몰아 돌려 더 느려지는 걸 막음.
  - **그리기 호출 줄이기 2** (사용자 "PC는 부드러운데 웹만 메뉴부터 30fps 아래" — 브라우저는 그리기 호출 하나하나가 비쌈. 메뉴 약 480 → 400번, 웹 그림자까지 하면 약 300번):
    - 날아가는·꽂힌 화살 = `WeaponModels.make_arrow_fast` (조각 4개 → 합친 메시 1개, 종류마다 메시 하나를 같이 씀, 그림자 끔). 1인칭 손은 그대로 `make_arrow`.
    - 맵의 말·닭·진열된 저격총/AK·던진 닭 = `Meshes.merge_tree(노드, skip)` (같은 부모의 움직이지 않는 조각끼리 합침, 정점 색 재질 `Meshes.shared_vc_mat`).
      말은 꼬리(따로 흔들림)·마상창(`Items.held_lance`가 창끝 조각을 찾음)을 skip. 새 모델에 쓸 땐 따로 움직이는 MeshInstance3D를 skip에 넣을 것.
    - 웹 그림자 거리 `GFX.*.web_shadow_dist` (보통 70m, 높음 220m) → `GameData.shadow_dist_now()`.
    - 메뉴 병과 무리·병과 액자·결과 무대·1인칭 손 SubViewport의 MSAA도 `GameData.msaa_now()`를 따름.
  - **웹 렉 대응 3** (사용자 "웹이 메뉴·경기 내내 끊기고 노래도 끊김", 탭 하나여도):
    - 웹은 그래픽 품질을 직접 고르기 전엔 `WEB_PERF.quality`("low" — 그림자·잔디·소품 끔)로 시작. 설정에서 고르면 `[video] quality_set = true`로 저장하고 그걸 씀 (예전 파일의 기본 '보통'은 무시). PC는 그대로.
      측정(PC 1280×720): 개인전 274 → 484 FPS·그리기 358 → 242, 쟁탈전 218 → 343·466 → 298.
    - 소리 속성은 **바뀔 때만** 넣는다 (`Music.set_db`·`set_paused`, Sfx 반복 소리). 웹은 음악을 브라우저 소리(Sample)로 틀어서 넣을 때마다 브라우저에 명령이 가는데, 예전엔 매 프레임 `stream_paused = false`·`volume_db`를 넣었다.
    - 트럼펫 멜로디(`TrumpetVoice`)는 조용하면 플레이어를 멈춤 (예전엔 메뉴 무리·봇 음유시인마다 늘 돌며 0을 채움 — 웹은 소리 섞기가 화면 프레임 안이라 부담). 동시에 소리를 만드는 건 가장 큰 `MAX_VOICES`(2)개, 음높이는 32샘플마다 계산.
    - 병과 고르기·대기실처럼 화면을 다 덮는 페이지(`Menu.COVER_PAGES`)에선 뒤의 3D를 안 그림 (`viewport.disable_3d`, `menu._sync_3d`).

## PC 내보내기 (exe)

```bash
godot --headless --path . --export-release "Windows" "export/windows/중세난장판.exe"
```
- exe 하나에 게임 데이터가 다 들어 있다 (`binary_format/embed_pck`). 친구대전용 `libwebrtc_native.windows.template_release.x86_64.dll`이 옆에 같이 나오니 **exe와 dll을 같이** 준다 (zip으로 묶기).
- 윈도 템플릿은 `windows_release_x86_64.exe`·`_console.exe`만 받아 두었다 (웹 템플릿과 같은 폴더).
- 코드 서명·아이콘 바꾸기(rcedit)는 안 함 → 처음 실행할 때 Windows SmartScreen이 "알 수 없는 게시자"라고 막을 수 있다 ("추가 정보 → 실행").

## 테스트 실행

Godot 실행 파일 경로는 환경에 맞게 바꾼다 (Windows 예: `Godot_v4.7.2-stable_win64.exe`).

```bash
# 스크립트 오류 확인 (2초 실행 후 종료)
godot --headless --path . --quit-after 120

# 이동·전투·돌멩이 자동 테스트 — 모두 "ALL PASS"가 나와야 함
godot --headless --fixed-fps 60 --path . -s tests/test_movement.gd
godot --headless --fixed-fps 60 --path . -s tests/test_trip.gd
godot --headless --fixed-fps 60 --path . -s tests/test_combat.gd
godot --headless --fixed-fps 60 --path . -s tests/test_stone.gd
godot --headless --fixed-fps 60 --path . -s tests/test_bow.gd
godot --headless --fixed-fps 60 --path . -s tests/test_crossbow.gd
godot --headless --fixed-fps 60 --path . -s tests/test_close_range.gd
godot --headless --fixed-fps 60 --path . -s tests/test_hitbox.gd
godot --headless --fixed-fps 60 --path . -s tests/test_holy.gd
godot --headless --fixed-fps 60 --path . -s tests/test_cannon.gd
godot --headless --fixed-fps 60 --path . -s tests/test_vampire.gd
godot --headless --fixed-fps 60 --path . -s tests/test_bot.gd
godot --headless --fixed-fps 60 --path . -s tests/test_match.gd
godot --headless --fixed-fps 60 --path . -s tests/test_items.gd
godot --headless --fixed-fps 60 --path . -s tests/test_fx.gd
godot --headless --fixed-fps 60 --path . -s tests/test_net.gd   # 가짜 신호 서버 포트 24690 + 진짜 WebRTC (1~2분)
godot --headless --fixed-fps 60 --path . -s tests/test_net_control.gd   # 포트 24691
godot --headless --fixed-fps 60 --path . -s tests/test_bard.gd
godot --headless --fixed-fps 60 --path . -s tests/test_bard_fx.gd
godot --headless --fixed-fps 60 --path . -s tests/test_music.gd
godot --headless --fixed-fps 60 --path . -s tests/test_fish.gd
godot --headless --fixed-fps 60 --path . -s tests/test_control.gd
godot --headless --fixed-fps 60 --path . -s tests/test_map_deco.gd
godot --headless --fixed-fps 60 --path . -s tests/test_ui_kit.gd
godot --headless --fixed-fps 60 --path . -s tests/test_result_fx.gd
```

처음 받은 저장소(.godot 없음)는 먼저 `godot --headless --editor --path . --quit`를 한 번 돌려야 webrtc_native 확장이 등록된다 (안 하면 test_net이 "WebRTC 쓸 수 있음"에서 실패).
새 `class_name` 스크립트를 추가하면 한 번 `godot --headless --editor --path . --quit`로 클래스 목록을 갱신해야 다른 스크립트가 찾는다.

테스트에서 `await physics_frame` 한 번만 누르고 바로 떼면 캐릭터가 입력을 읽기 전에 떼질 수 있다. 한 번 쏘기는 2프레임 누른다.
`-s` 테스트 스크립트에선 오토로드 이름(`GameData`)을 바로 쓸 수 없다. `root.get_node("GameData")`로 접근한다.
같은 이유로 테스트 스크립트에서 `BotAI`·`Combat` 같은 class_name 타입을 직접 적으면(`var ai: BotAI`, `Combat.seg_point`) GameData보다 먼저 컴파일돼 실패한다. 타입 없이 쓰거나 인스턴스(`C.seg_point`)로 부른다.
main.tscn은 메뉴 상태로 시작한다. 경기가 필요한 테스트는 `root.add_child(main)` 뒤에 `main.start_match.call_deferred()`를 부른다 (바로 부르면 Main이 아직 트리에 없음).
히트스톱은 프레임 수로 시간을 재는 테스트를 망치므로 테스트에선 `GameData.hitstop_enabled = false`로 끈다.
그 전에 `GameData`의 save_enabled·third_person·difficulty·chosen_cls를 정해 두면 저장된 설정과 상관없이 같은 조건으로 돈다.
플레이어는 `scripted_input` 딕셔너리로 입력을 흉내 낼 수 있다. 같은 구조로 봇 입력에도 쓸 수 있다.

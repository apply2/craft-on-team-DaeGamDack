class_name TrumpetVoice
extends AudioStreamPlayer
## 음유시인 트럼펫 멜로디 (4.5단계) — AudioStreamGenerator로 톱니파 + 비브라토 + 로우패스를 실시간으로 만든다.
## 연주하는 동안 "도-미-솔-미-도-솔-도"를 반복하고, 음마다 ±detune 센트씩 음정이 살짝 틀어진다.
## DerpModel이 음유시인 몸에 하나씩 붙이고 매 프레임 update(연주 중?, 위치)를 부른다.
## 크기는 Sfx.vol_at(거리)를 따른다. 소리가 꺼진 환경(헤드리스)에선 만들지 않는다.
## 가볍게 (웹 렉 대응): 조용하면 플레이어를 멈추고(generator가 안 돎), 동시에 만드는 건 가장 큰 MAX_VOICES개만,
##   음높이(비브라토·센트)는 PITCH_EVERY샘플마다 한 번만 계산한다.

const MAX_VOICES := 2      # 동시에 소리를 만드는 트럼펫 수 (가장 크게 들리는 것부터)
const PITCH_EVERY := 32    # 음높이를 다시 계산하는 간격 (샘플). 22050Hz에서 1.5ms — 비브라토 6Hz엔 충분
static var _all: Array[TrumpetVoice] = []

var _pb: AudioStreamGeneratorPlayback
var _on := false
var _vol := 0.0        # 지금 크기 (부드럽게 따라감)
var _want := 0.0
var _ph := 0.0         # 톱니파 위상
var _vt := 0.0         # 비브라토 시간
var _lp := 0.0         # 로우패스 상태
var _ni := 0           # 몇 번째 음
var _nt := 0.0         # 이 음에서 지난 시간
var _cents := 0.0      # 이 음의 틀어짐


func _ready() -> void:
	var S: Dictionary = GameData.TRUMPET_SND
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(S.rate)
	gen.buffer_length = 0.15
	stream = gen
	bus = "SFX"
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # 웹의 Sample 재생 방식에선 generator가 안 돈다
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


## 이 트럼펫보다 크게 들리는 트럼펫 수 (MAX_VOICES 이상이면 이번엔 소리를 안 만듦)
func _rank() -> int:
	var r := 0
	for v in _all:
		if v != self and (v._want > _want or (v._want == _want and v.get_instance_id() < get_instance_id())):
			r += 1
	return r


func update(on: bool, pos: Vector3) -> void:
	if on and not _on:  # 다시 불기 시작하면 멜로디 처음부터
		_ni = 0
		_nt = 0.0
		_cents = randf_range(-1, 1) * float(GameData.WEAPONS.trumpet.detune)
	_on = on
	_want = Sfx.vol_at(pos) * GameData.SFX_VOL * float(GameData.TRUMPET_SND.vol) if on else 0.0


func _process(_dt: float) -> void:
	var want := _want if _want > 0.001 and _rank() < MAX_VOICES else 0.0
	if want <= 0.0 and _vol < 0.0005:  # 조용하면 멈춤 (웹에선 소리 섞기를 화면 프레임이 맡아서, 도는 generator마다 부담)
		_vol = 0.0
		if playing:
			stop()
			_pb = null
		return
	if not playing:
		play()
		_pb = get_stream_playback()
	if not _pb:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var S: Dictionary = GameData.TRUMPET_SND
	var rate := float(S.rate)
	var note_len := float(S.note)
	var step := note_len + float(S.gap)
	var mel: Array = S.melody
	var base := float(S.base_hz)
	var vib_hz := float(S.vib_hz)
	var vib_c := float(S.vib_cents)
	var a := 1.0 - exp(-TAU * float(S.lowpass) / rate)
	var detune := float(GameData.WEAPONS.trumpet.detune)
	var buf := PackedVector2Array()
	buf.resize(n)
	var inv := 1.0 / rate
	var df := 0.0  # 한 샘플에 위상이 도는 양 (PITCH_EVERY마다 다시 계산)
	for i in n:
		_vol += (want - _vol) * 0.0015
		_nt += inv
		var fresh := i % PITCH_EVERY == 0
		if _nt >= step:
			_nt -= step
			_ni = (_ni + 1) % mel.size()
			_cents = randf_range(-1, 1) * detune
			fresh = true
		_vt += inv
		if fresh:
			var cents := float(mel[_ni]) * 100.0 + _cents + sin(_vt * TAU * vib_hz) * vib_c
			df = base * pow(2.0, cents / 1200.0) * inv
		_ph += df
		if _ph >= 1.0:
			_ph -= 1.0
		var env := 0.0
		if _nt < note_len:
			env = minf(1.0, _nt / 0.012) * minf(1.0, (note_len - _nt) / 0.03)
		_lp += a * ((2.0 * _ph - 1.0) - _lp)
		var s := _lp * env * _vol
		buf[i] = Vector2(s, s)
	_pb.push_buffer(buf)

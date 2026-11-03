# Underwater Procedural Audio Generator for Godot 4
# Synthesizes 16-bit PCM AudioStreamWAV assets in-memory with zero external dependencies.
class_name UnderwaterAudio

static var _cache: Dictionary = {}

static func get_stream(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStreamWAV = null
	match sound_name:
		"knife_slash":
			stream = _generate_knife_slash()
		"knife_hit":
			stream = _generate_knife_hit()
		"axe_swing":
			stream = _generate_axe_swing()
		"axe_hit":
			stream = _generate_axe_hit()
		"sonic_blast":
			stream = _generate_sonic_blast()
		"laser":
			stream = _generate_laser()
		"sonic_hit":
			stream = _generate_sonic_hit()
		"hit_confirm":
			stream = _generate_hit_confirm()
		"kill_sound":
			stream = _generate_kill_sound()
		"weapon_equip":
			stream = _generate_weapon_equip()
		"booster_start":
			stream = _generate_booster_start()
		"booster_stop":
			stream = _generate_booster_stop()
		"sub_torpedo_launch":
			stream = _generate_sub_torpedo_launch()
		"sub_torpedo_hit":
			stream = _generate_sub_torpedo_hit()
		"sub_heavy_blast":
			stream = _generate_sub_heavy_blast()
		"sub_enter":
			stream = _generate_sub_enter()
		"sub_exit":
			stream = _generate_sub_exit()
		"tame_success":
			stream = _generate_tame_success()
		"mount_ride":
			stream = _generate_mount_ride()
		"warp_escape":
			stream = _generate_warp_escape()
		"laser_marker":
			stream = _generate_laser_marker()
		"shield_deploy":
			stream = _generate_shield_deploy()
		"shield_retract":
			stream = _generate_shield_retract()
		"shield_block":
			stream = _generate_shield_block()
		"pet_recall":
			stream = _generate_pet_recall()
	if stream:
		_cache[sound_name] = stream
	return stream

static func play_sound(tree: SceneTree, sound_name: String, volume_db: float = -6.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	var stream := get_stream(sound_name)
	if not stream or not tree:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

static func _create_wav(samples: PackedFloat32Array, mix_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var int_val: int = int(clamped * 32767.0)
		bytes.encode_s16(i * 2, int_val)
	wav.data = bytes
	return wav

static func _generate_laser() -> AudioStreamWAV:
	var mix_rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(int(mix_rate * 0.18))
	var phase := 0.0
	for i in range(samples.size()):
		var t := float(i) / mix_rate
		phase += TAU * lerpf(2400.0, 650.0, t / 0.18) / mix_rate
		samples[i] = sin(phase) * exp(-t * 25.0) * minf(1.0, t * 300.0) * 0.65
	return _create_wav(samples, mix_rate)

# 1. 战术刀破水挥刃音效 (800Hz -> 240Hz 扫频 + 高通粉噪)
static func _generate_knife_slash() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.22
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI)
		# 频率从 820Hz 骤降至 210Hz
		var freq: float = lerpf(820.0, 210.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var tone := sin(phase) * 0.45
		# 水流湍流与空化噪声
		var noise := (randf() * 2.0 - 1.0) * 0.4
		samples[i] = (tone + noise) * env * 0.85
	return _create_wav(samples, mix_rate)

# 2. 战术刀切入生物肌体音效 (沉闷割裂与短促肉感冲击)
static func _generate_knife_hit() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.16
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 26.0)
		var freq: float = lerpf(340.0, 120.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var tone := sin(phase) * 0.6
		var noise := (randf() * 2.0 - 1.0) * 0.35 * exp(-t * 38.0)
		samples[i] = (tone + noise) * env * 0.9
	return _create_wav(samples, mix_rate)

# 3. 破拆重斧横扫挥击音效 (低频水涌 Whoosh，95Hz -> 35Hz 次重音)
static func _generate_axe_swing() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.42
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI)
		var freq: float = lerpf(115.0, 38.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var tone := sin(phase) * 0.75 + sin(phase * 0.5) * 0.25
		var turbulence := (randf() * 2.0 - 1.0) * 0.25 * env
		samples[i] = (tone + turbulence) * env * 0.95
	return _create_wav(samples, mix_rate)

# 4. 破拆重斧毁灭重击音效 (骨骼粉碎与水锤冲击爆裂)
static func _generate_axe_hit() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.32
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 14.0)
		var freq: float = lerpf(180.0, 42.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		# 次低频水锤轰击
		var sub := sin(phase) * 0.7
		# 冲击爆碎瞬态 (Crunch transient)
		var crunch := (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.5
		samples[i] = (sub + crunch) * env * 0.98
	return _create_wav(samples, mix_rate)

# 5. 声波脉冲发射音效 (电容瞬态充能瞬爆 + 水下高能声学激波)
static func _generate_sonic_blast() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.45
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 9.5)
		# 极速调频扫频 (Chirp: 1600Hz -> 65Hz)
		var freq: float = 1600.0 * exp(-t * 18.0) + 65.0
		phase += freq * TAU / float(mix_rate)
		var chirp := sin(phase) * 0.7
		# 高能水体空化低频回鸣
		var resonance := sin(t * 130.0 * TAU) * 0.3 * exp(-t * 6.0)
		samples[i] = (chirp + resonance) * env * 0.95
	return _create_wav(samples, mix_rate)

# 6. 声波脉冲震晕命中音效 (高频压电共振与水体震颤)
static func _generate_sonic_hit() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 18.0)
		phase1 += 620.0 * TAU / float(mix_rate)
		phase2 += 890.0 * TAU / float(mix_rate)
		var harmonics := (sin(phase1) + sin(phase2)) * 0.4
		var buzz := sin(phase1 * 3.0) * 0.15
		samples[i] = (harmonics + buzz) * env * 0.88
	return _create_wav(samples, mix_rate)

# 7. 击中确认滴答音 (Hit Confirm Tick)
static func _generate_hit_confirm() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.04
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 90.0)
		phase += 2200.0 * TAU / float(mix_rate)
		samples[i] = sin(phase) * env * 0.65
	return _create_wav(samples, mix_rate)

# 8. 巨兽击杀与能量释放低鸣
static func _generate_kill_sound() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.65
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * exp(-t * 2.5)
		var freq: float = lerpf(180.0, 32.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var sub := sin(phase) * 0.75 + sin(phase * 1.5) * 0.25
		samples[i] = sub * env * 0.95
	return _create_wav(samples, mix_rate)

# 9. 水下装备切换与机械卡扣拔出音效
static func _generate_weapon_equip() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.20
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	var click_phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI)
		# 柔和水涌声 (280Hz -> 85Hz)
		var freq: float = lerpf(280.0, 85.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var tone := sin(phase) * 0.5
		# 机械插鞘闭锁清脆微点击 (在 t ≈ 0.05s 时触发)
		var click_env := exp(-absf(t - 0.05) * 85.0)
		click_phase += 1650.0 * TAU / float(mix_rate)
		var click := sin(click_phase) * click_env * 0.4
		var water := (randf() * 2.0 - 1.0) * 0.2 * env
		samples[i] = (tone + click + water) * env * 0.8
	return _create_wav(samples, mix_rate)

# 10. 水下迷你助推器启动旋翼加速音效 (电驱涡轮高频升频)
static func _generate_booster_start() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.32
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := minf(1.0, t * 12.0) * (1.0 - (t / duration) * 0.25)
		var freq: float = lerpf(260.0, 920.0, pow(t / duration, 1.4))
		phase += freq * TAU / float(mix_rate)
		var tone := sin(phase) * 0.55 + sin(phase * 2.0) * 0.2
		var bubbles := (randf() * 2.0 - 1.0) * 0.28 * env
		samples[i] = (tone + bubbles) * env * 0.82
	return _create_wav(samples, mix_rate)

# 11. 水下迷你助推器熄火降频音效
static func _generate_booster_stop() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 8.5)
		var freq: float = lerpf(780.0, 180.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env * 0.72
	return _create_wav(samples, mix_rate)

# 12. 潜艇鱼雷管气动弹射射击音效
static func _generate_sub_torpedo_launch() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.35
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 9.5)
		var freq: float = lerpf(450.0, 95.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var hiss := (randf() * 2.0 - 1.0) * 0.42 * exp(-t * 22.0)
		samples[i] = (sin(phase) * 0.65 + hiss) * env * 0.95
	return _create_wav(samples, mix_rate)

# 13. 鱼雷水下爆破音效
static func _generate_sub_torpedo_hit() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.48
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 6.0)
		var freq: float = lerpf(160.0, 42.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var rumble := (randf() * 2.0 - 1.0) * 0.5 * exp(-t * 12.0)
		samples[i] = (sin(phase) * 0.7 + rumble) * env * 0.92
	return _create_wav(samples, mix_rate)

# 14. 泰坦巨型潜艇震荡深水重炮灭世轰击音效
static func _generate_sub_heavy_blast() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.85
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 3.8)
		var freq: float = lerpf(92.0, 24.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		var sub := sin(phase) * 0.85 + sin(phase * 0.5) * 0.35
		var crunch := (randf() * 2.0 - 1.0) * 0.65 * exp(-t * 18.0)
		samples[i] = (sub + crunch) * env * 0.98
	return _create_wav(samples, mix_rate)

# 15. 登舰气密舱门闭锁液压音效
static func _generate_sub_enter() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * exp(-t * 5.0)
		var freq: float = lerpf(380.0, 160.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env * 0.75
	return _create_wav(samples, mix_rate)

# 16. 离开潜艇泄压注水音效
static func _generate_sub_exit() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.24
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 10.0)
		var hiss := (randf() * 2.0 - 1.0) * 0.6 * env
		samples[i] = hiss * 0.8
	return _create_wav(samples, mix_rate)

static func _generate_tame_success() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.65
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var p1 := 0.0
	var p2 := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * exp(-t * 1.8)
		var f1: float = lerpf(520.0, 880.0, t / duration)
		var f2: float = lerpf(780.0, 1320.0, t / duration)
		p1 += f1 * TAU / float(mix_rate)
		p2 += f2 * TAU / float(mix_rate)
		samples[i] = (sin(p1) * 0.5 + sin(p2) * 0.35) * env
	return _create_wav(samples, mix_rate)

static func _generate_mount_ride() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.38
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * 0.6
		var freq: float = lerpf(140.0, 260.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env
	return _create_wav(samples, mix_rate)

static func _generate_warp_escape() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 1.2
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := clampf(t / 0.3, 0.0, 1.0) * exp(-t * 0.8)
		var freq: float = lerpf(220.0, 1200.0, (t / duration) * (t / duration))
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env * 0.7
	return _create_wav(samples, mix_rate)

static func _generate_laser_marker() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.16
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * exp(-t * 8.0)
		var freq: float = lerpf(1800.0, 950.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env * 0.5
	return _create_wav(samples, mix_rate)

static func _generate_shield_deploy() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * 0.85
		var freq: float = lerpf(260.0, 780.0, (t / duration) * (t / duration))
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env
	return _create_wav(samples, mix_rate)

static func _generate_shield_retract() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.22
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * exp(-t * 6.0) * 0.7
		var freq: float = lerpf(650.0, 180.0, t / duration)
		phase += freq * TAU / float(mix_rate)
		samples[i] = sin(phase) * env
	return _create_wav(samples, mix_rate)

static func _generate_shield_block() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.32
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var phase := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := exp(-t * 9.0)
		var f1: float = 880.0
		var f2: float = 1320.0
		phase += f1 * TAU / float(mix_rate)
		var tone := sin(phase) * 0.6 + sin(phase * 1.5) * 0.4
		var noise := (randf() * 2.0 - 1.0) * 0.35 * exp(-t * 18.0)
		samples[i] = (tone + noise) * env
	return _create_wav(samples, mix_rate)

static func _generate_pet_recall() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.45
	var total_samples := int(mix_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)
	var p1 := 0.0
	var p2 := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var env := sin((t / duration) * PI) * 0.75
		var freq1: float = lerpf(980.0, 1560.0, t / duration)
		var freq2: float = lerpf(1320.0, 2080.0, t / duration)
		p1 += freq1 * TAU / float(mix_rate)
		p2 += freq2 * TAU / float(mix_rate)
		samples[i] = (sin(p1) * 0.5 + sin(p2) * 0.35) * env
	return _create_wav(samples, mix_rate)

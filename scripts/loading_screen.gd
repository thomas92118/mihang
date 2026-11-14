extends CanvasLayer
## Custom expedition startup loading screen replacing Godot's default boot/loading view.
## On Desktop: animates a 60fps Sunken Observatory astrolabe & bathymetric gauge while
## background-loading heavy GLB libraries and scenes/main.tscn.
## On Web: coordinates stage telemetry with assets/web/custom_shell.html for a single
## seamless dissolve straight into the rendered 3D ocean title showcase.

const Art = preload("res://scripts/art_direction.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MIN_DESKTOP_DISPLAY_TIME := 1.45
const FADE_OUT_DURATION := 0.42

const PRELOAD_MANIFEST := [
	"res://assets/models/expedition_library.glb",
	"res://assets/models/reference_diver.glb",
	"res://assets/models/ocean_surface.glb",
	"res://assets/models/coral.glb",
	"res://assets/models/staghorn_coral.glb",
	"res://assets/models/table_coral.glb",
	"res://assets/models/brain_coral.glb",
	"res://assets/models/kelp.glb",
	"res://assets/models/rock.glb",
	"res://assets/models/ruins.glb",
	"res://assets/models/shipwreck.glb",
	"res://assets/models/pod.glb",
	"res://assets/models/manta_ray.glb",
	"res://assets/models/sea_turtle.glb",
	"res://assets/models/jellyfish.glb",
	MAIN_SCENE_PATH,
]

const BIOME_STAGES := [
	[0.00, "阳光浅礁带"],
	[0.18, "琉璃珊瑚礁花园"],
	[0.36, "翡翠巨藻迷宫海峡"],
	[0.54, "暮光大断崖"],
	[0.72, "东海沉没星象古都"],
	[0.88, "远古深海母树"],
	[0.96, "南极渊星辉圣域"],
]

const EXPEDITION_TIPS := [
	"穿行于珊瑚林间时，声呐脉冲可揭示沉睡遗迹与海沟航向。",
	"深入海沟水压更强，升级循环呼吸器可从容探索百米极渊。",
	"缔结契约的海洋伙伴会伴随左右，与你一同巡游九片海域。",
]

var _root: Control
var _plate: OceanLoadingPlate
var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _header_bar: ColorRect
var _header_label: Label
var _depth_caption: Label
var _depth_value: Label
var _biome_label: Label
var _eyebrow_bar: ColorRect
var _eyebrow_label: Label
var _title_label: Label
var _subtitle_label: Label
var _divider_bar: ColorRect
var _lead_label: Label
var _tip_label: Label
var _phase_label: Label
var _percent_label: Label
var _range_label: Label
var _ruler_labels: Array[Label] = []

var _queue: Array[String] = []
var _active_path := ""
var _loaded_count := 0
var _held_resources: Array[Resource] = []
var _main_packed: PackedScene = null
var _main_instance: Node = null

var _clock := 0.0
var _target_progress := 0.04
var _display_progress := 0.0
var _tip_index := 0
var _tip_timer := 0.0
var _stage := "loading" # loading -> instantiating -> warmup -> fading -> done
var _warmup_frames := 0
var _fade_elapsed := 0.0
var _skip_min_wait := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var user_args := OS.get_cmdline_user_args()
	if "--smoke-world" in user_args or "--capture" in user_args:
		set_process(false)
		_fast_boot_cli.call_deferred()
		return

	if OS.has_feature("web"):
		set_process(false)
		_build_web_bridge_backdrop()
		_run_web_handoff.call_deferred()
		return

	_build_desktop_ui()
	_start_preload_queue()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_skip_min_wait = true
	elif event is InputEventMouseButton and event.pressed:
		_skip_min_wait = true

func _fast_boot_cli() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		get_tree().root.add_child(inst)
		get_tree().current_scene = inst
	queue_free()

func _build_web_bridge_backdrop() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.color = Color(0.016, 0.078, 0.125, 1.0)
	_root.add_child(_backdrop)

func _run_web_handoff() -> void:
	_eval_web_js("if (window.__abyssalSetEngineStage) window.__abyssalSetEngineStage(0.90, '正在唤醒珊瑚森林与海底生态群落...');")
	await get_tree().process_frame

	for warm_path: String in ["res://assets/models/expedition_library.glb", "res://assets/models/reference_diver.glb"]:
		if ResourceLoader.exists(warm_path):
			var res := load(warm_path)
			if res != null:
				_held_resources.append(res)
			await get_tree().process_frame

	_eval_web_js("if (window.__abyssalSetEngineStage) window.__abyssalSetEngineStage(0.96, '正在整备珊瑚浅礁与深海光影...');")
	await get_tree().process_frame

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		get_tree().root.add_child(inst)
		get_tree().current_scene = inst

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if is_instance_valid(_backdrop):
		_backdrop.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	_held_resources.clear()
	_eval_web_js("window.__abyssalGameReady = true; if (window.__abyssalFinishLoading) window.__abyssalFinishLoading();")
	queue_free()

func _eval_web_js(code: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(code, true)

func _build_desktop_ui() -> void:
	var font: FontFile = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	var sym_font: FontFile = preload("res://assets/fonts/Symbols-Subset.ttf")
	var controls_font: FontFile = preload("res://assets/fonts/Controls-CJK-Subset.otf")
	var fallbacks: Array[Font] = font.fallbacks.duplicate()
	for fb: Font in [controls_font, sym_font]:
		if not fallbacks.has(fb):
			fallbacks.append(fb)
	font.fallbacks = fallbacks

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15

	_root = Control.new()
	_root.name = "LoadingRoot"
	_root.theme = theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float u_time = 0.0;
uniform float u_progress = 0.0;
void fragment() {
	vec2 uv = UV;
	vec3 top_col = mix(vec3(0.032, 0.165, 0.245), vec3(0.042, 0.205, 0.295), 0.5 + 0.5 * sin(u_time * 0.4));
	vec3 mid_col = vec3(0.020, 0.098, 0.162);
	vec3 bot_col = vec3(0.010, 0.042, 0.075);
	vec3 col = mix(top_col, mid_col, smoothstep(0.0, 0.56, uv.y));
	col = mix(col, bot_col, smoothstep(0.45, 1.0, uv.y));

	// Sunlit ocean caustic shafts from surface
	float slant1 = uv.x + uv.y * 0.36 + sin(u_time * 0.32) * 0.05;
	float slant2 = uv.x - uv.y * 0.24 - cos(u_time * 0.25) * 0.04;
	float ray1 = pow(max(0.0, sin(slant1 * 9.5 + u_time * 0.45)), 6.0);
	float ray2 = pow(max(0.0, sin(slant2 * 13.0 - u_time * 0.38)), 8.0);
	float depth_fade = (1.0 - smoothstep(0.02, 0.84, uv.y));
	col += vec3(0.24, 0.62, 0.66) * (ray1 * 0.075 + ray2 * 0.05) * depth_fade;

	// Subtle warm observatory glow around astrolabe side
	float astro_dist = distance(uv, vec2(0.73, 0.47));
	col += vec3(0.08, 0.30, 0.35) * (1.0 - smoothstep(0.0, 0.38, astro_dist)) * (0.28 + 0.12 * u_progress);

	// Vignette
	vec2 centered = (uv - 0.5) * 2.0;
	float vig = smoothstep(0.75, 1.65, dot(centered, centered));
	col = mix(col, vec3(0.006, 0.024, 0.042), vig * 0.52);
	COLOR = vec4(col, 1.0);
}"""
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = shader
	_backdrop.material = _backdrop_mat
	_root.add_child(_backdrop)

	_plate = OceanLoadingPlate.new()
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)

	_header_bar = _make_rect(_root, Art.AMBER)
	_header_label = _make_label(_root, "深 蓝 回 声   /   潜 航 准 备", 12, Art.MUTED)

	_depth_caption = _make_label(_root, "水深", 11, Art.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	_depth_value = _make_label(_root, "000 m", 26, Art.PAPER, HORIZONTAL_ALIGNMENT_RIGHT)
	_biome_label = _make_label(_root, "阳光浅礁带", 12, Art.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	_eyebrow_bar = _make_rect(_root, Art.AMBER)
	_eyebrow_label = _make_label(_root, "一 场 始 于 浅 礁 的 远 行", 14, Art.PAPER)
	_title_label = _make_label(_root, "深蓝回声", 72, Art.PAPER)
	_subtitle_label = _make_label(_root, "A B Y S S A L   E C H O", 18, Art.CYAN)
	_divider_bar = _make_rect(_root, Color(Art.AMBER, 0.72))
	_lead_label = _make_label(_root, "循着微光，游向未知。", 24, Art.PAPER)
	_tip_label = _make_label(_root, EXPEDITION_TIPS[0], 14, Art.MUTED)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_phase_label = _make_label(_root, "正在整备潜航装备与深海照明...", 13, Art.PAPER)
	_range_label = _make_label(_root, "九片海域  ·  00 — 600 m", 12, Art.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_percent_label = _make_label(_root, "0%", 20, Art.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)

	for mark: String in ["00 m", "150 m", "300 m", "450 m", "600 m"]:
		var r_lbl := _make_label(_root, mark, 11, Color(Art.MUTED, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
		_ruler_labels.append(r_lbl)

	_root.resized.connect(_layout_ui)
	_layout_ui()

func _make_rect(parent: Control, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _make_label(parent: Control, text: String, font_size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl

func _layout_ui() -> void:
	if not is_instance_valid(_root):
		return
	var vp := _root.size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(get_viewport().size)

	var pad_x := clampf(vp.x * 0.058, 28.0, 88.0)
	var pad_y := clampf(vp.y * 0.052, 24.0, 52.0)
	var content_w := vp.x - pad_x * 2.0

	# Top bar
	_header_bar.position = Vector2(pad_x, pad_y + 2.0)
	_header_bar.size = Vector2(3.0, 20.0)
	_header_label.position = Vector2(pad_x + 15.0, pad_y)
	_header_label.size = Vector2(340.0, 24.0)

	_depth_value.position = Vector2(vp.x - pad_x - 160.0, pad_y - 6.0)
	_depth_value.size = Vector2(160.0, 34.0)
	_depth_caption.position = Vector2(vp.x - pad_x - 172.0, pad_y + 5.0)
	_depth_caption.size = Vector2(64.0, 20.0)
	_biome_label.position = Vector2(vp.x - pad_x - 280.0, pad_y + 30.0)
	_biome_label.size = Vector2(280.0, 22.0)

	# Editorial title column (left) & astrolabe center (right)
	var center_y := vp.y * 0.46
	var col_w := minf(520.0, content_w * 0.54)
	var top_block_y := center_y - 168.0

	_eyebrow_bar.position = Vector2(pad_x, top_block_y + 12.0)
	_eyebrow_bar.size = Vector2(38.0, 2.0)
	_eyebrow_label.position = Vector2(pad_x + 52.0, top_block_y)
	_eyebrow_label.size = Vector2(col_w, 26.0)

	_title_label.position = Vector2(pad_x - 4.0, top_block_y + 38.0)
	_title_label.size = Vector2(col_w + 40.0, 96.0)

	_subtitle_label.position = Vector2(pad_x + 4.0, top_block_y + 140.0)
	_subtitle_label.size = Vector2(col_w, 30.0)

	_divider_bar.position = Vector2(pad_x + 4.0, top_block_y + 190.0)
	_divider_bar.size = Vector2(52.0, 1.0)

	_lead_label.position = Vector2(pad_x + 2.0, top_block_y + 210.0)
	_lead_label.size = Vector2(col_w, 36.0)

	_tip_label.position = Vector2(pad_x + 4.0, top_block_y + 258.0)
	_tip_label.size = Vector2(minf(450.0, col_w), 58.0)

	# Bottom horizon gauge
	var bar_y := vp.y - pad_y - 28.0
	var bar_rect := Rect2(pad_x, bar_y, content_w, 6.0)
	_phase_label.position = Vector2(pad_x + 18.0, bar_y - 30.0)
	_phase_label.size = Vector2(content_w * 0.62, 24.0)

	_percent_label.position = Vector2(vp.x - pad_x - 84.0, bar_y - 34.0)
	_percent_label.size = Vector2(84.0, 28.0)
	_range_label.position = Vector2(vp.x - pad_x - 310.0, bar_y - 29.0)
	_range_label.size = Vector2(216.0, 22.0)

	for i in range(_ruler_labels.size()):
		var t := float(i) / float(maxi(1, _ruler_labels.size() - 1))
		var rx := pad_x + content_w * t
		_ruler_labels[i].position = Vector2(rx - 36.0, bar_y + 12.0)
		_ruler_labels[i].size = Vector2(72.0, 18.0)

	var astro_radius := clampf(minf(vp.x * 0.135, vp.y * 0.215), 96.0, 162.0)
	var astro_center := Vector2(vp.x - pad_x - astro_radius - clampf(vp.x * 0.04, 12.0, 64.0), center_y + 4.0)
	_plate.configure_geometry(astro_center, astro_radius, bar_rect, Vector2(pad_x + 5.0, bar_y - 18.0))

func _start_preload_queue() -> void:
	_queue.clear()
	for path: String in PRELOAD_MANIFEST:
		if ResourceLoader.exists(path):
			_queue.append(path)
	if _queue.is_empty():
		_queue.append(MAIN_SCENE_PATH)
	_request_next_resource()

func _request_next_resource() -> void:
	if _loaded_count >= _queue.size():
		_active_path = ""
		return
	_active_path = _queue[_loaded_count]
	var err := ResourceLoader.load_threaded_request(_active_path)
	if err != OK:
		# Fallback to synchronous load on next step if threaded request unavailable
		var direct := load(_active_path)
		if direct != null:
			_on_resource_loaded(_active_path, direct)

func _on_resource_loaded(path: String, res: Resource) -> void:
	if res != null:
		_held_resources.append(res)
		if path == MAIN_SCENE_PATH and res is PackedScene:
			_main_packed = res as PackedScene
	_loaded_count += 1
	_active_path = ""

func _process(delta: float) -> void:
	_clock += delta
	_tip_timer += delta
	if _tip_timer >= 3.8 and is_instance_valid(_tip_label):
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % EXPEDITION_TIPS.size()
		_tip_label.text = EXPEDITION_TIPS[_tip_index]

	match _stage:
		"loading":
			_poll_threaded_loader()
			var total := float(maxi(1, _queue.size()))
			var raw_ratio := float(_loaded_count) / total
			var time_gate := 1.0 if _skip_min_wait else clampf(_clock / MIN_DESKTOP_DISPLAY_TIME, 0.0, 1.0)
			_target_progress = maxf(_target_progress, minf(raw_ratio, time_gate) * 0.88)
			if _loaded_count >= _queue.size() and (_skip_min_wait or _clock >= MIN_DESKTOP_DISPLAY_TIME):
				_target_progress = 0.92
				_stage = "instantiating"
		"instantiating":
			_phase_label.text = "正在连接声呐罗盘与生命支持..."
			if _display_progress >= 0.89:
				if _main_packed == null:
					_main_packed = load(MAIN_SCENE_PATH) as PackedScene
				if _main_packed != null:
					_main_instance = _main_packed.instantiate()
					get_tree().root.add_child(_main_instance)
					get_tree().current_scene = _main_instance
				_held_resources.clear()
				_target_progress = 1.0
				_warmup_frames = 0
				_stage = "warmup"
		"warmup":
			_phase_label.text = "航道已就绪  ·  即将潜入深海"
			_warmup_frames += 1
			if _warmup_frames >= 3 and _display_progress >= 0.985:
				_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_fade_elapsed = 0.0
				_stage = "fading"
		"fading":
			_fade_elapsed += delta
			var t := clampf(_fade_elapsed / FADE_OUT_DURATION, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - t, 3.0)
			_root.modulate.a = 1.0 - eased
			if t >= 1.0:
				_stage = "done"
				set_process(false)
				queue_free()
				return

	var speed := 10.0 if _stage in ["instantiating", "warmup", "fading"] else 6.5
	_display_progress = lerpf(_display_progress, _target_progress, clampf(delta * speed, 0.0, 1.0))
	if absf(_target_progress - _display_progress) < 0.0015:
		_display_progress = _target_progress
	_sync_visuals(delta)

func _poll_threaded_loader() -> void:
	if _active_path.is_empty():
		if _loaded_count < _queue.size():
			_request_next_resource()
		return
	var sub_progress := []
	var status := ResourceLoader.load_threaded_get_status(_active_path, sub_progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var frac := float(sub_progress[0]) if not sub_progress.is_empty() else 0.0
			var total := float(maxi(1, _queue.size()))
			var partial := (float(_loaded_count) + clampf(frac, 0.0, 0.99)) / total
			var time_gate := 1.0 if _skip_min_wait else clampf(_clock / MIN_DESKTOP_DISPLAY_TIME, 0.0, 1.0)
			_target_progress = maxf(_target_progress, minf(partial, time_gate) * 0.88)
		ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(_active_path)
			_on_resource_loaded(_active_path, res)
			if _loaded_count < _queue.size():
				_request_next_resource()
		_:
			var fallback := load(_active_path)
			_on_resource_loaded(_active_path, fallback)
			if _loaded_count < _queue.size():
				_request_next_resource()

func _sync_visuals(delta: float) -> void:
	if is_instance_valid(_backdrop_mat):
		_backdrop_mat.set_shader_parameter("u_time", _clock)
		_backdrop_mat.set_shader_parameter("u_progress", _display_progress)
	if is_instance_valid(_plate):
		_plate.advance(_clock, delta, _display_progress)

	var pct := roundi(clampf(_display_progress, 0.0, 1.0) * 100.0)
	_percent_label.text = "%d%%" % pct
	var depth_m := roundi(clampf(_display_progress, 0.0, 1.0) * 600.0)
	_depth_value.text = "%03d m" % depth_m

	var biome_text := "阳光浅礁带"
	for entry in BIOME_STAGES:
		if _display_progress >= float(entry[0]):
			biome_text = str(entry[1])
	_biome_label.text = biome_text

	if _stage == "loading":
		if _display_progress < 0.28:
			_phase_label.text = "正在整备潜航装备与深海照明..."
		elif _display_progress < 0.60:
			_phase_label.text = "正在勘测浅礁地形与洋流航道..."
		else:
			_phase_label.text = "正在唤醒珊瑚森林与海底生态群落..."


class OceanLoadingPlate extends Control:
	## Procedural vector astrolabe, marine snow particles & horizon gauge.
	var _astro_center := Vector2(920, 380)
	var _astro_radius := 140.0
	var _bar_rect := Rect2(72, 730, 1136, 6)
	var _beacon_dot := Vector2(77, 712)
	var _time := 0.0
	var _progress := 0.0
	var _particles: Array[Dictionary] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261115
		for i in range(54):
			_particles.append({
				"uv": Vector2(rng.randf(), rng.randf()),
				"speed": rng.randf_range(0.014, 0.042),
				"sway": rng.randf_range(0.006, 0.018),
				"phase": rng.randf_range(0.0, TAU),
				"radius": rng.randf_range(1.1, 3.1),
				"gold": (i % 7 == 0),
				"bubble": (i % 4 == 0),
				"alpha": rng.randf_range(0.18, 0.54),
			})

	func configure_geometry(astro_center: Vector2, astro_radius: float, bar_rect: Rect2, beacon_dot: Vector2) -> void:
		_astro_center = astro_center
		_astro_radius = astro_radius
		_bar_rect = bar_rect
		_beacon_dot = beacon_dot
		queue_redraw()

	func advance(clock: float, delta: float, progress: float) -> void:
		_time = clock
		_progress = clampf(progress, 0.0, 1.0)
		for p: Dictionary in _particles:
			var uv: Vector2 = p["uv"]
			uv.y -= float(p["speed"]) * delta
			uv.x += sin(clock * 0.9 + float(p["phase"])) * float(p["sway"]) * delta
			if uv.y < -0.03:
				uv.y = 1.03
			if uv.x < -0.02:
				uv.x = 1.02
			elif uv.x > 1.02:
				uv.x = -0.02
			p["uv"] = uv
		queue_redraw()

	func _draw() -> void:
		_draw_marine_particles()
		_draw_astrolabe()
		_draw_horizon_gauge()

	func _draw_marine_particles() -> void:
		var vp := size
		for p: Dictionary in _particles:
			var pos := Vector2(float(p["uv"].x) * vp.x, float(p["uv"].y) * vp.y)
			var twinkle := 0.72 + 0.28 * sin(_time * 2.4 + float(p["phase"]))
			var a := float(p["alpha"]) * twinkle
			var rad := float(p["radius"])
			if bool(p["bubble"]):
				draw_arc(pos, rad + 0.6, 0.0, TAU, 16, Color(Art.CYAN, a * 0.85), 1.0, true)
			elif bool(p["gold"]):
				draw_circle(pos, rad, Color(Art.AMBER, a))
			else:
				draw_circle(pos, rad, Color(Art.PAPER, a * 0.85))

	func _draw_astrolabe() -> void:
		var c := _astro_center
		var r := _astro_radius

		# Soft core lagoon glow
		draw_circle(c, r * 0.86, Color(0.06, 0.28, 0.34, 0.20))
		draw_circle(c, r * 0.56, Color(0.03, 0.14, 0.21, 0.42))

		# Outer degree ticks (slow rotation)
		var tick_rot := _time * 0.11
		for i in range(48):
			var ang := float(i) / 48.0 * TAU + tick_rot
			var dir := Vector2(cos(ang), sin(ang))
			var is_cardinal := (i % 12 == 0)
			var inner_k := 1.03 if is_cardinal else 1.06
			var outer_k := 1.11 if is_cardinal else 1.09
			var col := Art.AMBER if i == 0 else Color(Art.CYAN, 0.52 if is_cardinal else 0.20)
			draw_line(c + dir * (r * inner_k), c + dir * (r * outer_k), col, 1.8 if is_cardinal else 1.0, true)

		# Base radial progress track & glowing progress arc
		draw_arc(c, r * 0.96, 0.0, TAU, 96, Color(Art.CYAN, 0.14), 2.0, true)
		if _progress > 0.005:
			var start_a := -PI * 0.5
			var end_a := start_a + TAU * _progress
			draw_arc(c, r * 0.96, start_a, end_a, 96, Color(Art.CYAN, 0.26), 6.0, true)
			var arc_col := Art.CYAN.lerp(Art.AMBER, clampf(_progress * 0.85, 0.0, 1.0))
			draw_arc(c, r * 0.96, start_a, end_a, 96, arc_col, 2.6, true)
			var tip_pos := c + Vector2(cos(end_a), sin(end_a)) * (r * 0.96)
			draw_circle(tip_pos, 4.2, Art.AMBER)
			draw_circle(tip_pos, 8.5, Color(Art.AMBER, 0.22))

		# Undulating bathymetric contour rings (echoing OceanUiTheme.ExpeditionPlate)
		for ring in range(4):
			var pts := PackedVector2Array()
			var ring_r := r * (0.36 + float(ring) * 0.135)
			var phase := -_time * 0.18 + float(ring) * 0.45
			for seg in range(73):
				var a := float(seg) / 72.0 * TAU
				var rr := ring_r * (1.0 + 0.035 * sin(a * 3.0 + phase))
				pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.92))
			var ring_col := Color(Art.CYAN, 0.16) if ring == 2 else Color(Art.PAPER, 0.09)
			draw_polyline(pts, ring_col, 1.0, true)

		# Crosshairs
		draw_line(c + Vector2(-r * 0.90, 0.0), c + Vector2(r * 0.90, 0.0), Color(Art.CYAN, 0.09), 1.0)
		draw_line(c + Vector2(0.0, -r * 0.90), c + Vector2(0.0, r * 0.90), Color(Art.CYAN, 0.09), 1.0)

		# Expanding sonar echo ripples
		for pulse_idx in range(2):
			var p_phase := fposmod(_time * 0.34 + float(pulse_idx) * 0.5, 1.0)
			var p_rad := lerpf(r * 0.18, r * 0.92, p_phase)
			var p_alpha := (1.0 - p_phase) * 0.34
			var p_col := Color(Art.CYAN, p_alpha) if pulse_idx == 0 else Color(Art.AMBER, p_alpha * 0.75)
			draw_arc(c, p_rad, 0.0, TAU, 64, p_col, 1.2, true)

		# Rotating sonar sweep beam
		var sweep_a := _time * 1.15
		for trail in range(10):
			var ta := sweep_a - float(trail) * 0.045
			var alpha := (1.0 - float(trail) / 10.0) * 0.16
			draw_line(c, c + Vector2(cos(ta), sin(ta)) * (r * 0.90), Color(Art.CYAN, alpha), 2.2, true)
		draw_line(c, c + Vector2(cos(sweep_a), sin(sweep_a)) * (r * 0.92), Color(Art.CYAN, 0.52), 1.4, true)

		# Sunken Observatory gold constellation path
		var w1 := c + Vector2(-r * 0.36, r * 0.32)
		var w2 := c + Vector2(-r * 0.04, r * 0.06)
		var w3 := c + Vector2(r * 0.24, -r * 0.36)
		draw_polyline(PackedVector2Array([w1, w2, w3]), Color(Art.AMBER, 0.58), 1.3, true)
		for wp: Vector2 in [w1, w2, w3]:
			draw_circle(wp, 3.2, Art.AMBER)
			draw_arc(wp, 7.5, 0.0, TAU, 24, Color(Art.AMBER, 0.24), 1.0, true)

		# Gliding pearl diver silhouette at center-left of astrolabe
		var bob := Vector2(0.0, sin(_time * 1.6) * 3.5)
		var dc := c + Vector2(-r * 0.14, -r * 0.08) + bob
		var rot := -0.46 + sin(_time * 1.6) * 0.05
		var s := r / 140.0
		draw_set_transform(dc, rot, Vector2(s, s))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-26, -9.5), Vector2(-14, -3.2), Vector2(-14, 3.2), Vector2(-26, 9.5)
		]), Color(Art.PAPER, 0.92))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, -8), Vector2(5, -8), Vector2(9.5, -14), Vector2(-1.5, -14)
		]), Art.PAPER)
		var hull := PackedVector2Array()
		for idx in range(24):
			var t := float(idx) / 24.0 * TAU
			var hx := cos(t) * 23.0
			var hy := sin(t) * (8.5 if cos(t) > -0.2 else 5.8)
			hull.append(Vector2(hx + 3.0, hy))
		draw_colored_polygon(hull, Art.PAPER)
		draw_line(Vector2(-12, 0), Vector2(5, 0), Color(0.05, 0.29, 0.35, 0.95), 2.0, true)
		draw_circle(Vector2(16, 0), 4.8, Art.INK)
		draw_circle(Vector2(17.2, -0.9), 2.2, Art.CYAN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_horizon_gauge() -> void:
		# Pulsing gold status dot beside phase label
		var blink := 0.65 + 0.35 * sin(_time * 3.6)
		draw_circle(_beacon_dot, 6.5, Color(Art.AMBER, 0.18 * blink))
		draw_circle(_beacon_dot, 3.4, Color(Art.AMBER, blink))

		# Track background + subtle border
		draw_rect(_bar_rect, Color(Art.CYAN, 0.12), true)
		draw_rect(_bar_rect.grow(0.5), Color(Art.CYAN, 0.22), false, 1.0)

		# Ruler ticks
		for i in range(5):
			var tx := _bar_rect.position.x + _bar_rect.size.x * (float(i) / 4.0)
			draw_line(Vector2(tx, _bar_rect.end.y + 2.0), Vector2(tx, _bar_rect.end.y + 7.0), Color(Art.CYAN, 0.30), 1.0)

		# Active luminous fill
		if _progress > 0.002:
			var fill_w := maxf(4.0, _bar_rect.size.x * _progress)
			var fill_rect := Rect2(_bar_rect.position, Vector2(fill_w, _bar_rect.size.y))
			draw_rect(fill_rect.grow(2.0), Color(Art.CYAN, 0.18), true)
			draw_rect(fill_rect, Art.CYAN.lerp(Art.AMBER, clampf(_progress * 0.65, 0.0, 1.0)), true)
			var tip := Vector2(fill_rect.end.x, fill_rect.get_center().y)
			draw_circle(tip, 8.5, Color(Art.AMBER, 0.28))
			draw_circle(tip, 4.8, Art.AMBER)
			draw_circle(tip, 2.6, Art.PAPER)

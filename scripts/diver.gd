extends CharacterBody3D

const ModelFinish = preload("res://scripts/presentation/model_finish.gd")
const DiverSilhouette = preload("res://scripts/presentation/diver_silhouette.gd")
const BlenderArt = preload("res://scripts/presentation/blender_art.gd")
const ReferenceDiver = preload("res://scripts/presentation/reference_diver.gd")

const OceanDepths = preload("res://scripts/ocean_depths.gd")
const Ocean = preload("res://scripts/ocean.gd")

const AIM_FOV := 48.0
const SCOPE_FOV := 11.56
const CHARGE_THRESHOLD := 3.0
const CHARGE_DURATION := 3.0
const THIRD_PERSON_DEFAULT_DIST := 3.05
const THIRD_PERSON_MIN_DIST := 1.6
const THIRD_PERSON_MAX_DIST := 6.5
const THIRD_PERSON_AIM_DIST := 1.45

var camera: Camera3D
var lamp: SpotLight3D
var lamp_fill: OmniLight3D
var active: bool = false
var input_controller: Node
var upgraded: bool = false
var exploration_mode: bool = false
var sprinting: bool = false
var overweight: bool = false
var explorer_speed_mult: float = 1.0

# Third-person camera & 3D Diver character model
var third_person_mode: bool = true
var third_person_distance: float = THIRD_PERSON_DEFAULT_DIST
var current_camera_distance: float = THIRD_PERSON_DEFAULT_DIST
var _applied_camera_distance: float = THIRD_PERSON_DEFAULT_DIST
var vehicle_camera_distance: float = 0.0
var in_submarine_mode: bool = false
var in_mount_mode: bool = false
var body_collision: CollisionShape3D = null
var vehicle_exclude_rid: RID = RID()
var _cam_ray_query: PhysicsRayQueryParameters3D = null
var _cam_ray_exclude: Array[RID] = []
var _cam_ray_exclude_self_rid: RID = RID()
var _cam_ray_exclude_vehicle_rid: RID = RID()
var _cam_ray_cache_valid: bool = false
var _cam_ray_last_frame: int = -1
var _cam_ray_last_origin: Vector3 = Vector3.ZERO
var _cam_ray_last_target: Vector3 = Vector3.ZERO
var _cam_ray_last_sub_mode: bool = false
var _cam_ray_last_mount_mode: bool = false
var _cam_ray_last_scoped: bool = false
var _cam_ray_cached_hit_valid: bool = false
var _cam_ray_cached_hit_dist: float = 0.0
var equipment_rig: Node3D
var diver_model: Node3D
var body_pivot: Node3D
var head_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_forearm_pivot: Node3D
var right_forearm_pivot: Node3D
var left_hand_socket: Node3D
var right_hand_socket: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var left_knee_pivot: Node3D
var right_knee_pivot: Node3D
var left_fin_pivot: Node3D
var right_fin_pivot: Node3D
var breath_bubbles: CPUParticles3D
var backpack_thruster_bubbles: CPUParticles3D
var swim_clock: float = 0.0
var swim_motion_blend: float = 0.0
var swim_kick_rate: float = 2.2
var turn_bank: float = 0.0
var reference_model_active := false
var _reference_drivers: Dictionary = {}
var body_combat_yaw: float = 0.0
var body_combat_pitch: float = 0.0
var body_combat_roll: float = 0.0
var body_combat_lunge: Vector3 = Vector3.ZERO
var combat_stance_blend: float = 0.0
var right_wrist_rot: Vector3 = Vector3.ZERO
var left_wrist_rot: Vector3 = Vector3.ZERO
var melee_grip_pitch: float = 38.0

# Weapon viewmodel system
var weapon_mount: Node3D
var weapon_nodes: Dictionary = {}
var weapon_base_trans: Dictionary = {}
var current_weapon: String = "knife"
var aiming := false
var scoped := false
var aim_blend := 0.0
var gun_trigger_held := false
var charge_time := 0.0
var gun_muzzle: Marker3D
var charge_glow: MeshInstance3D
var marker_muzzle: Marker3D
var shield_mount: Node3D
var shield_node: Node3D
var shield_active: bool = false

# Handheld Mini Propulsion Booster (Seaglide / H 助推器)
var booster_active: bool = false
var booster_node: Node3D = null
var booster_propeller: Node3D = null
var booster_particles: CPUParticles3D = null
var booster_light: SpotLight3D = null
var attack_cooldown: float = 0.0
var attack_anim_time: float = 0.0
var attack_anim_duration: float = 0.25
var muzzle_flash: OmniLight3D

# Attack reinforcement and procedural impact feedback
var damage_bonus: float = 0.0
var camera_punch: Vector3 = Vector3.ZERO
var camera_trauma: float = 0.0
var hitstop_timer: float = 0.0
var hitstop_jitter: Vector3 = Vector3.ZERO
var mouse_lag: Vector2 = Vector2.ZERO
var mouse_lag_target: Vector2 = Vector2.ZERO

# Procedural weapon attack combos & dynamic feedback
var combo_index: int = 0
var combo_timer: float = 0.0
var equip_anim_time: float = 0.0
var equip_duration: float = 0.22
var fluid_drag_pos: Vector3 = Vector3.ZERO
var fluid_drag_rot: Vector3 = Vector3.ZERO
# VFX Nodes
var cleave_mesh: MeshInstance3D
var cleave_core_mesh: MeshInstance3D
var thrust_cone_mesh: MeshInstance3D
var slash_sparks: CPUParticles3D
var slash_light: OmniLight3D
var sonic_ring: MeshInstance3D
var blade_bubbles: CPUParticles3D
var vfx_timer: float = 0.0
var vfx_max_timer: float = 0.0
var marine_snow: CPUParticles3D
var biomod_dash_unlocked: bool = false
var biomod_vision_unlocked: bool = false
var dash_cooldown: float = 0.0
var _lamp_saved_before_sub: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	body_collision = shape
	add_child(shape)

	_ensure_third_person_rig()

	# High-performance volumetric flashlight: wide beam penetrating deep sea
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.96, 0.88)
	lamp.shadow_enabled = true
	lamp.light_energy = 9.0
	lamp.spot_range = 85.0
	lamp.spot_angle = 55.0
	lamp.spot_attenuation = 0.8
	lamp.position = Vector3(0.0, 0.16, -0.32)
	lamp.visible = false
	equipment_rig.add_child(lamp)

	# Soft ambient fill light for immediate diver perimeter
	lamp_fill = OmniLight3D.new()
	lamp_fill.light_color = Color(0.78, 0.85, 0.88)
	lamp_fill.light_energy = 1.05
	lamp_fill.omni_range = 16.0
	lamp_fill.omni_attenuation = 1.05
	lamp_fill.position = Vector3(0.0, 0.08, -1.45)
	lamp_fill.visible = false
	equipment_rig.add_child(lamp_fill)

	# Marine snow micro-plankton particles attached to diver viewpoint
	marine_snow = CPUParticles3D.new()
	marine_snow.name = "MarineSnow"
	marine_snow.amount = 75
	marine_snow.lifetime = 4.0
	marine_snow.preprocess = 2.0
	marine_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	marine_snow.emission_box_extents = Vector3(6.5, 4.5, 7.5)
	marine_snow.position = Vector3(0, 0, -5.0)
	marine_snow.direction = Vector3(0, -0.2, -0.6)
	marine_snow.gravity = Vector3(0, -0.05, 0)
	marine_snow.initial_velocity_min = 0.08
	marine_snow.initial_velocity_max = 0.22
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.018
	s_mesh.height = 0.036
	s_mesh.radial_segments = 6
	s_mesh.rings = 3
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(0.72, 0.94, 1.0, 0.38)
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s_mesh.material = s_mat
	marine_snow.mesh = s_mesh
	camera.add_child(marine_snow)

	_setup_weapons()
	_setup_booster()
	_setup_vfx()
	ModelFinish.apply(equipment_rig, "weapon")

func _ensure_third_person_rig() -> void:
	if not is_instance_valid(equipment_rig):
		equipment_rig = Node3D.new()
		equipment_rig.name = "EquipmentRig"
		equipment_rig.position = Vector3(0.0, -0.32, 0.22)
		add_child(equipment_rig)
	if not is_instance_valid(diver_model):
		_build_diver_model()
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.fov = 78.0
		camera.near = 0.12
		camera.far = 240.0
		camera.current = true
		camera.position = Vector3(0.0, 0.0, THIRD_PERSON_DEFAULT_DIST)
		add_child(camera)
	if not is_instance_valid(weapon_mount):
		_setup_weapons()
	if not is_instance_valid(cleave_mesh):
		_setup_vfx()

func toggle_lamp() -> bool:
	lamp.visible = not lamp.visible
	if is_instance_valid(lamp_fill):
		lamp_fill.visible = lamp.visible
	return lamp.visible

func trigger_dash(oxygen_available: float = 90.0) -> Dictionary:
	if not biomod_dash_unlocked:
		return {"success": false, "reason": "尚未激活涡流突进模组"}
	if dash_cooldown > 0.0:
		return {"success": false, "reason": "涡流冲刺充能中 (%.1fs)" % dash_cooldown}
	if not exploration_mode and oxygen_available < 10.0:
		return {"success": false, "reason": "氧气不足无法启动涡流推进"}
	dash_cooldown = 4.5
	var forward: Vector3 = -camera.global_basis.z if (is_instance_valid(camera) and camera.is_inside_tree()) else -basis.z
	velocity += forward * 16.0
	camera_punch = Vector3(-0.065, 0.0, 0.035)
	add_trauma(0.35)
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = 4.0
	return {"success": true, "cost": 12.0}

func _setup_weapons() -> void:
	if is_instance_valid(weapon_mount):
		return
	if not is_instance_valid(equipment_rig):
		equipment_rig = Node3D.new()
		equipment_rig.name = "EquipmentRig"
		equipment_rig.position = Vector3(0.0, -0.32, 0.22)
		add_child(equipment_rig)
	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	equipment_rig.add_child(weapon_mount)
	shield_mount = Node3D.new()
	shield_mount.name = "ShieldMount"
	equipment_rig.add_child(shield_mount)
	_build_shield_viewmodel()
	var weapon_files := {
		"knife": "res://assets/models/weapon_knife.glb",
		"axe": "res://assets/models/weapon_axe.glb",
		"sonic": "res://assets/models/weapon_sonic.glb"
	}
	var transforms := {
		"knife": {"pos": Vector3(0.25, -0.12, -0.44), "rot": Vector3(8.0, 168.0, -15.0), "scale": 1.02},
		"axe": {"pos": Vector3(0.27, -0.15, -0.46), "rot": Vector3(15.0, -15.0, -12.0), "scale": 1.08},
		"sonic": {"pos": Vector3(0.23, -0.12, -0.48), "rot": Vector3(2.0, -6.0, 0.0), "scale": 1.02}
	}
	for id: String in weapon_files:
		var scene_res = load(weapon_files[id])
		if scene_res:
			var node: Node3D = scene_res.instantiate()
			weapon_mount.add_child(node)
			var cfg: Dictionary = transforms[id]
			node.position = cfg["pos"]
			node.rotation_degrees = cfg["rot"]
			node.scale = Vector3.ONE * cfg["scale"]
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var w_mi: MeshInstance3D = child
				if w_mi.mesh:
					for s_idx in range(w_mi.mesh.get_surface_count()):
						var w_mat := w_mi.mesh.surface_get_material(s_idx)
						if w_mat is BaseMaterial3D:
							var wb: BaseMaterial3D = w_mat
							wb.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
							wb.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
							wb.rim_enabled = false
							wb.rim = 0.52
							wb.rim_tint = 0.35
			weapon_base_trans[id] = {"pos": node.position, "rot": node.rotation_degrees}
			weapon_nodes[id] = node
	if weapon_nodes.has("sonic"):
		gun_muzzle = Marker3D.new()
		gun_muzzle.position = Vector3(0, 0.02, -0.46)
		weapon_nodes["sonic"].add_child(gun_muzzle)
		charge_glow = MeshInstance3D.new()
		var charge_sphere := SphereMesh.new()
		charge_sphere.radius = 0.11
		charge_sphere.height = 0.22
		charge_sphere.radial_segments = 32
		charge_sphere.rings = 16
		charge_glow.mesh = charge_sphere
		var charge_material := StandardMaterial3D.new()
		charge_material.albedo_color = Color(0.025, 0.2, 1.0)
		charge_material.emission_enabled = true
		charge_material.emission = Color(0.03, 0.22, 0.8)
		charge_material.roughness = 0.35
		charge_material.disable_fog = true
		charge_glow.material_override = charge_material
		charge_glow.visible = false
		weapon_mount.add_child(charge_glow)
		var halo := MeshInstance3D.new()
		var halo_sphere := SphereMesh.new()
		halo_sphere.radius = 0.125
		halo_sphere.height = 0.25
		halo.mesh = halo_sphere
		var halo_material := StandardMaterial3D.new()
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		halo_material.albedo_color = Color(0.03, 0.25, 1.0, 0.16)
		halo_material.disable_fog = true
		halo.material_override = halo_material
		charge_glow.add_child(halo)

	# Procedurally build tactical laser pointer Marker Gun (光标枪)
	var marker_root := Node3D.new()
	marker_root.name = "MarkerGun"
	_build_marker_gun(marker_root)
	weapon_mount.add_child(marker_root)
	var marker_cfg := {"pos": Vector3(0.22, -0.12, -0.44), "rot": Vector3(2.0, -4.0, 0.0), "scale": 1.02}
	marker_root.position = marker_cfg["pos"]
	marker_root.rotation_degrees = marker_cfg["rot"]
	marker_root.scale = Vector3.ONE * marker_cfg["scale"]
	weapon_base_trans["marker_gun"] = {"pos": marker_root.position, "rot": marker_root.rotation_degrees}
	weapon_nodes["marker_gun"] = marker_root

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color(0.35, 0.92, 1.0)
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 16.0
	muzzle_flash.position = Vector3(0.22, -0.16, -0.9)
	weapon_mount.add_child(muzzle_flash)

	# 空化微气泡发射器（安装在挥刃轨迹前端）
	blade_bubbles = CPUParticles3D.new()
	blade_bubbles.name = "BladeCavitationBubbles"
	blade_bubbles.emitting = false
	blade_bubbles.one_shot = true
	blade_bubbles.explosiveness = 0.85
	blade_bubbles.lifetime = 0.45
	blade_bubbles.amount = 24
	blade_bubbles.position = Vector3(0.12, -0.1, -0.8)
	blade_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	blade_bubbles.emission_box_extents = Vector3(0.3, 0.25, 0.3)
	blade_bubbles.direction = Vector3(-0.5, 0.2, -1.0)
	blade_bubbles.spread = 45.0
	blade_bubbles.initial_velocity_min = 1.2
	blade_bubbles.initial_velocity_max = 3.2
	blade_bubbles.damping_min = 4.0
	blade_bubbles.damping_max = 6.0
	blade_bubbles.gravity = Vector3(0, 0.8, 0)
	var bb_mesh := SphereMesh.new()
	bb_mesh.radius = 0.016
	bb_mesh.height = 0.032
	bb_mesh.radial_segments = 6
	bb_mesh.rings = 3
	var bb_mat := StandardMaterial3D.new()
	bb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bb_mat.albedo_color = Color(0.8, 0.96, 1.0, 0.55)
	bb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bb_mesh.material = bb_mat
	blade_bubbles.mesh = bb_mesh
	weapon_mount.add_child(blade_bubbles)

	set_weapon("knife")

func _setup_vfx() -> void:
	if is_instance_valid(cleave_mesh):
		return
	if not is_instance_valid(weapon_mount):
		_setup_weapons()
	# 动态水下新月光弧 (Tapered 3D Crescent Blade Ribbon for Third-Person)
	cleave_mesh = MeshInstance3D.new()
	cleave_mesh.name = "CrescentSlashOuter"
	cleave_mesh.mesh = _create_crescent_arc_mesh(0.68, 1.48, 152.0, 28)
	var cleave_mat := StandardMaterial3D.new()
	cleave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cleave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cleave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cleave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cleave_mat.vertex_color_use_as_albedo = true
	cleave_mat.albedo_color = Color(0.4, 0.95, 1.0, 0.85)
	cleave_mesh.material_override = cleave_mat
	cleave_mesh.position = Vector3(0.0, -0.02, -0.95)
	cleave_mesh.rotation_degrees = Vector3(35.0, -25.0, 45.0)
	cleave_mesh.visible = false
	weapon_mount.add_child(cleave_mesh)

	# 高亮内层锋刃白芯 (Inner Razor Core Highlight)
	cleave_core_mesh = MeshInstance3D.new()
	cleave_core_mesh.name = "CrescentSlashCore"
	cleave_core_mesh.mesh = _create_crescent_arc_mesh(1.06, 1.44, 136.0, 24)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core_mat.vertex_color_use_as_albedo = true
	core_mat.albedo_color = Color(0.92, 0.99, 1.0, 0.95)
	cleave_core_mesh.material_override = core_mat
	cleave_mesh.add_child(cleave_core_mesh)

	# 3段突刺螺旋水压气锥 (Piercing Hydro-Vortex Cone for Combo 3 Thrust)
	thrust_cone_mesh = MeshInstance3D.new()
	thrust_cone_mesh.name = "ThrustVortexCone"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.52
	cone.height = 2.15
	cone.radial_segments = 20
	cone.cap_top = false
	cone.cap_bottom = false
	thrust_cone_mesh.mesh = cone
	var cone_mat := StandardMaterial3D.new()
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_mat.albedo_color = Color(0.35, 0.96, 1.0, 0.82)
	thrust_cone_mesh.material_override = cone_mat
	thrust_cone_mesh.position = Vector3(0.10, -0.06, -1.55)
	thrust_cone_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	thrust_cone_mesh.visible = false
	weapon_mount.add_child(thrust_cone_mesh)

	# 挥砍电光与深海流光火花粒子 (Bioluminescent Slash Sparks)
	slash_sparks = CPUParticles3D.new()
	slash_sparks.name = "SlashEnergySparks"
	slash_sparks.emitting = false
	slash_sparks.one_shot = true
	slash_sparks.explosiveness = 0.92
	slash_sparks.lifetime = 0.36
	slash_sparks.amount = 28
	slash_sparks.position = Vector3(0.08, -0.05, -1.15)
	slash_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	slash_sparks.emission_sphere_radius = 0.42
	slash_sparks.direction = Vector3(0.0, 0.1, -1.0)
	slash_sparks.spread = 68.0
	slash_sparks.initial_velocity_min = 2.6
	slash_sparks.initial_velocity_max = 6.4
	slash_sparks.damping_min = 5.0
	slash_sparks.damping_max = 8.0
	slash_sparks.gravity = Vector3(0.0, 0.4, 0.0)
	var sp_mesh := BoxMesh.new()
	sp_mesh.size = Vector3(0.016, 0.016, 0.095)
	var sp_mat := StandardMaterial3D.new()
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sp_mat.albedo_color = Color(0.55, 0.98, 1.0, 0.9)
	sp_mesh.material = sp_mat
	slash_sparks.mesh = sp_mesh
	weapon_mount.add_child(slash_sparks)

	# 近战挥砍瞬态光晕照亮角色与水面 (Slash Dynamic Light)
	slash_light = OmniLight3D.new()
	slash_light.name = "SlashDynamicLight"
	slash_light.position = Vector3(0.0, 0.0, -1.15)
	slash_light.light_color = Color(0.35, 0.95, 1.0)
	slash_light.light_energy = 0.0
	slash_light.omni_range = 6.5
	weapon_mount.add_child(slash_light)

	# 水下千米声波激波同心环 (Kilometer Sonic Shockwave Ring)
	sonic_ring = MeshInstance3D.new()
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.65
	ring_torus.outer_radius = 0.95
	ring_torus.rings = 28
	ring_torus.ring_segments = 14
	sonic_ring.mesh = ring_torus
	var sonic_mat := StandardMaterial3D.new()
	sonic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sonic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sonic_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sonic_mat.albedo_color = Color(0.55, 0.88, 1.0, 0.9)
	sonic_ring.material_override = sonic_mat
	sonic_ring.position = Vector3(0.22, -0.16, -1.2)
	sonic_ring.visible = false
	weapon_mount.add_child(sonic_ring)

func _create_crescent_arc_mesh(inner_r: float, outer_r: float, sweep_deg: float, segments: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_rad := deg_to_rad(sweep_deg * 0.5)
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var a0 := lerpf(-half_rad, half_rad, t0)
		var a1 := lerpf(-half_rad, half_rad, t1)
		var env0 := sin(t0 * PI)
		var env1 := sin(t1 * PI)
		var w0 := pow(env0, 0.65)
		var w1 := pow(env1, 0.65)
		var r_in0 := lerpf(outer_r * 0.92, inner_r, w0)
		var r_out0 := lerpf(outer_r * 0.95, outer_r, w0)
		var r_in1 := lerpf(outer_r * 0.92, inner_r, w1)
		var r_out1 := lerpf(outer_r * 0.95, outer_r, w1)

		var p0_in := Vector3(sin(a0) * r_in0, cos(a0) * r_in0 * 0.14, -cos(a0) * r_in0)
		var p0_out := Vector3(sin(a0) * r_out0, cos(a0) * r_out0 * 0.05, -cos(a0) * r_out0)
		var p1_in := Vector3(sin(a1) * r_in1, cos(a1) * r_in1 * 0.14, -cos(a1) * r_in1)
		var p1_out := Vector3(sin(a1) * r_out1, cos(a1) * r_out1 * 0.05, -cos(a1) * r_out1)

		var c_in0 := Color(0.55, 0.95, 1.0, env0 * 0.18)
		var c_out0 := Color(1.0, 1.0, 1.0, pow(env0, 0.5) * 0.98)
		var c_in1 := Color(0.55, 0.95, 1.0, env1 * 0.18)
		var c_out1 := Color(1.0, 1.0, 1.0, pow(env1, 0.5) * 0.98)

		st.set_normal(Vector3.UP)
		st.set_color(c_in0)
		st.add_vertex(p0_in)
		st.set_color(c_out0)
		st.add_vertex(p0_out)
		st.set_color(c_out1)
		st.add_vertex(p1_out)

		st.set_color(c_in0)
		st.add_vertex(p0_in)
		st.set_color(c_out1)
		st.add_vertex(p1_out)
		st.set_color(c_in1)
		st.add_vertex(p1_in)
	return st.commit()

func toggle_booster() -> bool:
	if not is_instance_valid(booster_node):
		_setup_booster()
	booster_active = not booster_active
	if is_instance_valid(booster_node):
		booster_node.visible = booster_active
	if booster_active:
		cancel_gun_charge()
		aiming = false
		scoped = false
	for id: String in weapon_nodes:
		weapon_nodes[id].visible = (id == current_weapon) and not booster_active
	return booster_active

func set_weapon(weapon_id: String) -> void:
	if current_weapon != weapon_id:
		cancel_gun_charge()
		aiming = false
		scoped = false
		if weapon_nodes.has(current_weapon):
			var old_base: Dictionary = weapon_base_trans.get(current_weapon, {})
			if not old_base.is_empty():
				weapon_nodes[current_weapon].position = old_base["pos"]
				weapon_nodes[current_weapon].rotation_degrees = old_base["rot"]
		attack_anim_time = 0.0
		equip_anim_time = equip_duration
		_trigger_equip_vfx()
	current_weapon = weapon_id
	combo_index = 0
	combo_timer = 0.0
	for id: String in weapon_nodes:
		weapon_nodes[id].visible = (id == current_weapon) and not booster_active

func _setup_booster() -> void:
	if is_instance_valid(booster_node):
		return
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		add_child(camera)
	if not is_instance_valid(equipment_rig):
		equipment_rig = Node3D.new()
		equipment_rig.name = "EquipmentRig"
		equipment_rig.position = Vector3(0.0, -0.32, 0.22)
		add_child(equipment_rig)
	booster_node = Node3D.new()
	booster_node.name = "MiniBooster"
	booster_node.position = Vector3(0.0, -0.14, -0.46)
	booster_node.rotation_degrees = Vector3(5.0, 0.0, 0.0)
	equipment_rig.add_child(booster_node)

	var mat_hull := StandardMaterial3D.new()
	mat_hull.albedo_color = Color(0.14, 0.68, 1.0)
	mat_hull.metallic = 0.28
	mat_hull.roughness = 0.22
	mat_hull.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_hull.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_hull.rim_enabled = false
	mat_hull.rim = 0.52

	var mat_white := StandardMaterial3D.new()
	mat_white.albedo_color = Color(0.95, 0.98, 1.0)
	mat_white.metallic = 0.2
	mat_white.roughness = 0.24
	mat_white.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_white.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_white.rim_enabled = false
	mat_white.rim = 0.48

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.12, 0.20, 0.32)
	mat_dark.metallic = 0.45
	mat_dark.roughness = 0.28
	mat_dark.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_dark.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_dark.rim_enabled = false
	mat_dark.rim = 0.45

	var mat_display := StandardMaterial3D.new()
	mat_display.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_display.albedo_color = Color(0.2, 0.95, 0.85)

	# Main hydrodynamic pod fuselage
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.085
	sphere.height = 0.38
	body.mesh = sphere
	body.rotation_degrees = Vector3(90, 0, 0)
	body.material_override = mat_hull
	booster_node.add_child(body)

	# Top console housing
	var console := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.045, 0.18)
	console.mesh = box
	console.position = Vector3(0, 0.07, -0.04)
	console.rotation_degrees = Vector3(-18, 0, 0)
	console.material_override = mat_white
	booster_node.add_child(console)

	# Digital Mini Sonar Screen
	var screen_mesh := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.08, 0.005, 0.09)
	screen_mesh.mesh = s_box
	screen_mesh.position = Vector3(0, 0.095, -0.04)
	screen_mesh.rotation_degrees = Vector3(-18, 0, 0)
	screen_mesh.material_override = mat_display
	booster_node.add_child(screen_mesh)

	# Front Nose LED Headlight
	booster_light = SpotLight3D.new()
	booster_light.position = Vector3(0, 0.02, -0.22)
	booster_light.spot_range = 42.0
	booster_light.spot_angle = 45.0
	booster_light.light_color = Color(0.85, 0.98, 1.0)
	booster_light.light_energy = 5.0
	booster_node.add_child(booster_light)

	# Left and Right Handlebars
	for side in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.012
		cyl.bottom_radius = 0.012
		cyl.height = 0.16
		bar.mesh = cyl
		bar.position = Vector3(side * 0.12, 0.02, 0.02)
		bar.rotation_degrees = Vector3(15, 0, side * 75)
		bar.material_override = mat_white
		booster_node.add_child(bar)

		var grip := MeshInstance3D.new()
		var g_cyl := CylinderMesh.new()
		g_cyl.top_radius = 0.016
		g_cyl.bottom_radius = 0.016
		g_cyl.height = 0.11
		grip.mesh = g_cyl
		grip.position = Vector3(side * 0.19, -0.02, 0.03)
		grip.rotation_degrees = Vector3(12, 0, side * 15)
		grip.material_override = mat_dark
		booster_node.add_child(grip)

	# Rear Ducted Shroud
	var shroud := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.095
	shroud.mesh = torus
	shroud.position = Vector3(0, 0, 0.20)
	shroud.rotation_degrees = Vector3(90, 0, 0)
	shroud.material_override = mat_dark
	booster_node.add_child(shroud)

	# Propeller Rotor
	booster_propeller = Node3D.new()
	booster_propeller.position = Vector3(0, 0, 0.20)
	booster_node.add_child(booster_propeller)
	for r in [0.0, 90.0]:
		var blade := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.018, 0.155, 0.008)
		blade.mesh = b_box
		blade.rotation_degrees = Vector3(0, 0, r)
		blade.material_override = mat_white
		booster_propeller.add_child(blade)

	# Cavitation Bubble Emitter at Thruster Jet
	booster_particles = CPUParticles3D.new()
	booster_particles.position = Vector3(0, 0, 0.24)
	booster_particles.emitting = false
	booster_particles.amount = 24
	booster_particles.lifetime = 0.45
	booster_particles.direction = Vector3(0, 0, 1)
	booster_particles.spread = 22.0
	booster_particles.initial_velocity_min = 2.5
	booster_particles.initial_velocity_max = 5.5
	booster_particles.gravity = Vector3(0, 0.6, 0)
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.022
	p_mesh.height = 0.044
	p_mesh.radial_segments = 6
	p_mesh.rings = 3
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p_mat.albedo_color = Color(0.75, 0.95, 1.0, 0.6)
	p_mesh.material = p_mat
	booster_particles.mesh = p_mesh
	booster_node.add_child(booster_particles)

	booster_node.visible = false

func toggle_aim() -> bool:
	if current_weapon != "sonic":
		aiming = false
		return false
	if scoped:
		scoped = false
		aiming = true
		return true
	aiming = not aiming
	return aiming

func toggle_scope() -> bool:
	if current_weapon != "sonic":
		return false
	scoped = not scoped
	aiming = scoped
	return scoped

func begin_gun_charge() -> bool:
	if current_weapon != "sonic" or attack_cooldown > 0.0 or gun_trigger_held:
		return false
	gun_trigger_held = true
	charge_time = 0.0
	return true

func cancel_gun_charge() -> void:
	gun_trigger_held = false
	charge_time = 0.0
	if is_instance_valid(charge_glow):
		charge_glow.visible = false

func get_charge_ratio() -> float:
	return clampf(charge_time / CHARGE_DURATION, 0.0, 1.0)

func get_muzzle_position() -> Vector3:
	if not is_inside_tree():
		return position + Vector3(0.22, -0.16, -0.9)
	if current_weapon == "marker_gun" and is_instance_valid(marker_muzzle) and marker_muzzle.is_inside_tree():
		return marker_muzzle.global_position
	return gun_muzzle.global_position if (is_instance_valid(gun_muzzle) and gun_muzzle.is_inside_tree()) else (camera.to_global(Vector3(0.22, -0.16, -0.9)) if (is_instance_valid(camera) and camera.is_inside_tree()) else position)

func get_aim_origin() -> Vector3:
	return global_position if is_inside_tree() else position

func _update_vehicle_collision_state() -> void:
	var in_vehicle: bool = in_submarine_mode or in_mount_mode
	if in_vehicle:
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(body_collision):
			body_collision.disabled = true
		velocity = Vector3.ZERO
		camera_trauma = 0.0
		camera_punch = Vector3.ZERO
		hitstop_timer = 0.0
		hitstop_jitter = Vector3.ZERO
		if is_instance_valid(camera):
			camera.rotation.z = 0.0
	else:
		collision_layer = 1
		collision_mask = 1
		if is_instance_valid(body_collision):
			body_collision.disabled = false

func set_submarine_mode(in_sub: bool, sub_type: String = "scout", sub_rid: RID = RID()) -> void:
	var was_in_sub := in_submarine_mode
	in_submarine_mode = in_sub
	vehicle_exclude_rid = sub_rid if in_sub else RID()
	if in_sub:
		vehicle_camera_distance = 22.0 if sub_type == "titan" else (6.5 if sub_type == "mini" else 9.2)
		if is_instance_valid(backpack_thruster_bubbles):
			backpack_thruster_bubbles.emitting = false
		if not was_in_sub and is_instance_valid(lamp):
			_lamp_saved_before_sub = lamp.visible
		if is_instance_valid(lamp):
			lamp.visible = false
		if is_instance_valid(lamp_fill):
			lamp_fill.visible = false
	elif not in_mount_mode:
		vehicle_camera_distance = 0.0
	if not in_sub and was_in_sub:
		if is_instance_valid(lamp):
			lamp.visible = _lamp_saved_before_sub
		if is_instance_valid(lamp_fill):
			lamp_fill.visible = _lamp_saved_before_sub
	if is_instance_valid(breath_bubbles):
		breath_bubbles.emitting = not in_sub
	_update_vehicle_collision_state()

func set_mount_mode(mounted: bool, is_boss_mount: bool = false) -> void:
	in_mount_mode = mounted
	if mounted:
		vehicle_camera_distance = 7.5 if is_boss_mount else 4.8
	elif not in_submarine_mode:
		vehicle_camera_distance = 0.0
	_update_vehicle_collision_state()

func release_gun_charge() -> Dictionary:
	if not gun_trigger_held or current_weapon != "sonic":
		cancel_gun_charge()
		return {}
	var held_for := charge_time
	var power := get_charge_ratio()
	cancel_gun_charge()
	if held_for < CHARGE_THRESHOLD:
		return attack()
	attack_cooldown = 2.4
	attack_anim_duration = 0.45
	attack_anim_time = attack_anim_duration
	equip_anim_time = 0.0
	camera_punch = Vector3(-0.055, 0, 0)
	add_trauma(0.2)
	return {
		"weapon": "sonic", "mode": "stasis_orb", "power": power,
		"field_radius": lerpf(8.0, 12.0, power), "freeze_duration": lerpf(4.0, 6.0, power)
	}

func _trigger_equip_vfx() -> void:
	if is_instance_valid(blade_bubbles) and blade_bubbles.is_inside_tree():
		blade_bubbles.restart()
		blade_bubbles.emitting = true
func add_trauma(amount: float) -> void:
	camera_trauma = clampf(camera_trauma + amount, 0.0, 1.0)

func trigger_hitstop(duration: float = 0.05) -> void:
	hitstop_timer = duration

func attack() -> Dictionary:
	_ensure_third_person_rig()
	if attack_cooldown > 0.0:
		return {}
	equip_anim_time = 0.0
	# 连击推进与超时重置
	if combo_timer > 0.0:
		if current_weapon == "knife":
			combo_index = (combo_index + 1) % 3
		elif current_weapon == "axe":
			combo_index = (combo_index + 1) % 2
		else:
			combo_index = 0
	else:
		combo_index = 0

	var result := {}
	match current_weapon:
		"knife":
			attack_cooldown = 0.28
			attack_anim_duration = 0.26
			combo_timer = attack_cooldown + 0.40
			var final_dmg: float = 32.0 + damage_bonus
			result = {
				"weapon": "knife",
				"name": "潜水战术刀",
				"damage": final_dmg,
				"base_damage": 32.0,
				"bonus": damage_bonus,
				"range": 6.2,
				"is_sonic": false,
				"knockback": 6.5,
				"cleave_angle": 0.42,
				"max_targets": 3,
				"combo": combo_index + 1,
				"active_delay": 0.06 if combo_index < 2 else 0.08
			}
			# 3段连击不同的打击后坐力与光刃姿态
			if combo_index == 0:
				camera_punch = Vector3(-0.022, 0.018, 0.0)
				add_trauma(0.12)
				_trigger_slash_vfx(Vector3(10.0, 6.0, 34.0), Vector3(0.92, 0.92, 0.92), Color(0.28, 0.95, 1.0, 0.92), 0.24, false)
			elif combo_index == 1:
				camera_punch = Vector3(0.018, -0.022, 0.0)
				add_trauma(0.14)
				_trigger_slash_vfx(Vector3(-10.0, -6.0, -146.0), Vector3(0.98, 0.98, 0.98), Color(0.38, 1.0, 0.86, 0.94), 0.24, false)
			else:
				# 第3段贯通刺
				camera_punch = Vector3(-0.035, 0.0, 0.0)
				add_trauma(0.20)
				_trigger_slash_vfx(Vector3(0.0, 0.0, 0.0), Vector3(0.85, 0.85, 1.25), Color(0.45, 0.98, 1.0, 0.96), 0.28, true)

		"axe":
			attack_cooldown = 0.55
			attack_anim_duration = 0.50
			combo_timer = attack_cooldown + 0.45
			var final_dmg: float = 70.0 + damage_bonus
			result = {
				"weapon": "axe",
				"name": "破拆战斧",
				"damage": final_dmg,
				"base_damage": 70.0,
				"bonus": damage_bonus,
				"range": 8.5,
				"is_sonic": false,
				"knockback": 16.0,
				"cleave_angle": 0.12,  # Wide 165° forward arc
				"max_targets": 99,     # Sweeps all predators in front
				"combo": combo_index + 1,
				"active_delay": 0.13
			}
			camera_punch = Vector3(-0.075, -0.052, 0.0) if combo_index == 0 else Vector3(-0.075, 0.052, 0.0)
			add_trauma(0.42)
			var arc_rot := Vector3(8.0, 4.0, 22.0) if combo_index == 0 else Vector3(-8.0, -4.0, -158.0)
			var axe_color := Color(1.0, 0.72, 0.22, 0.96) if combo_index == 0 else Color(0.35, 0.98, 1.0, 0.96)
			_trigger_slash_vfx(arc_rot, Vector3(1.52, 1.52, 1.45), axe_color, 0.38, false)

		"sonic":
			attack_cooldown = 0.32
			attack_anim_duration = 0.22
			combo_timer = 0.0
			var final_dmg: float = 100.0 + damage_bonus * 1.5
			result = {
				"weapon": "sonic",
				"name": "蓝光静滞枪",
				"mode": "laser",
				"damage": final_dmg,
				"base_damage": 100.0,
				"bonus": damage_bonus,
				"range": 2000.0,
				"is_sonic": false,
				"knockback": 0.0,
				"cleave_angle": 0.999,
				"max_targets": 1,
				"combo": 1,
				"active_delay": 0.0
			}
			camera_punch = Vector3(-0.018, 0.0, 0.0)
			add_trauma(0.08)
			if is_instance_valid(muzzle_flash):
				muzzle_flash.light_energy = 7.0
				muzzle_flash.omni_range = 12.0
			if is_instance_valid(sonic_ring):
				sonic_ring.visible = true
				sonic_ring.position = Vector3(0.18, -0.10, -0.95)
				sonic_ring.scale = Vector3.ONE * 0.32
				var s_mat = sonic_ring.material_override
				if s_mat is StandardMaterial3D:
					s_mat.albedo_color = Color(0.42, 0.92, 1.0, 0.92)
				vfx_timer = 0.24
				vfx_max_timer = 0.24

		"marker_gun":
			attack_cooldown = 0.15
			attack_anim_duration = 0.12
			combo_timer = 0.0
			result = {
				"weapon": "marker_gun",
				"name": "光标指示枪",
				"mode": "marker_pointer",
				"damage": 0.0,
				"base_damage": 0.0,
				"bonus": 0.0,
				"range": 2500.0,
				"is_sonic": false,
				"knockback": 0.0,
				"cleave_angle": 0.999,
				"max_targets": 1,
				"combo": 1,
				"active_delay": 0.0
			}
			camera_punch = Vector3(-0.005, 0.0, 0.0)
			add_trauma(0.02)

	attack_anim_time = attack_anim_duration
	return result

func _trigger_slash_vfx(rot_deg: Vector3, target_scale: Vector3, color: Color, duration: float, is_thrust: bool = false) -> void:
	if is_instance_valid(cleave_mesh):
		cleave_mesh.visible = not is_thrust
		cleave_mesh.position = Vector3(0.0, -0.02, -0.88)
		cleave_mesh.rotation_degrees = rot_deg
		cleave_mesh.scale = target_scale * 0.72
		var mat = cleave_mesh.material_override
		if mat is StandardMaterial3D:
			mat.albedo_color = color
		if is_instance_valid(cleave_core_mesh):
			var core_mat = cleave_core_mesh.material_override
			if core_mat is StandardMaterial3D:
				core_mat.albedo_color = Color(0.95, 1.0, 1.0, color.a)
		vfx_timer = duration
		vfx_max_timer = duration
	if is_instance_valid(thrust_cone_mesh):
		thrust_cone_mesh.visible = is_thrust
		if is_thrust:
			thrust_cone_mesh.position = Vector3(0.08, -0.05, -1.10)
			thrust_cone_mesh.scale = Vector3(0.65, 0.55, 0.65)
			var c_mat = thrust_cone_mesh.material_override
			if c_mat is StandardMaterial3D:
				c_mat.albedo_color = color
			vfx_timer = duration
			vfx_max_timer = duration
	if is_instance_valid(slash_sparks):
		var sp_mesh := slash_sparks.mesh as BoxMesh
		if sp_mesh and sp_mesh.material is StandardMaterial3D:
			(sp_mesh.material as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.95)
		slash_sparks.amount = 38 if current_weapon == "axe" else 24
		if slash_sparks.is_inside_tree():
			slash_sparks.restart()
			slash_sparks.emitting = true
	if is_instance_valid(slash_light):
		slash_light.light_color = Color(color.r, color.g, color.b)
		slash_light.light_energy = 5.8 if current_weapon == "axe" else 3.6
	if is_instance_valid(blade_bubbles) and blade_bubbles.is_inside_tree():
		blade_bubbles.restart()
		blade_bubbles.emitting = true

func _control_strength(action: String) -> float:
	return float(input_controller.get_strength(action)) if is_instance_valid(input_controller) else Input.get_action_strength(action)

func _control_axis(negative: String, positive: String) -> float:
	return _control_strength(positive) - _control_strength(negative)

func _look_settings(key: String, default_value: Variant) -> Variant:
	return input_controller.settings.get(key, default_value) if is_instance_valid(input_controller) else default_value

func _apply_look_angles(angles: Vector2) -> void:
	rotate_y(-angles.x)
	camera.rotation.x = clampf(camera.rotation.x - angles.y, -1.45, 1.45)
	if is_instance_valid(equipment_rig):
		equipment_rig.rotation = camera.rotation
	camera.position = camera.basis.z * _applied_camera_distance
	mouse_lag_target.x = clampf(mouse_lag_target.x - angles.x * 0.27, -0.04, 0.04)
	mouse_lag_target.y = clampf(mouse_lag_target.y + angles.y * 0.27, -0.035, 0.035)

func apply_look_delta(relative: Vector2, from_touch: bool = false) -> void:
	if not active:
		return
	var sensitivity := 0.00028 if scoped else (0.0011 if aiming else 0.0022)
	if from_touch:
		sensitivity *= float(_look_settings("touch_sensitivity", 1.0))
	var direction := relative
	if bool(_look_settings("invert_y", false)):
		direction.y = -direction.y
	_apply_look_angles(direction * sensitivity)

func apply_look_rate(value: Vector2, delta: float) -> void:
	if not active or value.is_zero_approx():
		return
	var sensitivity: float = 2.4 * float(_look_settings("gamepad_sensitivity", 1.0))
	sensitivity *= 0.127 if scoped else (0.5 if aiming else 1.0)
	if bool(_look_settings("invert_y", false)):
		value.y = -value.y
	# Sticks express angular velocity; mouse/touch express displacement.
	_apply_look_angles(value * sensitivity * delta)

func adjust_camera_distance(amount: float) -> void:
	third_person_distance = clampf(third_person_distance + amount, THIRD_PERSON_MIN_DIST, THIRD_PERSON_MAX_DIST)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(event.relative)
	elif active and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_camera_distance(-0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_camera_distance(0.35)

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		_update_third_person_camera(delta)
		return
	if is_instance_valid(input_controller):
		apply_look_rate(input_controller.get_look_vector(), delta)
	if in_submarine_mode or in_mount_mode:
		sprinting = not aiming and _control_strength("sprint") > 0.5
		var veh_fov: float = SCOPE_FOV if scoped else (AIM_FOV if aiming else (84.0 if sprinting else 78.0))
		camera.fov = lerpf(camera.fov, veh_fov, 1.0 - exp(-delta * 9.0))
		_update_third_person_camera(delta)
		return
	# A 左拐 (Turn left), D 右拐 (Turn right)
	var turn_val := _control_axis("right", "left")
	if turn_val != 0.0:
		var turn_rate := 2.4
		rotate_y(turn_val * turn_rate * delta)
		mouse_lag_target.x = clampf(mouse_lag_target.x - turn_val * 0.02, -0.04, 0.04)
	turn_bank = lerpf(turn_bank, clampf(-turn_val * 0.32, -0.35, 0.35), 1.0 - exp(-delta * 8.0))

	# W 前进, S 后退
	var fwd_val := _control_strength("forward") - _control_strength("backward") * 0.65

	# C 下降, 空格 上升
	var vert_val := _control_axis("descend", "ascend")

	var forward_dir := -camera.global_basis.z
	var right_dir := camera.global_basis.x
	var direction := forward_dir * fwd_val + right_dir * (-turn_val * 0.28)
	direction.y += vert_val

	sprinting = not aiming and _control_strength("sprint") > 0.5 and direction.length_squared() > 0.1
	var base_speed: float = 8.5 if (upgraded or exploration_mode) else 5.2
	if booster_active:
		base_speed = 19.5 if (upgraded or exploration_mode) else 16.0
	var speed: float = base_speed * explorer_speed_mult * (1.45 if (sprinting and booster_active) else (1.6 if sprinting else 1.0))
	if aiming:
		speed *= 0.6
	if overweight and not exploration_mode and not booster_active:
		speed *= 0.72
	velocity = velocity.lerp(direction.limit_length() * speed, 1.0 - exp(-delta * 4.0))
	move_and_slide()

	if booster_active and is_instance_valid(booster_propeller):
		var is_moving := direction.length_squared() > 0.05
		var spin_rate := 36.0 if sprinting else 24.0
		booster_propeller.rotate_z(delta * (spin_rate if is_moving else 4.0))
		if is_instance_valid(booster_particles):
			booster_particles.emitting = is_moving

	# Seamless 1800m x 1800m Open-World Ocean boundaries
	position.x = clampf(position.x, -900.0, 900.0)
	position.z = clampf(position.z, -900.0, 900.0)
	var min_seabed_y: float = maxf(-OceanDepths.MAX_DIVE_DEPTH, Ocean.terrain_height(position.x, position.z) + 0.65)
	if position.y < min_seabed_y:
		position.y = min_seabed_y
		if velocity.y < 0.0:
			velocity.y = 0.0
	elif position.y > 1.2:
		position.y = 1.2

	var target_fov: float = SCOPE_FOV if scoped else (AIM_FOV if aiming else (84.0 if sprinting else 78.0))
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 9.0))
	_update_third_person_camera(delta)

func _process(delta: float) -> void:
	_ensure_third_person_rig()
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 6.0)
	if gun_trigger_held:
		charge_time = minf(CHARGE_DURATION, charge_time + delta)
	if is_instance_valid(charge_glow):
		charge_glow.visible = gun_trigger_held and charge_time >= 0.15
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.04
		charge_glow.scale = Vector3.ONE * (0.35 + get_charge_ratio() * 4.65) * pulse
		charge_glow.rotate_y(delta * 3.0)
	if weapon_nodes.has("sonic"):
		weapon_nodes["sonic"].visible = current_weapon == "sonic" and not scoped and not booster_active
	if weapon_nodes.has("marker_gun"):
		weapon_nodes["marker_gun"].visible = current_weapon == "marker_gun" and not scoped and not booster_active
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_index = 0
	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hitstop_jitter = Vector3.ZERO
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - delta)
		hitstop_jitter = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.018
	elif attack_anim_time > 0.0:
		attack_anim_time = maxf(0.0, attack_anim_time - delta)
	if is_instance_valid(muzzle_flash):
		if muzzle_flash.light_energy > 0.0:
			muzzle_flash.light_energy = maxf(0.0, muzzle_flash.light_energy - delta * 28.0)
		elif current_weapon == "sonic" and not in_submarine_mode:
			# 声波脉冲枪待机能量核心呼吸发光
			var idle_glow := sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5
			muzzle_flash.light_energy = idle_glow * 1.5
			muzzle_flash.omni_range = 6.0

	# Biomod Vision: adapt fill lighting in deep abyss
	if is_instance_valid(lamp_fill):
		if biomod_vision_unlocked and position.y < -45.0:
			lamp_fill.light_energy = 1.65
			lamp_fill.omni_range = 22.0
		else:
			lamp_fill.light_energy = 1.05
			lamp_fill.omni_range = 16.0
	# 鼠标惯性阻尼滞后解算 (Spring-damper mouse lag)
	mouse_lag = mouse_lag.lerp(mouse_lag_target, delta * 14.0)
	mouse_lag_target = mouse_lag_target.lerp(Vector2.ZERO, delta * 8.0)

	# Camera punch & trauma-based shake
	if is_instance_valid(camera):
		if in_submarine_mode:
			camera_punch = Vector3.ZERO
			camera_trauma = 0.0
			camera.rotation.z = 0.0
		elif camera_punch.length_squared() > 0.00001:
			camera.rotation += camera_punch * delta * 18.0
			camera_punch = camera_punch.lerp(Vector3.ZERO, delta * 12.0)

		if not in_submarine_mode and camera_trauma > 0.0:
			var trauma_pwr: float = camera_trauma * camera_trauma
			var shake_roll := (randf() * 2.0 - 1.0) * trauma_pwr * 0.024
			var shake_pitch := (randf() * 2.0 - 1.0) * trauma_pwr * 0.020
			camera.rotation.z += shake_roll
			camera.rotation.x += shake_pitch
			camera_trauma = maxf(0.0, camera_trauma - delta * 3.2)
		elif not in_submarine_mode:
			camera.rotation.z = lerpf(camera.rotation.z, 0.0, 1.0 - exp(-delta * 12.0))
	_update_third_person_camera(delta)
	# Visual effects update
	if is_instance_valid(slash_light) and slash_light.light_energy > 0.0:
		slash_light.light_energy = maxf(0.0, slash_light.light_energy - delta * 18.0)
	if vfx_timer > 0.0:
		vfx_timer = maxf(0.0, vfx_timer - delta)
		var progress: float = 1.0 - (vfx_timer / maxf(vfx_max_timer, 0.001))
		if is_instance_valid(cleave_mesh) and cleave_mesh.visible:
			cleave_mesh.scale += Vector3(1.0, 1.0, 1.15) * delta * 3.4
			cleave_mesh.position.z -= delta * 2.2
			cleave_mesh.rotate_object_local(Vector3.UP, delta * 6.2)
			var fade := clampf(sin(progress * PI) * 1.15 if progress < 0.35 else pow(1.0 - progress, 1.35), 0.0, 1.0)
			var mat = cleave_mesh.material_override
			if mat is StandardMaterial3D:
				mat.albedo_color.a = fade * 0.92
			if is_instance_valid(cleave_core_mesh):
				var c_mat = cleave_core_mesh.material_override
				if c_mat is StandardMaterial3D:
					c_mat.albedo_color.a = fade
			if vfx_timer <= 0.0:
				cleave_mesh.visible = false

		if is_instance_valid(thrust_cone_mesh) and thrust_cone_mesh.visible:
			thrust_cone_mesh.scale += Vector3(1.1, 2.4, 1.1) * delta * 2.8
			thrust_cone_mesh.position.z -= delta * 5.2
			thrust_cone_mesh.rotate_object_local(Vector3.UP, delta * 18.0)
			var t_mat = thrust_cone_mesh.material_override
			if t_mat is StandardMaterial3D:
				t_mat.albedo_color.a = clampf(pow(1.0 - progress, 1.25) * 0.9, 0.0, 1.0)
			if vfx_timer <= 0.0:
				thrust_cone_mesh.visible = false

		if is_instance_valid(sonic_ring) and sonic_ring.visible:
			sonic_ring.scale += Vector3.ONE * delta * 9.5
			sonic_ring.position.z -= delta * 24.0
			var s_mat = sonic_ring.material_override
			if s_mat is StandardMaterial3D:
				s_mat.albedo_color.a = clampf((1.0 - progress) * 0.95, 0.0, 1.0)
			if vfx_timer <= 0.0:
				sonic_ring.visible = false

	if in_submarine_mode:
		if equip_anim_time > 0.0:
			equip_anim_time = maxf(0.0, equip_anim_time - delta)
		return

	_animate_diver_model(delta)
	if not is_instance_valid(weapon_mount):
		return
	var active_node: Node3D = weapon_nodes.get(current_weapon, null)
	if not active_node:
		return
	var base: Dictionary = weapon_base_trans.get(current_weapon, {})
	if base.is_empty():
		return
	var base_pos: Vector3 = base["pos"]
	var base_rot: Vector3 = base["rot"]
	if current_weapon == "sonic":
		base_pos = base_pos.lerp(Vector3(0.025, -0.14, -0.46), aim_blend)
		if gun_trigger_held:
			base_pos.z -= get_charge_ratio() * 0.3
		base_rot = base_rot.lerp(Vector3.ZERO, aim_blend)

	# Subtle natural swimming sway
	var sway_time := Time.get_ticks_msec() * 0.003
	var sway_x := sin(sway_time) * (0.012 if sprinting else 0.006)
	var sway_y := cos(sway_time * 2.0) * (0.010 if sprinting else 0.005)
	sway_x *= 1.0 - aim_blend * 0.75
	sway_y *= 1.0 - aim_blend * 0.75

	# 冲刺姿态调整 (冲刺时压枪下移，平稳贴胸)
	var sprint_offset := Vector3(0.02, -0.06, 0.08) if sprinting else Vector3.ZERO
	var sprint_rot := Vector3(-12.0, 8.0, 5.0) if sprinting else Vector3.ZERO

	# 攻击微卡肉（Hitstop）冻结动画进度推进
	var anim_offset_pos := Vector3.ZERO
	var anim_offset_rot := Vector3.ZERO

	# 冻结动画解算与抖动叠加
	var jitter := hitstop_jitter
	if attack_anim_time > 0.0:
		var progress: float = 1.0 - (attack_anim_time / attack_anim_duration)
		match current_weapon:
			"knife":
				# 战术刀 3 段水下连击动作解算
				if combo_index == 0:
					# Combo 1: 右上至左下深切斜扫
					var strike := sin(progress * PI)
					anim_offset_pos = Vector3(-0.26 * strike, -0.12 * strike, -0.34 * strike)
					anim_offset_rot = Vector3(-32.0 * strike, -62.0 * strike, 55.0 * strike)
				elif combo_index == 1:
					# Combo 2: 左下至右上反手挑削
					var strike := sin(progress * PI)
					anim_offset_pos = Vector3(0.22 * strike, 0.20 * strike, -0.28 * strike)
					anim_offset_rot = Vector3(42.0 * strike, 52.0 * strike, -48.0 * strike)
				else:
					# Combo 3: 蓄力贯通突刺 (Pull back then burst thrust)
					if progress < 0.22:
						var p0 := progress / 0.22
						anim_offset_pos = Vector3(0.0, 0.02 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-5.0 * p0, 0.0, 5.0 * p0)
					else:
						var p1 := (progress - 0.22) / 0.78
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(0.02 * strike, -0.03 * strike, -0.52 * strike)
						anim_offset_rot = Vector3(-12.0 * strike, -15.0 * strike, 26.0 * strike)

			"axe":
				if combo_index == 0:
					# 战斧 Combo 1: 右上至左下顺手重劈 (Anticipation -> Cleave -> Overshoot -> Settle)
					if progress < 0.26:
						# 阶段1: 克服水阻沉重蓄力
						var p0 := progress / 0.26
						anim_offset_pos = Vector3(0.12 * p0, 0.18 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-35.0 * p0, 48.0 * p0, -22.0 * p0)
					elif progress < 0.68:
						# 阶段2: 爆发性全屏弧面广角横扫
						var p1 := (progress - 0.26) / 0.42
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(0.12 - 0.54 * p1, 0.18 - 0.52 * p1, -0.32 * strike)
						anim_offset_rot = Vector3(-35.0 + 130.0 * p1, 48.0 - 132.0 * p1, -22.0 - 46.0 * p1)
					else:
						# 阶段3: 惯性过冲与流体阻尼回弹
						var p2 := (progress - 0.68) / 0.32
						var settle := (1.0 - p2) * exp(-p2 * 4.5) * sin(p2 * PI * 2.5)
						anim_offset_pos = Vector3(-0.42 * (1.0 - p2), -0.34 * (1.0 - p2) + settle * 0.03, settle * 0.04)
						anim_offset_rot = Vector3(95.0 * (1.0 - p2), -84.0 * (1.0 - p2), -68.0 * (1.0 - p2) + settle * 10.0)
				else:
					# 战斧 Combo 2: 左侧至右侧反手回劈 (Mirrored reverse cleave matching reversed VFX arc)
					if progress < 0.26:
						# 阶段1: 左侧沉重收缩蓄力
						var p0 := progress / 0.26
						anim_offset_pos = Vector3(-0.16 * p0, 0.16 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-30.0 * p0, -45.0 * p0, 25.0 * p0)
					elif progress < 0.68:
						# 阶段2: 爆发性反向横扫撕裂
						var p1 := (progress - 0.26) / 0.42
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(-0.16 + 0.58 * p1, 0.16 - 0.48 * p1, -0.32 * strike)
						anim_offset_rot = Vector3(-30.0 + 125.0 * p1, -45.0 + 130.0 * p1, 25.0 + 42.0 * p1)
					else:
						# 阶段3: 右侧过冲与流体回弹稳定
						var p2 := (progress - 0.68) / 0.32
						var settle := (1.0 - p2) * exp(-p2 * 4.5) * sin(p2 * PI * 2.5)
						anim_offset_pos = Vector3(0.42 * (1.0 - p2), -0.32 * (1.0 - p2) + settle * 0.03, settle * 0.04)
						anim_offset_rot = Vector3(95.0 * (1.0 - p2), 85.0 * (1.0 - p2), 67.0 * (1.0 - p2) - settle * 10.0)
			"sonic":
				if progress < 0.12:
					var p0 := progress / 0.12
					anim_offset_pos = Vector3(0.0, 0.12 * p0, 0.44 * p0)
					anim_offset_rot = Vector3(-42.0 * p0, 0.0, 0.0)
				else:
					var p1 := (progress - 0.12) / 0.88
					var spring := exp(-p1 * 6.5) * cos(p1 * 14.0)
					anim_offset_pos = Vector3(0.0, 0.12 * spring, 0.44 * spring)
					anim_offset_rot = Vector3(-42.0 * spring, 0.0, 0.0)
	anim_offset_pos += jitter

	# 叠加待机晃动、冲刺姿态、攻击位移动态与鼠标惯性迟滞
	var lag_pos := Vector3(mouse_lag.x, mouse_lag.y, 0)
	var lag_rot := Vector3(-mouse_lag.y * 30.0, mouse_lag.x * 40.0, -mouse_lag.x * 20.0)

	# 切换武器拔刀 procedural equip 动画
	var equip_offset_pos := Vector3.ZERO
	var equip_offset_rot := Vector3.ZERO
	if equip_anim_time > 0.0:
		equip_anim_time = maxf(0.0, equip_anim_time - delta)
		var eq_p := 1.0 - (equip_anim_time / maxf(equip_duration, 0.001))
		var eq_ease := 1.0 - pow(1.0 - eq_p, 3.0)
		var factor := 1.0 - eq_ease
		equip_offset_pos = Vector3(0.02 * factor, -0.22 * factor, 0.10 * factor)
		equip_offset_rot = Vector3(-18.0 * factor, 12.0 * factor, -8.0 * factor)

	# 水下 3D 流体阻力响应 (Dynamic fluid drag from swimming velocity)
	var local_vel := (camera.global_basis.inverse() * velocity) if (is_instance_valid(camera) and camera.is_inside_tree()) else velocity
	var target_fluid_pos := Vector3(
		clampf(-local_vel.x * 0.0025, -0.035, 0.035),
		clampf(-local_vel.y * 0.003, -0.04, 0.04),
		clampf(local_vel.z * 0.002, -0.03, 0.03)
	)
	var target_fluid_rot := Vector3(
		clampf(local_vel.y * 1.6, -15.0, 15.0),
		clampf(-local_vel.x * 2.2, -18.0, 18.0),
		clampf(local_vel.x * 1.4, -12.0, 12.0)
	)
	fluid_drag_pos = fluid_drag_pos.lerp(target_fluid_pos, delta * 7.5)
	fluid_drag_rot = fluid_drag_rot.lerp(target_fluid_rot, delta * 7.5)

	var is_melee := current_weapon == "knife" or current_weapon == "axe"
	if is_melee and is_instance_valid(diver_model) and is_instance_valid(body_pivot) and is_instance_valid(right_arm_pivot) and is_instance_valid(right_forearm_pivot) and is_instance_valid(right_hand_socket) and is_instance_valid(equipment_rig):
		_sync_melee_weapon_to_hand(active_node, current_weapon, lag_rot + fluid_drag_rot * 0.45, jitter)
	elif reference_model_active and third_person_mode and not scoped and current_weapon in ["sonic", "marker_gun"]:
		_sync_reference_gun_to_hand(active_node, current_weapon, lag_rot + fluid_drag_rot * 0.3, jitter)
	else:
		active_node.position = base_pos + Vector3(sway_x, sway_y, 0) + sprint_offset + anim_offset_pos + lag_pos + equip_offset_pos + fluid_drag_pos
		active_node.rotation_degrees = base_rot + sprint_rot + anim_offset_rot + lag_rot + equip_offset_rot + fluid_drag_rot
	if is_instance_valid(shield_node) and shield_active and is_instance_valid(diver_model) and is_instance_valid(body_pivot) and is_instance_valid(left_arm_pivot) and is_instance_valid(left_forearm_pivot) and is_instance_valid(left_hand_socket) and is_instance_valid(equipment_rig) and is_instance_valid(shield_mount):
		_sync_shield_to_left_arm()
	if is_instance_valid(charge_glow) and charge_glow.is_inside_tree():
		charge_glow.global_position = get_muzzle_position()

func _update_third_person_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if is_instance_valid(equipment_rig):
		equipment_rig.rotation = camera.rotation
	var desired_dist: float = third_person_distance
	if scoped:
		desired_dist = 0.0
	elif vehicle_camera_distance > 0.0:
		desired_dist = vehicle_camera_distance
	elif aiming:
		desired_dist = THIRD_PERSON_AIM_DIST
	elif sprinting or booster_active:
		desired_dist = third_person_distance + 0.42

	if delta > 0.0 and not scoped:
		current_camera_distance = lerpf(current_camera_distance, desired_dist, 1.0 - exp(-delta * 10.0))
		if absf(current_camera_distance - desired_dist) < 0.0005:
			current_camera_distance = desired_dist
	else:
		current_camera_distance = desired_dist

	var actual_dist: float = current_camera_distance
	if actual_dist > 0.1 and is_inside_tree() and get_world_3d() != null and get_world_3d().direct_space_state != null:
		var origin := global_position
		var back_dir := camera.global_basis.z.normalized()
		var desired_cam_pos := origin + back_dir * actual_dist
		var frame_now := Engine.get_process_frames()
		var same_query := (
			_cam_ray_cache_valid
			and frame_now == _cam_ray_last_frame
			and origin.is_equal_approx(_cam_ray_last_origin)
			and desired_cam_pos.is_equal_approx(_cam_ray_last_target)
			and in_submarine_mode == _cam_ray_last_sub_mode
			and in_mount_mode == _cam_ray_last_mount_mode
			and scoped == _cam_ray_last_scoped
		)
		var self_rid := get_rid()
		if same_query and _cam_ray_exclude_self_rid == self_rid and _cam_ray_exclude_vehicle_rid == vehicle_exclude_rid:
			if _cam_ray_cached_hit_valid:
				actual_dist = clampf(_cam_ray_cached_hit_dist - 0.25, 0.55, actual_dist)
		else:
			if _cam_ray_query == null:
				_cam_ray_query = PhysicsRayQueryParameters3D.new()
			if _cam_ray_exclude.is_empty() or _cam_ray_exclude_self_rid != self_rid or _cam_ray_exclude_vehicle_rid != vehicle_exclude_rid:
				_cam_ray_exclude.clear()
				_cam_ray_exclude.append(self_rid)
				if vehicle_exclude_rid.is_valid():
					_cam_ray_exclude.append(vehicle_exclude_rid)
				_cam_ray_query.exclude = _cam_ray_exclude
				_cam_ray_exclude_self_rid = self_rid
				_cam_ray_exclude_vehicle_rid = vehicle_exclude_rid
			_cam_ray_query.from = origin
			_cam_ray_query.to = desired_cam_pos
			_cam_ray_query.collision_mask = 1
			var hit := get_world_3d().direct_space_state.intersect_ray(_cam_ray_query)
			if not hit.is_empty() and hit.get("collider") is StaticBody3D:
				_cam_ray_cached_hit_valid = true
				_cam_ray_cached_hit_dist = origin.distance_to(hit["position"])
				actual_dist = clampf(_cam_ray_cached_hit_dist - 0.25, 0.55, actual_dist)
			else:
				_cam_ray_cached_hit_valid = false
				_cam_ray_cached_hit_dist = 0.0
			_cam_ray_cache_valid = true
			_cam_ray_last_frame = frame_now
			_cam_ray_last_origin = origin
			_cam_ray_last_target = desired_cam_pos
			_cam_ray_last_sub_mode = in_submarine_mode
			_cam_ray_last_mount_mode = in_mount_mode
			_cam_ray_last_scoped = scoped

	_applied_camera_distance = actual_dist
	camera.position = camera.basis.z * actual_dist
	if is_instance_valid(diver_model):
		diver_model.visible = third_person_mode and not scoped and not in_submarine_mode

func _build_diver_model() -> void:
	if ReferenceDiver.available():
		_build_reference_diver_model()
		return
	diver_model = Node3D.new()
	diver_model.name = "DiverThirdPersonModel"
	diver_model.position = Vector3(0.0, -0.58, 0.24)
	diver_model.scale = Vector3.ONE * 1.15
	add_child(diver_model)

	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	diver_model.add_child(body_pivot)

	var mat_suit := StandardMaterial3D.new()
	mat_suit.albedo_color = Color("17354b")
	mat_suit.set_meta("diver_pigment", true)
	mat_suit.metallic = 0.06
	mat_suit.roughness = 0.72
	mat_suit.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_suit.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_suit.rim_enabled = false
	mat_suit.rim = 0.54
	mat_suit.rim_tint = 0.32

	var mat_armor := StandardMaterial3D.new()
	mat_armor.albedo_color = Color("527d88")
	mat_armor.set_meta("diver_pigment", true)
	mat_armor.metallic = 0.10
	mat_armor.roughness = 0.66
	mat_armor.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_armor.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_armor.rim_enabled = false
	mat_armor.rim = 0.52

	var mat_accent := StandardMaterial3D.new()
	mat_accent.albedo_color = Color("d5b566")
	mat_accent.set_meta("diver_pigment", true)
	mat_accent.metallic = 0.14
	mat_accent.roughness = 0.52
	mat_accent.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_accent.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_accent.rim_enabled = false
	mat_accent.rim = 0.52

	var mat_cyan := StandardMaterial3D.new()
	mat_cyan.albedo_color = Color("7caeae")
	mat_cyan.set_meta("diver_pigment", true)
	mat_cyan.emission_enabled = true
	mat_cyan.emission = Color("71aaa9")
	mat_cyan.emission_energy_multiplier = 0.09

	var mat_visor := StandardMaterial3D.new()
	mat_visor.albedo_color = Color("2b6e7d")
	mat_visor.set_meta("diver_pigment", true)
	mat_visor.metallic = 0.22
	mat_visor.roughness = 0.28
	mat_visor.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_visor.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_visor.rim_enabled = false
	mat_visor.emission_enabled = true
	mat_visor.emission = Color("52a8b5")
	mat_visor.emission_energy_multiplier = 0.07

	var mat_tank := StandardMaterial3D.new()
	mat_tank.albedo_color = Color("345969")
	mat_tank.set_meta("diver_pigment", true)
	mat_tank.metallic = 0.12
	mat_tank.roughness = 0.65
	mat_tank.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_tank.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_tank.rim_enabled = false
	mat_tank.rim = 0.52

	var mat_membrane := StandardMaterial3D.new()
	mat_membrane.albedo_color = Color("d8d5b7")
	mat_membrane.set_meta("diver_pigment", true)
	mat_membrane.metallic = 0.08
	mat_membrane.roughness = 0.58
	mat_membrane.rim_enabled = false

	# Continuous original suit contours stay on the existing articulated rig.
	var torso := MeshInstance3D.new()
	torso.name = "ExpeditionTorso"
	torso.mesh = DiverSilhouette.torso()
	torso.material_override = mat_suit
	body_pivot.add_child(torso)

	var chest_plate := MeshInstance3D.new()
	chest_plate.name = "ContourChestShell"
	chest_plate.mesh = DiverSilhouette.chest()
	chest_plate.material_override = mat_armor
	body_pivot.add_child(chest_plate)

	var harness_mesh := BlenderArt.mesh("diver_harness")
	if harness_mesh != null:
		var harness := MeshInstance3D.new()
		harness.name = "SatinBrassHarness"
		harness.mesh = harness_mesh
		harness.material_override = mat_accent
		body_pivot.add_child(harness)

	var chest_clasp := MeshInstance3D.new()
	chest_clasp.name = "SternumClaspAccent"
	var cc_box := BoxMesh.new()
	cc_box.size = Vector3(0.048, 0.012, 0.012)
	chest_clasp.mesh = cc_box
	chest_clasp.position = Vector3(0.0, 0.222, -0.088)
	chest_clasp.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	chest_clasp.material_override = mat_accent
	body_pivot.add_child(chest_clasp)

	var spine_strip := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.018, 0.13, 0.012)
	spine_strip.mesh = s_box
	spine_strip.position = Vector3(0, 0.12, 0.10)
	spine_strip.material_override = mat_cyan
	body_pivot.add_child(spine_strip)

	var belt := MeshInstance3D.new()
	belt.name = "WarmNavigationBelt"
	belt.mesh = DiverSilhouette.belt()
	belt.material_override = mat_accent
	body_pivot.add_child(belt)

	# 2. Articulated Head & Diving Helmet
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.34, 0)
	body_pivot.add_child(head_pivot)

	var helmet := MeshInstance3D.new()
	helmet.name = "StreamlinedHelmet"
	helmet.mesh = DiverSilhouette.helmet()
	helmet.material_override = mat_suit
	head_pivot.add_child(helmet)

	var visor := MeshInstance3D.new()
	visor.name = "DarkVisor"
	visor.mesh = DiverSilhouette.visor()
	visor.material_override = mat_visor
	head_pivot.add_child(visor)

	var visor_rim := MeshInstance3D.new()
	visor_rim.name = "VisorRimAccent"
	visor_rim.mesh = DiverSilhouette.visor_rim()
	visor_rim.material_override = mat_accent
	head_pivot.add_child(visor_rim)

	var collar := MeshInstance3D.new()
	collar.name = "ExpeditionCollar"
	collar.mesh = DiverSilhouette.collar()
	collar.position = Vector3(0, -0.092, 0)
	collar.material_override = mat_accent
	head_pivot.add_child(collar)

	var headlamp_bezel := MeshInstance3D.new()
	var hl_cyl := CylinderMesh.new()
	hl_cyl.top_radius = 0.020
	hl_cyl.bottom_radius = 0.024
	hl_cyl.height = 0.026
	hl_cyl.radial_segments = 10
	hl_cyl.rings = 0
	headlamp_bezel.mesh = hl_cyl
	headlamp_bezel.position = Vector3(0, 0.084, -0.078)
	headlamp_bezel.rotation.x = PI * 0.5
	headlamp_bezel.material_override = mat_cyan
	head_pivot.add_child(headlamp_bezel)

	# 3. Twin Scuba Oxygen Cylinders & Hydro-Thruster Backpack
	var backpack := Node3D.new()
	backpack.name = "ScubaBackpack"
	backpack.position = Vector3(0, 0.10, 0.145)
	body_pivot.add_child(backpack)
	var pack_shell := MeshInstance3D.new()
	pack_shell.name = "ContouredBackpack"
	pack_shell.mesh = DiverSilhouette.backpack()
	pack_shell.material_override = mat_suit
	backpack.add_child(pack_shell)

	for side in [-1.0, 1.0]:
		var tank := MeshInstance3D.new()
		tank.name = "IntegratedTankLeft" if side < 0.0 else "IntegratedTankRight"
		tank.mesh = DiverSilhouette.tank()
		tank.position = Vector3(side * 0.052, 0.0, 0.045)
		tank.material_override = mat_tank
		backpack.add_child(tank)

		var nozzle := MeshInstance3D.new()
		var nz_cyl := CylinderMesh.new()
		nz_cyl.top_radius = 0.022
		nz_cyl.bottom_radius = 0.032
		nz_cyl.height = 0.07
		nz_cyl.radial_segments = 10
		nz_cyl.rings = 0
		nozzle.mesh = nz_cyl
		nozzle.position = Vector3(side * 0.052, -0.168, 0.040)
		nozzle.rotation.x = 0.25
		nozzle.material_override = mat_suit
		backpack.add_child(nozzle)

	var o2_gauge := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(0.014, 0.12, 0.012)
	o2_gauge.mesh = g_box
	o2_gauge.position = Vector3(0, 0.015, 0.085)
	o2_gauge.material_override = mat_cyan
	backpack.add_child(o2_gauge)

	# Regulator breathing bubbles
	breath_bubbles = CPUParticles3D.new()
	breath_bubbles.name = "RegulatorBubbles"
	breath_bubbles.position = Vector3(0, 0.20, 0.04)
	breath_bubbles.amount = 14
	breath_bubbles.lifetime = 1.6
	breath_bubbles.direction = Vector3(0, 1.0, 0.4)
	breath_bubbles.spread = 22.0
	breath_bubbles.initial_velocity_min = 0.35
	breath_bubbles.initial_velocity_max = 0.85
	breath_bubbles.gravity = Vector3(0, 0.9, 0)
	var b_mesh := SphereMesh.new()
	b_mesh.radius = 0.018
	b_mesh.height = 0.036
	b_mesh.radial_segments = 6
	b_mesh.rings = 3
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	b_mat.albedo_color = Color(0.78, 0.96, 1.0, 0.55)
	b_mesh.material = b_mat
	breath_bubbles.mesh = b_mesh
	backpack.add_child(breath_bubbles)

	# Sprint / Dash backpack thruster cavitation trail
	backpack_thruster_bubbles = CPUParticles3D.new()
	backpack_thruster_bubbles.name = "BackpackThrusterJet"
	backpack_thruster_bubbles.position = Vector3(0, -0.20, 0.05)
	backpack_thruster_bubbles.emitting = false
	backpack_thruster_bubbles.amount = 28
	backpack_thruster_bubbles.lifetime = 0.55
	backpack_thruster_bubbles.direction = Vector3(0, -0.6, 1.0)
	backpack_thruster_bubbles.spread = 20.0
	backpack_thruster_bubbles.initial_velocity_min = 2.2
	backpack_thruster_bubbles.initial_velocity_max = 4.6
	backpack_thruster_bubbles.gravity = Vector3(0, 0.6, 0)
	backpack_thruster_bubbles.mesh = b_mesh
	backpack.add_child(backpack_thruster_bubbles)

	# 4. Left & Right Articulated Arms
	left_arm_pivot = _build_limb_arm(-1.0, mat_suit, mat_armor, mat_accent, mat_cyan)
	right_arm_pivot = _build_limb_arm(1.0, mat_suit, mat_armor, mat_accent, mat_cyan)

	# 5. Left & Right Articulated Legs with Hydrodynamic Diving Fins
	left_leg_pivot = _build_limb_leg(-1.0, mat_suit, mat_armor, mat_accent, mat_membrane)
	right_leg_pivot = _build_limb_leg(1.0, mat_suit, mat_armor, mat_accent, mat_membrane)

	# Subtle local character rim light so the 3D diver is always visible in deep abyss
	var suit_light := OmniLight3D.new()
	suit_light.name = "DiverSuitRimLight"
	suit_light.position = Vector3(0.0, 0.18, 0.72)
	suit_light.light_color = Color(0.58, 0.82, 0.88)
	suit_light.light_energy = 0.16
	suit_light.omni_range = 2.6
	suit_light.omni_attenuation = 1.15
	diver_model.add_child(suit_light)
	ModelFinish.apply(diver_model, "diver")
	BlenderArt.finish_diver(diver_model)
	diver_model.set_meta("mesh_contract", DiverSilhouette.CONTRACT_VERSION)
	diver_model.set_meta("triangle_budget", DiverSilhouette.TRIANGLE_BUDGET)

func _build_reference_diver_model() -> void:
	reference_model_active = true
	diver_model = Node3D.new()
	diver_model.name = "DiverThirdPersonModel"
	diver_model.position = Vector3(0.0, -0.58, 0.24)
	diver_model.scale = Vector3.ONE * 1.15
	add_child(diver_model)
	body_pivot = ReferenceDiver.joint(diver_model, "BodyPivot", Vector3.ZERO)
	head_pivot = ReferenceDiver.joint(body_pivot, "HeadPivot", Vector3(0, 0.34, 0))
	left_arm_pivot = ReferenceDiver.joint(body_pivot, "LeftArmPivot", Vector3(-0.18, 0.19, 0))
	right_arm_pivot = ReferenceDiver.joint(body_pivot, "RightArmPivot", Vector3(0.18, 0.19, 0))
	left_forearm_pivot = ReferenceDiver.joint(left_arm_pivot, "LeftForearmPivot", Vector3(0, -0.235, 0))
	right_forearm_pivot = ReferenceDiver.joint(right_arm_pivot, "RightForearmPivot", Vector3(0, -0.235, 0))
	left_hand_socket = ReferenceDiver.joint(left_forearm_pivot, "LeftHandSocket", Vector3(0, -0.255, -0.005))
	right_hand_socket = ReferenceDiver.joint(right_forearm_pivot, "RightHandSocket", Vector3(0, -0.255, -0.005))
	left_leg_pivot = ReferenceDiver.joint(body_pivot, "LeftLegPivot", Vector3(-0.08, -0.17, 0.01))
	right_leg_pivot = ReferenceDiver.joint(body_pivot, "RightLegPivot", Vector3(0.08, -0.17, 0.01))
	left_knee_pivot = ReferenceDiver.joint(left_leg_pivot, "LeftKneePivot", Vector3(0, -0.265, 0))
	right_knee_pivot = ReferenceDiver.joint(right_leg_pivot, "RightKneePivot", Vector3(0, -0.265, 0))
	left_fin_pivot = ReferenceDiver.joint(left_knee_pivot, "LeftFinPivot", Vector3(0, -0.26, 0))
	right_fin_pivot = ReferenceDiver.joint(right_knee_pivot, "RightFinPivot", Vector3(0, -0.26, 0))
	left_fin_pivot.rotation_degrees.x = 11.5
	right_fin_pivot.rotation_degrees.x = 11.5
	var fin_l := ReferenceDiver.joint(left_fin_pivot, "FinMembraneDirection", Vector3.ZERO)
	var fin_r := ReferenceDiver.joint(right_fin_pivot, "FinMembraneDirection", Vector3.ZERO)
	# The old ankle animation adds 11.5 degrees. New fins are modeled along +Z
	# with no hidden mesh pre-rotation, for a net 70-degree relaxed foot angle.
	fin_l.rotation_degrees.x = 58.5
	fin_r.rotation_degrees.x = 58.5
	_reference_drivers = {
		"body": body_pivot, "head": head_pivot,
		"arm_l": left_arm_pivot, "arm_r": right_arm_pivot,
		"forearm_l": left_forearm_pivot, "forearm_r": right_forearm_pivot,
		"leg_l": left_leg_pivot, "leg_r": right_leg_pivot,
		"calf_l": left_knee_pivot, "calf_r": right_knee_pivot,
		"fin_l": fin_l, "fin_r": fin_r}
	var report := ReferenceDiver.populate(_reference_drivers)
	diver_model.set_meta("mesh_contract", ReferenceDiver.CONTRACT_VERSION)
	diver_model.set_meta("reference_model", ReferenceDiver.MODEL_PATH)
	diver_model.set_meta("reference_parts", report.parts)
	diver_model.set_meta("reference_triangles", report.triangles)
	diver_model.set_meta("art_finished", true)
	set_meta("art_finished", true)
	# Breathing and sprint particles remain controller-owned, independent of the
	# character's authored glass, skin, cloth and metallic materials.
	var bubble := SphereMesh.new()
	bubble.radius = 0.012
	bubble.height = 0.024
	bubble.radial_segments = 6
	bubble.rings = 3
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_mat.albedo_color = Color(0.8, 0.96, 1.0, 0.35)
	bubble.material = bubble_mat
	breath_bubbles = CPUParticles3D.new()
	breath_bubbles.name = "RegulatorBubbles"
	breath_bubbles.position = Vector3(0, -0.065, -0.11)
	breath_bubbles.amount = 10
	breath_bubbles.lifetime = 1.6
	breath_bubbles.direction = Vector3.UP
	breath_bubbles.gravity = Vector3(0, 0.8, 0)
	breath_bubbles.initial_velocity_min = 0.25
	breath_bubbles.initial_velocity_max = 0.5
	breath_bubbles.mesh = bubble
	head_pivot.add_child(breath_bubbles)
	backpack_thruster_bubbles = CPUParticles3D.new()
	backpack_thruster_bubbles.name = "BackpackThrusterJet"
	backpack_thruster_bubbles.position = Vector3(0, -0.1, 0.16)
	backpack_thruster_bubbles.amount = 20
	backpack_thruster_bubbles.lifetime = 0.55
	backpack_thruster_bubbles.direction = Vector3(0, -0.6, 1)
	backpack_thruster_bubbles.gravity = Vector3(0, 0.6, 0)
	backpack_thruster_bubbles.initial_velocity_min = 2.0
	backpack_thruster_bubbles.initial_velocity_max = 3.5
	backpack_thruster_bubbles.emitting = false
	backpack_thruster_bubbles.mesh = bubble
	body_pivot.add_child(backpack_thruster_bubbles)

func _build_limb_arm(side: float, mat_suit: Material, mat_armor: Material, mat_accent: Material, mat_cyan: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "LeftArmPivot" if side < 0.0 else "RightArmPivot"
	pivot.position = Vector3(side * 0.20, 0.21, -0.01)
	body_pivot.add_child(pivot)

	var pauldron := MeshInstance3D.new()
	pauldron.name = "ContourShoulder"
	pauldron.mesh = DiverSilhouette.shoulder()
	pauldron.position = Vector3(-side * 0.010, -0.022, -0.016)
	pauldron.rotation_degrees = Vector3(26.0, 0.0, side * 10.0)
	pauldron.material_override = mat_armor
	pivot.add_child(pauldron)

	var upper_arm := MeshInstance3D.new()
	upper_arm.name = "TaperedUpperArm"
	upper_arm.mesh = DiverSilhouette.upper_arm()
	upper_arm.position = Vector3(side * 0.02, -0.10, -0.05)
	upper_arm.rotation_degrees = Vector3(32.0, 0, -side * 8.0)
	upper_arm.material_override = mat_suit
	pivot.add_child(upper_arm)

	# Articulated Elbow Pivot for dynamic combat swings & two-handed weapon poses
	var elbow_pivot := Node3D.new()
	elbow_pivot.name = "LeftForearmPivot" if side < 0.0 else "RightForearmPivot"
	elbow_pivot.position = Vector3(side * 0.02, -0.15, -0.10)
	pivot.add_child(elbow_pivot)
	if side < 0.0:
		left_forearm_pivot = elbow_pivot
	else:
		right_forearm_pivot = elbow_pivot

	# A curved textile sleeve covers the real elbow pivot. The visual upper
	# arm ends inside it; combat/weapon animation still owns the same pivot.
	for joint_part: Array in [["diver_elbow_sleeve", "FlexibleElbowSleeve", mat_suit], ["diver_elbow_guard", "ContourElbowGuard", mat_armor]]:
		var joint_mesh := BlenderArt.mesh(joint_part[0])
		if joint_mesh != null:
			var joint := MeshInstance3D.new()
			joint.name = joint_part[1]
			joint.mesh = joint_mesh
			joint.material_override = joint_part[2]
			elbow_pivot.add_child(joint)

	var forearm := MeshInstance3D.new()
	forearm.name = "TaperedForearm"
	forearm.mesh = DiverSilhouette.forearm()
	forearm.position = Vector3(0.0, -0.04, -0.09)
	forearm.rotation_degrees = Vector3(72.0, -side * 10.0, 0)
	forearm.material_override = mat_suit
	elbow_pivot.add_child(forearm)

	var cuff := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.044
	c_cyl.bottom_radius = 0.044
	c_cyl.height = 0.025
	c_cyl.radial_segments = 10
	c_cyl.rings = 0
	cuff.mesh = c_cyl
	cuff.position = Vector3(-side * 0.01, -0.07, -0.17)
	cuff.rotation_degrees = Vector3(72.0, -side * 10.0, 0)
	cuff.material_override = mat_accent
	elbow_pivot.add_child(cuff)

	var glove := MeshInstance3D.new()
	glove.name = "ContourGlove"
	glove.mesh = DiverSilhouette.glove()
	glove.position = Vector3(-side * 0.01, -0.08, -0.21)
	glove.rotation_degrees = Vector3(72.0, -side * 10.0, 0.0)
	glove.material_override = mat_suit
	elbow_pivot.add_child(glove)

	var hand_socket := Node3D.new()
	hand_socket.name = "LeftHandSocket" if side < 0.0 else "RightHandSocket"
	hand_socket.position = glove.position
	elbow_pivot.add_child(hand_socket)
	if side < 0.0:
		left_hand_socket = hand_socket
	else:
		right_hand_socket = hand_socket
	return pivot

func _build_limb_leg(side: float, mat_suit: Material, mat_armor: Material, mat_accent: Material, mat_membrane: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "LeftLegPivot" if side < 0.0 else "RightLegPivot"
	pivot.position = Vector3(side * 0.09, -0.15, 0.01)
	body_pivot.add_child(pivot)

	var thigh := MeshInstance3D.new()
	thigh.name = "TaperedThigh"
	thigh.mesh = DiverSilhouette.thigh()
	thigh.position = Vector3(0, -0.11, 0.012)
	thigh.rotation_degrees = Vector3(-6.0, 0, 0)
	thigh.material_override = mat_suit
	pivot.add_child(thigh)

	var knee_pivot := Node3D.new()
	knee_pivot.name = "LeftKneePivot" if side < 0.0 else "RightKneePivot"
	knee_pivot.position = Vector3(0, -0.235, 0.025)
	pivot.add_child(knee_pivot)
	if side < 0.0:
		left_knee_pivot = knee_pivot
	else:
		right_knee_pivot = knee_pivot
	var knee := MeshInstance3D.new()
	knee.name = "ContourKnee"
	knee.mesh = DiverSilhouette.knee()
	knee.material_override = mat_armor
	knee_pivot.add_child(knee)

	var calf := MeshInstance3D.new()
	calf.name = "TaperedCalf"
	calf.mesh = DiverSilhouette.calf()
	calf.position = Vector3(0, -0.12, 0.018)
	calf.rotation_degrees = Vector3(-7.5, 0, 0)
	calf.material_override = mat_suit
	knee_pivot.add_child(calf)

	# Flexible ankle separates the trailing fin phase from the thigh kick.
	var ankle := Node3D.new()
	ankle.name = "LeftFinPivot" if side < 0.0 else "RightFinPivot"
	ankle.position = Vector3(0, -0.245, 0.034)
	ankle.rotation_degrees.x = 11.5
	knee_pivot.add_child(ankle)
	if side < 0.0:
		left_fin_pivot = ankle
	else:
		right_fin_pivot = ankle
	var fin := MeshInstance3D.new()
	fin.name = "SweptNavigationFin"
	fin.mesh = DiverSilhouette.fin()
	fin.position = Vector3(0, -0.010, -0.006)
	fin.rotation_degrees = Vector3(66.0, 0.0, 0.0)
	fin.material_override = mat_membrane
	ankle.add_child(fin)
	var trim_mesh := BlenderArt.mesh("diver_fin_trim")
	if trim_mesh != null:
		var fin_trim := MeshInstance3D.new()
		fin_trim.name = "SatinFinRim"
		fin_trim.mesh = trim_mesh
		fin_trim.material_override = mat_accent
		fin.add_child(fin_trim)

	var fin_rib := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(0.014, 0.009, 0.22)
	fin_rib.mesh = r_box
	fin_rib.position = Vector3(0, 0.011, 0.155)
	fin_rib.material_override = mat_suit
	fin.add_child(fin_rib)
	return pivot

func _animate_diver_model(delta: float) -> void:
	if not is_instance_valid(diver_model) or not is_instance_valid(body_pivot):
		return
	var horiz_spd := Vector2(velocity.x, velocity.z).length()
	var total_spd := velocity.length()
	var is_moving := total_spd > 0.25
	var motion_target := smoothstep(0.12, 6.5, total_spd)
	swim_motion_blend = lerpf(swim_motion_blend, motion_target, 1.0 - exp(-delta * 4.5))
	var kick_target := lerpf(2.0, 4.8, swim_motion_blend)
	if sprinting or booster_active:
		kick_target = 6.4
	swim_kick_rate = lerpf(swim_kick_rate, kick_target, 1.0 - exp(-delta * 5.0))
	swim_clock += delta * swim_kick_rate

	# Compute full-body combat choreography (torso twist, lunge, shoulder & elbow curves)
	var target_combat_yaw := 0.0
	var target_combat_pitch := 0.0
	var target_combat_roll := 0.0
	var target_lunge := Vector3.ZERO
	var l_shoulder := Vector3.ZERO
	var r_shoulder := Vector3.ZERO
	var l_elbow := Vector3.ZERO
	var r_elbow := Vector3.ZERO
	var r_wrist := Vector3(0.0, 0.0, -18.0 if current_weapon == "knife" else (-14.0 if current_weapon == "axe" else 0.0))
	var l_wrist := Vector3.ZERO
	var target_grip_pitch := 38.0 if current_weapon == "knife" else 42.0
	var in_attack := attack_anim_time > 0.0
	var in_combat_posture := in_attack or (combo_timer > 0.0 and (current_weapon == "knife" or current_weapon == "axe"))
	combat_stance_blend = move_toward(combat_stance_blend, 1.0 if in_combat_posture else 0.0, delta * (14.0 if in_attack else 5.0))

	if in_attack:
		var p := clampf(1.0 - (attack_anim_time / maxf(attack_anim_duration, 0.001)), 0.0, 1.0)
		match current_weapon:
			"knife":
				if combo_index == 0:
					# 1段：正手右上引刀蓄力 -> 左下爆发斜劈斩 -> 流体阻尼收刀
					# Godot坐标系：+X抬肩向上/-X挥臂向下，-Y向右侧外展/+Y向左横扫过胸，+body_yaw右肩前送左旋
					if p < 0.20:
						var w := sin((p / 0.20) * PI * 0.5)
						target_combat_yaw = deg_to_rad(-14.0 * w)
						target_combat_pitch = deg_to_rad(4.0 * w)
						target_combat_roll = deg_to_rad(-5.0 * w)
						target_lunge = Vector3(0.02 * w, 0.02 * w, 0.04 * w)
						r_shoulder = Vector3(18.0 * w, -16.0 * w, 14.0 * w)
						r_elbow = Vector3(8.0 * w, -6.0 * w, 0.0)
						r_wrist = Vector3(8.0 * w, -4.0 * w, lerpf(-18.0, -48.0, w))
						l_shoulder = Vector3(18.0 * w, 12.0 * w, -8.0 * w)
						l_elbow = Vector3(12.0 * w, 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 40.0, w)
					elif p < 0.68:
						var t := (p - 0.20) / 0.48
						var s := 1.0 - pow(1.0 - t, 2.4)
						var arc_mid := sin(t * PI)
						target_combat_yaw = deg_to_rad(lerpf(-14.0, 20.0, s))
						target_combat_pitch = deg_to_rad(lerpf(4.0, -8.0, s))
						target_combat_roll = deg_to_rad(lerpf(-5.0, 6.0, s))
						target_lunge = Vector3(lerpf(0.02, -0.03, s), lerpf(0.02, -0.02, s), lerpf(0.04, -0.22, arc_mid))
						r_shoulder = Vector3(lerpf(18.0, -18.0, s), lerpf(-16.0, 28.0, s), lerpf(14.0, -10.0, s))
						r_elbow = Vector3(lerpf(8.0, -10.0, s) - 12.0 * arc_mid, lerpf(-6.0, 8.0, s), 0.0)
						r_wrist = Vector3(lerpf(8.0, -18.0, s), lerpf(-4.0, 4.0, s), -48.0)
						l_shoulder = Vector3(lerpf(18.0, -20.0, s), lerpf(12.0, -22.0, s), lerpf(-8.0, -16.0, s))
						l_elbow = Vector3(lerpf(12.0, 22.0, s), 0.0, 0.0)
						target_grip_pitch = lerpf(40.0, 22.0, s)
					else:
						var rt := (p - 0.68) / 0.32
						var keep := 1.0 - smoothstep(0.0, 1.0, rt)
						target_combat_yaw = deg_to_rad(20.0 * keep)
						target_combat_pitch = deg_to_rad(-8.0 * keep)
						target_combat_roll = deg_to_rad(6.0 * keep)
						target_lunge = Vector3(-0.03 * keep, -0.02 * keep, -0.08 * keep)
						r_shoulder = Vector3(-18.0 * keep, 28.0 * keep, -10.0 * keep)
						r_elbow = Vector3(-10.0 * keep, 8.0 * keep, 0.0)
						r_wrist = Vector3(-18.0 * keep, 4.0 * keep, lerpf(-18.0, -48.0, keep))
						l_shoulder = Vector3(-20.0 * keep, -22.0 * keep, -16.0 * keep)
						l_elbow = Vector3(22.0 * keep, 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 22.0, keep)
				elif combo_index == 1:
					# 2段：衔接1段左下收刀位，翻腕调转刀刃朝向右上 -> 反手左下至右上回旋挑斩
					if p < 0.18:
						var w := sin((p / 0.18) * PI * 0.5)
						target_combat_yaw = deg_to_rad(18.0 * w)
						target_combat_pitch = deg_to_rad(-6.0 * w)
						target_combat_roll = deg_to_rad(6.0 * w)
						target_lunge = Vector3(-0.02 * w, -0.02 * w, 0.04 * w)
						r_shoulder = Vector3(-16.0 * w, 28.0 * w, -12.0 * w)
						r_elbow = Vector3(4.0 * w, 10.0 * w, 0.0)
						r_wrist = Vector3(8.0 * w, -4.0 * w, lerpf(-48.0, 132.0, w))
						l_shoulder = Vector3(-18.0 * w, -22.0 * w, -14.0 * w)
						l_elbow = Vector3(20.0 * w, 0.0, 0.0)
						target_grip_pitch = lerpf(28.0, 38.0, w)
					elif p < 0.66:
						var t := (p - 0.18) / 0.48
						var s := 1.0 - pow(1.0 - t, 2.4)
						var arc_mid := sin(t * PI)
						target_combat_yaw = deg_to_rad(lerpf(18.0, -20.0, s))
						target_combat_pitch = deg_to_rad(lerpf(-6.0, 6.0, s))
						target_combat_roll = deg_to_rad(lerpf(6.0, -6.0, s))
						target_lunge = Vector3(lerpf(-0.02, 0.03, s), 0.03 * arc_mid, lerpf(0.04, -0.20, arc_mid))
						r_shoulder = Vector3(lerpf(-16.0, 20.0, s), lerpf(28.0, -22.0, s), lerpf(-12.0, 16.0, s))
						r_elbow = Vector3(lerpf(4.0, -8.0, s) - 12.0 * arc_mid, lerpf(10.0, -10.0, s), 0.0)
						r_wrist = Vector3(lerpf(8.0, -18.0, s), lerpf(-4.0, 4.0, s), 132.0)
						l_shoulder = Vector3(lerpf(-18.0, 18.0, s), lerpf(-22.0, 16.0, s), -12.0)
						l_elbow = Vector3(lerpf(20.0, 12.0, s), 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 22.0, s)
					else:
						var rt := (p - 0.66) / 0.34
						var keep := 1.0 - smoothstep(0.0, 1.0, rt)
						target_combat_yaw = deg_to_rad(-20.0 * keep)
						target_combat_pitch = deg_to_rad(6.0 * keep)
						target_combat_roll = deg_to_rad(-6.0 * keep)
						target_lunge = Vector3(0.03 * keep, 0.0, -0.06 * keep)
						r_shoulder = Vector3(20.0 * keep, -22.0 * keep, 16.0 * keep)
						r_elbow = Vector3(-8.0 * keep, -10.0 * keep, 0.0)
						r_wrist = Vector3(-18.0 * keep, 4.0 * keep, lerpf(-18.0, 132.0, keep))
						l_shoulder = Vector3(18.0 * keep, 16.0 * keep, -12.0 * keep)
						l_elbow = Vector3(12.0 * keep, 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 22.0, keep)
				else:
					# 3段：右肘收肋蓄力压平刀尖 -> 躯干左旋送肩、右臂完全伸直向前螺旋直刺贯穿
					if p < 0.24:
						var w := sin((p / 0.24) * PI * 0.5)
						target_combat_yaw = deg_to_rad(-18.0 * w)
						target_combat_pitch = deg_to_rad(4.0 * w)
						target_combat_roll = deg_to_rad(-4.0 * w)
						target_lunge = Vector3(0.0, 0.0, 0.08 * w)
						r_shoulder = Vector3(-20.0 * w, -12.0 * w, 10.0 * w)
						r_elbow = Vector3(18.0 * w, 6.0 * w, 0.0)
						r_wrist = Vector3(0.0, 0.0, lerpf(-18.0, 0.0, w))
						l_shoulder = Vector3(34.0 * w, 12.0 * w, -8.0 * w)
						l_elbow = Vector3(14.0 * w, 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 0.0, w)
					elif p < 0.66:
						var t := (p - 0.24) / 0.42
						var s := 1.0 - pow(1.0 - t, 3.0)
						target_combat_yaw = deg_to_rad(lerpf(-18.0, 18.0, s))
						target_combat_pitch = deg_to_rad(lerpf(4.0, -10.0, s))
						target_combat_roll = deg_to_rad(lerpf(-4.0, 5.0, s))
						target_lunge = Vector3(0.0, 0.0, lerpf(0.08, -0.34, s))
						r_shoulder = Vector3(lerpf(-20.0, 18.0, s), lerpf(-12.0, -2.0, s), lerpf(10.0, -6.0, s))
						r_elbow = Vector3(lerpf(18.0, -24.0, s), lerpf(6.0, -8.0, s), 0.0)
						r_wrist = Vector3(0.0, 0.0, lerpf(0.0, -85.0, s))
						l_shoulder = Vector3(lerpf(34.0, -28.0, s), lerpf(12.0, -24.0, s), lerpf(-8.0, -18.0, s))
						l_elbow = Vector3(lerpf(14.0, 32.0, s), 0.0, 0.0)
						target_grip_pitch = 0.0
					else:
						var rt := (p - 0.66) / 0.34
						var keep := 1.0 - smoothstep(0.0, 1.0, rt)
						target_combat_yaw = deg_to_rad(18.0 * keep)
						target_combat_pitch = deg_to_rad(-10.0 * keep)
						target_combat_roll = deg_to_rad(5.0 * keep)
						target_lunge = Vector3(0.0, 0.0, -0.34 * keep)
						r_shoulder = Vector3(18.0 * keep, -2.0 * keep, -6.0 * keep)
						r_elbow = Vector3(-24.0 * keep, -8.0 * keep, 0.0)
						r_wrist = Vector3(0.0, 0.0, lerpf(-18.0, -85.0, keep))
						l_shoulder = Vector3(-28.0 * keep, -24.0 * keep, -18.0 * keep)
						l_elbow = Vector3(32.0 * keep, 0.0, 0.0)
						target_grip_pitch = lerpf(38.0, 0.0, keep)
			"axe":
				# 破拆战斧：双手重型大开大合蓄力斜劈 + 反手回劈 + 流体阻尼回弹
				if combo_index == 0:
					if p < 0.26:
						var w := sin((p / 0.26) * PI * 0.5)
						target_combat_yaw = deg_to_rad(-22.0 * w)
						target_combat_pitch = deg_to_rad(8.0 * w)
						target_combat_roll = deg_to_rad(-7.0 * w)
						target_lunge = Vector3(0.03 * w, 0.04 * w, 0.10 * w)
						r_shoulder = Vector3(24.0 * w, -22.0 * w, 18.0 * w)
						r_elbow = Vector3(12.0 * w, -8.0 * w, 0.0)
						r_wrist = Vector3(10.0 * w, 0.0, lerpf(-14.0, -58.0, w))
						l_shoulder = Vector3(22.0 * w, -8.0 * w, -10.0 * w)
						l_elbow = Vector3(18.0 * w, 0.0, 0.0)
						target_grip_pitch = lerpf(42.0, 44.0, w)
					elif p < 0.68:
						var t := (p - 0.26) / 0.42
						var s := 1.0 - pow(1.0 - t, 2.2)
						var cleave := sin(t * PI)
						target_combat_yaw = deg_to_rad(lerpf(-22.0, 26.0, s))
						target_combat_pitch = deg_to_rad(lerpf(8.0, -14.0, s))
						target_combat_roll = deg_to_rad(lerpf(-7.0, 8.0, s))
						target_lunge = Vector3(lerpf(0.03, -0.04, s), -0.04 * cleave, lerpf(0.10, -0.30, cleave))
						r_shoulder = Vector3(lerpf(24.0, -20.0, s), lerpf(-22.0, 34.0, s), lerpf(18.0, -14.0, s))
						r_elbow = Vector3(lerpf(12.0, -10.0, s) - 14.0 * cleave, lerpf(-8.0, 12.0, s), 0.0)
						r_wrist = Vector3(lerpf(10.0, -20.0, s), 0.0, -58.0)
						l_shoulder = Vector3(lerpf(22.0, -14.0, s), lerpf(-8.0, 26.0, s), -12.0)
						l_elbow = Vector3(lerpf(18.0, 10.0, s), 0.0, 0.0)
						target_grip_pitch = lerpf(44.0, 18.0, s)
					else:
						var rp := (p - 0.68) / 0.32
						var settle := 1.0 - smoothstep(0.0, 1.0, rp)
						target_combat_yaw = deg_to_rad(26.0 * settle)
						target_combat_pitch = deg_to_rad(-14.0 * settle)
						target_combat_roll = deg_to_rad(8.0 * settle)
						target_lunge = Vector3(-0.04 * settle, 0.0, -0.10 * settle)
						r_shoulder = Vector3(-20.0 * settle, 34.0 * settle, -14.0 * settle)
						r_elbow = Vector3(-10.0 * settle, 12.0 * settle, 0.0)
						r_wrist = Vector3(-20.0 * settle, 0.0, lerpf(-14.0, -58.0, settle))
						l_shoulder = Vector3(-14.0 * settle, 26.0 * settle, -12.0 * settle)
						l_elbow = Vector3(10.0 * settle, 0.0, 0.0)
						target_grip_pitch = lerpf(42.0, 18.0, settle)
				else:
					if p < 0.26:
						var w := sin((p / 0.26) * PI * 0.5)
						target_combat_yaw = deg_to_rad(22.0 * w)
						target_combat_pitch = deg_to_rad(-8.0 * w)
						target_combat_roll = deg_to_rad(7.0 * w)
						target_lunge = Vector3(-0.03 * w, -0.02 * w, 0.08 * w)
						r_shoulder = Vector3(-16.0 * w, 34.0 * w, -14.0 * w)
						r_elbow = Vector3(8.0 * w, 12.0 * w, 0.0)
						r_wrist = Vector3(10.0 * w, 0.0, lerpf(-58.0, 122.0, w))
						l_shoulder = Vector3(-12.0 * w, 26.0 * w, -12.0 * w)
						l_elbow = Vector3(18.0 * w, 0.0, 0.0)
						target_grip_pitch = lerpf(36.0, 42.0, w)
					elif p < 0.68:
						var t := (p - 0.26) / 0.42
						var s := 1.0 - pow(1.0 - t, 2.2)
						var cleave := sin(t * PI)
						target_combat_yaw = deg_to_rad(lerpf(22.0, -26.0, s))
						target_combat_pitch = deg_to_rad(lerpf(-8.0, 10.0, s))
						target_combat_roll = deg_to_rad(lerpf(7.0, -8.0, s))
						target_lunge = Vector3(lerpf(-0.03, 0.04, s), 0.03 * cleave, lerpf(0.08, -0.28, cleave))
						r_shoulder = Vector3(lerpf(-16.0, 22.0, s), lerpf(34.0, -26.0, s), lerpf(-14.0, 18.0, s))
						r_elbow = Vector3(lerpf(8.0, -8.0, s) - 14.0 * cleave, lerpf(12.0, -12.0, s), 0.0)
						r_wrist = Vector3(lerpf(10.0, -20.0, s), 0.0, 122.0)
						l_shoulder = Vector3(lerpf(-12.0, 20.0, s), lerpf(26.0, -12.0, s), -10.0)
						l_elbow = Vector3(lerpf(18.0, 12.0, s), 0.0, 0.0)
						target_grip_pitch = lerpf(42.0, 18.0, s)
					else:
						var rp := (p - 0.68) / 0.32
						var settle := 1.0 - smoothstep(0.0, 1.0, rp)
						target_combat_yaw = deg_to_rad(-26.0 * settle)
						target_combat_pitch = deg_to_rad(10.0 * settle)
						target_combat_roll = deg_to_rad(-8.0 * settle)
						target_lunge = Vector3(0.04 * settle, 0.0, -0.08 * settle)
						r_shoulder = Vector3(22.0 * settle, -26.0 * settle, 18.0 * settle)
						r_elbow = Vector3(-8.0 * settle, -12.0 * settle, 0.0)
						r_wrist = Vector3(-20.0 * settle, 0.0, lerpf(-14.0, 122.0, settle))
						l_shoulder = Vector3(20.0 * settle, -12.0 * settle, -10.0 * settle)
						l_elbow = Vector3(12.0 * settle, 0.0, 0.0)
						target_grip_pitch = lerpf(42.0, 18.0, settle)
			"sonic", "marker_gun":
				# 蓝光静滞枪 / 光标枪：后坐力震退与上扬复原
				var recoil := sin(p * PI) if p < 0.25 else exp(-(p - 0.25) * 5.0) * cos((p - 0.25) * 10.0)
				target_combat_pitch = deg_to_rad(10.0 * recoil)
				target_lunge = Vector3(0.0, 0.0, 0.14 * recoil)
				r_shoulder = Vector3(44.0 + 24.0 * recoil, -12.0, 6.0)
				r_elbow = Vector3(28.0 * recoil, 0.0, 0.0)
				l_shoulder = Vector3(40.0 + 18.0 * recoil, 22.0, -8.0)
				l_elbow = Vector3(22.0 + 16.0 * recoil, 0.0, 0.0)

	var combat_track_rate := 55.0 if in_attack else 16.0
	var track_alpha := 1.0 if in_attack else (1.0 - exp(-delta * combat_track_rate))
	body_combat_yaw = lerpf(body_combat_yaw, target_combat_yaw, track_alpha)
	body_combat_pitch = lerpf(body_combat_pitch, target_combat_pitch, track_alpha)
	body_combat_roll = lerpf(body_combat_roll, target_combat_roll, track_alpha)
	body_combat_lunge = body_combat_lunge.lerp(target_lunge, track_alpha)
	melee_grip_pitch = lerpf(melee_grip_pitch, target_grip_pitch, track_alpha)

	var cam_pitch: float = camera.rotation.x if is_instance_valid(camera) else 0.0
	if in_mount_mode:
		# Riding posture on mount back
		body_pivot.rotation.x = lerpf(body_pivot.rotation.x, -0.25 + cam_pitch * 0.4 + body_combat_pitch, 1.0 - exp(-delta * 10.0))
		body_pivot.rotation.y = body_combat_yaw
		body_pivot.rotation.z = lerpf(body_pivot.rotation.z, turn_bank * 0.6 + body_combat_roll, 1.0 - exp(-delta * 10.0))
	else:
		var raw_swim_lean := clampf(horiz_spd / 7.5, 0.0, 1.0) * 0.72
		var swim_lean := raw_swim_lean * lerpf(1.0, 0.22, combat_stance_blend)
		var base_torso_lean := lerpf(-0.32, -0.16, combat_stance_blend)
		var target_body_pitch := base_torso_lean - swim_lean + cam_pitch * lerpf(0.65, 0.78, combat_stance_blend) + body_combat_pitch
		# Cruise follows the water-relative motion with a long, calm silhouette.
		# Combat keeps its authored torso curves so weapon/hand alignment is exact.
		var vertical_lean := atan2(velocity.y, maxf(horiz_spd, 1.2)) * 0.38
		var cruise_pitch := -0.22 - swim_motion_blend * 0.85 + cam_pitch * 0.42 + vertical_lean
		var pose_combat := 1.0 if in_attack else combat_stance_blend
		target_body_pitch = lerpf(cruise_pitch, target_body_pitch, pose_combat)
		body_pivot.rotation.x = target_body_pitch if in_attack else lerpf(body_pivot.rotation.x, target_body_pitch, 1.0 - exp(-delta * 9.0))
		body_pivot.rotation.y = body_combat_yaw + sin(swim_clock * 0.5) * swim_motion_blend * 0.022 * (1.0 - pose_combat)
		var flow_roll := sin(swim_clock - 0.35) * swim_motion_blend * 0.025 * (1.0 - pose_combat)
		body_pivot.rotation.z = (turn_bank + body_combat_roll) if in_attack else lerpf(body_pivot.rotation.z, turn_bank + body_combat_roll + flow_roll, 1.0 - exp(-delta * 8.0))

	diver_model.position = Vector3(0.0, -0.58 + sin(swim_clock * 0.5) * (0.015 if not is_moving else 0.025), 0.24) + body_combat_lunge

	if is_instance_valid(head_pivot):
		head_pivot.rotation.x = clampf(cam_pitch * 0.45 + 0.28, -0.55, 0.65)
		head_pivot.rotation.y = -body_combat_yaw * 0.55

	if is_instance_valid(left_leg_pivot) and is_instance_valid(right_leg_pivot):
		var kick_amp := lerpf(0.055, 0.165, swim_motion_blend)
		if sprinting or booster_active:
			kick_amp = 0.225
		if in_mount_mode:
			left_leg_pivot.rotation.x = 0.35
			right_leg_pivot.rotation.x = 0.35
			left_leg_pivot.rotation.z = 0.22
			right_leg_pivot.rotation.z = -0.22
		else:
			var kick_alpha := 1.0 - exp(-delta * 12.0)
			left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, sin(swim_clock) * kick_amp, kick_alpha)
			right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, sin(swim_clock + PI + 0.06) * kick_amp, kick_alpha)
			left_leg_pivot.rotation.z = -0.015
			right_leg_pivot.rotation.z = 0.015
		for side in range(2):
			var knee: Node3D = left_knee_pivot if side == 0 else right_knee_pivot
			var ankle: Node3D = left_fin_pivot if side == 0 else right_fin_pivot
			var phase := swim_clock + (0.0 if side == 0 else PI + 0.06)
			if is_instance_valid(knee):
				var knee_target := -0.44 if in_mount_mode else -maxf(0.0, cos(phase - 0.20)) * kick_amp * 0.52
				knee.rotation.x = lerpf(knee.rotation.x, knee_target, 1.0 - exp(-delta * 9.0))
			if is_instance_valid(ankle):
				var ankle_target := deg_to_rad(11.5) + (-0.05 if in_mount_mode else sin(phase - 1.15) * kick_amp * 0.62)
				ankle.rotation.x = lerpf(ankle.rotation.x, ankle_target, 1.0 - exp(-delta * 8.0))

	if is_instance_valid(left_arm_pivot) and is_instance_valid(right_arm_pivot):
		if booster_active:
			left_arm_pivot.rotation_degrees = Vector3(28.0, 14.0, 10.0)
			right_arm_pivot.rotation_degrees = Vector3(28.0, -14.0, -10.0)
			if is_instance_valid(left_forearm_pivot):
				left_forearm_pivot.rotation_degrees = Vector3.ZERO
			if is_instance_valid(right_forearm_pivot):
				right_forearm_pivot.rotation_degrees = Vector3.ZERO
			right_wrist_rot = Vector3.ZERO
			left_wrist_rot = Vector3.ZERO
		else:
			var is_gun := current_weapon == "sonic" or current_weapon == "marker_gun"
			var aim_pitch_comp := rad_to_deg(cam_pitch - body_pivot.rotation.x) * lerpf(0.35, 0.75, combat_stance_blend)
			var eq_factor := 0.0
			if equip_anim_time > 0.0:
				var eq_p := 1.0 - (equip_anim_time / maxf(equip_duration, 0.001))
				eq_factor = pow(clampf(1.0 - eq_p, 0.0, 1.0), 2.2)

			if shield_active:
				left_arm_pivot.rotation_degrees = Vector3(36.0, 22.0, -14.0) + l_shoulder * 0.35
				if is_instance_valid(left_forearm_pivot):
					left_forearm_pivot.rotation_degrees = Vector3(18.0, 12.0, 0.0)
			elif in_attack and (current_weapon == "axe" or is_gun):
				left_arm_pivot.rotation_degrees = Vector3(24.0 + aim_pitch_comp * 0.5, 16.0, -8.0) + l_shoulder
				if is_instance_valid(left_forearm_pivot):
					left_forearm_pivot.rotation_degrees = l_elbow
			elif is_gun and (aiming or gun_trigger_held):
				# 双手持枪瞄准 / 蓄力姿态
				var charge_shake := sin(Time.get_ticks_msec() * 0.04) * get_charge_ratio() * 3.5 if gun_trigger_held else 0.0
				left_arm_pivot.rotation_degrees = Vector3(42.0 + charge_shake, 24.0, -10.0)
				if is_instance_valid(left_forearm_pivot):
					left_forearm_pivot.rotation_degrees = Vector3(24.0, 14.0, 0.0)
			elif current_weapon == "axe" and not is_moving:
				# 战斧双手戒备握持姿态
				var idle_breathe := sin(swim_clock * 0.5) * 3.5
				left_arm_pivot.rotation_degrees = Vector3(26.0 + idle_breathe, 24.0, -10.0) + l_shoulder
				if is_instance_valid(left_forearm_pivot):
					left_forearm_pivot.rotation_degrees = Vector3(22.0, 12.0, 0.0) + l_elbow
			else:
				var l_stroke := sin(swim_clock * 0.5) * lerpf(4.0, 9.5, swim_motion_blend)
				left_arm_pivot.rotation_degrees = Vector3(lerpf(15.0, 6.0, swim_motion_blend) + l_stroke, 8.0, lerpf(-11.0, -7.0, swim_motion_blend)) + l_shoulder
				if is_instance_valid(left_forearm_pivot):
					left_forearm_pivot.rotation_degrees = Vector3(8.0 + sin(swim_clock * 0.5 - 0.6) * 4.0, 4.0, 0.0) + l_elbow

			var r_idle_sway := sin(swim_clock * 0.5 + 0.6) * (6.0 if is_moving else 2.5) * (1.0 - combat_stance_blend)
			var r_base := Vector3(44.0, -12.0, 6.0) if (is_gun and (aiming or gun_trigger_held)) else (
				Vector3(22.0 + r_idle_sway, -12.0, 10.0) if current_weapon == "knife" else (
				Vector3(26.0 + r_idle_sway, -10.0, 12.0) if current_weapon == "axe" else Vector3(26.0, -10.0, 8.0)
			))
			var r_elbow_base := Vector3(14.0, 8.0, 0.0) if (current_weapon == "knife" or current_weapon == "axe") else Vector3.ZERO
			if sprinting and not in_attack and not is_gun:
				r_base += Vector3(-10.0, 12.0, -4.0)
				r_elbow_base += Vector3(12.0, 6.0, 0.0)
			if eq_factor > 0.001:
				r_base += Vector3(-28.0 * eq_factor, -10.0 * eq_factor, 8.0 * eq_factor)
				r_elbow_base += Vector3(-18.0 * eq_factor, 0.0, 0.0)
				r_wrist.x -= 24.0 * eq_factor
			if gun_trigger_held:
				r_base.x += sin(Time.get_ticks_msec() * 0.045) * get_charge_ratio() * 4.0
			right_arm_pivot.rotation_degrees = r_base + Vector3(aim_pitch_comp, 0.0, 0.0) + r_shoulder
			if is_instance_valid(right_forearm_pivot):
				right_forearm_pivot.rotation_degrees = r_elbow_base + r_elbow
			right_wrist_rot = r_wrist
			left_wrist_rot = l_wrist

		if is_instance_valid(right_hand_socket):
			var forearm_align_r := Basis.from_euler(Vector3(deg_to_rad(-20.8), deg_to_rad(2.7), 0.0))
			var wrist_roll_r := Basis(Vector3.BACK, deg_to_rad(right_wrist_rot.z))
			var wrist_flex_r := Basis.from_euler(Vector3(deg_to_rad(right_wrist_rot.x), deg_to_rad(right_wrist_rot.y), 0.0))
			right_hand_socket.basis = forearm_align_r * wrist_roll_r * wrist_flex_r
		if is_instance_valid(left_hand_socket):
			var forearm_align_l := Basis.from_euler(Vector3(deg_to_rad(-20.8), deg_to_rad(-2.7), 0.0))
			var wrist_roll_l := Basis(Vector3.BACK, deg_to_rad(left_wrist_rot.z))
			var wrist_flex_l := Basis.from_euler(Vector3(deg_to_rad(left_wrist_rot.x), deg_to_rad(left_wrist_rot.y), 0.0))
			left_hand_socket.basis = forearm_align_l * wrist_roll_l * wrist_flex_l

	if is_instance_valid(backpack_thruster_bubbles):
		backpack_thruster_bubbles.emitting = (sprinting or dash_cooldown > 3.8) and not in_submarine_mode
	if reference_model_active:
		_animate_reference_posture(delta, cam_pitch, in_attack)
		ReferenceDiver.sync_skin(diver_model, _reference_drivers)

func _animate_reference_posture(delta: float, cam_pitch: float, in_attack: bool) -> void:
	# New anatomy rests vertically. It must not inherit the static 32/72-degree
	# bends baked into v3's cylindrical upper-arm and forearm meshes.
	if in_attack:
		# Combat choreography already solves the wrist so the knife thrust and
		# its blade direction agree. Idle anatomical alignment must not replace it.
		return
	var is_gun := current_weapon in ["sonic", "marker_gun"]
	var aiming_gun := is_gun and (aiming or gun_trigger_held)
	if not in_attack and combat_stance_blend < 0.05 and not in_mount_mode:
		var vertical_lean := atan2(velocity.y, maxf(Vector2(velocity.x, velocity.z).length(), 1.2)) * 0.26
		var pitch := lerpf(-0.025, -1.30, swim_motion_blend) + cam_pitch * 0.40 + vertical_lean
		body_pivot.rotation.x = pitch
		head_pivot.rotation.x = clampf(cam_pitch * 0.45 + 0.05 + swim_motion_blend * 0.58, -0.55, 0.75)
	if booster_active:
		left_arm_pivot.rotation_degrees = Vector3(65, 10, -6)
		right_arm_pivot.rotation_degrees = Vector3(65, -10, 6)
		left_forearm_pivot.rotation_degrees = Vector3(12, 8, 0)
		right_forearm_pivot.rotation_degrees = Vector3(12, -8, 0)
	elif aiming_gun and not in_attack:
		var aim_pitch := rad_to_deg(cam_pitch - body_pivot.rotation.x) * 0.55
		left_arm_pivot.rotation_degrees = Vector3(72 + aim_pitch, 12, -8)
		right_arm_pivot.rotation_degrees = Vector3(75 + aim_pitch, -8, 6)
		left_forearm_pivot.rotation_degrees = Vector3(12, 12, 0)
		right_forearm_pivot.rotation_degrees = Vector3(8, -7, 0)
	elif not in_attack and combat_stance_blend < 0.05 and not shield_active and current_weapon != "axe":
		var slow := sin(swim_clock * 0.5)
		var stroke := lerpf(1.8, 9.0, swim_motion_blend)
		left_arm_pivot.rotation_degrees = Vector3(3 + slow * stroke, 2, -4)
		right_arm_pivot.rotation_degrees = Vector3(5 - slow * stroke, -2, 4)
		left_forearm_pivot.rotation_degrees = Vector3(5 + sin(swim_clock * 0.5 - 0.5) * stroke * 0.35, 0, 0)
		right_forearm_pivot.rotation_degrees = Vector3(7 - sin(swim_clock * 0.5 - 0.5) * stroke * 0.35, 0, 0)
	for socket: Node3D in [left_hand_socket, right_hand_socket]:
		var wrist := left_wrist_rot if socket == left_hand_socket else right_wrist_rot
		var align := Basis.from_euler(Vector3(-PI * 0.5, 0, 0))
		socket.basis = align * Basis(Vector3.BACK, deg_to_rad(wrist.z)) * Basis.from_euler(Vector3(deg_to_rad(wrist.x), deg_to_rad(wrist.y), 0))

func _sync_melee_weapon_to_hand(active_node: Node3D, weapon_id: String, inertia_rot_deg: Vector3, jitter_offset: Vector3) -> void:
	var hand_in_diver: Transform3D = diver_model.transform * body_pivot.transform * right_arm_pivot.transform * right_forearm_pivot.transform * right_hand_socket.transform
	var mount_in_diver: Transform3D = equipment_rig.transform * weapon_mount.transform
	var hand_in_mount: Transform3D = mount_in_diver.affine_inverse() * hand_in_diver
	var hand_basis: Basis = hand_in_mount.basis.orthonormalized()

	var inertia_basis := Basis.from_euler(Vector3(
		deg_to_rad(clampf(inertia_rot_deg.x, -8.0, 8.0)),
		deg_to_rad(clampf(inertia_rot_deg.y, -8.0, 8.0)),
		deg_to_rad(clampf(inertia_rot_deg.z, -8.0, 8.0))
	))

	var weapon_scale := 1.02 if weapon_id == "knife" else 1.08
	var grip_basis_in_hand: Basis
	var local_grip_center: Vector3
	if weapon_id == "knife":
		# weapon_knife.glb: 刀尖在 +Z，橡胶刀柄中心在 -Z (-0.085)，锋刃在 -Y，刀背与护手在 +Y
		# 绕 Y 轴旋转 180° 使刀尖朝向手部前方 (-Z)，再按正握军刀倾角 melee_grip_pitch 向上抬起刀尖，使刀刃朝前下方切入
		grip_basis_in_hand = inertia_basis * Basis(Vector3.RIGHT, deg_to_rad(melee_grip_pitch)) * Basis(Vector3.UP, PI)
		local_grip_center = Vector3(0.0, 0.0, -0.085)
	else:
		# weapon_axe.glb: 斧头在 -Z，握把凹槽中心在 +Z (+0.14)，发光新月斧刃在 +Y
		# 绕 Z 轴翻转 180° 使斧刃朝向手部挥砍方向 (-Y)，再按握斧倾角向上抬起斧柄
		grip_basis_in_hand = inertia_basis * Basis(Vector3.RIGHT, deg_to_rad(melee_grip_pitch)) * Basis(Vector3.BACK, PI)
		local_grip_center = Vector3(0.0, 0.0, 0.14)

	var final_basis: Basis = (hand_basis * grip_basis_in_hand).scaled(Vector3.ONE * weapon_scale)
	var final_origin: Vector3 = hand_in_mount.origin - (final_basis * local_grip_center) + jitter_offset
	active_node.transform = Transform3D(final_basis, final_origin)

func _sync_reference_gun_to_hand(active_node: Node3D, weapon_id: String, inertia_rot_deg: Vector3, jitter_offset: Vector3) -> void:
	var hand_in_diver := diver_model.transform * body_pivot.transform * right_arm_pivot.transform * right_forearm_pivot.transform * right_hand_socket.transform
	var mount_in_diver := equipment_rig.transform * weapon_mount.transform
	var hand_in_mount := mount_in_diver.affine_inverse() * hand_in_diver
	var inertia := Basis.from_euler(Vector3(deg_to_rad(clampf(inertia_rot_deg.x, -5, 5)), deg_to_rad(clampf(inertia_rot_deg.y, -5, 5)), 0))
	var grip := Vector3(0, -0.10, 0.16) if weapon_id == "sonic" else Vector3(0, -0.08, 0.06)
	var final_basis := (hand_in_mount.basis.orthonormalized() * inertia).scaled(Vector3.ONE * 1.02)
	active_node.transform = Transform3D(final_basis, hand_in_mount.origin - final_basis * grip + jitter_offset)

func _sync_shield_to_left_arm() -> void:
	var l_hand_in_diver: Transform3D = diver_model.transform * body_pivot.transform * left_arm_pivot.transform * left_forearm_pivot.transform * left_hand_socket.transform
	var s_mount_in_diver: Transform3D = equipment_rig.transform * shield_mount.transform
	var l_hand_in_mount: Transform3D = s_mount_in_diver.affine_inverse() * l_hand_in_diver
	var l_basis: Basis = l_hand_in_mount.basis.orthonormalized()
	var shield_grip_basis := Basis.from_euler(Vector3(deg_to_rad(10.0), deg_to_rad(28.0), deg_to_rad(-18.0)))
	var final_s_basis := l_basis * shield_grip_basis
	var final_s_origin := l_hand_in_mount.origin + (l_basis * Vector3(-0.02, 0.02, 0.05))
	shield_node.transform = Transform3D(final_s_basis, final_s_origin)

func _build_marker_gun(root: Node3D) -> void:
	var body := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.045, 0.065, 0.26)
	body.mesh = b_box
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.12, 0.14, 0.18)
	mat_body.metallic = 0.85
	mat_body.roughness = 0.35
	body.material_override = mat_body
	root.add_child(body)

	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.016
	cyl.height = 0.12
	barrel.mesh = cyl
	barrel.position = Vector3(0, 0.01, -0.18)
	barrel.rotation.x = PI * 0.5
	var mat_barrel := StandardMaterial3D.new()
	mat_barrel.albedo_color = Color(0.42, 0.45, 0.5)
	mat_barrel.metallic = 0.95
	mat_barrel.roughness = 0.2
	barrel.material_override = mat_barrel
	root.add_child(barrel)

	var lens := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 0.011
	l_cyl.bottom_radius = 0.011
	l_cyl.height = 0.02
	lens.mesh = l_cyl
	lens.position = Vector3(0, 0.01, -0.25)
	lens.rotation.x = PI * 0.5
	var mat_lens := StandardMaterial3D.new()
	mat_lens.albedo_color = Color(1.0, 0.1, 0.1)
	mat_lens.emission_enabled = true
	mat_lens.emission = Color(1.0, 0.1, 0.1)
	mat_lens.emission_energy_multiplier = 4.0
	lens.material_override = mat_lens
	root.add_child(lens)

	var grip := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(0.038, 0.12, 0.05)
	grip.mesh = g_box
	grip.position = Vector3(0, -0.07, 0.04)
	grip.rotation.x = -0.35
	grip.material_override = mat_body
	root.add_child(grip)

	marker_muzzle = Marker3D.new()
	marker_muzzle.position = Vector3(0, 0.01, -0.27)
	root.add_child(marker_muzzle)

func toggle_shield() -> bool:
	shield_active = not shield_active
	if is_instance_valid(shield_node):
		shield_node.visible = shield_active
	return shield_active

func _build_shield_viewmodel() -> void:
	shield_node = Node3D.new()
	shield_node.name = "OneHandedEnergyShield"
	shield_node.position = Vector3(-0.25, -0.16, -0.38)
	shield_node.rotation_degrees = Vector3(8.0, 16.0, -12.0)
	shield_mount.add_child(shield_node)

	# 1. 左臂高科技护臂投影基座
	var vambrace := MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.08, 0.07, 0.22)
	vambrace.mesh = v_box
	var mat_arm := StandardMaterial3D.new()
	mat_arm.albedo_color = Color(0.12, 0.16, 0.20)
	mat_arm.metallic = 0.85
	mat_arm.roughness = 0.35
	vambrace.material_override = mat_arm
	shield_node.add_child(vambrace)

	# 2. 发光护盾发射线圈
	for side in [-1.0, 1.0]:
		var coil := MeshInstance3D.new()
		var c_cyl := CylinderMesh.new()
		c_cyl.top_radius = 0.015
		c_cyl.bottom_radius = 0.015
		c_cyl.height = 0.18
		coil.mesh = c_cyl
		coil.position = Vector3(side * 0.045, 0.02, 0)
		coil.rotation.x = PI * 0.5
		var mat_coil := StandardMaterial3D.new()
		mat_coil.albedo_color = Color(0.1, 0.85, 1.0)
		mat_coil.emission_enabled = true
		mat_coil.emission = Color(0.1, 0.85, 1.0)
		mat_coil.emission_energy_multiplier = 3.5
		coil.material_override = mat_coil
		shield_node.add_child(coil)

	# 3. 半透明六边形全息全向能量屏障 (单手，不影响右手持枪挥砍)
	var barrier := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 0.26
	b_mesh.bottom_radius = 0.26
	b_mesh.height = 0.012
	b_mesh.radial_segments = 6
	barrier.mesh = b_mesh
	barrier.position = Vector3(0.02, 0.04, -0.12)
	barrier.rotation.x = PI * 0.5
	var mat_shield := StandardMaterial3D.new()
	mat_shield.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_shield.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shield.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_shield.albedo_color = Color(0.15, 0.92, 1.0, 0.45)
	mat_shield.disable_fog = true
	barrier.material_override = mat_shield
	shield_node.add_child(barrier)

	# 4. 外圈加固能量环
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.25
	tor.outer_radius = 0.27
	ring.mesh = tor
	ring.position = Vector3(0.02, 0.04, -0.12)
	ring.rotation.x = PI * 0.5
	var mat_ring := StandardMaterial3D.new()
	mat_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_ring.albedo_color = Color(0.2, 1.0, 0.9, 0.85)
	mat_ring.disable_fog = true
	ring.material_override = mat_ring
	shield_node.add_child(ring)

	# 5. 护盾环境微光
	var s_light := OmniLight3D.new()
	s_light.position = Vector3(0.02, 0.06, -0.10)
	s_light.light_color = Color(0.18, 0.95, 1.0)
	s_light.light_energy = 2.4
	s_light.omni_range = 3.5
	shield_node.add_child(s_light)

	shield_node.visible = false

@icon ("icon.svg")
@tool
class_name UniParticles3D extends Node3D

#region GET_SHADERS
var SHADER:
	get:
		return load("%s/UniParticleGradientMap.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_ADD:
	get:
		return load("%s/UniParticleGradientMapAdd.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_SUB:
	get:
		return load("%s/UniParticleGradientMapSub.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_MULT:
	get:
		return load("%s/UniParticleGradientMapMult.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_PREMULT_ALPHA:
	get:
		return load("%s/UniParticleGradientMapMultAlpha.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_NEAREST:
	get:
		return load("%s/shaders_point/UniParticleGradientMapPoint.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_ADD_NEAREST:
	get:
		return load("%s/shaders_point/UniParticleGradientMapAddPoint.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_SUB_NEAREST:
	get:
		return load("%s/shaders_point/UniParticleGradientMapSubPoint.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_MULT_NEAREST:
	get:
		return load("%s/shaders_point/UniParticleGradientMapMultPoint.gdshader" % self.get_script().get_path().get_base_dir())
var SHADER_PREMULT_ALPHA_NEAREST:
	get:
		return load("%s/shaders_point/UniParticleGradientMapMultAlphaPoint.gdshader" % self.get_script().get_path().get_base_dir())
#endif

signal finished_burst

enum BlendMode {
	Mix,
	Add,
	Subtract,
	Multiply,
	PremultipliedAlpha
}

enum SamplingFilter {
	Linear = 0,
	Nearest = 1
}

enum BillboardMode {
	None = 2,
	Standard = 0,
	Vertical = 3,
	Stretched = 1,
	StretchedVertical = 4,
}

enum TextureSheetTiles {
	WHOLE_SHEET,
	SINGLE_ROW
}

enum EmissionShape {
	CONE,
	SPHERE,
	HEMISPHERE,
	BOX,
	CIRCLE,
	EDGE
}

enum EmitFrom {
	BASE,
	VOLUME
}

enum ArcMode {
	RANDOM,
	LOOP,
	PING_PONG,
	BURST_SPREAD
}

class Particle extends RefCounted:
	var functions: Array[Callable] = []
	var dead: bool = false
	var position: Vector3
	var base_velocity: Vector3  # Initial velocity affected by curve
	var gravity_velocity: Vector3  # Accumulated gravity
	var direction: Vector3  # Keep direction for orientation
	var scale: Vector2
	var angle: float
	var hue_offset: float
	var distance: float
	var lifetime: float
	var creation_time: float
	var creation_position: Vector3
	var material: Material
	var index: int
	var last_position: Vector3
	var burst_spot:float
	var tilesheet_starting_tile: int  # For storing the random row when using single row mode

	func kill():
		dead = true

# Runtime instance of a burst
class BurstInstance extends RefCounted:
	var time: float = 0.0
	var min_particles: int = 10
	var max_particles: int = 10
	var min_cycles: int = 1
	var max_cycles: int = 1
	var particle_interval: float = 0.0
	var probability: float = 1.0
	var _remaining_cycles: int = 0
	var _next_cycle_time: float = 0.0
	var _particles_in_burst: int = 0  # Total particles in this burst
	var _current_burst_index: int = 0  # Current particle index in burst

	func initialize() -> void:
		_remaining_cycles = randi_range(min_cycles, max_cycles)
		_next_cycle_time = time
		_reset_burst()

	func _reset_burst() -> void:
		_particles_in_burst = randi_range(min_particles, max_particles)
		_current_burst_index = 0

	func process(current_time: float):
		if _remaining_cycles <= 0:
			return 0

		if current_time < _next_cycle_time:
			return 0

		# Check probability
		if randf() > probability:
			# Failed probability check, skip this cycle
			_remaining_cycles -= 1
			if _remaining_cycles > 0:
				_next_cycle_time += particle_interval
			return 0

		# Emit all particles for this cycle at once
		var to_emit = _particles_in_burst
		var old_current_burst_index = _current_burst_index
		_current_burst_index = to_emit

		# Move to next cycle
		_remaining_cycles -= 1
		if _remaining_cycles > 0:
			_next_cycle_time += particle_interval
			_reset_burst()

		return Vector3i(to_emit, old_current_burst_index, _particles_in_burst)


class UniParticlesRng extends RandomNumberGenerator:
	func percent(percent: float) -> bool:
		return self.randi() % 100 < percent

	func exponential(param: float = 1.0) -> float:
		return ln(1.0 - randf())/(-param)

	func ln(arg: float) -> float:
		return log(arg)/log(exp(1))

#region Exports
@export_group("")
# !@ Main! (duration,start_lifetime_mode,start_lifetime_constant,start_lifetime_random,start_lifetime_curve,start_speed_mode,start_speed_constant,start_speed_random,gravity,start_size_mode,start_size_constant,start_size_random,start_size_curve,start_rotation_degrees_mode,start_rotation_degrees_constant,start_rotation_degrees_random,start_rotation_degrees_curve,use_world_space,start_size_squarerandom)
@export var enable_main_module: Vector2i = Vector2i.ONE

## Duration of the particle system in seconds (0 = infinite)
@export var duration: float = 1.0:
	set(value):
		duration = value
		_core_params_dirty = true

var start_lifetime: float:
	get:
		match start_lifetime_mode:
			0: return start_lifetime_constant
			1: return lerp(start_lifetime_random.x,start_lifetime_random.y,randf())
			_: return start_lifetime_curve.sample_baked(randf()) if start_lifetime_curve != null else start_lifetime_constant
## Initial lifetime of particles in seconds
# @@ Starting Lifetime (start_lifetime_constant,start_lifetime_random,start_lifetime_curve)
@export var start_lifetime_mode: int = 0  # 0=constant, 1=random, 2=curve
@export var start_lifetime_constant: float = 1.0
@export var start_lifetime_random: Vector2 = Vector2(0.5, 1.0)
@export var start_lifetime_curve: Curve = null

var start_speed: float:
	get:
		match start_speed_mode:
			0: return start_speed_constant
			1: return lerp(start_speed_random.x, start_speed_random.y, randf())
			_: return start_speed_constant

## Initial speed of particles when emitted
# @@ Starting Speed (start_speed_constant,start_speed_random)
@export var start_speed_mode: int = 0  # 0=constant, 1=random
@export var start_speed_constant: float = 5.0:
	set(value):
		start_speed_constant = value
		_core_params_dirty = true
@export var start_speed_random: Vector2 = Vector2(1.0, 5.0):
	set(value):
		start_speed_random = value
		_core_params_dirty = true

## Gravity force applied to particles
@export var gravity: Vector3 = Vector3.ZERO:
	set(value):
		gravity = value
		_core_params_dirty = true

var start_size: Vector2:
	get:
		match start_size_mode:
			0:
				return start_size_constant
			1:
				if (start_size_random.x == start_size_random.y and start_size_random.z == start_size_random.w):
					return Vector2.ONE * randf_range(start_size_random.x,start_size_random.z)
				return Vector2(lerp(start_size_random.x,start_size_random.z,randf()), lerp(start_size_random.y, start_size_random.w, randf()))
			3:
				return Vector2.ONE * randf_range(start_size_squarerandom.x,start_size_squarerandom.y)
			_:
				return (Vector2.ONE * start_size_curve.evaluate(randf())) if start_size_curve != null else start_size_constant
## Initial size of particles when emitted
# @@ Starting Size (start_size_constant,start_size_random,start_size_curve,start_size_squarerandom)
@export var start_size_mode: int = 0  # 0=constant, 1=random, 2=curve, 3=squarerandom
@export var start_size_constant: Vector2 = Vector2(0.15,0.15)
@export var start_size_random: Vector4 = Vector4(0.5, 0.5, 1.5, 1.5)
@export var start_size_curve: Curve = null
@export var start_size_squarerandom: Vector2 = Vector2(0.15,0.3)

var start_rotation_degrees: float:
	get:
		match start_rotation_degrees_mode:
			0:
				return start_rotation_degrees_constant
			1:
				return lerp(start_rotation_degrees_random.x,start_rotation_degrees_random.y,randf())
			_:
				return start_rotation_degrees_curve.evaluate(randf()) if start_rotation_degrees_curve != null else start_rotation_degrees_constant
## Initial rotation of particles in degrees
# @@ Start Rotation (start_rotation_degrees_constant,start_rotation_degrees_random,start_rotation_degrees_curve)
@export var start_rotation_degrees_mode: int = 0  # 0=constant, 1=random, 2=curve
@export_range(-180, 180) var start_rotation_degrees_constant: float = 0.0
@export var start_rotation_degrees_random: Vector2 = Vector2(0.0, 90.0)
@export var start_rotation_degrees_curve: Curve = null

## Use global position for particles (won't follow node movement)
@export var use_world_space: bool = false:
	set(value):
		use_world_space = value
		_core_params_dirty = true

# !@ Play Behavior! (play_on_start,loop,play_in_reverse,start_delay,start_delay_percentage,destroy_on_finish,debugging)
@export var enable_play_behavior: Vector2i = Vector2i.ZERO

## Start particle burst automatically when node enters scene
@export var play_on_start: bool = true
## Start a new burst when the current one finishes
@export var loop: bool = true
## Play particle animation in reverse
@export var play_in_reverse: bool = false
## Delay before the particle system starts emitting
@export var start_delay: float = 0.0
# @only_show_if(has_start_delay)
## Start particles partway through their lifetime
@export_range(0.0, 1.0) var start_delay_percentage: float = 0.0
var has_start_delay:bool:
	get: return start_delay>0.001
## Free this node after the burst completes
@export var destroy_on_finish: bool = false
## Enable debug logging
@export var debugging: bool = false

# !@ Emission Module (max_particles,max_emissions_per_frame,emission_type,rate_over_time,rate_over_distance,bursts)
@export var enable_emission: Vector2i = Vector2i(1, 0)
var emission_visible:bool:
	get: return enable_emission.y == 1

## Enable/disable particle emission
var emitting: bool:
	get: return enable_emission.x == 1
	set(value):
		enable_emission.x = 1 if value else 0
		_core_params_dirty = true

## Maximum number of particles that can exist simultaneously
@export var max_particles: int = 400:
	set(value):
		max_particles = value
		_core_params_dirty = true
## Maximum number of particles that can be emitted in a single frame
@export var max_emissions_per_frame: int = 100:
	set(value):
		max_emissions_per_frame = value if value is int else 100
		_core_params_dirty = true
## Rate of particle emission per second (for Time)
@export var rate_over_time: float = 10.0:
	set(value):
		rate_over_time = value
		_core_params_dirty = true
## Rate of particle emission per meter (for Distance)
@export var rate_over_distance: float = 10.0:
	set(value):
		rate_over_distance = value
		_core_params_dirty = true
## Array of burst configurations
@export var bursts: Array = []

# !@ Shape Module (shape_type,radius,angle,position_offset,direction_in_world_space,rotation_offset,box_extents,arc_degrees,arc_speed_mode,arc_mode,arc_spread,arc_speed_constant,arc_speed_curve,radius_thickness,shape_length,emit_from,random_direction,spherize_direction,invert_direction)
@export var enable_shape: Vector2i = Vector2i.ZERO:
	set(value):
		enable_shape = value
		_core_params_dirty = true

var is_type_billboard_stretched:bool:
	get:
		return billboard_mode == BillboardMode.Stretched or billboard_mode == BillboardMode.StretchedVertical

var is_type_cone:bool:
	get:
		return shape_type == EmissionShape.CONE
var is_type_arc:bool:
	get:
		return shape_type == EmissionShape.CONE or shape_type == EmissionShape.SPHERE or shape_type == EmissionShape.CIRCLE or shape_type == EmissionShape.HEMISPHERE
var is_type_arc_not_random_arc:bool:
	get:
		return is_type_arc and arc_mode != ArcMode.RANDOM
var should_show_shape_length:bool:
	get:
		return (emit_from == EmitFrom.VOLUME and is_type_cone) or shape_type == EmissionShape.EDGE
var is_type_sphere:bool:
	get:
		return shape_type == EmissionShape.SPHERE or shape_type == EmissionShape.HEMISPHERE
var is_type_box:bool:
	get:
		return shape_type == EmissionShape.BOX
var is_type_box_or_edge:bool:
	get:
		return shape_type == EmissionShape.BOX or shape_type == EmissionShape.EDGE



## Type of emission shape
@export var shape_type: EmissionShape = EmissionShape.CONE:
	get:
		return shape_type if enable_shape.x == 1 else EmissionShape.CONE
	set(value):
		shape_type = value
		_core_params_dirty = true

# @only_hide_if(is_type_box_or_edge)
## Initial spawn radius from center (used by Cone, Sphere, Circle, Ring)
@export var radius: float = 0.0:
	set(value):
		radius = value
		_core_params_dirty = true

# @only_hide_if(is_type_box_or_edge)
## The radius thickness (0 = surface only, 1 = full volume)
@export_range(0.0, 1.0) var radius_thickness: float = 1.0:
	set(v):
		radius_thickness = v
		_core_params_dirty = true

# @only_show_if(is_type_cone)
## Angular spread of particle directions (in degrees)
@export_range(0, 90,0.1) var angle: float = 0.0:
	set(value):
		angle = value
		_core_params_dirty = true
		## Base cone angle that tilts particles outward (Cone: 0-180)

## Box dimensions (only for Box shape)
# @only_show_if(is_type_box)
@export var box_extents: Vector3 = Vector3(1, 1, 1):
	set(v):
		box_extents = v
		_core_params_dirty = true

## How much to randomize the particle direction (0 = shape-based only, 1 = fully random)
@export_range(0.0, 1.0) var random_direction: float = 0.0:
	set(value):
		random_direction = value
		_core_params_dirty = true

## How much to spheerize the particle direction (0 = leave the direction as is, 1 = functions the same as direction does in shape mode sphere)
# @only_hide_if(is_type_sphere)
@export_range(0.0, 1.0) var spherize_direction: float = 0.0:
	set(value):
		spherize_direction = value
		_core_params_dirty = true

# Cone specific properties
## How to emit particles from the cone
# @only_show_if(is_type_cone)
@export var emit_from: EmitFrom = EmitFrom.BASE:
	get:
		return emit_from if is_type_cone else EmitFrom.VOLUME
	set(v):
		emit_from = v
		_core_params_dirty = true

## The length of the shape (only used when emitting from volume)
# @only_show_if(should_show_shape_length)
@export var shape_length: float = 1.0:
	get:
		return shape_length if should_show_shape_length else 1.0
	set(v):
		shape_length = v
		_core_params_dirty = true


## The angular portion of the circle to emit from (in degrees)
# @only_show_if(is_type_arc)
@export_range(0.0, 360.0, 0.1) var arc_degrees: float = 360.0:
	set(v):
		arc_degrees = v
		_core_params_dirty = true

## How particles are distributed around the arc
# @only_show_if(is_type_arc)
@export var arc_mode: ArcMode = ArcMode.RANDOM:
	set(v):
		arc_mode = v
		_core_params_dirty = true

## Discrete intervals for particle spawning (0 = continuous)
# @only_show_if(is_type_arc_not_random_arc)
@export_range(0.0, 1.0) var arc_spread: float = 0.0:
	set(v):
		arc_spread = v
		_core_params_dirty = true

## Speed of emission position around arc
# @only_show_if(is_type_arc_not_random_arc)
# @@ Arc Speed (arc_speed_constant,arc_speed_curve)
@export var arc_speed_mode: int = 0
## Speed of emission position around arc
# @only_show_if(is_type_arc_not_random_arc)
@export var arc_speed_constant: float = 1.0:
	set(v):
		arc_speed_constant = v
		_core_params_dirty = true
## Curve controlling arc speed over time
# @only_show_if(is_type_arc_not_random_arc)
@export var arc_speed_curve: Curve:
	set(v):
		arc_speed_curve = v
		_core_params_dirty = true


## Use velocity in world space for particles
@export var direction_in_world_space: bool = false:
	set(value):
		direction_in_world_space = value
		_core_params_dirty = true
## Invert resulting direction
@export var invert_direction: bool = false:
	set(value):
		invert_direction = value
		_core_params_dirty = true

## Position offset applied to particles
@export var position_offset: Vector3:
	set(value):
		position_offset = value
		_core_params_dirty = true

## Rotation offset applied to the shape direction (in degrees)
@export var rotation_offset: Vector3:
	set(value):
		rotation_offset = value
		_core_params_dirty = true

# !@ Size Over Lifetime (size_over_lifetime,width_over_lifetime,height_over_lifetime)
@export var enable_size_over_lifetime: Vector2i = Vector2i.ZERO

## Animate overall size over particle lifetime
@export var size_over_lifetime: Curve
## Animate horizontal size over particle lifetime
@export var width_over_lifetime: Curve
## Animate vertical size over particle lifetime
@export var height_over_lifetime: Curve

# !@ Velocity Over Lifetime (velocity_over_lifetime,velocity_in_world_space,offset_over_lifetime)
@export var enable_velocity_over_lifetime: Vector2i = Vector2i.ZERO

## Velocity curve over lifetime (multiplies base velocity)
@export var velocity_over_lifetime: Curve
## Animate position offset over particle lifetime
var offset_over_lifetime: Curve
## Velocity space (local or world)
@export var velocity_in_world_space: bool = false

# !@ Rotation Over Lifetime (rotation_over_lifetime,orbit_over_lifetime,orbit_around_axis)
@export var enable_rotation_over_lifetime: Vector2i = Vector2i.ZERO
## Animate rotation angle over particle lifetime
@export var rotation_over_lifetime: Curve
## Animate velocity rotation over particle lifetime
@export var orbit_over_lifetime: Curve
@export var orbit_around_axis:Vector3 = Vector3.UP

# !@ Color Over Lifetime (color_over_lifetime,starting_hue,hue_variation)
@export var enable_color_over_lifetime: Vector2i = Vector2i.ZERO
var has_color_over_lifetime:bool:
	get:
		return enable_color_over_lifetime.x == 1
## Gradient texture for coloring particles
@export var color_over_lifetime: GradientTexture1D:
	set(value):
		color_over_lifetime = value
		_material_dirty = true
## Random hue variation
@export_range(0.0, 1.0) var starting_hue: float = 0.0
## Random hue variation
@export_range(0.0, 1.0) var hue_variation: float = 0.0

# !@ Texture Sheet Animation (h_frames,v_frames,tiles_mode,use_random_starting_tile,start_index_tile,animation_cycles,frame_over_time)
## Enable texture sheet animation
@export var enable_texture_sheet: Vector2i = Vector2i.ZERO:
	set(v):
		enable_texture_sheet = v
		_core_params_dirty = true

var texture_sheet_enabled: bool:
	get:
		return enable_texture_sheet.x == 1
## Number of horizontal frames in the texture sheet
@export var h_frames: int = 1:
	set(value):
		h_frames = value
		_update_shader_parameters()
## Number of vertical frames in the texture sheet
@export var v_frames: int = 1:
	set(value):
		v_frames = value
		_update_shader_parameters()
## How to tile the texture sheet
@export var tiles_mode: TextureSheetTiles = TextureSheetTiles.WHOLE_SHEET:
	set(value):
		tiles_mode = value
		_update_shader_parameters()
## For single row mode, whether to use a random row
@export var use_random_starting_tile: bool = true:
	set(value):
		use_random_starting_tile = value
		_update_shader_parameters()
## For single row mode with random_row disabled, which row to use
@export_range(0, 127) var start_index_tile: int = 0:
	set(value):
		start_index_tile = value
		_update_shader_parameters()
## Animation speed multiplier
@export var animation_cycles: float = 1.0:
	set(value):
		animation_cycles = value
		_update_shader_parameters()
## Curve controlling frame progression over particle lifetime
@export var frame_over_time: Curve

# !@ Rendering! (particle_texture,tint_color,billboard_mode,velocity_stretch,length_stretch,align_to_velocity,blend_mode,override_material,custom_mesh,render_priority,sampling_filter,rendering_layer)
@export var enable_rendering: Vector2i = Vector2i.ZERO

## Texture to use for each particle
@export var particle_texture: Texture2D:
	set(value):
		particle_texture = value
		_material_dirty = true
@export var tint_color:Color = Color.WHITE:
	set(value):
		tint_color = value
		_update_shader_parameters()
## Billboard rendering mode
@export var billboard_mode: BillboardMode = BillboardMode.Standard:
	set(value):
		billboard_mode = value
		_update_shader_parameters()
## How much to stretch based on velocity (0 = no stretch)
# @only_show_if(is_type_billboard_stretched)
@export_range(-10.0, 10.0) var velocity_stretch: float = 0.0
## How much to stretch based on length/direction (0 = no stretch)
# @only_show_if(is_type_billboard_stretched)
@export_range(-10.0, 10.0) var length_stretch: float = 0.0
@export var align_to_velocity:bool = false:
	set(value):
		align_to_velocity = value
		_update_shader_parameters()
## How particles blend with the background
@export var blend_mode: BlendMode = BlendMode.Mix:
	set(value):
		blend_mode = value
		_material_dirty = true
## Render order priority number.
@export var render_priority: int = 0:
	set(value):
		render_priority = value if value is int else 0
		_material_dirty = true
## Render sampling filter.
@export var sampling_filter: SamplingFilter = SamplingFilter.Linear:
	set(value):
		sampling_filter = value if value is SamplingFilter else SamplingFilter.Linear
		_material_dirty = true

@export_flags_3d_render var rendering_layer:int = 1:
	set(value):
		rendering_layer = value if value is int else 1
		_core_params_dirty = true

## Use override material
@export var override_material: Material = null:
	set(value):
		override_material = value
		_material_dirty = true
## Custom mesh to use for particles (if null, uses default quad)
@export var custom_mesh: Mesh = null:
	set(value):
		custom_mesh = value
		_core_params_dirty = true

# Track arc rotation for non-random modes
var _current_arc_rotation: float = 0.0
var _arc_direction: int = 1  # Used for ping-pong mode



#endregion
# Static cache for shared resources
static var _shared_quad_mesh: RID = RID()
static var _mesh_arrays = null  # Keep mesh data reference
var _multimesh: RID = RID()
var _instance: RID = RID()
var shared_material: bool = true
# Instance-specific material
var _particles: Array[Particle] = []
var _shared_material: Material
var _material_dirty: bool = false
var _rng: UniParticlesRng
var _active: bool = false
var _time: float = 0.0
var _buffer: PackedFloat32Array
var _visible_count: int = 0
var _emission_accumulator: Vector2 = Vector2.ZERO
var _last_position: Vector3
var _active_bursts: Array[BurstInstance] = []
var _playing: bool = false
var _emission_time: float = 0.0
var _core_params_dirty: bool = false:
	set(v):
		if not done_ready:
			return
		if Engine.is_editor_hint():
			update_gizmos()
		if _core_params_dirty != v:
			_core_params_dirty = v
var _add_new_burst_definition:bool = false
var _last_transform: Transform3D
var playback_speed: float = 1.0
var paused: bool = false

var simulation_time: float:
	get:
		return _emission_time if _emission_time >= 0 else 0.0

var _child_particles: Array[UniParticles3D] = []
var _child_particles_cached: bool = false

func create_burst_instance(index: int) -> BurstInstance:
	var base_idx = index * 9
	var instance = BurstInstance.new()

	if base_idx + 8 < bursts.size():
		instance.time = float(bursts[base_idx])
		var count_mode = int(bursts[base_idx + 1])
		instance.min_particles = int(bursts[base_idx + 2])
		instance.max_particles = int(bursts[base_idx + 3]) if count_mode == 1 else instance.min_particles

		var cycle_mode = int(bursts[base_idx + 4])
		instance.min_cycles = int(bursts[base_idx + 5])
		instance.max_cycles = int(bursts[base_idx + 6]) if cycle_mode == 1 else instance.min_cycles

		instance.particle_interval = float(bursts[base_idx + 7])
		instance.probability = float(bursts[base_idx + 8])
	else:
		# Default values if array access would be invalid
		instance.time = 0.0
		instance.min_particles = 10
		instance.max_particles = 10
		instance.min_cycles = 1
		instance.max_cycles = 1
		instance.particle_interval = 0.0
		instance.probability = 1.0

	return instance

var done_ready:bool = false
func _ready() -> void:
	if debugging: print("UniParticles3D ready, editor: ", Engine.is_editor_hint())
	_rng = UniParticlesRng.new()
	if play_on_start and not Engine.is_editor_hint():
		if debugging: print("Autostarting burst")
		play()
	done_ready = true

func _create_material() -> Material:
	# If override material is set, use it directly
	if override_material:
		if debugging: print("Using override material")
		return override_material

	# Otherwise create shader material with blend modes
	var material = ShaderMaterial.new()

	# Select shader based on blend mode
	match blend_mode:
		BlendMode.Mix:
			material.shader = SHADER if sampling_filter == SamplingFilter.Linear else SHADER_NEAREST
		BlendMode.Add:
			material.shader = SHADER_ADD if sampling_filter == SamplingFilter.Linear else SHADER_ADD_NEAREST
		BlendMode.Subtract:
			material.shader = SHADER_SUB if sampling_filter == SamplingFilter.Linear else SHADER_SUB_NEAREST
		BlendMode.Multiply:
			material.shader = SHADER_MULT if sampling_filter == SamplingFilter.Linear else SHADER_MULT_NEAREST
		BlendMode.PremultipliedAlpha:
			material.shader = SHADER_PREMULT_ALPHA if sampling_filter == SamplingFilter.Linear else SHADER_PREMULT_ALPHA_NEAREST

	if render_priority is int:
		material.render_priority = render_priority
	if particle_texture:
		if debugging: print("Setting albedo texture: ", particle_texture)
		material.set_shader_parameter("albedo_texture", particle_texture)
	else:
		if debugging: print("No albedo texture set")

	if has_color_over_lifetime and color_over_lifetime:
		if debugging: print("Setting gradient texture: ", color_over_lifetime)
		material.set_shader_parameter("gradient_texture", color_over_lifetime)
	else:
		if debugging: print("No gradient texture set")
	
	_update_material_shader_parameters(material)

	return material

func _create_shared_quad_mesh() -> RID:
	# If we have a custom mesh, just return its RID directly
	if custom_mesh != null:
		if debugging: print("Using custom mesh")
		return custom_mesh.get_rid()

	# Don't recreate if already exists
	if _shared_quad_mesh != RID() and _shared_quad_mesh.is_valid():
		return _shared_quad_mesh

	# Otherwise create default quad mesh
	_shared_quad_mesh = RenderingServer.mesh_create()

	if _mesh_arrays == null:
		_mesh_arrays = []
		_mesh_arrays.resize(RenderingServer.ARRAY_MAX)

		# Define quad vertices
		var vertices = PackedVector3Array([
			Vector3(-0.5, -0.5, 0),
			Vector3(0.5, -0.5, 0),
			Vector3(0.5, 0.5, 0),
			Vector3(-0.5, 0.5, 0)
		])
		_mesh_arrays[RenderingServer.ARRAY_VERTEX] = vertices

		# Define UVs
		var uvs = PackedVector2Array([
			Vector2(0, 1),
			Vector2(1, 1),
			Vector2(1, 0),
			Vector2(0, 0)
		])
		_mesh_arrays[RenderingServer.ARRAY_TEX_UV] = uvs

		# Define indices for triangles
		var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_mesh_arrays[RenderingServer.ARRAY_INDEX] = indices

	RenderingServer.mesh_add_surface_from_arrays(_shared_quad_mesh, RenderingServer.PRIMITIVE_TRIANGLES, _mesh_arrays)

	if debugging: print("Created shared mesh: ", _shared_quad_mesh)
	return _shared_quad_mesh

func _create_multimesh() -> void:
	# Cleanup existing multimesh if any
	if _multimesh != RID():
		if _instance != RID():
			RenderingServer.free_rid(_instance)
			_instance = RID()
		RenderingServer.free_rid(_multimesh)
		_multimesh = RID()

	if debugging: print("Creating new multimesh with max_particles: ", max_particles)
	_multimesh = RenderingServer.multimesh_create()
	var mesh = _create_shared_quad_mesh()

	# Create buffer for all particle data
	_buffer = PackedFloat32Array()
	_buffer.resize(max_particles * 20)  # 20 floats per particle

	# Create instance in scene
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _multimesh)

	# Make sure we have a valid scenario
	var scenario = get_world_3d().scenario
	if scenario.is_valid():
		RenderingServer.instance_set_scenario(_instance, scenario)
		if debugging: print("Set scenario: ", scenario)
	else:
		push_error("Invalid scenario")

	# Set visibility and initial transform
	RenderingServer.instance_set_visible(_instance, true)
	if use_world_space:
		RenderingServer.instance_set_transform(_instance, Transform3D())
	else:
		RenderingServer.instance_set_transform(_instance, transform)
	_last_transform = global_transform

	RenderingServer.multimesh_set_mesh(_multimesh, mesh)

	# Allocate with transform, color and custom data
	RenderingServer.multimesh_allocate_data(_multimesh, max_particles,
		RenderingServer.MULTIMESH_TRANSFORM_3D,
		true,  # Enable color data
		true)  # Use custom data for scale/rotation

	if debugging: print("Created multimesh: ", _multimesh, " with instance: ", _instance)

	# Set initial material
	if shared_material:
		_shared_material = _create_material()
		RenderingServer.instance_geometry_set_material_override(_instance, _shared_material)
	
	# Set initial shader parameters
	_update_shader_parameters()
	
	RenderingServer.instance_set_layer_mask(_instance, rendering_layer)
	
	# Kill any particles that exceed the new max_particles
	while _particles.size() > max_particles:
		_particles.pop_back().kill()

func _create_particle() -> Particle:
	var particle = Particle.new()

	# Assign next available index
	particle.index = _particles.size()

	# Set up material
	if shared_material:
		if not _shared_material:
			_shared_material = _create_material()
		particle.material = _shared_material
	else:
		particle.material = _create_material()

	return particle

func _update_particle(t: float, particle: Particle) -> void:
	if particle.dead or _multimesh == RID():
		return

	# Calculate local transform
	var xform = Transform3D()

	# Apply all transform updates
	for update_func in particle.functions:
		xform = update_func.call(t, particle, xform)

	# Calculate forward direction based on movement
	var forward = particle.direction
	var velocity_combined:Vector3 = (particle.base_velocity + particle.gravity_velocity)
	if (((billboard_mode == BillboardMode.Stretched or (billboard_mode == BillboardMode.StretchedVertical)) and abs(velocity_stretch) > 0.001) or align_to_velocity) and velocity_combined.length() > 0.001:
		# Always work in local space for consistent billboard orientation
		var local_velocity = velocity_combined
		# if use_world_space:
			# Transform world space velocity to local space for consistent stretching
		local_velocity = global_transform.basis.inverse() * velocity_combined
		forward = local_velocity.normalized()

	# Create rotation basis to face direction
	var up = Vector3.UP
	if abs(forward.dot(Vector3.UP)) > 0.99:
		up = Vector3.BACK
	var right = up.cross(forward).normalized()
	up = forward.cross(right).normalized()

	# Create the basis
	xform.basis = Basis(right, up, forward)

	if override_material != null:
		var use_scale:Vector2 = particle.scale
		if width_over_lifetime:
			use_scale.x = particle.scale.x * width_over_lifetime.sample(t)
		else:
			use_scale.x = particle.scale.x  # scale x
		if height_over_lifetime:
			use_scale.y = particle.scale.y * height_over_lifetime.sample(t)
		else:
			use_scale.y = particle.scale.y  # scale y
		xform.basis = xform.basis.scaled(Vector3(use_scale.x, use_scale.y, use_scale.x))

	# If in world space, we need to transform the basis back to world space
	if use_world_space:
		xform.basis = global_transform.basis * xform.basis

	# Handle global vs local positioning
	if use_world_space:
		# Start with the creation position
		xform.origin += particle.creation_position

	# Calculate buffer index for this particle
	var idx = particle.index * 20

	if _buffer.size() < idx or _buffer.size() < idx + 19:
		return
	# Set transform (12 floats)
	_buffer[idx + 0] = xform.basis.x.x
	_buffer[idx + 1] = xform.basis.y.x
	_buffer[idx + 2] = xform.basis.z.x
	_buffer[idx + 3] = xform.origin.x
	_buffer[idx + 4] = xform.basis.x.y
	_buffer[idx + 5] = xform.basis.y.y
	_buffer[idx + 6] = xform.basis.z.y
	_buffer[idx + 7] = xform.origin.y
	_buffer[idx + 8] = xform.basis.x.z
	_buffer[idx + 9] = xform.basis.y.z
	_buffer[idx + 10] = xform.basis.z.z
	_buffer[idx + 11] = xform.origin.z

	# Set color (4 floats)
	var hue_offset = particle.hue_offset

	_buffer[idx + 12] = hue_offset  # r
	_buffer[idx + 13] = clamp(t,0.0,1.0)  # g
	_buffer[idx + 14] = 1.0# if billboard_mode == BillboardMode.None else (0.5 if billboard_mode == BillboardMode.Stretched else 1.0)
	#if align_to_velocity:
	#	_buffer[idx + 14] *= -1
	  # b
	_buffer[idx + 15] = 1.0  # a

	# Handle texture sheet animation in alpha channel
	if texture_sheet_enabled:
		var frame_time = t
		if frame_over_time:
			frame_time = frame_over_time.sample(t)

		# Apply animation cycles
		frame_time = frame_time * animation_cycles

		if tiles_mode == TextureSheetTiles.WHOLE_SHEET:
			var total_frames = h_frames * v_frames
			if animation_cycles <= 0.001:
				# When cycles is 0 or negative, just use the starting tile without animation
				_buffer[idx + 15] = float(particle.tilesheet_starting_tile) / float(total_frames)
			else:
				# For animation, normalize time across all frames and add starting offset
				frame_time = fmod(frame_time * total_frames + particle.tilesheet_starting_tile, total_frames)
				_buffer[idx + 15] = frame_time / total_frames
		else: # SINGLE_ROW
			# For single row, normalize time across row and encode row index
			frame_time = fmod(frame_time * h_frames, h_frames)
			_buffer[idx + 15] = frame_time / h_frames + float(particle.tilesheet_starting_tile)
	else:
		_buffer[idx + 15] = -1.0  # Animation disabled

	# Calculate velocity and store last position
	var current_pos = xform.origin
	particle.last_position = current_pos

	# Calculate stretch factors
	var stretch = 1.0

	if billboard_mode == BillboardMode.Stretched or billboard_mode == BillboardMode.StretchedVertical:
		var vel_stretch:float = 0.0
		if abs(velocity_stretch) > 0.001 and velocity_combined.length() > 0.001:
			vel_stretch = (velocity_combined.length() * velocity_stretch)
		stretch = 1.0 + vel_stretch + length_stretch

	# Set custom data (4 floats)
	_buffer[idx + 16] = particle.angle if enable_rotation_over_lifetime.x == 0 or rotation_over_lifetime == null else particle.angle + rotation_over_lifetime.sample(t)  # rotation
	if width_over_lifetime:
		_buffer[idx + 17] = particle.scale.x * width_over_lifetime.sample(t)
	else:
		_buffer[idx + 17] = particle.scale.x  # scale x
	if height_over_lifetime:
		_buffer[idx + 18] = particle.scale.y * height_over_lifetime.sample(t)
	else:
		_buffer[idx + 18] = particle.scale.y  # scale y

	if size_over_lifetime:
		var sampled_amount = size_over_lifetime.sample(t)
		_buffer[idx + 17] *= sampled_amount
		_buffer[idx + 18] *= sampled_amount

	_buffer[idx + 19] = stretch  # stretch factor


func _emit_particle(_burst_spot:float = 0.0, has_override_pos:bool = false, override_position:Vector3 = Vector3.ZERO) -> void:
	if not emitting:
		return

	if max_particles <= 0:
		return

	var particle: Particle
	var reusing_particle:bool = false
	if _particles.size() >= max_particles:
		# Find oldest dead particle for reuse
		for p in _particles:
			if p.dead:
				particle = p
				reusing_particle = true
				break

		if not reusing_particle:
			# If we failed at findinga dead particle to reuse, let's try to find the oldest particle to reuse.
			var oldest_time:float = _time + 1.0
			for p in _particles:
				if p.creation_time < oldest_time:
					particle = p
					oldest_time = p.creation_time
					reusing_particle = true

		if reusing_particle:
			particle.dead = true
			# Force update the particle's buffer entry to make it invisible
			var idx = particle.index * 20
			_buffer[idx + 15] = 0.0  # Set alpha to 0
			RenderingServer.multimesh_set_buffer(_multimesh, _buffer)
			# Now initialize the particle
			particle.creation_time = _time
			particle.burst_spot = _burst_spot
			_initialize_particle(particle)
			if has_override_pos and use_world_space:
				particle.creation_position = override_position
			# Finally mark it as alive and update it
			particle.dead = false
			_update_particle(0.0, particle)
			return

	# Create new particle if we haven't reached max yet
	particle = _create_particle()
	particle.creation_time = _time
	particle.burst_spot = _burst_spot
	_initialize_particle(particle)
	if has_override_pos and use_world_space:
		particle.creation_position = override_position
	_update_particle(0.0, particle)
	_particles.append(particle)

func update_instance_transform():
	if use_world_space:
		# In global mode, only use identity transform since particles are in world space
		RenderingServer.instance_set_transform(_instance, Transform3D())
	else:
		# In local mode, use full global transform to account for parent transformations
		RenderingServer.instance_set_transform(_instance, global_transform)
	_last_transform = global_transform

func _process(delta: float) -> void:
	if not _playing or paused:
		return

	# Scale delta by playback speed
	delta *= playback_speed

	# Update instance transform if node has moved
	if global_transform != _last_transform:
		update_instance_transform()

	# Check if we need to recreate multimesh due to parameter changes
	if _core_params_dirty:
		stop()
		if debugging: print("Core parameters changed, recreating multimesh")
		_core_params_dirty = false
		play.call_deferred()

	if _material_dirty and shared_material:
		_update_shared_material()
		_material_dirty = false

	_time += delta
	_emission_time += delta

	# Don't emit during start delay
	if _emission_time < 0:
		return

	var alive_count = 0
	var last_alive_index = 0

	# First pass: count alive particles and find last alive index
	for i in range(_particles.size()):
		var particle = _particles[i]
		if not particle.dead:
			# Scale particle time by playback speed
			var particle_time = (_time - particle.creation_time) / (particle.lifetime / playback_speed)
			if play_in_reverse:
				particle_time = 1.0 - particle_time

			if particle_time < 0.0 or particle_time >= 1.0:
				particle.kill()
				if debugging: print("Particle died at time: ", particle_time)
			else:
				alive_count += 1
				last_alive_index = i

	# Update visible count immediately when particles die
	if _visible_count != alive_count:
		_visible_count = alive_count
		if _multimesh.is_valid():
			RenderingServer.multimesh_set_visible_instances(_multimesh, alive_count)
		else:
			_create_multimesh()
		if debugging: print("Updated visible count to: ", alive_count)

	# Check if we've hit duration and need to loop
	if duration > 0 and _emission_time >= duration:
		if loop:
			if debugging: print("Duration reached, looping emission")
			# Keep fractional part of emission accumulator for smooth transition
			_emission_accumulator.x = fmod(_emission_accumulator.x, 1.0 / rate_over_time)
			_emission_time = -start_delay

			# Reinitialize bursts from definitions
			_active_bursts.clear()
			var def_count = bursts.size() / 9
			for i in def_count:
				var burst_instance = create_burst_instance(i)
				burst_instance.initialize()
				_active_bursts.append(burst_instance)
		else:
			# If not repeating, only finish when all particles are dead
			if alive_count == 0:
				if debugging: print("All particles dead and past duration, finishing")
				_finish()
				return

	# Check if we should be emitting
	var should_emit = duration > 0.01 and _emission_time < duration

	if should_emit:
		# Handle regular emission
		if rate_over_time > 0.0001:
			# Calculate time between particles
			var time_per_particle = 1.0 / rate_over_time if rate_over_time > 0 else INF
			_emission_accumulator.x += delta

			# Add safety check for infinite loop prevention
			var emission_count = 0

			# Emit particles based on accumulated time
			while _emission_accumulator.x >= time_per_particle and emission_count < max_emissions_per_frame:
				_emission_accumulator.x -= time_per_particle
				if debugging: print("Emitting timed particle at ", _emission_time)
				_emit_particle()
				emission_count += 1

			# If we hit the limit, warn about it
			if emission_count >= max_emissions_per_frame:
				push_warning("UniParticles3D: Too many particles requested in one frame. Consider reducing rate_over_time.")
				_emission_accumulator.x = 0  # Reset accumulator to prevent buildup

		if rate_over_distance > 0.001:
			var distance = global_position.distance_to(_last_position)
			_emission_accumulator.y += rate_over_distance * distance
			var particles_to_emit = min(floor(_emission_accumulator.y), max_emissions_per_frame)  # Limit particles per frame
			_emission_accumulator.y -= particles_to_emit

			# Calculate movement vector for interpolation
			var movement_vector = global_position - _last_position

			# Emit particles spread along the movement path
			for i in range(min(particles_to_emit,max_emissions_per_frame)):
				# Calculate interpolation factor (0 to 1) for this particle
				var t = (i as float) / (particles_to_emit as float)
				# Emit particle at interpolated position
				_emit_particle(0.0, true, _last_position + movement_vector * t)

			_last_position = global_position

	# Handle bursts
	for burst in _active_bursts:
		var particles_to_emit = burst.process(_emission_time)
		if particles_to_emit is Vector3i:
			# Emiting multiple at once
			while particles_to_emit.x > 0:
				_emit_particle((particles_to_emit.y as float) / ((particles_to_emit.z - 1) as float))
				particles_to_emit.x -= 1
				particles_to_emit.y += 1


	# Update alive particles
	if alive_count > 0:
		var write_index = 0
		for i in range(last_alive_index + 1):
			var particle = _particles[i]
			if not particle.dead:
				if particle.index != write_index:
					particle.index = write_index
				# Scale particle time by playback speed
				var particle_time = (_time - particle.creation_time) / (particle.lifetime / playback_speed)
				if play_in_reverse:
					particle_time = 1.0 - particle_time
				_update_particle(particle_time, particle)
				write_index += 1

		# Update buffer
		RenderingServer.multimesh_set_buffer(_multimesh, _buffer)

func _finish() -> void:
	_playing = false
	_visible_count = 0
	RenderingServer.multimesh_set_visible_instances(_multimesh, 0)
	set_process(false)
	emit_signal("finished_burst")

	if loop:
		play(false)
	elif destroy_on_finish and not Engine.is_editor_hint():
		queue_free()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			# Ensure particles are stopped in editor before saving
			stop(true)

		NOTIFICATION_PREDELETE, NOTIFICATION_WM_CLOSE_REQUEST:
			# Clean up RenderingServer resources
			if _instance != RID():
				RenderingServer.free_rid(_instance)
				_instance = RID()

			if _multimesh != RID():
				RenderingServer.free_rid(_multimesh)
				_multimesh = RID()

			# Clear particle references
			_particles.clear()
			_active_bursts.clear()

			# Clear shared resources if we're the last one
			if _shared_quad_mesh != RID():
				# Only free in editor to avoid conflicts with other instances
				if Engine.is_editor_hint():
					RenderingServer.free_rid(_shared_quad_mesh)
					_shared_quad_mesh = RID()
					_mesh_arrays = null

			# Free any instance-specific materials
			if not shared_material and _shared_material:
				RenderingServer.free_rid(_shared_material.get_rid())
				_shared_material = null

		NOTIFICATION_CHILD_ORDER_CHANGED:
			# Force recache of child particles on next play
			_child_particles_cached = false

		NOTIFICATION_TRANSFORM_CHANGED:
			if _instance != RID() and not use_world_space:
				update_instance_transform()

func _update_shared_material() -> void:
	if not _playing or not shared_material:
		return

	var new_material = _create_material()
	# Update the material on the multimesh instance
	RenderingServer.instance_geometry_set_material_override(_instance, new_material)
	_shared_material = new_material

func _initialize_particle(particle: Particle) -> void:
	# Store the global position at creation time, but don't include it in initial position calculations
	particle.creation_position = global_position if use_world_space else Vector3.ZERO

	# Initialize lifetime
	particle.lifetime = start_lifetime

	# Initialize random tile if using texture sheet animation
	if texture_sheet_enabled and use_random_starting_tile:
		if tiles_mode == TextureSheetTiles.WHOLE_SHEET:
			particle.tilesheet_starting_tile = randi() % (h_frames * v_frames)
		else:
			particle.tilesheet_starting_tile = randi() % v_frames
	else:
		particle.tilesheet_starting_tile = start_index_tile

	var desired_radius: float = 0.0
	desired_radius = radius * _rng.randf()

	var radius_angle = _rng.randf() * TAU
	particle.position = Vector3(desired_radius * cos(radius_angle), 0, desired_radius * sin(radius_angle))

	# Get initial direction from shape settings
	var spawn_direction = Vector3.UP  # Default direction if no angle settings


	# Initialize position and direction based on shape type
	if enable_shape.x == 0:
		particle.direction = Vector3.UP
		particle.position = Vector3.ZERO
	else:
		match shape_type:
			EmissionShape.CONE:
				_initialize_cone_particle(particle)
			EmissionShape.SPHERE:
				_initialize_sphere_particle(particle)
			EmissionShape.BOX:
				_initialize_box_particle(particle)
			EmissionShape.CIRCLE:
				_initialize_circle_particle(particle)
			EmissionShape.EDGE:
				_initialize_edge_particle(particle)
			EmissionShape.HEMISPHERE:
				_initialize_hemisphere_particle(particle)

	if spherize_direction > 0.001:
		var spherized_direction:Vector3 = particle.position.normalized()
		particle.direction = lerp(particle.direction, spherized_direction, spherize_direction)

	# Apply random direction if needed
	if random_direction > 0.001:
		var random_phi = _rng.randf() * TAU
		var random_costheta = lerp(1.0, -1.0, _rng.randf())
		var random_theta = acos(random_costheta)
		var random_dir = Vector3(
			sin(random_theta) * cos(random_phi),
			sin(random_theta) * sin(random_phi),
			cos(random_theta)
		).normalized()

		# Blend between shape-based and random direction
		particle.direction = particle.direction.lerp(random_dir, random_direction).normalized()

	spawn_direction = particle.direction

	# Apply rotation offset to base direction before other modifications
	if rotation_offset != Vector3.ZERO:
		var basis = Basis()
		if direction_in_world_space:
			# Apply rotations in world space order
			basis = basis.rotated(Vector3.RIGHT, deg_to_rad(rotation_offset.x))
			basis = basis.rotated(Vector3.UP, deg_to_rad(rotation_offset.y))
			basis = basis.rotated(Vector3.FORWARD, deg_to_rad(rotation_offset.z))
		else:
			# Apply rotations in local space order
			basis = basis.rotated(Vector3.FORWARD, deg_to_rad(rotation_offset.z))
			basis = basis.rotated(Vector3.UP, deg_to_rad(rotation_offset.y))
			basis = basis.rotated(Vector3.RIGHT, deg_to_rad(rotation_offset.x))
		particle.direction = basis * (particle.direction * (1.0 if not invert_direction else -1.0))
		particle.position = basis * particle.position

	# Initialize speed using the new start_speed property
	particle.distance = start_speed

	# Initialize scale
	particle.scale = start_size

	# Initialize angle
	particle.angle = deg_to_rad(start_rotation_degrees)
	# Initialize color offset
	if has_color_over_lifetime:
		particle.hue_offset = starting_hue + lerp(0.0, hue_variation, _rng.randf())

	# Initialize velocities - transform to world space if needed
	particle.base_velocity = particle.direction * particle.distance
	if not direction_in_world_space:
		# Transform the velocity to world space for consistent movement
		particle.base_velocity = global_transform.basis * particle.base_velocity

	# When playing in reverse, start at the probable end position
	if play_in_reverse:
		# Calculate approximate final position based on initial velocity and gravity
		var lifetime_seconds = particle.lifetime / playback_speed
		# Move particle to estimated end position
		particle.position += (particle.base_velocity * lifetime_seconds) + (0.5 * gravity * lifetime_seconds * lifetime_seconds)
		# Reverse the velocity
		particle.base_velocity = -particle.base_velocity

	particle.gravity_velocity = Vector3.ZERO if not play_in_reverse else -gravity * particle.lifetime
	particle.last_position = particle.position
	particle.functions = _get_update_functions()

func _initialize_cone_particle(particle: Particle) -> void:
	# Calculate arc position based on mode
	var arc_angle: float
	var original_arc:float = deg_to_rad(arc_degrees)
	match arc_mode:
		ArcMode.RANDOM:
			arc_angle = _rng.randf() * deg_to_rad(arc_degrees)
		ArcMode.LOOP:
			# Calculate base angle from current rotation
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation = fmod(_current_arc_rotation + arc_speed_curve.sample(curve_time) * original_arc, arc_degrees)
			else:
				_current_arc_rotation = fmod(_current_arc_rotation + (arc_speed_constant * original_arc), arc_degrees)

			# If spread is enabled, randomly offset within the spread interval
			if arc_spread > 0:
				var spread_segments = floor(arc_degrees * arc_spread)
				var segment = floor(_current_arc_rotation * arc_spread) / arc_spread
				arc_angle = deg_to_rad(segment)
			else:
				arc_angle = deg_to_rad(_current_arc_rotation)

		ArcMode.PING_PONG:
			# Update current rotation based on speed and direction
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation += (arc_speed_curve.sample(curve_time) * original_arc) * _arc_direction
			else:
				_current_arc_rotation += (arc_speed_constant * original_arc) * _arc_direction

			# Handle direction changes
			if _current_arc_rotation >= arc_degrees:
				_arc_direction = -1
				_current_arc_rotation = arc_degrees
			elif _current_arc_rotation <= 0:
				_arc_direction = 1
				_current_arc_rotation = 0

			# Apply spread if enabled
			if arc_spread > 0:
				var spread_segments = floor(arc_degrees * arc_spread)
				var segment = floor(_current_arc_rotation * arc_spread) / arc_spread
				arc_angle = deg_to_rad(segment)
			else:
				arc_angle = deg_to_rad(_current_arc_rotation)

		ArcMode.BURST_SPREAD:
			if arc_spread > 0:
				# Calculate discrete positions based on spread
				var spread_segments = max(1, floor(arc_degrees * arc_spread))
				# Distribute particles evenly among available segments
				var segment_index = floor(particle.burst_spot * spread_segments)
				arc_angle = deg_to_rad(segment_index / arc_spread)
			else:
				# Distribute evenly around the arc
				arc_angle = deg_to_rad(arc_degrees * particle.burst_spot)

	# Calculate radius with thickness
	var outer_radius = radius
	var inner_radius = radius * (1.0 - radius_thickness)
	var r = lerp(outer_radius, inner_radius, _rng.randf())

	# Calculate base position
	particle.position = Vector3(
		r * cos(arc_angle),
		0,
		r * sin(arc_angle)
	)

	# Calculate direction based on cone angle
	var cone_angle_rad = deg_to_rad(clamp(angle, 0.0, 89.99))

	if particle.position.length_squared() > 0.001:
		# Calculate the radius at the top of the cone
		var cone_height = shape_length  # Use unit height for direction calculation
		var top_radius = r + (cone_height * tan(cone_angle_rad))

		# Get the normalized position on base circle
		var base_pos_normalized = Vector2(particle.position.x, particle.position.z).normalized()

		# Calculate the point on the top circle this particle should aim at
		var target = Vector3(
			base_pos_normalized.x * top_radius,
			particle.position.y + cone_height,
			base_pos_normalized.y * top_radius
		)

		# Direction is from particle position to target
		particle.direction = (target - particle.position).normalized()
	else:
		# If at center, use straight up
		particle.direction = Vector3.UP

	# Handle volume emission
	var height = 0.0
	if emit_from == EmitFrom.VOLUME:
		height = _rng.randf() * shape_length
		var radius_at_height = (r * (1.0 - height / shape_length)) + (height * tan(cone_angle_rad))
		particle.position.y = height
		particle.position.x *= radius_at_height / r
		particle.position.z *= radius_at_height / r


func _initialize_sphere_particle(particle: Particle) -> void:
	# Calculate radius with thickness
	var outer_radius = radius
	var inner_radius = radius * (1.0 - radius_thickness)
	var r = lerp(outer_radius, inner_radius, _rng.randf())

	# Calculate angles based on arc mode
	var phi: float
	match arc_mode:
		ArcMode.RANDOM:
			phi = (_rng.randf() * deg_to_rad(arc_degrees))
		ArcMode.LOOP:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation = fmod(_current_arc_rotation + arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees), arc_degrees)
			else:
				_current_arc_rotation = fmod(_current_arc_rotation + (arc_speed_constant * deg_to_rad(arc_degrees)), arc_degrees)

			if arc_spread > 0:
				var spread_segments = floor(arc_degrees * arc_spread)
				var segment = floor(_current_arc_rotation * arc_spread) / arc_spread
				phi = deg_to_rad(segment)
			else:
				phi = deg_to_rad(_current_arc_rotation)

		ArcMode.PING_PONG:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation += (arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees)) * _arc_direction
			else:
				_current_arc_rotation += (arc_speed_constant * deg_to_rad(arc_degrees)) * _arc_direction

			if _current_arc_rotation >= arc_degrees:
				_arc_direction = -1
				_current_arc_rotation = arc_degrees
			elif _current_arc_rotation <= 0:
				_arc_direction = 1
				_current_arc_rotation = 0

			phi = deg_to_rad(_current_arc_rotation)

		ArcMode.BURST_SPREAD:
			if arc_spread > 0:
				var spread_segments = max(1, floor(arc_degrees * arc_spread))
				var segment_index = floor(particle.burst_spot * spread_segments)
				phi = deg_to_rad(segment_index / arc_spread)
			else:
				phi = deg_to_rad(arc_degrees * particle.burst_spot)

	# Always randomize vertical angle for full sphere coverage
	var costheta = lerp(1.0, -1.0, _rng.randf())
	var theta = acos(costheta)

	# Convert spherical coordinates to Cartesian
	particle.position = Vector3(
		r * sin(theta) * cos(phi),
		r * cos(theta),          # This will always be positive (top half)
		r * sin(theta) * sin(phi)
	)
	particle.direction = particle.position.normalized()

func _initialize_box_particle(particle: Particle) -> void:
	particle.position = Vector3(
		(_rng.randf() * 2.0 - 1.0) * box_extents.x,
		(_rng.randf() * 2.0 - 1.0) * box_extents.y,
		(_rng.randf() * 2.0 - 1.0) * box_extents.z
	)
	particle.direction = Vector3.UP

func _initialize_circle_particle(particle: Particle) -> void:
	# Calculate radius with thickness
	var outer_radius = radius
	var inner_radius = radius * (1.0 - radius_thickness)
	var r = lerp(outer_radius, inner_radius, _rng.randf())

	# Calculate angle based on arc mode
	var angle: float
	match arc_mode:
		ArcMode.RANDOM:
			angle = (_rng.randf() * deg_to_rad(arc_degrees))
		ArcMode.LOOP:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation = fmod(_current_arc_rotation + arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees), arc_degrees)
			else:
				_current_arc_rotation = fmod(_current_arc_rotation + (arc_speed_constant * deg_to_rad(arc_degrees)), arc_degrees)

			if arc_spread > 0:
				var spread_segments = floor(arc_degrees * arc_spread)
				var segment = floor(_current_arc_rotation * arc_spread) / arc_spread
				angle = deg_to_rad(segment)
			else:
				angle = deg_to_rad(_current_arc_rotation)

		ArcMode.PING_PONG:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation += (arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees)) * _arc_direction
			else:
				_current_arc_rotation += (arc_speed_constant * deg_to_rad(arc_degrees)) * _arc_direction

			if _current_arc_rotation >= arc_degrees:
				_arc_direction = -1
				_current_arc_rotation = arc_degrees
			elif _current_arc_rotation <= 0:
				_arc_direction = 1
				_current_arc_rotation = 0

			angle = deg_to_rad(_current_arc_rotation)

		ArcMode.BURST_SPREAD:
			if arc_spread > 0:
				var spread_segments = max(1, floor(arc_degrees * arc_spread))
				var segment_index = floor(particle.burst_spot * spread_segments)
				angle = deg_to_rad(segment_index / arc_spread)
			else:
				angle = deg_to_rad(arc_degrees * particle.burst_spot)

	particle.position = Vector3(r * cos(angle), 0, r * sin(angle))
	particle.direction = Vector3.UP

func _initialize_edge_particle(particle: Particle) -> void:
	var t = _rng.randf()
	particle.position = Vector3(0, lerp(-radius, radius, t), 0)
	particle.direction = Vector3.UP

func _initialize_hemisphere_particle(particle: Particle) -> void:
	# Calculate radius with thickness
	var outer_radius = radius
	var inner_radius = radius * (1.0 - radius_thickness)
	var r = lerp(outer_radius, inner_radius, _rng.randf())

	# Calculate angles based on arc mode
	var phi: float
	match arc_mode:
		ArcMode.RANDOM:
			phi = (_rng.randf() * deg_to_rad(arc_degrees))
		ArcMode.LOOP:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation = fmod(_current_arc_rotation + arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees), arc_degrees)
			else:
				_current_arc_rotation = fmod(_current_arc_rotation + (arc_speed_constant * deg_to_rad(arc_degrees)), arc_degrees)

			if arc_spread > 0:
				var spread_segments = floor(arc_degrees * arc_spread)
				var segment = floor(_current_arc_rotation * arc_spread) / arc_spread
				phi = deg_to_rad(segment)
			else:
				phi = deg_to_rad(_current_arc_rotation)

		ArcMode.PING_PONG:
			if arc_speed_mode == 1 and arc_speed_curve:
				var curve_time = _emission_time / duration if duration > 0 else 0.0
				_current_arc_rotation += (arc_speed_curve.sample(curve_time) * deg_to_rad(arc_degrees)) * _arc_direction
			else:
				_current_arc_rotation += (arc_speed_constant * deg_to_rad(arc_degrees)) * _arc_direction

			if _current_arc_rotation >= arc_degrees:
				_arc_direction = -1
				_current_arc_rotation = arc_degrees
			elif _current_arc_rotation <= 0:
				_arc_direction = 1
				_current_arc_rotation = 0

			phi = deg_to_rad(_current_arc_rotation)

		ArcMode.BURST_SPREAD:
			if arc_spread > 0:
				var spread_segments = max(1, floor(arc_degrees * arc_spread))
				var segment_index = floor(particle.burst_spot * spread_segments)
				phi = deg_to_rad(segment_index / arc_spread)
			else:
				phi = deg_to_rad(arc_degrees * particle.burst_spot)

	# For hemisphere, we only want the top half, so theta ranges from 0 to PI/2
	var costheta = lerp(1.0, 0.0, _rng.randf())  # Only top half
	var theta = acos(costheta)

	# Convert spherical coordinates to Cartesian
	particle.position = Vector3(
		r * sin(theta) * cos(phi),
		r * cos(theta),          # This will always be positive (top half)
		r * sin(theta) * sin(phi)
	)
	particle.direction = particle.position.normalized()

func _update_width_height_over_lifetime(t: float, p: Particle, xform: Transform3D):
	var p_scale := p.scale
	if width_over_lifetime:
		p_scale.x = p.scale.x * width_over_lifetime.sample(t)
	if height_over_lifetime:
		p_scale.y = p.scale.y * height_over_lifetime.sample(t)
	xform = xform.scaled(Vector3(p_scale.x, p_scale.y, 1.0))
	return xform

func _update_scale_over_lifetime(t: float, p: Particle, xform: Transform3D):
	if size_over_lifetime == null:
		return xform
	var scale_factor = size_over_lifetime.sample(t)
	return xform.scaled(Vector3(p.scale.x * scale_factor, p.scale.y * scale_factor, 1.0))

func _update_scale(t: float, p: Particle, xform: Transform3D):
	return xform.scaled(Vector3(p.scale.x, p.scale.y, 1.0))

func _update_position_and_velocity(t: float, p: Particle, xform: Transform3D):
	var delta = get_process_delta_time()

	# Scale base velocity by curve
	var current_velocity = p.base_velocity
	if enable_velocity_over_lifetime.x == 1 and velocity_over_lifetime:
		# When in reverse, we sample from the opposite end of the curve
		var sample_time = (1.0 - t) if play_in_reverse else t
		current_velocity *= velocity_over_lifetime.sample(sample_time)

	# Update gravity velocity
	if play_in_reverse:
		# In reverse, gravity works opposite
		p.gravity_velocity = p.gravity_velocity.lerp(-gravity, delta * 0.2)
	else:
		p.gravity_velocity = p.gravity_velocity.lerp(gravity, delta * 0.2)

	# Update position using both velocities
	var movement = (current_velocity + p.gravity_velocity) * delta * playback_speed
	if not use_world_space:
		# Transform movement back to local space
		movement = global_transform.basis.inverse() * movement
	p.position += movement

	xform.origin = p.position

	# Apply position offset if any
	if position_offset != Vector3.ZERO:
		var offset_amount = Vector3.ONE
		if offset_over_lifetime:
			var sample_time = (1.0 - t) if play_in_reverse else t
			offset_amount = Vector3.ONE * offset_over_lifetime.sample(sample_time)

		var final_offset = position_offset * offset_amount
		if not use_world_space:
			# Transform offset to local space if needed
			final_offset = global_transform.basis.inverse() * final_offset

		xform.origin += final_offset

	return xform

func _update_rotation_and_orbit(t: float, p: Particle, xform: Transform3D):
	# Get orbit angle from curve
	var orbit_angle = (orbit_over_lifetime.sample(t) * TAU * 0.01) if orbit_over_lifetime != null else 0.0 # Full rotation is TAU radians
	# Get current position relative to center
	var pos = p.position
	if use_world_space:
		# If in world space, transform position to local space for rotation
		pos = global_transform.basis.inverse() * (pos - global_position)
	# Create rotation around Y axis (or customize the axis as needed)
	var rotation = Basis().rotated(orbit_around_axis, orbit_angle)
	# Apply rotation to position
	pos = rotation * pos
	# Apply same rotation to velocity to maintain tangential movement
	p.base_velocity = rotation * p.base_velocity
	if use_world_space:
		# Transform back to world space if needed
		pos = global_transform.basis * pos + global_position
	# Update position
	p.position = pos
	xform.origin = pos

	return xform

func _get_update_functions() -> Array[Callable]:
	var functions :Array[Callable]= []

	# Scale update functions
	if enable_size_over_lifetime.x == 1 and (width_over_lifetime != null or height_over_lifetime != null):
		functions.append(_update_width_height_over_lifetime)
	elif enable_size_over_lifetime.x == 1 and size_over_lifetime:
		functions.append(_update_scale_over_lifetime)
	else:
		functions.append(_update_scale)

	# Position update using velocity
	functions.append(_update_position_and_velocity)

	# Add orbit update before position update
	if enable_rotation_over_lifetime.x == 1 and orbit_over_lifetime:
		functions.append(_update_rotation_and_orbit)

	return functions

func play(_clear_on_play:bool = true) -> void:
	if _playing:
		if debugging: print("Already playing")
		return

	update_instance_transform.call_deferred()
	# Create multimesh if needed
	_create_multimesh()
	# Cache child particles on first play
	_cache_child_particles()
	# Play any child particles that aren't already playing
	for child in _child_particles:
		if not child._playing:
			if debugging: print("Playing child particle system")
			# Pass along the loop setting to children
			child.loop = loop
			child.play(_clear_on_play)


	if _clear_on_play:
		clear(false)

	if debugging: print("Starting particle system with max particles: ", max_particles)
	_playing = true
	_time = 0.0
	_emission_time = -start_delay

	# Initialize accumulator to maintain even spacing from the start
	_emission_accumulator.x = 0.0
	_emission_accumulator.y = (1.0 / rate_over_time) if rate_over_time > 0.0001 else 1.0
	_last_position = global_position

	# Initialize bursts from definitions
	_active_bursts.clear()
	var def_count = bursts.size() / 9
	for i in def_count:
		var burst_instance = create_burst_instance(i)
		burst_instance.initialize()
		_active_bursts.append(burst_instance)

	set_process(true)

func clear(also_stop:bool = false) -> void:
	if also_stop:
		stop()

	# Clear existing particles
	for particle in _particles:
		particle.kill()
	_particles.clear()
	_active_bursts.clear()

	# Update visible count and buffer even when not playing
	_visible_count = 0
	if _multimesh != RID():
		# Clear the buffer
		for i in range(_buffer.size()):
			_buffer[i] = 0.0
		# Update the multimesh
		RenderingServer.multimesh_set_buffer(_multimesh, _buffer)
		RenderingServer.multimesh_set_visible_instances(_multimesh, 0)

func stop(also_clear:bool = false) -> void:
	_playing = false
	_active_bursts.clear()

	# Stop all child particles
	for child in _child_particles:
		child.stop(also_clear)

	if also_clear:
		clear()

func _update_shader_parameters() -> void:
	if shared_material and not _shared_material == override_material and _shared_material is ShaderMaterial:
		# Switch to normal uniform parameters for all built-in generated materials
		# There is no difference and instance uniforms have heavy limitations on web
		_update_material_shader_parameters(_shared_material as ShaderMaterial)
	else:
		# Still use instances for "override materials" for backwards compatibility
		# (we don't want to write to the material since it might be shared elsewhere)
		_update_instance_shader_parameters()

# Shader Parameters OPTION A: write particle settings shared across all particles on the Material
func _update_material_shader_parameters(m: ShaderMaterial) -> void:
	m.set_shader_parameter("particles_anim_h_frames", h_frames)
	m.set_shader_parameter("particles_anim_v_frames", v_frames)
	m.set_shader_parameter("particles_anim_tiles_mode", tiles_mode)# not used?
	m.set_shader_parameter("particles_anim_enabled", texture_sheet_enabled)# not used?
	m.set_shader_parameter("billboard_mode", billboard_mode)
	m.set_shader_parameter("align_to_velocity", 1 if align_to_velocity else 0)
	if tint_color != null:
		m.set_shader_parameter("tint_color", tint_color)

# Shader Parameters OPTION B: write particle settings shared across all particles on the MultiMesh
func _update_instance_shader_parameters() -> void:
	if _instance == RID():
		return

	RenderingServer.instance_geometry_set_shader_parameter(_instance, "particles_anim_h_frames", h_frames)
	RenderingServer.instance_geometry_set_shader_parameter(_instance, "particles_anim_v_frames", v_frames)
	RenderingServer.instance_geometry_set_shader_parameter(_instance, "particles_anim_tiles_mode", tiles_mode)
	RenderingServer.instance_geometry_set_shader_parameter(_instance, "particles_anim_enabled", texture_sheet_enabled)
	RenderingServer.instance_geometry_set_shader_parameter(_instance, "billboard_mode", billboard_mode)
	RenderingServer.instance_geometry_set_shader_parameter(_instance, "align_to_velocity", 1 if align_to_velocity else 0)
	if tint_color != null:
		RenderingServer.instance_geometry_set_shader_parameter(_instance, "tint_color", tint_color)


# Helper function to get alignment basis from direction
func _get_alignment_basis(direction: Vector3) -> Basis:
	var basis = Basis()
	var up = Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.99:
		up = Vector3.BACK

	basis.z = direction
	basis.y = up
	basis.x = up.cross(direction).normalized()
	basis.y = direction.cross(basis.x).normalized()
	return basis

func _cache_child_particles() -> void:
	if _child_particles_cached:
		return
	_child_particles.clear()
	for child in get_children():
		if child is UniParticles3D:
			_child_particles.append(child)

	_child_particles_cached = true
	if debugging: print("Cached ", _child_particles.size(), " child particle systems")

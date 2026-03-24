class_name Enemy
extends Node2D

## Base enemy node. Attach a PathProvider child before calling initialize().
## initialize() must be called with an EnemyDefinition and Difficulty before
## adding the enemy to the scene tree (or immediately after).

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the enemy's HP reaches zero.
signal enemy_died(enemy: Enemy)

## Emitted when the enemy successfully traverses the path to the exit.
signal enemy_reached_exit(enemy: Enemy)

## Emitted by Splitting elites on death. Game spawns copies at this position.
signal elite_split_requested(position: Vector2, definition: EnemyDefinition, difficulty: int, path_index: int, progress_ratio: float, remaining_modifiers: Array)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var _definition: EnemyDefinition = null
var _health: EnemyHealth = null
var _renderer: EnemyRenderer = null
var _path_provider: PathProvider = null

var _effective_speed: float = 150.0
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _initialized: bool = false

# Ability system
var _ability_cooldown: float = 0.0
var _speed_buff_factor: float = 1.0
var _speed_buff_timer: float = 0.0

# Focus Fire debuff (from tower synergy)
var _focus_fire_timer: float = 0.0
var _focus_fire_mult: float = 1.0

# Drone swarm / magnetic elite cooldown timers (avoid O(n^2) per frame)
var _drone_swarm_cooldown: float = 0.0
var _elite_magnetic_cooldown: float = 0.0

# Elite modifier state
var _elite_modifiers: Array[int] = []
var _elite_regen_timer: float = 0.0
var _elite_phase_timer: float = 0.0
var _elite_phase_active: bool = false
var _elite_phase_remaining: float = 0.0
var _elite_enraged_timer: float = 0.0
var _elite_enraged_speed_bonus: float = 0.0
var _speed_multiplier: float = 1.0

# Kill attribution (tower type that last dealt damage)
var _last_damage_tower_type: int = -1

# Spawn context (for splitting)
var _spawn_path_index: int = 0
var _spawn_difficulty: int = 0

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Fully initialises the enemy from a definition and difficulty.
## Creates EnemyHealth and EnemyRenderer as children.
## path_provider must already be added as a child (or set via set_path_provider).
func initialize(def: EnemyDefinition, difficulty: int) -> void:
	_definition = def

	var constants := Constants.new()
	var hp_mult: float = constants.DIFFICULTY_HP_MULT.get(difficulty, 1.0) as float
	var spd_mult: float = constants.DIFFICULTY_SPEED_MULT.get(difficulty, 1.0) as float

	# Health component
	_health = EnemyHealth.new()
	_health.name = "EnemyHealth"
	add_child(_health)
	_health.initialize(
		def.base_hp * hp_mult,
		def.armor,
		def.shield,
		def.resistance_map
	)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)

	# Renderer component
	_renderer = EnemyRenderer.new()
	_renderer.name = "EnemyRenderer"
	add_child(_renderer)
	_renderer.setup(def)

	# Tank Fortified mechanic
	if def.archetype == Enums.EnemyArchetype.TANK:
		_health.enable_fortified()

	# Speed (affected by difficulty)
	_speed_multiplier = spd_mult
	_effective_speed = def.speed * spd_mult

	_initialized = true

## Assign the path provider. Must be set before _process runs.
func set_path_provider(provider: PathProvider) -> void:
	_path_provider = provider

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _initialized or _path_provider == null:
		return
	if not _health.is_alive():
		return

	# Advance along path
	var current_speed := _effective_speed * _slow_factor * _speed_buff_factor
	_path_provider.move(current_speed, delta)

	# Sync visual position with path
	global_position = _path_provider.get_current_position()

	# Slow timer countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_factor = 1.0

	# Speed buff timer countdown
	if _speed_buff_timer > 0.0:
		_speed_buff_timer -= delta
		if _speed_buff_timer <= 0.0:
			_speed_buff_timer = 0.0
			_speed_buff_factor = 1.0

	# Focus Fire debuff countdown
	if _focus_fire_timer > 0.0:
		_focus_fire_timer -= delta
		if _focus_fire_timer <= 0.0:
			_focus_fire_timer = 0.0
			_focus_fire_mult = 1.0

	# Archetype abilities
	_process_abilities(delta)

	# Elite modifier abilities
	_process_elite_modifiers(delta)

	# Check exit
	if _path_provider.has_reached_end():
		on_reached_exit()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Applies a movement slow effect. factor is 0.0–1.0 (1.0 = no slow, 0.5 = half speed).
## The effect lasts for duration seconds; a new slow only applies if stronger.
func apply_slow(factor: float, duration: float) -> void:
	var clamped: float = clampf(factor, 0.05, 1.0)
	if clamped < _slow_factor:
		# Stronger slow: apply it and reset the timer
		_slow_factor = clamped
		_slow_timer = duration
	else:
		# Same or weaker slow: only extend duration if current timer is shorter
		if duration > _slow_timer:
			_slow_timer = duration

## Returns the gold value of this enemy (from its definition).
func get_gold_value() -> int:
	if _definition == null:
		return 0
	return _definition.gold_value

## Returns true if the enemy is still alive.
func is_alive() -> bool:
	if _health == null:
		return false
	return _health.is_alive()

## Returns 0.0–1.0 HP fraction.
func get_hp_percentage() -> float:
	if _health == null:
		return 0.0
	return _health.get_hp_percentage()

## Returns current path progress ratio (0.0–1.0).
func get_progress_ratio() -> float:
	if _path_provider == null:
		return 0.0
	return _path_provider.get_progress_ratio()

## Returns the archetype enum value, or -1 if no definition.
func get_archetype() -> int:
	if _definition == null:
		return -1
	return _definition.archetype

## Returns true if this enemy is a boss.
func is_boss() -> bool:
	return _definition != null and _definition.is_boss

## Returns the EnemyDefinition resource, or null.
func get_definition() -> EnemyDefinition:
	return _definition

## Multiplies the effective speed by the given factor.
func scale_speed(factor: float) -> void:
	_effective_speed *= factor

## Applies a temporary speed multiplier. Only the strongest active buff is kept.
func apply_speed_buff(factor: float, duration: float) -> void:
	_speed_buff_factor = maxf(factor, _speed_buff_factor)
	_speed_buff_timer = maxf(duration, _speed_buff_timer)

## Applies Focus Fire debuff (increased damage taken).
func apply_focus_fire(mult: float, duration: float) -> void:
	_focus_fire_mult = maxf(mult, _focus_fire_mult)
	_focus_fire_timer = maxf(duration, _focus_fire_timer)

## Returns the current damage-taken multiplier from Focus Fire debuff.
func get_damage_multiplier() -> float:
	return _focus_fire_mult

## Returns true if the enemy is currently slowed below normal speed.
func is_slowed() -> bool:
	return _slow_factor < 1.0

## Extends the current slow timer by extra seconds (does not change factor).
func extend_slow(extra: float) -> void:
	_slow_timer += extra

## Sets the spawn context used by Splitting elites and speed modifiers.
func initialize_spawn_context(path_idx: int, difficulty: int) -> void:
	_spawn_path_index = path_idx
	_spawn_difficulty = difficulty

## Alias for initialize_spawn_context (backward compat).
func set_spawn_context(path_index: int, difficulty: int) -> void:
	initialize_spawn_context(path_index, difficulty)

## Multiplies the effective speed by the given factor (stacks multiplicatively).
func apply_speed_multiplier(mult: float) -> void:
	_effective_speed *= mult

## Records the tower type that most recently dealt damage (for kill attribution).
func set_last_damage_source(tower_type: int) -> void:
	_last_damage_tower_type = tower_type

## Alias for set_last_damage_source (backward compat).
func set_last_damage_tower_type(tower_type: int) -> void:
	set_last_damage_source(tower_type)

## Returns the tower type that last dealt damage, or -1 if none.
func get_last_damage_source() -> int:
	return _last_damage_tower_type

## Applies an elite modifier to this enemy. Scales HP per modifier applied.
func apply_elite_modifier(modifier: int) -> void:
	if _elite_modifiers.has(modifier):
		return
	_elite_modifiers.append(modifier)
	# Scale HP up for elites (preserve current HP fraction)
	if _health != null:
		_health.scale_max_hp(Constants.ELITE_HP_SCALE)
	if _renderer != null:
		_renderer.set_elite_modifiers(_elite_modifiers)

func is_elite() -> bool:
	return not _elite_modifiers.is_empty()

func has_elite_modifier(modifier: int) -> bool:
	return _elite_modifiers.has(modifier)

func is_phasing() -> bool:
	return _elite_phase_active

## Called when the enemy reaches the exit. Emits signal and queues removal.
func on_reached_exit() -> void:
	enemy_reached_exit.emit(self)
	set_process(false)
	queue_free()

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_health_changed(hp: float, max_hp: float, shield: float) -> void:
	if _renderer != null:
		_renderer.update_health(hp, max_hp, shield)

func _on_died() -> void:
	set_process(false)
	if _definition != null and _definition.archetype == Enums.EnemyArchetype.SCOUT:
		_scatter_signal()
	if has_elite_modifier(Enums.EliteModifier.SPLITTING):
		var remaining: Array = _elite_modifiers.filter(func(m: int) -> bool: return m != Enums.EliteModifier.SPLITTING)
		elite_split_requested.emit(global_position, _definition, _spawn_difficulty, _spawn_path_index, get_progress_ratio(), remaining)
	_spawn_death_effect()
	AudioManager.play_enemy_death(_definition.size_scale if _definition != null else 1.0)
	enemy_died.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Archetype abilities
# ---------------------------------------------------------------------------

func _process_abilities(delta: float) -> void:
	if _definition == null:
		return
	match _definition.archetype:
		Enums.EnemyArchetype.HEALER:
			_process_healer(delta)
		Enums.EnemyArchetype.SHIELDER:
			_process_shielder(delta)
		Enums.EnemyArchetype.DRONE:
			_process_drone_swarm()

func _process_healer(delta: float) -> void:
	_ability_cooldown -= delta
	if _ability_cooldown > 0.0:
		return
	_ability_cooldown = Constants.HEALER_PULSE_COOLDOWN
	var healed_any: bool = false
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		if not node.is_alive():
			continue
		if global_position.distance_to(node.global_position) > Constants.HEALER_PULSE_RANGE:
			continue
		var ally_health: EnemyHealth = node.get_node_or_null("EnemyHealth")
		if ally_health != null:
			ally_health.heal(ally_health.get_max_hp() * Constants.HEALER_PULSE_FRACTION)
			healed_any = true

func _process_shielder(delta: float) -> void:
	_ability_cooldown -= delta
	if _ability_cooldown > 0.0:
		return
	_ability_cooldown = Constants.SHIELDER_AURA_COOLDOWN
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		if not node.is_alive():
			continue
		if global_position.distance_to(node.global_position) > Constants.SHIELDER_AURA_RANGE:
			continue
		var ally_health: EnemyHealth = node.get_node_or_null("EnemyHealth")
		if ally_health != null and ally_health.get_shield() < Constants.SHIELDER_AURA_MAX:
			var grant: float = minf(Constants.SHIELDER_AURA_AMOUNT, Constants.SHIELDER_AURA_MAX - ally_health.get_shield())
			ally_health.add_shield(grant)

func _process_drone_swarm() -> void:
	_drone_swarm_cooldown -= get_process_delta_time()
	if _drone_swarm_cooldown > 0.0:
		return
	_drone_swarm_cooldown = 0.5
	var drone_count: int = 0
	var drones: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Enemy) or not node.is_alive():
			continue
		if node.get_archetype() == Enums.EnemyArchetype.DRONE:
			drone_count += 1
			drones.append(node)
	if drone_count >= Constants.DRONE_OVERWHELM_THRESHOLD:
		for d in drones:
			d.apply_speed_buff(Constants.DRONE_OVERWHELM_SPEED_MULT, 0.5)

func _scatter_signal() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		if not node.is_alive():
			continue
		if global_position.distance_to(node.global_position) > Constants.SCOUT_SCATTER_RANGE:
			continue
		node.apply_speed_buff(Constants.SCOUT_SCATTER_SPEED_MULT, Constants.SCOUT_SCATTER_DURATION)

# ---------------------------------------------------------------------------
# Elite modifier abilities
# ---------------------------------------------------------------------------

func _process_elite_modifiers(delta: float) -> void:
	if _elite_modifiers.is_empty():
		return
	for mod in _elite_modifiers:
		match mod:
			Enums.EliteModifier.REGENERATING:
				_process_elite_regen(delta)
			Enums.EliteModifier.PHASING:
				_process_elite_phasing(delta)
			Enums.EliteModifier.MAGNETIC:
				_process_elite_magnetic()
			Enums.EliteModifier.ENRAGED:
				_process_elite_enraged(delta)

func _process_elite_regen(delta: float) -> void:
	_elite_regen_timer -= delta
	if _elite_regen_timer > 0.0:
		return
	_elite_regen_timer = Constants.ELITE_REGEN_PULSE_INTERVAL
	if _health != null and _health.is_alive():
		_health.heal(_health.get_max_hp() * Constants.ELITE_REGEN_HP_PER_SECOND * Constants.ELITE_REGEN_PULSE_INTERVAL)

func _process_elite_phasing(delta: float) -> void:
	if _elite_phase_active:
		_elite_phase_remaining -= delta
		if _elite_phase_remaining <= 0.0:
			_elite_phase_active = false
			if _renderer != null:
				_renderer.set_phasing(false)
	else:
		_elite_phase_timer -= delta
		if _elite_phase_timer <= 0.0:
			_elite_phase_timer = Constants.ELITE_PHASE_INTERVAL
			_elite_phase_active = true
			_elite_phase_remaining = Constants.ELITE_PHASE_DURATION
			if _renderer != null:
				_renderer.set_phasing(true)

func _process_elite_magnetic() -> void:
	_elite_magnetic_cooldown -= get_process_delta_time()
	if _elite_magnetic_cooldown > 0.0:
		return
	_elite_magnetic_cooldown = 0.5
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy) or not node.is_alive():
			continue
		if global_position.distance_to(node.global_position) <= Constants.ELITE_MAGNETIC_RANGE:
			node.apply_speed_buff(Constants.ELITE_MAGNETIC_SPEED_MULT, 0.5)

func _process_elite_enraged(delta: float) -> void:
	_elite_enraged_timer -= delta
	if _elite_enraged_timer > 0.0:
		return
	_elite_enraged_timer = Constants.ELITE_ENRAGED_INTERVAL
	if _elite_enraged_speed_bonus < Constants.ELITE_ENRAGED_SPEED_CAP:
		_elite_enraged_speed_bonus = minf(
			_elite_enraged_speed_bonus + Constants.ELITE_ENRAGED_SPEED_INCREMENT,
			Constants.ELITE_ENRAGED_SPEED_CAP
		)
		if _definition != null:
			_effective_speed = _definition.speed * _speed_multiplier * (1.0 + _elite_enraged_speed_bonus)

# ---------------------------------------------------------------------------
# Death effect
# ---------------------------------------------------------------------------

func _spawn_death_effect() -> void:
	var effect := _DeathEffect.new()
	var color := Color.WHITE
	var radius: float = 12.0
	if _definition != null:
		color = _definition.color
		radius = _definition.shape_radius * _definition.size_scale
	effect.setup(color, radius)
	effect.global_position = global_position
	var parent := get_parent()
	if parent == null:
		effect.queue_free()
		return
	parent.add_child(effect)
	# Animate: expand and fade out, scaled by enemy size
	var size_sc: float = 1.0
	if _definition != null:
		size_sc = _definition.size_scale
	var final_scale: float = 2.0 * size_sc
	var tw := effect.create_tween()
	tw.tween_property(effect, "scale", Vector2(final_scale, final_scale), 0.3)
	tw.parallel().tween_property(effect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(effect.queue_free)

# ---------------------------------------------------------------------------
# Inner classes
# ---------------------------------------------------------------------------

class _DeathEffect extends Node2D:
	var _color: Color = Color.WHITE
	var _radius: float = 12.0

	func setup(color: Color, radius: float) -> void:
		_color = color
		_radius = radius

	func _draw() -> void:
		# Expanding ring
		draw_arc(Vector2.ZERO, _radius, 0, TAU, 16, _color, 2.0)
		# Inner burst
		draw_circle(Vector2.ZERO, _radius * 0.3, Color(_color.r, _color.g, _color.b, 0.4))

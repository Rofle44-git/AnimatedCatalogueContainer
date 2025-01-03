@tool
@icon("res://addons/AnimatedCatalogueContainer/icon.svg")
class_name AnimatedCatalogueContainer extends Control

enum AnimationMode {
	IN_PARALLEL,
	IN_SERIES,
}

@export var active_idx: int = 0:
	set(value):
		active_idx = value
		if Engine.is_editor_hint(): _refresh()
@export var alignment_factor: Vector2 = Vector2(0.5, 0.5)
@export_subgroup("Animation", "anim")
@export var anim_mode: AnimationMode = AnimationMode.IN_PARALLEL
@export var anim_position: bool = true
@export var anim_alpha: bool = true
@export var anim_scale: bool = true
@export_range(-360.0, 360.0, 0.1, "suffix:°") var anim_direction_deg: float = 90.0:
	set(value):
		anim_direction_deg = value
		_dir = Vector2.UP.rotated(deg_to_rad(value)).normalized()
		if Engine.is_editor_hint(): _refresh()
@export var anim_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var anim_transition_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var anim_process_mode: Tween.TweenProcessMode = Tween.TWEEN_PROCESS_IDLE
@export_range(0.01, 1.0, 0.01, "suffix:s") var anim_duration: float = 0.25

var _dir: Vector2 = Vector2.UP.rotated(deg_to_rad(anim_direction_deg)).normalized()


func _init() -> void:
	tree_entered.connect(_on_resized)
	child_entered_tree.connect(_on_child_entered_tree)

func _ready() -> void:
	resized.connect(_on_resized, CONNECT_DEFERRED)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_refresh()

func transition_by_node(_node: Control) -> void:
	var _children: Array[Node] = get_children()
	if _children.has(_node): transition(_children.find(_node))

func transition(new_idx: int) -> void:
	new_idx = clampi(new_idx, 0, get_child_count()-1)
	if new_idx == active_idx: return
	var _active_idx: int = active_idx
	active_idx = new_idx
	match anim_mode:
		AnimationMode.IN_PARALLEL: hide_node(_active_idx, new_idx)
		AnimationMode.IN_SERIES: await hide_node(_active_idx, new_idx)

	await show_node(new_idx, _active_idx)

func previous() -> void:
	transition(active_idx-1)

func this() -> void:
	transition(active_idx)

func next() -> void:
	transition(active_idx+1)

func hide_node(idx: int, new_idx: int) -> void:
	var n: Control = get_child(idx) as Control
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_process_input(false)
	if anim_alpha: _tween(n, "modulate", Color(n.modulate.to_html(false), 0.0), Color(n.modulate.to_html(false), 1.0))
	if anim_position: _tween(n, "position", _aligned(idx - new_idx))
	else: n.position = _aligned(0)
	if anim_scale: _tween(n, "scale", Vector2.ZERO, Vector2.ONE)
	await get_tree().create_timer(anim_duration).timeout
	n.hide()

func show_node(idx: int, prev_idx: int) -> void:
	var n: Control = get_child(idx) as Control
	n.pivot_offset = size * alignment_factor
	n.mouse_filter = Control.MOUSE_FILTER_STOP
	n.set_process_input(true)
	n.show()
	if anim_alpha: _tween(n, "modulate", Color(n.modulate.to_html(false), 1.0), Color(n.modulate.to_html(false), 0.0))
	if anim_position: _tween(n, "position", _aligned(0), _aligned(idx - prev_idx))
	else: n.position = _aligned(0)
	if anim_scale: _tween(n, "scale", Vector2.ONE, Vector2.ZERO)
	await get_tree().create_timer(anim_duration).timeout

func _aligned(idx: int) -> Vector2:
	return size * _dir * float(idx)

func _refresh() -> void:
	var n: Control
	var active: bool
	for i: int in range(0, get_child_count()):
		active = i == active_idx
		n = get_child(i) as Control
		var p: Vector2 = _aligned(clampi(i - active_idx, -1, 1)) if anim_position else _aligned(0)
		n.reset_size()
		n.set_anchors_and_offsets_preset(PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE)
		n.position = p
		n.mouse_filter = MOUSE_FILTER_STOP if active else MOUSE_FILTER_IGNORE
		n.set_process_input(active)
		n.modulate.a = 1.0 if active || !anim_alpha else 0.0
		n.pivot_offset = size * alignment_factor
		n.scale = Vector2.ONE if active || !anim_scale else Vector2.ZERO
		n.visible = active || Engine.is_editor_hint()

func _tween(n: Control, p: String, v: Variant, f: Variant = null) -> PropertyTweener:
	if f != null: n.set(StringName(p), f)
	return n.create_tween().set_ease(anim_ease_type)\
			.set_process_mode(anim_process_mode).set_trans(anim_transition_type)\
			.tween_property(n, NodePath(p), v, anim_duration)

func _on_child_entered_tree(node: Control) -> void:
	node.set_anchors_preset(PRESET_FULL_RECT)
	node.pivot_offset = size * alignment_factor

func _on_resized() -> void:
	_refresh()

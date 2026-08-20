class_name RewindTrackedNodeDelta extends Resource

@export var node_path: NodePath = ""
@export var properties: PackedStringArray = []

var values_list: Dictionary = {}

func setup(frames_to_store: int, keyframes_modulo: int, precision: int, bytes_per_delta: int) -> void:
	values_list.clear()
	for property in properties:
		var values := RewindResourceDelta.new()
		values.frames_to_store = frames_to_store
		
		var real_precision: float
		match precision:
			0:
				real_precision = 1
			1:
				real_precision = 0.1
			2:
				real_precision = 0.01
			3:
				real_precision = 0.001
			4:
				real_precision = 0.0001
			5:
				real_precision = 0.00001
			6:
				real_precision = 0.000001
			7:
				real_precision = 0.0000001
			8:
				real_precision = 0.00000001
			9:
				real_precision = 0.000000001
		values.precision = real_precision
		
		if frames_to_store % keyframes_modulo == 0:
			values.keyframes_modulo = keyframes_modulo
		else:
			push_error("The number of frames to store (Time recorded * Physics ticks per seconds) must be divisible by Keyframe modulo")
			assert(false, "The number of frames to store (Time recorded * Physics ticks per seconds) must be divisible by Keyframe modulo")
			continue
		if bytes_per_delta == 1 or bytes_per_delta == 2 or bytes_per_delta == 4:
			values.bytes_per_delta = bytes_per_delta
		else:
			push_error("Bytes per delta must be 1, 2 or 4")
			assert(false, "Bytes per delta must be 1, 2 or 4")
			continue
			
		values_list[property] = values
 
func record(node: Node) -> void:
	for property in properties:
		var values: RewindResourceDelta = values_list.get(property)
		if values:
			values.add_value(node.get(property))
 
## Applies the value from `n` frames ago for every tracked property onto
## `node`. Returns false if any property's history is exhausted (buffer ran
## out), in which case the caller should stop the rewind.
func rewind_frame(node: Node, n: int) -> bool:
	for property in properties:
		var values: RewindResourceDelta = values_list.get(property)
		if values == null:
			continue
		var value = values.get_value_n_frames_ago(n)
		if value == null:
			return false
		node.set(property, value)
	return true
 
func get_size() -> int:
	var total := 0
	for values in values_list.values():
		total += values.get_size()
	return total
 
func reset() -> void:
	for values in values_list.values():
		values.reset()

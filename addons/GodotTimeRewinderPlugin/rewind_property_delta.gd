class_name RewindResourceDelta extends Resource

var values : PackedByteArray = PackedByteArray()
var frames_to_store: int = 0

var write_index: int = 0
var current_size: int = 0
var last_value : Variant = null
var value_type : Variant.Type = TYPE_NIL

var keyframes_modulo: int = 30
var precision: float = 0.001
var bytes_per_delta: int = 4
var component_count: int = 0
var initialized: bool = false

var bytes_for_keyframe: int = 0
var bytes_for_delta: int = 0
var block_size: int = 0
var block_count: int = 0

# Holds the block currently being recorded. It is only merged into `values`
# once fully written, so a block in `values` is always internally consistent
# (its keyframe and all its deltas always come from the same recording pass).
var staging_block: PackedByteArray = PackedByteArray()

func add_value(value) -> void:
	if not initialized:
		create_buffer(typeof(value))
	write_value(value)
	write_index += 1
	if write_index >= frames_to_store:
		write_index = 0
	current_size = min(current_size + 1, frames_to_store)
	last_value = value

func get_value_n_frames_ago(n : int):
	if n >= current_size or n < 0:
		return null
	var read_index = write_index - 1 - n
	read_index = posmod(read_index, frames_to_store)
	return read_value(read_index)

func create_buffer(type: Variant.Type) -> void:
	value_type = type
	if value_type == TYPE_BOOL:
		precision = 1.0
		bytes_per_delta = 1
	component_count = get_component_count(type)
	bytes_for_keyframe = 1 + component_count * 4
	bytes_for_delta =  1 + component_count * bytes_per_delta
	block_size = bytes_for_keyframe + (keyframes_modulo - 1) * bytes_for_delta
	block_count = frames_to_store/keyframes_modulo
	
	values.resize(block_size * block_count)
	staging_block.resize(block_size)
	initialized = true

func write_value(value: Variant) -> void:
	var components := to_components(value)
	
	var pos_in_block: int = posmod(write_index, keyframes_modulo)
	var local_offset: int = 0
	if pos_in_block != 0:
		local_offset = bytes_for_keyframe + (pos_in_block - 1) * bytes_for_delta
	
	if pos_in_block == 0:
		staging_block[local_offset] = 1
		for i in range(component_count):
			staging_block.encode_float(local_offset + 1 + i * 4, components[i])
	else:
		staging_block[local_offset] = 0
		var previous := to_components(last_value)
		for i in range(component_count):
			var quantized := roundi((components[i] - previous[i]) / precision)
			match bytes_per_delta:
				1:
					staging_block.encode_s8(local_offset + 1 + i * bytes_per_delta, quantized)
				2:
					staging_block.encode_s16(local_offset + 1 + i * bytes_per_delta, quantized)
				4:
					staging_block.encode_s32(local_offset + 1 + i * bytes_per_delta, quantized)
				_:
					push_error("Bytes per delta incorrect. Check what you're trying to record")
	
	# The block is complete: commit it to the main buffer in one shot so
	# `values` never holds a half-old / half-new block.
	if pos_in_block == keyframes_modulo - 1:
		var current_block: int = posmod(write_index / keyframes_modulo, block_count)
		var block_offset: int = current_block * block_size
		for i in range(block_size):
			values[block_offset + i] = staging_block[i]

func read_value(index: int):
	# Find the nearest keyframe at or before the requested frame, then walk
	# forward through the deltas. Since keyframes are frequent, this is
	# bounded by keyframes_modulo.
	var current_block: int = posmod(index / keyframes_modulo, block_count)
	var pos_in_block: int = posmod(index, keyframes_modulo)
	
	var active_block: int = posmod(write_index / keyframes_modulo, block_count)
	var active_local_pos: int = posmod(write_index, keyframes_modulo)
	
	var source: PackedByteArray
	var block_offset: int
	
	if current_block == active_block and pos_in_block < active_local_pos:
		# Already recorded this pass, but not committed to `values` yet:
		# read it straight out of the staging block.
		source = staging_block
		block_offset = 0
	else:
		# Either a fully committed block, or a position in the active block
		# that hasn't been overwritten this pass yet (still holds the
		# previous, fully consistent recording pass).
		source = values
		block_offset = current_block * block_size
	
	var keyframe_values := decode_keyframe_components(source, block_offset)
	
	var idx: int = block_offset + bytes_for_keyframe
	var delta_values: Array
	for i in range(pos_in_block):
		delta_values = decode_delta_components(source, idx)
		for c in range(component_count):
			keyframe_values[c] += delta_values[c] * precision
		idx += bytes_for_delta
	
	return from_components(keyframe_values)

func decode_keyframe_components(source: PackedByteArray, index: int) -> Array:
	var result: Array = []
	for i in range(component_count):
		result.append(source.decode_float(index + 1 + i * 4))
	return result
	
func decode_delta_components(source: PackedByteArray, index: int) -> Array:
	var result: Array = []
	for i in range(component_count):
		match bytes_per_delta:
			1:
				result.append(source.decode_s8(index + 1 +  i * bytes_per_delta))
			2:
				result.append(source.decode_s16(index + 1  +  i * bytes_per_delta))
			4:
				result.append(source.decode_s32(index + 1  +  i * bytes_per_delta))
			_:
				return []
	return result

func get_component_count(type: Variant.Type) -> int:
	match type:
		TYPE_FLOAT, TYPE_INT, TYPE_BOOL:
			return 1
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return 2
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return 3
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION:
			return 4
		_:
			return 0

func to_components(value: Variant) -> Array:
	match typeof(value):
		TYPE_BOOL:
			return [1.0 if value else 0.0]
		TYPE_INT:
			return [int(value)]
		TYPE_FLOAT:
			return [float(value)]
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [float(value.x), float(value.y)]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [float(value.x), float(value.y), float(value.z)]
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION:
			return [float(value.x), float(value.y), float(value.z), float(value.w)]
	return []

func from_components(a: Array):
	match value_type:
		TYPE_BOOL:
			return bool(a[0])
		TYPE_INT:
			return int(a[0])
		TYPE_FLOAT:
			return float(a[0])
		TYPE_VECTOR2:
			return Vector2(a[0], a[1])
		TYPE_VECTOR2I:
			return Vector2i(roundi(a[0]), roundi(a[1]))
		TYPE_VECTOR3:
			return Vector3(a[0], a[1], a[2])
		TYPE_VECTOR3I:
			return Vector3i(roundi(a[0]), roundi(a[1]), roundi(a[2]))
		TYPE_QUATERNION:
			return Quaternion(a[0], a[1], a[2], a[3])
		TYPE_VECTOR4:
			return Vector4(a[0], a[1], a[2], a[3])
		TYPE_VECTOR4I:
			return Vector4i(roundi(a[0]), roundi(a[1]), roundi(a[2]), roundi(a[3]))
	return null

func get_size() -> int:
	return values.size() + staging_block.size()
	
func reset() -> void:
	initialized = false
	values = PackedByteArray()
	staging_block = PackedByteArray()
	last_value = null
	write_index = 0
	current_size = 0

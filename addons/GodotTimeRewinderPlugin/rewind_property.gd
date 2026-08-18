class_name RewindResource extends Resource

@export var node_path: NodePath = ""
@export var property_name: String = ""
var raw_values : Variant = null
var frames_to_store: int = 0

var write_index: int = 0
var current_size: int = 0
var value_type : Variant.Type = TYPE_NIL

func add_value(value) -> void:
	if value_type == TYPE_NIL:
		create_buffer(value)
	raw_values[write_index] = value
	write_index += 1
	if write_index >= frames_to_store:
		write_index = 0
	current_size = min(current_size + 1, frames_to_store)

func get_value_n_frames_ago(n : int):
	print(str(node_path) + " " + str(n))
	if n >= current_size or n < 0:
		return null
	var read_index = write_index - 1 - n
	if read_index < 0:
		read_index += frames_to_store
	
	return raw_values[read_index]

func peek_last_value():
	if current_size == 0:
		return null
	if write_index - 1 < 0:
		return raw_values[frames_to_store - 1]
	else:
		return raw_values[write_index - 1]

func create_buffer(value):
	value_type = typeof(value)
	match value_type:
		TYPE_INT:
			raw_values = PackedInt64Array()
		TYPE_FLOAT:
			raw_values = PackedFloat64Array()
		TYPE_VECTOR2, TYPE_VECTOR2I:
			raw_values = PackedVector2Array()
		TYPE_VECTOR3, TYPE_VECTOR3I:
			raw_values = PackedVector3Array()
		TYPE_QUATERNION, TYPE_VECTOR4, TYPE_VECTOR4I:
			raw_values = PackedVector4Array()
		TYPE_STRING:
			raw_values = PackedStringArray()
		_:
			raw_values = Array()
	raw_values.resize(frames_to_store)

func get_size() -> int:
	return var_to_bytes(raw_values).size()
	
func reset() -> void:
	raw_values = null
	value_type = TYPE_NIL
	write_index = 0
	current_size = 0
	

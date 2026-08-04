class_name RewindResource extends Resource

@export var node_path: NodePath
@export var property_name: String = ""
var values
var frames_to_store: int = 0

var write_index: int = 0
var current_size: int = 0
var last_value
var value_type : Variant.Type = TYPE_NIL

func add_value(value):
	if value_type == TYPE_NIL:
		create_buffer(value)
	values[write_index] = value
	write_index += 1
	if write_index >= frames_to_store:
		write_index = 0
	current_size = min(current_size + 1, frames_to_store)

func get_value_n_frames_ago(n : int):
	print(n)
	if n >= current_size or n <= 0:
		return null
	var index = write_index - 1 - n
	if index < 0:
		index += frames_to_store
	
	return values[index]

func peek_last_value():
	if current_size == 0:
		return null
	if write_index - 1 < 0:
		return values[frames_to_store - 1]
	else:
		return values[write_index - 1]

func create_buffer(value):
	value_type = typeof(value)
	match value_type:
		TYPE_INT:
			values = PackedInt64Array()
		TYPE_FLOAT:
			values = PackedFloat32Array()
		TYPE_VECTOR2:
			values = PackedVector2Array()
		TYPE_VECTOR3:
			values = PackedVector3Array()
		TYPE_QUATERNION:
			values = PackedVector4Array()
		_:
			values = Array()
	values.resize(frames_to_store)

func get_size() -> int:
	return var_to_bytes(values).size()

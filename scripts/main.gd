extends Node3D

@onready var time_rewinder := %TimeRewinder
@onready var soft_body := $Moving/Ball2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("rewind"):
		if time_rewinder.rewinding:
			time_rewinder.stop_rewind()
		else:
			time_rewinder.rewind()
	if Input.is_action_just_pressed("add"):
		time_rewinder.add_rewindable_node(soft_body.get_path(), ["position", "rotation"] as Array[String])

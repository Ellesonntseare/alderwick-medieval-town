extends Node3D
# Retains the source pack's descriptive fields without requiring its C# editor plugin.
@export var Piece: String = ""
@export var Props: Dictionary[String, String] = {}
@export var BlenderSlots: PackedInt32Array = PackedInt32Array()

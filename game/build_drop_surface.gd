extends Control
var editor: Node
func _can_drop_data(at: Vector2,data: Variant) -> bool:
	return data is Dictionary and data.has("town_asset") and editor.world_point(at)!=null
func _drop_data(at: Vector2,data: Variant) -> void:
	editor.place(data.town_asset,editor.world_point(at))

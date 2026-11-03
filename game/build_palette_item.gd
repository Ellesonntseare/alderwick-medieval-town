extends Button
var editor: Node
var asset_id:=""
func _get_drag_data(_at: Vector2) -> Variant:
	var preview:=Label.new();preview.text=text
	set_drag_preview(preview)
	return {"town_asset":asset_id}

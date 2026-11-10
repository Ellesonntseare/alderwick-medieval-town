extends RefCounted

const STEP := 48.0
const LIMIT := 12
const SPAN := 180.0
var tiles: Dictionary = {}
var order: Array[Vector2i] = []
var hits := 0
var misses := 0

func key(point: Vector3) -> Vector2i:return Vector2i(roundi(point.x / STEP), roundi(point.z / STEP))
func anchor(cell: Vector2i) -> Vector3:return Vector3(cell.x * STEP, 0, cell.y * STEP)
func area(cell: Vector2i) -> Rect2:return Rect2(Vector2(cell) * STEP - Vector2.ONE * SPAN / 2, Vector2.ONE * SPAN)

func find(cell: Vector2i, version: int) -> Texture2D:
	if not tiles.has(cell) or tiles[cell].version != version:
		tiles.erase(cell);order.erase(cell);misses += 1;return null
	hits += 1;order.erase(cell);order.append(cell)
	return tiles[cell].texture

func store(cell: Vector2i, texture: Texture2D, version: int) -> void:
	if not texture:return
	tiles[cell] = {"texture":texture,"version":version};order.erase(cell);order.append(cell)
	while order.size() > LIMIT:tiles.erase(order.pop_front())

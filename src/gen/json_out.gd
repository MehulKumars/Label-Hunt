## Readable JSON for data files people diff: dicts expand one key per line, arrays of scalars stay inline,
## and whole floats are written as ints (Godot parses every JSON number as a float).
class_name JsonOut
extends RefCounted


static func write(path: String, data: Variant) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(stringify(data) + "\n")
	return OK


static func stringify(v: Variant, indent: String = "") -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				return "{}"
			var inner := indent + "  "
			var parts: Array[String] = []
			for k in d:
				parts.append(inner + JSON.stringify(str(k)) + ": " + stringify(d[k], inner))
			return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a: Array = Array(v)
			if a.is_empty():
				return "[]"
			if a.all(func(x): return typeof(x) not in [TYPE_DICTIONARY, TYPE_ARRAY]) \
					or a.all(func(x): return typeof(x) == TYPE_ARRAY and (x as Array).all(func(y): return typeof(y) not in [TYPE_DICTIONARY, TYPE_ARRAY])):
				return "[" + ", ".join(a.map(func(x): return stringify(x, indent))) + "]"
			var inner := indent + "  "
			var parts: Array[String] = []
			for x in a:
				parts.append(inner + stringify(x, inner))
			return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
		TYPE_FLOAT:
			var f: float = v
			if is_equal_approx(f, roundf(f)) and absf(f) < 1e15:
				return str(int(f))
			return str(snappedf(f, 0.0001))
		_:
			return JSON.stringify(v)

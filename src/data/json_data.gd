extends RefCounted
## Shared JSON contract checks. Reject objects, engine types and precision loss.

static func valid(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= -9007199254740991 and value <= 9007199254740991
		TYPE_FLOAT:
			return is_finite(value) and absf(value) <= 9007199254740991.0
		TYPE_ARRAY:
			for element in value:
				if not valid(element):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if (not key is String and not key is StringName) or not valid(value[key]):
					return false
			return true
	return false

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func seed_value(value: Variant) -> bool:
	return integer(value) and value >= -2147483648 and value <= 2147483647

static func position(value: Variant) -> bool:
	return value is Dictionary and value.keys().size() == 2 and integer(value.get("x")) and integer(value.get("y"))

static func identifier(value: Variant) -> bool:
	if not value is String or value.length() > 128:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*:[a-z0-9_./-]+$")
	return pattern.search(value) != null

static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

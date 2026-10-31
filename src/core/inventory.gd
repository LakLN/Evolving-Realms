extends RefCounted
## Existing B content-ID totals, optionally with stack slots / unique item records.
const Data = preload("res://src/data/json_data.gd")
var last_error := ""

func award(registry: RefCounted, world_id: String, inventory: Dictionary, loot: Array, identity_key: String) -> Dictionary:
	var next := inventory.duplicate(true)
	var received: Array = []
	for index in loot.size():
		var drop: Variant = loot[index]
		if not drop is Dictionary or not Data.identifier(drop.get("content_id")) or not Data.integer(drop.get("version")) or not Data.integer(drop.get("quantity")) or drop.quantity < 1 or drop.quantity > 1000:
			return _error("Invalid inventory award")
		var definition: Dictionary = registry.load_definition(world_id, drop.content_id, int(drop.version))
		if definition.is_empty() or definition.get("kind") != "item" or definition.get("status") != "active":
			return _error("Only active item definitions can enter inventory")
		var payload: Dictionary = definition.payload
		var limit: Variant = payload.get("stack_limit", 1)
		if not Data.integer(limit) or limit < 1 or limit > 1000000 or not payload.get("stackable", limit > 1) is bool:
			return _error("Invalid item stacking rules")
		var stackable: bool = payload.get("stackable", limit > 1)
		var entry: Dictionary = next.get(drop.content_id, {"version": int(drop.version), "quantity": 0}).duplicate(true)
		if entry.version != drop.version:
			return _error("Inventory version conflict; existing version was preserved")
		var before := int(entry.quantity)
		if before < 0 or before + int(drop.quantity) > 1000000:
			return _error("Inventory quantity exceeds supported per-item capacity")
		if stackable:
			if entry.has("stacks") and not entry.stacks is Array:
				return _error("Inventory stack slots must be an array")
			var slots: Array = entry.get("stacks", []).duplicate()
			if not entry.has("stacks"):
				var remaining := before
				while remaining > 0:
					var count := mini(remaining, int(limit))
					slots.append(count)
					remaining -= count
			var total := 0
			for slot in slots:
				if not Data.integer(slot) or slot < 1 or slot > limit:
					return _error("Corrupt inventory stack slots")
				total += int(slot)
			if total != before:
				return _error("Inventory stack total mismatch")
			var remaining := int(drop.quantity)
			for slot in slots.size():
				var count := mini(remaining, int(limit) - int(slots[slot]))
				slots[slot] = int(slots[slot]) + count
				remaining -= count
			while remaining > 0:
				var count := mini(remaining, int(limit))
				slots.append(count)
				remaining -= count
			entry.stacks = slots
		else:
			if before + int(drop.quantity) > 10000 or (entry.has("instances") and not entry.instances is Array):
				return _error("Invalid or excessive individual item records")
			var instances: Array = entry.get("instances", []).duplicate(true)
			if not entry.has("instances"):
				for unit in before:
					instances.append({"instance_id": "item:" + (identity_key.get_slice("/source/", 0) + "/legacy/" + drop.content_id + "/" + str(unit)).sha256_text(), "metadata": {"legacy": true}})
			if instances.size() != before:
				return _error("Inventory instance total mismatch")
			var ids := {}
			for instance in instances:
				if not instance is Dictionary or not Data.identifier(instance.get("instance_id")) or ids.has(instance.instance_id):
					return _error("Invalid or duplicate individual item ID")
				ids[instance.instance_id] = true
			for unit in int(drop.quantity):
				var item_id := "item:" + (identity_key + "/drop/" + str(index) + "/unit/" + str(unit)).sha256_text()
				if ids.has(item_id):
					return _error("This individual item award was already applied")
				var metadata := {"source": identity_key}
				if drop.get("quality") is String:
					metadata.quality = drop.quality # Per-instance quality tier ID.
				instances.append({"instance_id": item_id, "metadata": metadata})
				ids[item_id] = true
			entry.instances = instances
		entry.quantity = before + int(drop.quantity)
		next[drop.content_id] = entry
		var receipt := {"content_id": drop.content_id, "version": int(drop.version), "quantity": int(drop.quantity), "name": definition.name}
		if drop.get("quality") is String:
			receipt.quality = drop.quality
		received.append(receipt)
	last_error = ""
	return {"inventory": next, "received": received}

func remove(inventory: Dictionary, content_id: String, quantity: int) -> Dictionary:
	## Returns a copy with `quantity` units removed ({} + last_error on failure).
	## Takes from the last stack slot / newest individual record first.
	var next := inventory.duplicate(true)
	var entry: Variant = next.get(content_id)
	if not entry is Dictionary or not Data.integer(entry.get("quantity")) or quantity < 1 or quantity > int(entry.quantity):
		return _error("Not enough of this item")
	if entry.has("stacks"):
		var slots: Array = entry.stacks
		var total := 0
		for slot in slots:
			total += int(slot) if Data.integer(slot) else 0
		if total != int(entry.quantity):
			return _error("Inventory stack total mismatch; item not used")
		var remaining := quantity
		while remaining > 0:
			var taken := mini(remaining, int(slots.back()))
			slots[slots.size() - 1] = int(slots.back()) - taken
			remaining -= taken
			if slots.back() == 0:
				slots.pop_back()
	if entry.has("instances"):
		if not entry.instances is Array or entry.instances.size() != int(entry.quantity):
			return _error("Inventory instance total mismatch; item not used")
		entry.instances.resize(entry.instances.size() - quantity)
	entry.quantity = int(entry.quantity) - quantity
	if entry.quantity == 0:
		next.erase(content_id)
	last_error = ""
	return {"inventory": next}

func rows(registry: RefCounted, world_id: String, inventory: Dictionary) -> Array:
	var result: Array = []
	var keys: Array = inventory.keys()
	keys.sort()
	for content_id in keys:
		var entry: Dictionary = inventory[content_id]
		var definition: Dictionary = registry.load_definition(world_id, content_id, int(entry.version))
		if definition.is_empty():
			continue
		var raw_limit: Variant = definition.payload.get("stack_limit", 1)
		var limit := int(raw_limit) if Data.integer(raw_limit) and raw_limit > 0 else 1
		var flag: Variant = definition.payload.get("stackable", limit > 1)
		var stackable: bool = flag if flag is bool else false
		var slots: Variant = entry.get("stacks", []) if stackable else entry.get("instances", [])
		var row := {"content_id": content_id, "version": entry.version, "name": definition.name, "description": definition.description, "type": definition.metadata.get("category", definition.kind), "quantity": entry.quantity, "stackable": stackable, "slots": slots if slots is Array else [], "stack_limit": limit, "definition": definition, "instance_id": "", "metadata": {}}
		if definition.payload.has("equipment") and slots is Array and slots.size() == int(entry.quantity):
			# Equipment: one row per individual instance (each has its own quality).
			for record in slots:
				var single := row.duplicate()
				single.quantity = 1
				single.slots = [record]
				single.instance_id = str(record.get("instance_id", ""))
				single.metadata = record.get("metadata", {})
				result.append(single)
			continue
		result.append(row)
	return result

func _error(message: String) -> Dictionary:
	last_error = message
	return {}

extends RefCounted
## Pure equip/unequip on copies of inventory + equipment. An item instance record
## {instance_id, metadata} moves between an inventory entry's `instances` list and
## character.equipment[slot]; totals are conserved and metadata (quality, source)
## travels with it. Callers apply the returned copies only on success.

static func equip(inventory: Dictionary, equipment: Dictionary, content_id: String, instance_id: String, slot: String) -> Dictionary:
	var next_inventory := inventory.duplicate(true)
	var next_equipment := equipment.duplicate(true)
	var entry: Variant = next_inventory.get(content_id)
	if not entry is Dictionary or not entry.get("instances") is Array or entry.instances.size() != int(entry.get("quantity", -1)):
		return {"error": "That item is not in your inventory"}
	var index := -1
	for i in entry.instances.size():
		if entry.instances[i] is Dictionary and entry.instances[i].get("instance_id") == instance_id:
			index = i
	if index < 0:
		return {"error": "That item is not in your inventory"}
	var record: Dictionary = entry.instances[index]
	entry.instances.remove_at(index)
	entry.quantity = int(entry.quantity) - 1
	var version := int(entry.version)
	if entry.quantity == 0:
		next_inventory.erase(content_id)
	var replaced := {}
	if next_equipment.has(slot):
		replaced = next_equipment[slot]
		var error := _return_to_inventory(next_inventory, replaced)
		if not error.is_empty():
			return {"error": error}
	next_equipment[slot] = {"content_id": content_id, "version": version, "instance_id": instance_id, "metadata": record.get("metadata", {}).duplicate(true)}
	return {"inventory": next_inventory, "equipment": next_equipment, "replaced": replaced}

static func unequip(inventory: Dictionary, equipment: Dictionary, slot: String) -> Dictionary:
	if not equipment.has(slot):
		return {"error": "Nothing is equipped in that slot"}
	var next_inventory := inventory.duplicate(true)
	var next_equipment := equipment.duplicate(true)
	var record: Dictionary = next_equipment[slot]
	next_equipment.erase(slot)
	var error := _return_to_inventory(next_inventory, record)
	if not error.is_empty():
		return {"error": error}
	return {"inventory": next_inventory, "equipment": next_equipment, "removed": record}

static func _return_to_inventory(inventory: Dictionary, record: Dictionary) -> String:
	var entry: Dictionary = inventory.get(record.content_id, {"version": int(record.version), "quantity": 0, "instances": []})
	if int(entry.version) != int(record.version):
		return "Inventory holds another version of this item; nothing was changed"
	if not entry.get("instances") is Array or entry.instances.size() != int(entry.quantity):
		return "Inventory item records are inconsistent; nothing was changed"
	for existing in entry.instances:
		if existing is Dictionary and existing.get("instance_id") == record.instance_id:
			return "Duplicate item instance; nothing was changed"
	entry.instances.append({"instance_id": record.instance_id, "metadata": record.get("metadata", {}).duplicate(true)})
	entry.quantity = int(entry.quantity) + 1
	inventory[record.content_id] = entry
	return ""

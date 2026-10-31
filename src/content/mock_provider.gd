extends RefCounted
## Structured sample only. Registration uses the same path as future AI proposals.

static func herb() -> Dictionary:
	return {
		"content_id": "mock:moonleaf", "schema_version": 1, "version": 1,
		"kind": "item", "name": "Moonleaf", "description": "A silver medicinal leaf.",
		"metadata": {"tags": ["herb"], "rarity": "common"},
		"payload": {"stack_limit": 50}, "dependencies": [],
		"required_capabilities": ["definition.item"],
		"provenance": {"provider": "offline_mock", "origin": "ai"},
	}

static func spirit_egg() -> Dictionary:
	return {
		"content_id": "mock:spirit_egg", "schema_version": 1, "version": 1,
		"kind": "item", "name": "Unhatched Spirit Egg",
		"required_capabilities": ["creature.incubation", "creature.contract"],
		"payload": {"incubation_turns": 100}, "provenance": {"provider": "offline_mock"},
	}

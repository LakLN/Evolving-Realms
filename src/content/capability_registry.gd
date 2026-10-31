extends RefCounted
## Executable vocabulary is derived from engine handlers, never from provider claims.
const Skills = preload("res://src/core/skills.gd")
const Talents = preload("res://src/core/talents.gd")
const Effects = preload("res://src/core/effects.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Locations = preload("res://src/world/world_locations.gd")
const Events = preload("res://src/core/world_events.gd")
const DEFINITIONS := ["definition.item", "definition.resource", "definition.chest", "definition.creature", "definition.item_use", "definition.loot_extension", "definition.talent", "definition.skill", "definition.status", "definition.generation_proposal", "definition.encounter", "definition.region", "definition.location", "definition.world_event"]

static func all_supported() -> Array:
	var result: Array = DEFINITIONS.duplicate()
	for target in Skills.TARGETS:
		result.append("skill.target." + target)
		for effect in Skills.TARGETS[target]: result.append("skill.effect.%s.%s" % [target, effect])
	for condition in Skills.CONDITIONS: result.append("skill.condition." + condition)
	for relation in Skills.RELATIONS: result.append("skill.relation." + relation)
	var skills := Skills.new()
	skills.load_rules()
	for resource in skills.resource_ids(): result.append("skill.resource." + resource)
	for trigger in Talents.TRIGGERS:
		result.append("talent.trigger." + trigger)
		for effect in Talents.TRIGGERS[trigger]: result.append("talent.effect.%s.%s" % [trigger, effect])
	for effect in Talents.PASSIVE_EFFECTS: result.append("talent.effect.passive." + effect)
	for condition in Talents.CONDITIONS: result.append("talent.condition." + condition)
	for condition in Talents.AWAKENING_CONDITIONS: result.append("talent.awakening." + condition)
	for element in Effects.rules().elements: result.append("effect.element." + element)
	for tick in ["damage", "heal"]: result.append("effect.tick." + tick)
	for modifier in ["damage", "resistance", "healing", "status_duration", "status_stacks"]: result.append("effect.modifier." + modifier)
	for condition in ["source_status", "target_status", "hp_below_percent", "hp_at_least_percent"]: result.append("effect.condition." + condition)
	for effect in ["heal", "sate", "quench", "apply_status", "cleanse"]: result.append("item.effect." + effect)
	result.append("creature.hit_effect.apply_status")
	for condition in Encounters.CONDITIONS:
		result.append("encounter.condition." + condition)
		result.append("location.condition." + condition)
	for mode in Locations.DISCOVERY: result.append("location.discovery." + mode)
	for trigger in Locations.TRIGGERS: result.append("location.trigger." + trigger)
	for condition in Events.LOCAL_CONDITIONS: result.append("location.condition." + condition)
	for outcome in Events.OUTCOMES: result.append("event.outcome." + outcome)
	return result

static func supports(capability: String) -> bool:
	return capability in all_supported()

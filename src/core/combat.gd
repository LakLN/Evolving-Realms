extends RefCounted
## Deterministic combat rules shared by the player and every creature.
## Combatants are plain stat dictionaries {hp, max_hp, attack, defense}. Future
## weapons, skills, talents, status effects or resistances should derive these
## stats (or extend resolve) here — never inside UI or species-specific code.
const Loot = preload("res://src/core/loot_table.gd")
const Data = preload("res://src/data/json_data.gd")
const PLAYER_DEFAULTS := {"max_hp": 30, "attack": 5, "defense": 1}
const STAT_LIMIT := 100000

static func valid_stats(stats: Variant, require_hp: bool = false) -> bool:
	if not stats is Dictionary:
		return false
	for key in ["max_hp", "attack", "defense"]:
		if not Data.integer(stats.get(key)) or stats[key] < 0 or stats[key] > STAT_LIMIT:
			return false
	if stats.max_hp < 1 or (require_hp and (not Data.integer(stats.get("hp")) or stats.hp < 0 or stats.hp > stats.max_hp)):
		return false
	return true

static func player_stats(stats: Dictionary) -> Dictionary:
	## Normalized copy: missing combat keys get defaults; unrelated keys are kept.
	var result := stats.duplicate(true)
	for key in PLAYER_DEFAULTS:
		if not result.has(key):
			result[key] = PLAYER_DEFAULTS[key]
	if not result.has("hp"):
		result.hp = result.max_hp
	return result

static func resolve(attacker: Dictionary, defender: Dictionary, key: String) -> Dictionary:
	## damage = max(1, attack + variance - defense); variance in 0..attack/3 from a
	## SHA256 draw of key, so replaying the same action cannot change the result.
	var attack := int(attacker.attack)
	var spread := attack / 3
	var variance := Loot.number(key) % (spread + 1) if spread > 0 else 0
	var damage := maxi(1, attack + variance - int(defender.defense))
	var remaining := maxi(0, int(defender.hp) - damage)
	return {"damage": damage, "variance": variance, "hp": remaining, "killed": remaining == 0}

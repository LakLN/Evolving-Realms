extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Effects = preload("res://src/core/effects.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var path := ProjectSettings.globalize_path("user://m02f-" + Data.uuid() + ".sqlite")
	var store := Store.new()
	check(store.open(path), "Open real SQLite database")
	var world: Dictionary = store.create_world("Effects", 1847, 1, Pack.blueprint(1847))
	var a := Session.new(store)
	a.auto_awaken = false
	if not a.start_new(world.world_id, 101, "forest"):
		check(false, "Start: " + a.last_error)
		quit(1)
		return
	a.autosave_interval = 0
	var source := {"content_id": "core:skill/ember", "version": 1, "actor": "player"}
	var burn := {"type": "apply_status", "content_id": "core:status/burn", "version": 1}
	var regen := {"type": "apply_status", "content_id": "core:status/regeneration", "version": 1}
	check(a.skill_catalog.supported.has("core:skill/ember@1") and a.skill_catalog.books.has("core:book/purify@1"), "New skills and pinned books supported")
	var fire := {"modifiers": [{"type": "damage", "element": "fire", "percent": 50}], "hp": 10, "max_hp": 20}
	var resist := {"modifiers": [{"type": "resistance", "element": "fire", "percent": 50}, {"type": "resistance", "element": "ice", "percent": -50}]}
	check(Effects.damage(20, ["fire"], fire, resist) == 15 and Effects.damage(20, ["ice"], fire, resist) == 30 and Effects.damage(20, ["fire", "ice"], {}, resist) == 20, "Ordered outgoing bonus, resistance/weakness and mixed elements")
	check(Effects.damage(20, ["fire"], {}, {"modifiers": [{"type": "resistance", "element": "fire", "percent": 500}]}) == 0, "Resistance is capped; no negative damage")
	var unknown := a._definition("core:status/burn", 1).duplicate(true)
	unknown.payload.tick.type = "execute_script"
	check("effect.tick.execute_script" in Effects.classify(unknown).missing, "Unknown tick retained as named pending capability")
	var malformed := burn.duplicate()
	malformed.version = 1
	check(not Effects.check_application(malformed, {"dependencies": []}, store.content, world.world_id, []).is_empty(), "Missing pinned status dependency is explicit")
	var defense_before: int = a.combat_stats().defense
	for _i in 3: a.statuses.apply(a, {"type": "apply_status", "content_id": "core:status/ward", "version": 1}, source, "player")
	check(a.combat_stats().defense == defense_before + 3, "Refreshing a capped stat buff never stacks derived stats")
	a.statuses.cleanse(a, "player", false)
	check(a.combat_stats().defense == defense_before, "Dispel removes the derived buff exactly once")
	var creature := place(a)
	if creature.is_empty():
		check(false, "Place real creature")
		quit(1)
		return
	var id: String = creature.instance_id
	for _i in 5: a.statuses.apply(a, burn, source, id)
	check(creature.statuses.size() == 1 and creature.statuses[0].stacks == 3 and creature.statuses[0].remaining == 4, "Repeated applications cap stacks and refresh duration")
	a.statuses.cleanse(a, id)
	a.statuses.apply(a, regen, source, "player")
	a.stats().hp = 5
	var before: int = a.stats().hp
	check(a.wait_turn() and int(a.stats().hp) == before + 3 and a.run.state.character.statuses[0].remaining == 3, "HoT ticks once on accepted turn and ages once")
	before = a.stats().hp
	a.statuses.tick(a)
	a.statuses.finish_turn(a)
	check(a.stats().hp == before and a.run.state.character.statuses[0].remaining == 3, "Repeated tick/finish cannot duplicate healing or age twice")
	a.statuses.apply(a, burn, source, "player")
	a.run.state.character.statuses = a.run.state.character.statuses.filter(func(s: Dictionary) -> bool: return s.id != "core:status/regeneration")
	a.stats().hp = 20
	var inventory_before: Dictionary = a.run.state.inventory.duplicate(true)
	var award := Inventory.new().award(store.content, world.world_id, a.run.state.inventory, [{"content_id": "core:cinder_ring", "version": 1, "quantity": 1}], "test:ring")
	a.run.state.inventory = award.inventory
	var entry: Dictionary = a.run.state.inventory["core:cinder_ring"]
	var gear: Dictionary = entry.instances[0]
	a.run.state.character.equipment.accessory = {"content_id": "core:cinder_ring", "version": 1, "instance_id": gear.instance_id, "metadata": gear.metadata}
	a.run.state.inventory.erase("core:cinder_ring")
	a.refresh_stats()
	check(a.wait_turn() and a.stats().hp == 19, "Real worn gear halves player burn tick")
	a.statuses.cleanse(a, "player")
	a.statuses.apply(a, burn, source, id)
	check(creature.statuses[0].remaining == 6 and creature.statuses[0].inputs.max_stacks == 4, "Gear affects duration and stack capacity with saved inputs")
	check(not a.statuses.react(a, id, ["water"]).is_empty() and creature.statuses.is_empty(), "Water removes burn through data-driven reaction")
	# Creature stat debuff and blocked decisions use the same records as player.
	var slow := {"type": "apply_status", "content_id": "core:status/slow", "version": 1}
	a.statuses.apply(a, slow, source, id)
	check(int(a.roster.creature_stats(a, creature).attack) <= int(creature.definition.payload.stats.attack), "Creature debuff derives effective attack")
	a.statuses.cleanse(a, id)
	a.statuses.apply(a, {"type": "apply_status", "content_id": "core:status/stun", "version": 1}, source, "player")
	var pos: Vector2i = a.position
	var turn: int = a.run.state.turn
	check(a.try_move(Vector2i.RIGHT) and a.position == pos and int(a.run.state.turn) == turn + 1, "Stun consumes a turn without moving; player can recover")
	a.wait_turn()
	check(not Effects.has_status(a.run.state.character.statuses, "core:status/stun"), "Stun expires after two decisions")
	# Snapshot existing systems together; repeated load must never execute effects.
	a.statuses.apply(a, burn, source, id)
	a.statuses.apply(a, regen, source, "player")
	a.dirty = true
	check(a.save(), "Save active player and creature statuses: " + a.last_error)
	var snapshot: Dictionary = a.run.state.duplicate(true)
	var run_id: String = a.run.run_id
	for _i in 2:
		var resumed := Session.new(store)
		resumed.auto_awaken = false
		check(resumed.resume(run_id) and Acceptance.same(resumed.run.state, snapshot), "Resume preserves HP, source, stacks, duration and counters without a tick")
	var b := Session.new(store)
	b.auto_awaken = false
	check(b.start_new(world.world_id, 202) and b.run.state.character.statuses.is_empty() and b.run.state.entity_mutations.is_empty(), "Run B starts without A's statuses or creature mutations")
	# Real low-HP talent trigger creates HoT once, shares the bounded talent engine.
	b.autosave_interval = 0
	b.run.state.character.talents = [b.talent_rules.record(b.talent_definition("core:talent/ember_heart", 1), 0, int(b.run.state.turn))]
	b.reload_talents()
	b.stats().hp = 5
	b.wait_turn()
	check(b.run.state.character.statuses.size() == 1 and b.run.state.character.statuses[0].remaining == 4 and b.stats().hp == 5, "Low HP talent applies HoT after tick; no immediate second tick or aging")
	b.wait_turn()
	check(b.stats().hp == 8 and b.run.state.character.statuses[0].remaining == 3 and b.run.state.character.talents[0].state.rekindle.used == 1, "Talent HoT ticks next turn; cooldown prevents trigger loop")
	b.talents.resolving = true
	check(b.talents.fire("on_turn", b._talent_context("recursive")).is_empty(), "Shared trigger guard blocks recursive status activation")
	b.talents.resolving = false
	var passive: Dictionary = b.skill_definition("core:skill/searing_wounds", 1)
	check(b.skills.learn(b, passive, {"kind": "test"}).is_empty(), "Learn conditional effect passive through normal API")
	var low: Dictionary = b.statuses.actor(b, "player")
	var bleeding := {"statuses": [{"id": "core:status/bleed"}, {"id": "core:status/burn"}]}
	check(Effects.damage(10, ["fire"], low, bleeding) == 20 and Effects.damage(10, ["fire"], low, {"statuses": []}) == 10, "Talent and skill damage bonuses add only when target conditions match")
	b.stats().hp = 5
	b.wait_turn()
	check(b.stats().hp == 9, "Low-HP passive strengthens actual HoT tick")
	var tonic := Inventory.new().award(store.content, world.world_id, b.run.state.inventory, [{"content_id": "core:renewal_tonic", "version": 1, "quantity": 1}], "test:tonic")
	b.run.state.inventory = tonic.inventory
	check(b.use_item("core:renewal_tonic") and not b.run.state.inventory.has("core:renewal_tonic"), "Consumable uses the shared status path and is consumed once")
	check(Acceptance.same(store.load_world(world.world_id), world), "Status actions leave World Blueprint unchanged")
	store.close()
	store = Store.new()
	store.open(path)
	var restarted := Session.new(store)
	restarted.auto_awaken = false
	check(restarted.resume(run_id) and Acceptance.same(restarted.run.state, snapshot), "Reopened SQLite restores exact active status state")
	# A DoT kill goes through normal loot/XP exactly once, never on_attack.
	creature = restarted.roster.creatures[id]
	creature.hp = 1
	restarted.statuses.cleanse(restarted, "player", false)
	var xp_before: int = restarted.run.state.character.progression.adventurer.xp
	check(restarted.wait_turn() and creature.dead and restarted.last_events.filter(func(e: Dictionary) -> bool: return e.type == "creature_death" and e.target == id).size() == 1, "DoT can kill through shared combat reward path")
	var rewarded: Dictionary = restarted.run.state.inventory.duplicate(true)
	var xp_after: int = restarted.run.state.character.progression.adventurer.xp
	restarted.wait_turn()
	check(Acceptance.same(rewarded, restarted.run.state.inventory) and restarted.run.state.character.progression.adventurer.xp == xp_after and xp_after != xp_before, "Dead creature never ticks or grants loot/XP twice")
	check(restarted.statuses.apply(restarted, burn, source, id).is_empty(), "Dead target rejects status")
	# Reject corrupt status with save untouched, rather than reinterpreting it.
	var broken: Dictionary = snapshot.duplicate(true)
	broken.character.statuses[0].remaining = -1
	var saved: Dictionary = store.load_run(run_id)
	check(store.save_run(run_id, int(saved.revision), broken), "Store retains structurally valid JSON for feature validation")
	var rejected := Session.new(store)
	check(not rejected.resume(run_id) and "status" in rejected.last_error.to_lower(), "Corrupt status fails explicit session validation")
	# Authored fixture uses the real registry/roster, without changing procedural species.
	var c := Session.new(store)
	c.auto_awaken = false
	check(c.start_new(world.world_id, 303, "forest"), "Start combat effect fixture run")
	c.autosave_interval = 0
	var species: Dictionary = store.content.load_definition(world.world_id, "core:wolf", 1).duplicate(true)
	species.content_id = "test:venom_wolf"
	species.name = "Venom fixture"
	species.payload.erase("spawn")
	species.payload.stats = {"max_hp": 40, "attack": 1, "defense": 0}
	species.payload.elements = ["fire"]
	species.payload.effect_modifiers = [{"type": "resistance", "element": "fire", "percent": 50}]
	species.payload.on_hit_effects = [{"type": "apply_status", "content_id": "core:status/poison", "version": 1}]
	species.dependencies.append({"content_id": "core:status/poison", "version": 1})
	check(not store.content.register_definition(world.world_id, species).is_empty(), "Register a pinned authored creature with hit status and resistance")
	var target_tile := c.position
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if c.terrain.walkable(c.position + direction):
			target_tile = c.position + direction
			break
	var instance := {"instance_id": "test:effect_creature", "content_id": "test:venom_wolf", "version": 1, "position": {"x": target_tile.x, "y": target_tile.y}, "origin": "authored", "metadata": {}}
	var enemy: Dictionary = c.roster._runtime(instance)
	c.roster.creatures[instance.instance_id] = enemy
	check(c.skills.learn(c, c.skill_definition("core:skill/ember", 1), {"kind": "test"}).is_empty() and c.perform_action({"type": "skill", "skill_id": "core:skill/ember", "target_id": instance.instance_id}), "Cast actual elemental strike and status on a living creature")
	check(enemy.hp < 40 and enemy.statuses.size() == 1 and c.skills.resource(c, "energy") == 17, "Skill applies burn and damage, pays energy once")
	check(Effects.has_status(c.run.state.character.statuses, "core:status/poison") and c.run.state.character.statuses[0].remaining == 5, "Creature hit uses shared status engine after tick without early aging")
	check(c.save(), "Save creature-sourced status: " + c.last_error)
	var d := Session.new(store)
	check(d.resume(c.run.run_id) and d.run.state.character.statuses[0].source.actor == instance.instance_id, "Creature source identity survives save and reload")
	var invalid_creature: Dictionary = store.load_run(c.run.run_id)
	invalid_creature.state.entity_mutations[instance.instance_id].statuses = null
	check(store.save_run(c.run.run_id, int(invalid_creature.revision), invalid_creature.state), "Store malformed creature-status fixture")
	var invalid_session := Session.new(store)
	check(not invalid_session.resume(c.run.run_id) and "creature" in invalid_session.last_error.to_lower(), "Malformed creature status returns a normal load error without crashing")
	# Restore the valid snapshot before checking pending content.
	var invalid_revision: int = store.load_run(c.run.run_id).revision
	store.save_run(c.run.run_id, invalid_revision, c.run.state)
	var perma := Session.new(store)
	perma.auto_awaken = false
	check(perma.start_new(world.world_id, 404, "meadow", "permadeath"), "Start permadeath status fixture")
	var draught := Inventory.new().award(store.content, world.world_id, perma.run.state.inventory, [{"content_id": "core:cinder_draught", "version": 1, "quantity": 1}], "test:perma-draught")
	perma.run.state.inventory = draught.inventory
	perma.dirty = true
	perma.save()
	var revision_before: int = perma.run.revision
	check(perma.use_item("core:cinder_draught") and int(perma.run.revision) == revision_before + 1 and not perma.dirty, "Permadeath commits a DoT-damage turn immediately even at high HP")
	var perma_saved: Dictionary = store.load_run(perma.run.run_id)
	check(perma_saved.state.character.stats.hp == perma.stats().hp and not perma_saved.state.inventory.has("core:cinder_draught"), "Committed damage, item consumption and statuses stay atomic")
	var future_status: Dictionary = store.content.load_definition(world.world_id, "core:status/burn", 1).duplicate(true)
	future_status.content_id = "test:future_status"
	future_status.payload.tick.type = "chain_damage"
	store.content.register_definition(world.world_id, future_status)
	var future_skill: Dictionary = c.skill_definition("core:skill/ember", 1).duplicate(true)
	future_skill.content_id = "test:future_skill"
	future_skill.dependencies = [{"content_id": "test:future_status", "version": 1}]
	future_skill.payload.effects = [{"type": "apply_status", "content_id": "test:future_status", "version": 1}]
	store.content.register_definition(world.world_id, future_skill)
	var pending := Session.new(store)
	check(pending.resume(c.run.run_id) and not pending.skill_catalog.supported.has("test:future_skill@1") and pending.skill_catalog.pending.any(func(e: Dictionary) -> bool: return e.content_id == "test:future_skill" and "effect.tick.chain_damage" in e.missing), "Unknown referenced status mechanic stays pending with named requirement")
	var skill_count: int = pending.run.state.character.skills.size()
	check(not pending.skills.learn(pending, pending.skill_definition("test:future_skill", 1), {"kind": "test"}).is_empty() and pending.run.state.character.skills.size() == skill_count, "Pending status skill cannot be learned or executed")
	store.close()
	print("M02 CHECKPOINT F EFFECTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func place(session: RefCounted) -> Dictionary:
	var creature := Acceptance.nearest_creature(session, ["neutral", "passive"])
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var tile: Vector2i = session.position + direction
		if not creature.is_empty() and session.terrain.walkable(tile) and session.visible.has(tile) and session.roster.living_at(tile).is_empty():
			creature.position = tile
			return creature
	return {}

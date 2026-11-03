extends RefCounted
## Bounded offline diagnostics; internal target IDs never appear in Knowledge.
static func record(session: RefCounted, event: Dictionary) -> void:
	var saved := event.duplicate(true)
	saved.turn = int(session.run.state.turn)
	if event.get("outcome") == "refused":
		# A refusal must leave the entire gameplay Run state unchanged. Diagnostics
		# wait outside it until an accepted interaction or an explicit atomic save.
		session.pending_interaction_events.append(saved)
		if session.pending_interaction_events.size() > 512: session.pending_interaction_events.pop_front()
	else:
		append(session.run.state, session.pending_interaction_events + [saved])
		session.pending_interaction_events.clear()
	session.dirty = true

static func append(state: Dictionary, events: Array) -> void:
	var character: Dictionary = state.character
	if not character.has("interaction_history"): character.interaction_history = []
	character.interaction_history.append_array(events.duplicate(true))
	if character.interaction_history.size() > 512:
		character.interaction_history = character.interaction_history.slice(-512)

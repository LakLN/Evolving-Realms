"""Write the offline mock provider fixtures used by release acceptance (no network)."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from service.providers import Settings, generate

REQUESTS = {
    "mock_bundle.json": ("checkpoint-g-fixture", "collection", "Create elemental gear and an ability with a conditional affinity"),
    "mock_creature_bundle.json": ("checkpoint-h-fixture", "creature", "A hunting beast for unexplored woodland"),
    "mock_location_bundle.json": ("checkpoint-i-fixture", "location", "A place of old power in unexplored land"),
}

target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".tools/ai"
target.mkdir(parents=True, exist_ok=True)
for name, (request_id, kind, prompt) in REQUESTS.items():
    envelope = generate({"request_id": request_id, "kind": kind, "prompt": prompt, "context": {"version": 1}}, Settings())
    (target / name).write_text(json.dumps(envelope, ensure_ascii=False), encoding="utf-8")
print("Mock fixtures written to", target)

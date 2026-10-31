"""Offline only: deterministic mock, fake local provider, no paid API calls."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from service.providers import Settings, MockProvider, ChatCompletionsProvider, GenerationError, generate, parse_json

ROOT = Path(__file__).resolve().parents[1]
REQUEST = {"request_id": "checkpoint-g-fixture", "kind": "collection",
           "prompt": "Create elemental gear and an ability with a conditional affinity", "context": {"version": 1}}


@contextmanager
def server(mode="ok"):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_POST(self):
            self.server.calls += 1
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            self.server.body = body
            self.server.auth = self.headers.get("Authorization")
            if mode == "delay": time.sleep(0.15)
            self.send_response(503 if mode == "retry" else 401 if mode == "auth" else 200)
            self.end_headers()
            request = json.loads(body["messages"][-1]["content"])
            payload = {"choices": [{"finish_reason": "length" if mode == "incomplete" else "stop",
                                    "message": {"content": json.dumps(MockProvider().generate(request))}}]}
            try: self.wfile.write(json.dumps(payload).encode())
            except OSError: pass
    http = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    http.calls = 0
    thread = threading.Thread(target=http.serve_forever, daemon=True)
    thread.start()
    try: yield http
    finally:
        http.shutdown()
        http.server_close()
        thread.join(2)


def settings(http, **kwargs):
    return Settings(provider="chat_completions", model="test-model", api_key="dummy-not-a-real-key",
                    base_url="http://127.0.0.1:%d/v1" % http.server_port, **kwargs)


class ProvidersTest(unittest.TestCase):
    def test_mock_varies_mechanics_and_writes_gameplay_fixture(self):
        envelope = generate(REQUEST, Settings())
        self.assertEqual(envelope, generate(REQUEST, Settings()))
        other = generate({**REQUEST, "request_id": "different-composition"}, Settings())
        self.assertNotEqual(envelope["content"]["definitions"][0]["payload"], other["content"]["definitions"][0]["payload"])
        self.assertEqual({d["kind"] for d in envelope["content"]["definitions"]}, {"skill", "item", "talent", "creature", "loot_extension"})
        target = ROOT / ".tools/ai/mock_bundle.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(envelope, ensure_ascii=False), encoding="utf-8")

    def test_mock_creature_with_encounter_writes_world_fixture(self):
        request = {"request_id": "checkpoint-h-fixture", "kind": "creature",
                   "prompt": "A hunting beast for unexplored woodland", "context": {"version": 1}}
        envelope = generate(request, Settings())
        definitions = envelope["content"]["definitions"]
        self.assertEqual([d["kind"] for d in definitions], ["item", "creature", "encounter"])
        creature, encounter = definitions[1], definitions[2]
        self.assertNotIn("spawn", creature["payload"])
        self.assertEqual(encounter["payload"]["creature"], {"content_id": creature["content_id"], "version": 1})
        self.assertTrue(set(encounter["payload"]["biomes"]) <= set(creature["payload"]["movement"]["biomes"]))
        target = ROOT / ".tools/ai/mock_creature_bundle.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(envelope, ensure_ascii=False), encoding="utf-8")

    def test_configuration_and_explicit_network_gate(self):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(Settings.from_env().provider, "mock")
        with patch.dict("os.environ", {"ER_AI_PROVIDER": "chat_completions", "ER_AI_API_KEY": "secret"}, clear=True):
            with self.assertRaisesRegex(GenerationError, "configuration"): Settings.from_env()
        with server() as http:
            s = settings(http)
            self.assertNotIn(s.api_key, repr(s))
            with self.assertRaisesRegex(GenerationError, "explicit"): generate(REQUEST, s)
            self.assertEqual(http.calls, 0)

    def test_real_adapter_against_local_protocol_stub(self):
        with server() as http:
            envelope = generate(REQUEST, settings(http), allow_network=True)
            self.assertEqual(envelope["content"]["definitions"], MockProvider().generate(REQUEST)["definitions"])
            self.assertEqual(http.body["response_format"], {"type": "json_object"})
            self.assertEqual(http.body["model"], "test-model")
            self.assertEqual(http.auth, "Bearer dummy-not-a-real-key")
            self.assertNotIn("dummy-not-a-real-key", json.dumps(envelope))

    def test_retries_timeout_and_incomplete_output(self):
        with server("retry") as http:
            with self.assertRaisesRegex(GenerationError, "503"): generate(REQUEST, settings(http, retries=1), True)
            self.assertEqual(http.calls, 2)
        with server("auth") as http:
            with self.assertRaisesRegex(GenerationError, "401"): generate(REQUEST, settings(http, retries=2), True)
            self.assertEqual(http.calls, 1)
        with server("delay") as http:
            with self.assertRaisesRegex(GenerationError, "timed out"): generate(REQUEST, settings(http, timeout=0.03), True)
        with server("incomplete") as http:
            with self.assertRaisesRegex(GenerationError, "incomplete"): generate(REQUEST, settings(http), True)

    def test_bad_json_and_bounded_requests(self):
        for value in ['{"a":1,"a":2}', '{"value":NaN}', "[]", "not json"]:
            with self.assertRaises(GenerationError): parse_json(value)
        with self.assertRaises(GenerationError): generate({**REQUEST, "context": {"huge": "x" * 130000}}, Settings())
        with self.assertRaises(GenerationError): generate({**REQUEST, "kind": "execute_code"}, Settings())


class DeveloperCliTest(unittest.TestCase):
    """The developer tool end to end: real Godot authoring process, temp database, mock provider."""
    GODOT = ROOT / ".tools/godot/Godot_v4.7.2-stable_win64.exe"

    def cli(self, database, *args, ok=True):
        env = {**os.environ, "ER_AI_PROVIDER": "mock", "ER_AI_MODEL": "offline-v1"}
        done = subprocess.run([sys.executable, "-I", str(ROOT / "scripts/generate_content.py"), "--database", str(database), *args],
                              capture_output=True, text=True, encoding="utf-8", env=env, timeout=240)
        self.assertEqual(done.returncode == 0, ok, done.stderr[-400:])
        return json.loads(done.stdout) if ok else done.stderr

    @unittest.skipUnless(GODOT.is_file(), "project-local Godot not installed")
    def test_generate_review_confirm_activate_reject(self):
        with tempfile.TemporaryDirectory(prefix="er-cli-test-") as folder:
            db = Path(folder) / "lab.sqlite"
            world = self.cli(db, "init")["world_id"]
            draft = self.cli(db, "generate", "--world", world, "--kind", "equipment", "--prompt", "A frost-warding mantle", "--request-id", "cli-e2e")
            proposal = draft["content_id"]
            self.assertEqual((draft["payload"]["stage"], draft["payload"]["report"]["status"]), ("draft", "valid"))
            self.assertEqual(self.cli(db, "review", "--world", world, "--proposal", proposal)["current_validation"]["status"], "valid")
            self.assertIn("Confirm the proposal", self.cli(db, "activate", "--world", world, "--proposal", proposal, ok=False))
            self.assertEqual(self.cli(db, "registered", "--world", world)["registered"], [])
            self.cli(db, "confirm", "--world", world, "--proposal", proposal)
            self.assertEqual(self.cli(db, "activate", "--world", world, "--proposal", proposal)["payload"]["stage"], "activated")
            registered = self.cli(db, "registered", "--world", world)["registered"]
            self.assertTrue(registered and all(entry["proposal"] == proposal and entry["status"] == "active" for entry in registered))
            self.assertIn("cannot be rejected", self.cli(db, "reject", "--world", world, "--proposal", proposal, ok=False))
            summary = self.cli(db, "proposals", "--world", world)["proposals"]
            self.assertEqual([(p["proposal"], p["stage"], p["validation"]) for p in summary], [(proposal, "activated", "valid")])


if __name__ == "__main__":
    unittest.main()

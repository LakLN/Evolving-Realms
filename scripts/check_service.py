"""Boot the real optional HTTP service and verify its health contract."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import urlopen, Request

root = Path(__file__).resolve().parents[1]
with socket.socket() as probe:
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
process = subprocess.Popen(
    [sys.executable, "-E", "-m", "uvicorn", "service.app:app", "--host",
     "127.0.0.1", "--port", str(port)], cwd=root,
    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
    env={**os.environ, "ER_AI_PROVIDER": "mock", "ER_AI_MODEL": "offline-v1"},
)
try:
    deadline = time.monotonic() + 20
    while True:
        if process.poll() is not None:
            raise RuntimeError(process.stderr.read().decode(errors="replace"))
        try:
            with urlopen(f"http://127.0.0.1:{port}/health", timeout=1) as response:
                assert response.status == 200
                assert json.load(response) == {
                    "status": "ok", "provider": "none", "schema_version": 1,
                }
            break
        except (URLError, TimeoutError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)
    print("PASS: real FastAPI HTTP startup and health response")
    body = {"request_id": "http-offline-test", "kind": "skill", "prompt": "Create an elemental field technique", "context": {"version": 1}}
    with urlopen(Request(f"http://127.0.0.1:{port}/generate", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}), timeout=10) as response:
        generated = json.load(response)
        assert generated["provenance"]["provider"] == "mock"
        assert generated["content"]["definitions"][0]["kind"] == "skill"
    print("PASS: actual FastAPI generation endpoint uses mock without API costs")

finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    process.stderr.close()

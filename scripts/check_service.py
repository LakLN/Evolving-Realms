"""Boot the real optional HTTP service and verify its health contract."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import urlopen

root = Path(__file__).resolve().parents[1]
with socket.socket() as probe:
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
process = subprocess.Popen(
    [sys.executable, "-E", "-m", "uvicorn", "service.app:app", "--host",
     "127.0.0.1", "--port", str(port)], cwd=root,
    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
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
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    process.stderr.close()

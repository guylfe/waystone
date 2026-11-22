"""Exercise the normal game entry over three processes and one local relay."""

import argparse
import hashlib
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
from threading import Thread
from time import monotonic


REFERENCE = "https://github.com/example/waystone/issues/42"
PROJECT = Path(__file__).resolve().parents[1]


def run(godot: Path) -> None:
    requests = []

    class Relay(BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers["Content-Length"]))
            requests.append((monotonic(), self.path, self.headers["Idempotency-Key"],
                             self.headers.get("Authorization"), body))
            if len(requests) == 1:
                self.send_error(503)
                return
            digest = hashlib.sha256(body).hexdigest()
            receipt = json.dumps({
                "id": self.headers["Idempotency-Key"],
                "sha256": "wrong" if len(requests) == 2 else digest,
                "reference": REFERENCE,
            }).encode()
            self.send_response(201)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(receipt)))
            self.end_headers()
            self.wfile.write(receipt)

    with ThreadingHTTPServer(("127.0.0.1", 0), Relay) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            runtime = PROJECT / ".runtime"
            runtime.mkdir(exist_ok=True)
            with tempfile.TemporaryDirectory(prefix="comment-delivery-", dir=runtime) as case:
                data = Path(case)
                (data / "Roaming").mkdir()
                (data / "Local").mkdir()
                env = dict(os.environ, APPDATA=str(data / "Roaming"), LOCALAPPDATA=str(data / "Local"))
                endpoint = f"http://127.0.0.1:{server.server_port}/comments"
                for phase, expected in [("capture", 1), ("recover", 3), ("readback", 3)]:
                    result = subprocess.run(
                        [str(godot), "--headless", "--path", str(PROJECT),
                         "-s", "res://tests/run_comment_entry_probe.gd",
                         "--", "--loopback", phase, endpoint],
                        env=env, capture_output=True, encoding="utf-8", errors="replace", timeout=40,
                    )
                    print(result.stdout, end="")
                    print(result.stderr, end="")
                    assert result.returncode == 0 and "SCRIPT ERROR" not in result.stderr
                    assert len(requests) == expected, (phase, len(requests))
                _, path, note_id, authorization, body = requests[0]
                assert path == "/comments" and authorization is None
                assert all(request[1:] == requests[0][1:] for request in requests)
                payload = json.loads(body)
                assert payload["id"] == note_id and payload["context"]["mode"] == "expedition"
                assert note_id in [path.stem for path in data.rglob("*.receipt")]
                retry_gap = requests[2][0] - requests[1][0]
                assert 1.8 <= retry_gap < 6.5, retry_gap
                print(f"Relay: 503, stale digest, then valid 201 after {retry_gap:.2f}s."
                      " Same note ID and bytes on all attempts. No request after receipt on relaunch.")
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path, help="Path to the Godot console executable")
    run(parser.parse_args().godot.resolve())

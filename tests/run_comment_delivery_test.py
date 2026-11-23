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
from uuid import UUID


REFERENCE = "https://github.com/guylfe/waystone/issues/42"
LEGACY_REFERENCE = "https://github.com/guylfe/waystone/blob/main/comments/legacy.json"
PROJECT = Path(__file__).resolve().parents[1]


def run(godot: Path) -> None:
    requests = []
    remote_issues = {}

    class Relay(BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers["Content-Length"]))
            requests.append((monotonic(), self.path, self.headers["Idempotency-Key"],
                             self.headers.get("Authorization"), body))
            report_id = self.headers["Idempotency-Key"]
            # Model one GitHub issue being created before the first response
            # fails. Both retry responses describe that same remote write.
            issue = remote_issues.setdefault(report_id, (42, body))
            if len(requests) == 1:
                self.send_error(503)
                return
            receipt = json.dumps({
                "issueNumber": issue[0],
                "issueUrl": REFERENCE.replace("/42", "/43") if len(requests) == 2 else REFERENCE,
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
                origin = f"http://127.0.0.1:{server.server_port}"
                userdata = data / "Roaming" / "Godot" / "app_userdata" / "Waystone Prototype"
                comments = userdata / "run-comments"
                comments.mkdir(parents=True)
                config = userdata / "run-comment-delivery.cfg"
                config.write_text(f'[relay]\nendpoint="{origin}/comments"\ntoken=""\n')
                legacy_files = {}
                for note_id in ("1" * 32, "2" * 32):
                    record = json.dumps({"schema": 1, "id": note_id, "text": "Legacy local note", "context": {}}).encode()
                    legacy_files[comments / f"{note_id}.json"] = record
                    if note_id.startswith("2"):
                        legacy_files[comments / f"{note_id}.receipt"] = json.dumps({
                            "id": note_id, "sha256": hashlib.sha256(record).hexdigest(),
                            "reference": LEGACY_REFERENCE,
                        }).encode()
                for path, contents in legacy_files.items():
                    path.write_bytes(contents)
                for phase, expected in [("capture", 1), ("recover", 3), ("readback", 3)]:
                    result = subprocess.run(
                        [str(godot), "--headless", "--path", str(PROJECT),
                         "-s", "res://tests/run_comment_entry_probe.gd",
                         "--", "--loopback", phase, origin],
                        env=env, capture_output=True, encoding="utf-8", errors="replace", timeout=40,
                    )
                    print(result.stdout, end="")
                    print(result.stderr, end="")
                    assert result.returncode == 0 and "SCRIPT ERROR" not in result.stderr
                    assert len(requests) == expected, (phase, len(requests))
                _, path, note_id, authorization, body = requests[0]
                assert path == "/v1/feedback" and authorization is None
                assert all(request[1:] == requests[0][1:] for request in requests)
                payload = json.loads(body)
                assert UUID(note_id).version == 4
                assert payload == {
                    "game": "waystone", "reportId": note_id, "build": payload["context"]["build"],
                    "note": "n", "context": payload["context"],
                }
                assert payload["build"] and payload["context"]["mode"] == "expedition"
                receipt = json.loads((comments / f"{note_id}.receipt").read_bytes())
                assert receipt["issueNumber"] == 42 and receipt["issueUrl"] == REFERENCE
                assert all(path.read_bytes() == contents for path, contents in legacy_files.items())
                assert f'endpoint="{origin}/comments"' in config.read_text()
                assert remote_issues == {note_id: (42, body)}, remote_issues
                retry_gap = requests[2][0] - requests[1][0]
                assert 1.8 <= retry_gap < 6.5, retry_gap
                print(f"Feedback service: 503 after one write, mismatched issue URL, then valid 201 after {retry_gap:.2f}s."
                      " Same UUID and bytes on all attempts. No request after receipt on relaunch.")
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path, help="Path to the Godot console executable")
    run(parser.parse_args().godot.resolve())

"""Exercise the game UI, restarts and service retry contract on loopback."""

import argparse
from email.utils import formatdate, parsedate_to_datetime
import hashlib
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
from threading import Thread
from time import time
from uuid import UUID


LEGACY_REFERENCE = "https://github.com/guylfe/waystone/blob/main/comments/legacy.json"
OLDER_REPORTS = ("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
PROJECT = Path(__file__).resolve().parents[1]


def run(godot: Path) -> None:
    requests = []
    remote_files = {}
    deadlines = []

    class Relay(BaseHTTPRequestHandler):
        def do_POST(self):
            body = self.rfile.read(int(self.headers["Content-Length"]))
            requests.append((time(), self.path, self.headers["Idempotency-Key"],
                             self.headers.get("Authorization"), body))
            report_id = self.headers["Idempotency-Key"]
            receipt = {}
            retry_after = None
            if report_id in OLDER_REPORTS:
                if report_id == OLDER_REPORTS[0]:
                    status = 409
                else:
                    status = 400
            else:
                # Model one file written before the eventual confirmed receipt.
                remote_files.setdefault(report_id, body)
                if len(requests) == 1:
                    status, retry_after = 202, "4"
                elif len(requests) == 2:
                    status, retry_after = 429, formatdate(int(time()) + 4, usegmt=True)
                elif len(requests) == 3:
                    status, retry_after = 503, "5"
                else:
                    status, receipt = 200, {"game": "waystone", "reportId": report_id,
                                            "filePath": f"playtest-feedback/{report_id}.json"}
            if retry_after is not None:
                deadlines.append(parsedate_to_datetime(retry_after).timestamp() if status == 429 else time() + int(retry_after))
            receipt = json.dumps(receipt).encode()
            self.send_response(status)
            if retry_after is not None:
                self.send_header("Retry-After", retry_after)
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
                def probe(phase, expected):
                    result = subprocess.run(
                        [str(godot), "--headless", "--path", str(PROJECT),
                         "-s", "res://tests/run_comment_entry_probe.gd",
                         "--", "--loopback", phase, origin],
                        env=env, capture_output=True, encoding="utf-8", errors="replace", timeout=40,
                    )
                    print(result.stdout, end="")
                    print(result.stderr, end="")
                    assert result.returncode == 0
                    problems = ("SCRIPT ERROR", "Unicode parsing error")
                    assert all(problem not in result.stdout + result.stderr for problem in problems)
                    assert len(requests) == expected, (phase, len(requests))

                for phase, expected in [("capture", 1), ("recover", 4), ("readback", 4)]:
                    probe(phase, expected)
                _, path, note_id, authorization, body = requests[0]
                assert path == "/v3/feedback" and authorization is None
                assert all(request[1:] == requests[0][1:] for request in requests)
                payload = json.loads(body)
                assert UUID(note_id).version == 4
                assert payload == {
                    "game": "waystone", "reportId": note_id, "build": payload["context"]["game_version"],
                    "note": "n", "context": payload["context"],
                }
                assert payload["build"] and payload["context"]["mode"] == "expedition"
                receipt = json.loads((comments / f"{note_id}.receipt").read_bytes())
                assert receipt["filePath"] == f"playtest-feedback/{note_id}.json"
                assert all(path.read_bytes() == contents for path, contents in legacy_files.items())
                assert f'endpoint="{origin}/comments"' in config.read_text()
                assert remote_files == {note_id: body}, remote_files
                assert all(request[0] >= deadline - 0.10 for request, deadline in zip(requests[1:], deadlines))
                print("202, 429 and 503 all honored Retry-After, including across restart. "
                      "Same UUID and bytes on all attempts. No request after receipt on relaunch.")

                old_files = {}
                old_wire = {}
                for report_id in OLDER_REPORTS:
                    old_context = {
                        "build": "survey-0.3.10-c2349ae-FIXTURE", "game_version": "0.3.10",
                        "seed": "9223372036854775807", "source": "c2349ae-fixture",
                    }
                    old_text = "\U0001f642" * 1001
                    record = {"schema": 2, "id": report_id, "text": old_text,
                              "context": old_context, "send_publicly": True}
                    old_files[comments / f"{report_id}.json"] = json.dumps(record, ensure_ascii=False).encode()
                    # Frozen 0.3.10 envelope. Its build label and supplemental
                    # characters intentionally differ from the new constraints.
                    envelope = {"game": "waystone", "reportId": report_id, "note": old_text,
                                "context": old_context, "build": old_context["build"]}
                    old_wire[report_id] = json.dumps(envelope, ensure_ascii=False,
                                                     separators=(",", ":"), sort_keys=True).encode()
                for path, contents in old_files.items():
                    path.write_bytes(contents)
                for phase, expected in [("terminal", 6), ("terminal_restart", 6)]:
                    probe(phase, expected)
                older_requests = requests[4:]
                assert [request[2] for request in older_requests] == list(OLDER_REPORTS)
                assert all(request[1] == "/v3/feedback" and request[3] is None
                           and request[4] == old_wire[request[2]] for request in older_requests)
                assert all(path.read_bytes() == contents for path, contents in old_files.items())
                for report_id, status in zip(OLDER_REPORTS, (409, 400)):
                    rejected = json.loads((comments / f"{report_id}.v3.rejected").read_bytes())
                    assert rejected["status"] == status
                    assert rejected["sha256"] == hashlib.sha256(old_wire[report_id]).hexdigest()
                print("400 and 409 persisted without more requests. Both schema 2 reports replayed byte-for-byte.")
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path, help="Path to the Godot console executable")
    run(parser.parse_args().godot.resolve())

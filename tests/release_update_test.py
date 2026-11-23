"""Run the actual main scene against local startup-release fixtures."""

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
from threading import Thread
from time import sleep


PROJECT = Path(__file__).resolve().parents[1]
ASSETS = {"Windows": "Waystone-Windows.zip", "Android": "Waystone-Android.apk"}
RELEASES = "https://github.com/guylfe/waystone/releases/"
PAYLOAD = b"Waystone release verification fixture."


def run(godot: Path) -> None:
    requests = []
    scenario = ""
    platform = ""

    class Feed(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append((self.path, self.headers.get("Authorization"),
                             self.headers.get("Cookie"), self.headers.get("Content-Length")))
            if self.path == "/asset":
                if scenario in ("fresh", "foreign-redirect"):
                    self.send_response(302)
                    self.send_header("Location", "https://example.invalid/file" if scenario == "foreign-redirect"
                                     else f"http://127.0.0.1:{self.server.server_port}/cdn")
                    self.end_headers()
                else:
                    sleep(0.45)
                    payload = {"bad-digest": b"x" * len(PAYLOAD), "short": PAYLOAD[:-1]}.get(scenario, PAYLOAD)
                    self.respond(payload)
                return
            if self.path == "/cdn":
                self.respond(PAYLOAD)
                return
            if scenario in ("missing", "http-error"):
                self.send_error(404 if scenario == "missing" else 503)
                return
            if scenario == "timeout":
                sleep(7.0)
                return
            # The normal scene and the player's input must work before this response.
            sleep(0.85)
            tag = {"equal": "v0.3.9", "older": "v0.2.95"}.get(scenario, "v99.0.0")
            filename = ASSETS["Android" if scenario == "wrong-platform" else platform]
            body = json.dumps({
                "tag_name": tag, "draft": False, "prerelease": False,
                "assets": [{"name": filename, "state": "uploaded", "size": len(PAYLOAD),
                            "digest": None if scenario == "missing-digest" else "sha256:" + hashlib.sha256(PAYLOAD).hexdigest(),
                            "browser_download_url": RELEASES + f"download/{tag}/{filename}"}],
            }).encode()
            if scenario == "invalid":
                body = b'{"broken":'
            self.respond(body)

        def respond(self, body):
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass  # Later cancels a download while its response is in flight.

    with ThreadingHTTPServer(("127.0.0.1", 0), Feed) as server, socket.socket() as closed:
        closed.bind(("127.0.0.1", 0))  # Reserved port with no listener.
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            runtime = PROJECT / ".runtime"
            runtime.mkdir(exist_ok=True)
            for scenario, platform in [
                ("campaign", "Windows"), ("fresh", "Windows"), ("resumed", "Android"), ("survey", "Android"),
                ("bad-digest", "Windows"), ("short", "Windows"),
                ("foreign-redirect", "Windows"), ("missing-digest", "Android"),
                ("equal", "Windows"), ("older", "Windows"), ("wrong-platform", "Windows"),
                ("missing", "Windows"), ("invalid", "Windows"), ("http-error", "Windows"),
                ("offline", "Windows"), ("timeout", "Windows"),
            ]:
                prior = len(requests)
                port = closed.getsockname()[1] if scenario == "offline" else server.server_port
                with tempfile.TemporaryDirectory(prefix="release-update-", dir=runtime) as case:
                    data = Path(case)
                    (data / "Roaming").mkdir()
                    (data / "Local").mkdir()
                    env = dict(os.environ, APPDATA=str(data / "Roaming"), LOCALAPPDATA=str(data / "Local"))
                    result = subprocess.run([
                        str(godot), "--headless", "--path", str(PROJECT),
                        "-s", "res://tests/release_update_probe.gd", "--",
                        "--update-loopback", scenario, platform, f"http://127.0.0.1:{port}/releases/latest",
                    ], env=env, capture_output=True, encoding="utf-8", errors="replace", timeout=30)
                print(result.stdout, end="")
                print(result.stderr, end="")
                assert result.returncode == 0 and "ERROR:" not in result.stderr, scenario
                expected = [] if scenario == "offline" else [("/releases/latest", None, None, None)]
                if scenario in ("fresh", "resumed", "survey", "campaign", "bad-digest", "short", "foreign-redirect"):
                    expected.append(("/asset", None, None, None))
                if scenario == "fresh":
                    expected.append(("/cdn", None, None, None))
                assert requests[prior:] == expected, (scenario, requests[prior:])
            print("All discovery and download requests were anonymous GETs, with no cookie or body.")
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path)
    run(parser.parse_args().godot.resolve())

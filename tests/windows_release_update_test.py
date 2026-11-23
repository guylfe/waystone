"""Exercise the Windows updater with two genuine Waystone executable builds."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from zipfile import ZipFile


PROJECT = Path(__file__).resolve().parents[1]
HELPER = PROJECT / "scripts/core/install_windows_update.ps1"


def digest(path):
    with path.open("rb") as stream:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
        return checksum.hexdigest()


def wait_for_relaunch(path):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if path.exists() and "Godot Engine" in path.read_text(encoding="utf-8", errors="replace"):
            return
        time.sleep(0.1)
    raise AssertionError(f"Game did not relaunch: {path}")


def run(candidate, published_zip, published_digest):
    assert digest(published_zip) == published_digest
    shell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    runtime = PROJECT / ".runtime"
    runtime.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="windows-update-", dir=runtime) as temp:
        root = Path(temp)
        install = root / "Guy's disposable install"
        install.mkdir()
        target = install / "Waystone.exe"
        backup = target.with_suffix(".exe.previous")
        with ZipFile(published_zip) as archive:
            with archive.open("Waystone.exe") as source, target.open("wb") as destination:
                shutil.copyfileobj(source, destination)
        old_binary = digest(target)
        new_binary = digest(candidate)
        assert old_binary != new_binary, "pass a candidate built with the update implementation"

        env = dict(os.environ, APPDATA=str(root / "Roaming"), LOCALAPPDATA=str(root / "Local"))
        for key in ("APPDATA", "LOCALAPPDATA"):
            Path(env[key]).mkdir()
        subprocess.run([
            str(target), "--headless", "--log-file", str(root / "fixture.log"), "--", "--survey-smoke",
        ], env=env, timeout=30, check=True)
        save = next(root.rglob("*.save"))
        save_digest = digest(save)
        failure = root / "failure.txt"
        new_archive = root / "candidate.zip"
        with ZipFile(new_archive, "w") as archive:
            archive.write(candidate, "Waystone.exe")

        def replace(name, source, expected_digest, pid=0, succeeds=True):
            asset = root / (name + ".zip")
            shutil.copyfile(source, asset)
            log = root / (name + " game's log.txt")
            config = {
                "executable": str(target), "processId": pid, "asset": str(asset),
                "size": asset.stat().st_size, "sha256": expected_digest, "failure": str(failure),
                "arguments": ["--headless", "--quit-after", "30", "--log-file", str(log)],
            }
            encoded = base64.b64encode(json.dumps(config).encode("utf-8")).decode("ascii")
            command = "& {\n" + HELPER.read_text(encoding="utf-8") + "\n} '" + encoded + "'"
            result = subprocess.run([
                str(shell), "-NoProfile", "-NonInteractive", "-EncodedCommand",
                base64.b64encode(command.encode("utf-16-le")).decode("ascii"),
            ], env=env, capture_output=True, text=True, timeout=40, creationflags=subprocess.CREATE_NO_WINDOW)
            assert (result.returncode == 0) == succeeds, result.stderr
            try:
                wait_for_relaunch(log)
            except AssertionError as error:
                raise AssertionError(f"{error}\n{result.stderr}") from error
            assert digest(save) == save_digest, "existing save changed during replacement or relaunch"
            assert not asset.exists(), "staged update was left behind"

        # Keep the genuine old application running briefly while the helper starts.
        running = subprocess.Popen([
            str(target), "--headless", "--max-fps", "30", "--quit-after", "60",
            "--log-file", str(root / "running old game.log"),
        ], env=env, creationflags=subprocess.CREATE_NO_WINDOW)
        replace("install candidate", new_archive, digest(new_archive), running.pid)
        assert running.wait(timeout=5) == 0
        assert digest(target) == new_binary and digest(backup) == old_binary and not failure.exists()

        replace("wrong digest", published_zip, "0" * 64, succeeds=False)
        assert digest(target) == new_binary and digest(backup) == old_binary and failure.exists()
        failure.unlink()

        unsafe_archive = root / "extra-entry.zip"
        with ZipFile(unsafe_archive, "w") as archive:
            archive.write(candidate, "Waystone.exe")
            archive.writestr("../escaped.txt", "unexpected")
        replace("unexpected layout", unsafe_archive, digest(unsafe_archive), succeeds=False)
        assert digest(target) == new_binary and failure.exists() and not (root / "escaped.txt").exists()
        failure.unlink()

        invalid_archive = root / "unlaunchable.zip"
        with ZipFile(invalid_archive, "w") as archive:
            archive.writestr("Waystone.exe", b"x" * 100)
        replace("rollback", invalid_archive, digest(invalid_archive), succeeds=False)
        assert digest(target) == new_binary and failure.exists(), "previous executable was not restored"
        failure.unlink()

        replace("recover and install official bytes", published_zip, published_digest)
        assert digest(target) == old_binary and digest(backup) == new_binary and not failure.exists()
        assert not list(install.glob("Waystone.exe.next-*"))
        print("Windows updater swapped and relaunched real builds, rejected invalid assets, restored the executable after a launch failure, and preserved the Survey save.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("published_zip", type=Path)
    parser.add_argument("published_digest")
    args = parser.parse_args()
    run(args.candidate.resolve(), args.published_zip.resolve(), args.published_digest.lower().removeprefix("sha256:"))

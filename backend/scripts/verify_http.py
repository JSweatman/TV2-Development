"""Start the fixture resolver and verify a real localhost HTTP journey."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.parse import urlencode
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
PORT = int(os.getenv("TV2_VERIFY_PORT", "8765"))
BASE = f"http://127.0.0.1:{PORT}"


def get(path: str, **query):
    url = BASE + path
    if query:
        url += "?" + urlencode(query)
    with urlopen(url, timeout=2) as response:  # noqa: S310 - localhost verification only
        return response.status, json.loads(response.read().decode("utf-8"))


def main() -> int:
    env = os.environ.copy()
    env.update({
        "TV2_REPOSITORY": "fixture",
        "PYTHONPATH": str(ROOT / "src"),
    })
    process = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", str(PORT)],
        cwd=ROOT,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(30):
            try:
                if get("/ready")[0] == 200:
                    break
            except Exception:
                time.sleep(0.1)
        else:
            raise RuntimeError("resolver did not become ready")

        _, prefix = get("/v1/prefix", country="1", input="529")
        assert prefix["matches"][0]["exact"] is True
        assert prefix["matches"][0]["display_name"] == "TV2 Fixture Alpha"

        _, local = get("/v1/resolve", country="1", input="529")
        assert local["status"] == "resolved"
        assert {r["type"] for r in local["listing"]["resources"]} >= {"web", "call", "video_call", "text"}
        assert "cdd" not in json.dumps(local).lower()

        _, foreign = get("/v1/resolve", country="1", input="91*529")
        assert foreign["country_context"] == "91"
        assert foreign["listing"]["display_name"] == "TV2 Fixture India Namespace"

        _, global_ = get("/v1/resolve", country="1", input="*529")
        assert global_["country_context"] is None
        assert global_["listing"]["display_name"] == "TV2 Global Fixture"

        _, missing = get("/v1/resolve", country="1", input="999")
        assert missing["status"] == "not_found" and missing["listing"] is None

        print("TV2 localhost HTTP verification: PASS")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == "__main__":
    raise SystemExit(main())

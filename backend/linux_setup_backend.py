#!/usr/bin/env python3
import json, os, glob, subprocess, datetime, shlex, pwd, pathlib

LOG_BASE   = "/var/log/linux-setup"
REPORT_DIR = "/var/lib/linux-setup/reports"   # backend-owned
STATE_DIR  = "/var/lib/linux-setup/state"     # backend-owned
# Optional: per-user copies can be added later

def _ts():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def _ensure_dirs():
    for d in (LOG_BASE, REPORT_DIR, STATE_DIR):
        os.makedirs(d, exist_ok=True)

def _last_json():
    files = sorted(glob.glob(os.path.join(LOG_BASE, "provision-security_*.json")))
    return files[-1] if files else None

def run_provision(mode: str, profile: str = "", quick: bool=False):
    """
    Calls scripts/provision-security.sh with proper flags.
    Returns (ok, meta_dict)
    """
    _ensure_dirs()
    ts = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    log_file  = os.path.join(LOG_BASE, f"provision-security_{ts}.log")
    json_file = os.path.join(LOG_BASE, f"provision-security_{ts}.json")
    report_md = os.path.join(REPORT_DIR, "latest.md")

    script = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "provision-security.sh"
    if not script.exists():
        return False, {"error": "provision-security.sh not found", "script": str(script)}

    # Build command
    cmd = [ "bash", str(script), mode ]
    # Inside run_provision()
    if mode == "fix" and profile:  # profile holds fix_id
        cmd += ["--fix", profile]
    if profile:
        cmd += ["--profile", profile]
    if quick and mode == "audit":
        cmd += ["--quick"]
    # Let the script know where to write JSON/report (optional, if you add flags)
    # cmd += ["--json", json_file, "--report", report_md]

    env = os.environ.copy()
    # Ensure locale & non-interactive
    env["LC_ALL"] = "C.UTF-8"
    env["DEBIAN_FRONTEND"] = "noninteractive"

    with open(log_file, "wb") as lf:
        proc = subprocess.run(cmd, stdout=lf, stderr=subprocess.STDOUT, env=env)

    # If your script doesn’t accept --json/--report yet, we’ll find the last json written by the script
    # and copy/annotate it. For now we just try to read the new file if it exists; otherwise fallback.
    meta = {
        "mode": mode,
        "profile": profile or "default",
        "quick": quick,
        "ts": _ts(),
        "artifacts": {"log": log_file, "json": None, "report_md": report_md}
    }

    # Prefer the json we intended; otherwise find latest
    if os.path.exists(json_file):
        meta["artifacts"]["json"] = json_file
    else:
        last = _last_json()
        if last:
            meta["artifacts"]["json"] = last

    # Summarize success/failure
    meta["returncode"] = proc.returncode
    meta["ok"] = (proc.returncode == 0)

    # Persist a lightweight state snapshot
    state_file = os.path.join(STATE_DIR, "latest.json")
    try:
        with open(state_file, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
    except Exception as e:
        meta["state_write_error"] = str(e)

    return meta["ok"], meta

def get_latest():
    _ensure_dirs()
    latest_state = os.path.join(STATE_DIR, "latest.json")
    result = {"ts": _ts(), "state": None}
    if os.path.exists(latest_state):
        try:
            with open(latest_state, "r", encoding="utf-8") as f:
                result["state"] = json.load(f)
        except Exception as e:
            result["error"] = f"Failed to read state: {e}"
    else:
        result["info"] = "No runs yet."
    return result

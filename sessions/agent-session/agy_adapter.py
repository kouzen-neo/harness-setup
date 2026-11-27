"""Adapter for the Antigravity CLI (`agy -p`)."""

import json
import subprocess
from typing import Optional

from common import SessionError, State, TurnResult

# Owner-facing level -> agy flags. The default is `yolo` so unattended delegated turns do not stall on permission
# prompts; `--mode auto` is not available for every account. Pick a lower level with --permissions when the task allows.
PERMISSION_FLAGS = {
    "yolo": ["--dangerously-skip-permissions"],
    "accept-edits": ["--mode", "accept-edits"],
    "plan": ["--mode", "plan"],
    "default": [],
}
# When an alias matches several models, prefer these effort variants in this order.
PREFERRED_EFFORT_SUFFIXES = ("-high", "-medium")
MODELS_TIMEOUT_S = 60


class AgyAdapter:
    name = "agy"
    permission_levels = tuple(PERMISSION_FLAGS)
    default_permissions = "yolo"

    def models(self) -> list:
        try:
            done = subprocess.run(["agy", "models"], capture_output=True, text=True, timeout=MODELS_TIMEOUT_S)
        except FileNotFoundError as err:
            raise SessionError("the `agy` command was not found on PATH") from err
        rows = (line.split("\t") for line in done.stdout.splitlines())
        return [(cols[0].strip(), cols[1].strip()) for cols in rows if len(cols) >= 2 and cols[0].strip()]

    def resolve_model(self, requested: str) -> str:
        """Exact id, or an alias (neon, flash, hydrogen, opus, ...) that picks the -high, then -medium variant."""
        ids = [model_id for model_id, _ in self.models()]
        if not ids or requested in ids:
            return requested
        hits = [model_id for model_id in ids if requested.lower() in model_id.lower()]
        for suffix in PREFERRED_EFFORT_SUFFIXES:
            for model_id in hits:
                if model_id.endswith(suffix):
                    return model_id
        if hits:
            return hits[0]
        raise SessionError(f"unknown model '{requested}'; list the options with `models`")

    def new_session_id(self) -> Optional[str]:
        return None  # agy creates the conversation on the first turn; its id is read from the output.

    def run_turn(self, state: State, message: str, timeout_s: int) -> TurnResult:
        cmd = ["agy", "-p", message, "--output-format", "json", "--model", state.model, *PERMISSION_FLAGS[state.permissions]]
        if state.session_id:
            cmd += ["--conversation", state.session_id]
        try:
            done = subprocess.run(cmd, capture_output=True, text=True, cwd=state.cwd, timeout=timeout_s)
        except subprocess.TimeoutExpired as err:
            raise SessionError(f"no reply within {timeout_s}s; the turn may still be running in the CLI") from err
        except FileNotFoundError as err:
            raise SessionError("the `agy` command was not found on PATH") from err
        return parse_output(done.stdout, done.stderr, done.returncode, state.session_id)


def parse_output(stdout: str, stderr: str, returncode: int, session_id: Optional[str]) -> TurnResult:
    """Read the last JSON line of `agy -p --output-format json`, or raise a clear error."""
    lines = [line for line in stdout.splitlines() if line.strip().startswith("{")]
    try:
        data = json.loads(lines[-1])
    except (IndexError, ValueError) as err:
        detail = (stderr or stdout).strip()[:500] or f"exit code {returncode}"
        raise SessionError(f"agy returned no readable result: {detail}") from err
    if data.get("status") != "SUCCESS":
        raise SessionError(f"agy failed: {str(data.get('error') or data.get('response') or stderr).strip()[:500]}")
    return TurnResult(reply=str(data.get("response", "")), session_id=data.get("conversation_id") or session_id)

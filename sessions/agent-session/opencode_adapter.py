"""Adapter for the OpenCode CLI (`opencode run`)."""

import json
import subprocess
from typing import Optional

from common import SessionError, State, TurnResult

PERMISSION_FLAGS = {
    "auto": ["--auto"],
    "manual": [],
}


class OpenCodeAdapter:
    name = "opencode"
    permission_levels = tuple(PERMISSION_FLAGS)
    default_permissions = "auto"

    def models(self) -> list:
        try:
            done = subprocess.run(["opencode", "models"], capture_output=True, text=True, timeout=60)
        except FileNotFoundError as err:
            raise SessionError("the `opencode` command was not found on PATH") from err
        return [(line.strip(), "") for line in done.stdout.splitlines() if line.strip()]

    def resolve_model(self, requested: str) -> str:
        ids = [model_id for model_id, _ in self.models()]
        if requested in ids:
            return requested
        hits = [model_id for model_id in ids if requested.lower() in model_id.lower()]
        if len(hits) == 1:
            return hits[0]
        shown = ", ".join(hits[:10]) if hits else "none"
        raise SessionError(f"model '{requested}' matches {len(hits)} models ({shown}); use the exact id from `models`")

    def new_session_id(self) -> Optional[str]:
        return None  # OpenCode creates it on the first turn; it is read from the output.

    def run_turn(self, state: State, message: str, timeout_s: int) -> TurnResult:
        cmd = ["opencode", "run", "--model", state.model, "--format", "json", *PERMISSION_FLAGS[state.permissions]]
        if state.session_id:
            cmd += ["--session", state.session_id]
        else:
            cmd += ["--archived", "--title", f"agent-session {state.slot}"]
        cmd.append(message)
        try:
            done = subprocess.run(cmd, capture_output=True, text=True, cwd=state.cwd, timeout=timeout_s)
        except subprocess.TimeoutExpired as err:
            raise SessionError(f"no reply within {timeout_s}s; the turn may still be running in the CLI") from err
        except FileNotFoundError as err:
            raise SessionError("the `opencode` command was not found on PATH") from err
        return parse_events(done.stdout, done.stderr, done.returncode, state.session_id)


def parse_events(stdout: str, stderr: str, returncode: int, session_id: Optional[str]) -> TurnResult:
    """Collect the reply text and session id from `opencode run --format json` event lines."""
    texts, errors = [], []
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        session_id = event.get("sessionID") or session_id
        if event.get("type") == "text":
            texts.append(str(event.get("part", {}).get("text", "")))
        elif event.get("type") == "error":
            errors.append(str(event.get("error") or event.get("part") or event))
    if returncode != 0 or (errors and not texts):
        detail = "; ".join(errors) or stderr.strip() or f"exit code {returncode}"
        raise SessionError(f"opencode failed: {detail[:500]}")
    return TurnResult(reply="".join(texts), session_id=session_id)

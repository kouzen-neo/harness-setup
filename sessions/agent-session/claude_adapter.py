"""Adapter for the Claude Code CLI (`claude -p`)."""

import json
import subprocess
import uuid

from common import SessionError, State, TurnResult

CLAUDE_MODELS = [
    ("fable", "Latest Fable"),
    ("opus", "Latest Opus"),
    ("sonnet", "Latest Sonnet"),
    ("haiku", "Latest Haiku"),
    ("claude-fable-5-2", "Fable 5.2"),
    ("claude-opus-5-5", "Opus 5.5"),
    ("claude-sonnet-5-5", "Sonnet 5.5"),
    ("claude-haiku-5-5", "Haiku 5.5"),
]

# Owner-facing level -> Claude Code --permission-mode value.
PERMISSION_MODES = {
    "auto": "auto",
    "accept-edits": "acceptEdits",
    "plan": "plan",
    "yolo": "bypassPermissions",
}


class ClaudeAdapter:
    name = "claude"
    permission_levels = tuple(PERMISSION_MODES)
    default_permissions = "auto"

    def models(self) -> list:
        return CLAUDE_MODELS

    def resolve_model(self, requested: str) -> str:
        # The CLI accepts both aliases and full ids; pass the request through unchanged.
        return requested

    def new_session_id(self) -> str:
        return str(uuid.uuid4())

    def run_turn(self, state: State, message: str, timeout_s: int) -> TurnResult:
        session_flag = ["--session-id", state.session_id] if state.turns == 0 else ["--resume", state.session_id]
        cmd = ["claude", "-p", "--output-format", "json", "--model", state.model,
               "--permission-mode", PERMISSION_MODES[state.permissions], *session_flag]
        try:
            done = subprocess.run(cmd, input=message, capture_output=True, text=True, cwd=state.cwd, timeout=timeout_s)
        except subprocess.TimeoutExpired as err:
            raise SessionError(f"no reply within {timeout_s}s; the turn may still be running in the CLI") from err
        except FileNotFoundError as err:
            raise SessionError("the `claude` command was not found on PATH") from err
        return parse_output(done.stdout, done.stderr, done.returncode, state.session_id)


def parse_output(stdout: str, stderr: str, returncode: int, session_id: str) -> TurnResult:
    """Turn the `claude -p --output-format json` result into a TurnResult, or raise a clear error."""
    try:
        data = json.loads(stdout)
    except ValueError as err:
        detail = (stderr or stdout).strip()[:500] or f"exit code {returncode}"
        raise SessionError(f"claude returned no readable result: {detail}") from err
    if returncode != 0 or data.get("is_error"):
        raise SessionError(f"claude failed: {str(data.get('result') or stderr).strip()[:500]}")
    return TurnResult(reply=str(data.get("result", "")), session_id=data.get("session_id") or session_id)

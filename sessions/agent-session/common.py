"""Shared core of the claude-session and opencode-session wrappers.

One named conversation per agent CLI, driven with: start, send, status, stop, models.
The conversation itself lives in the agent's own store; this module keeps only a small
state file (model, working folder, session id, permission level, turn count).
"""

import argparse
import json
import logging
import os
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional, Protocol

DEFAULT_TIMEOUT_S = 1800
DEFAULT_SLOT = "default"
EXIT_OK = 0
EXIT_ERROR = 1

STATE_ROOT = Path(os.environ.get("AGENT_SESSION_HOME") or Path.home() / ".cache" / "agent-session")
log = logging.getLogger("agent-session")


class SessionError(RuntimeError):
    """A turn or command failed in a way the caller should see as a clear message."""


@dataclass
class State:
    agent: str
    slot: str
    model: str
    cwd: str
    permissions: str
    session_id: Optional[str]
    turns: int
    started_at: float


class Adapter(Protocol):
    """What an agent CLI has to provide."""

    name: str
    permission_levels: tuple
    default_permissions: str

    def models(self) -> list: ...

    def resolve_model(self, requested: str) -> str: ...

    def new_session_id(self) -> Optional[str]: ...

    def run_turn(self, state: State, message: str, timeout_s: int) -> "TurnResult": ...


@dataclass
class TurnResult:
    reply: str
    session_id: Optional[str]


def state_path(agent: str, slot: str) -> Path:
    return STATE_ROOT / f"{agent}-{slot}.json"


def load_state(agent: str, slot: str) -> Optional[State]:
    path = state_path(agent, slot)
    if not path.exists():
        return None
    try:
        return State(**json.loads(path.read_text(encoding="utf-8")))
    except (OSError, ValueError, TypeError) as err:
        raise SessionError(f"state file {path} is unreadable ({err}); run `stop` and `start` again") from err


def save_state(state: State) -> None:
    STATE_ROOT.mkdir(parents=True, exist_ok=True)
    path = state_path(state.agent, state.slot)
    path.write_text(json.dumps(asdict(state), ensure_ascii=False), encoding="utf-8")
    path.chmod(0o600)


def cmd_models(adapter: Adapter, _args) -> None:
    for model_id, label in adapter.models():
        print(f"{model_id}\t{label}")


def cmd_start(adapter: Adapter, args) -> None:
    if load_state(adapter.name, args.slot):
        raise SessionError(f"a {adapter.name} session '{args.slot}' is already started; use `stop` first")
    if not args.model:
        raise SessionError("choose a model first (ask the owner); list the options with `models`")
    if args.permissions not in adapter.permission_levels:
        raise SessionError(f"--permissions must be one of: {', '.join(adapter.permission_levels)}")
    cwd = Path(args.cwd).resolve()
    if not cwd.is_dir():
        raise SessionError(f"--cwd {cwd} is not a folder")
    state = State(
        agent=adapter.name,
        slot=args.slot,
        model=adapter.resolve_model(args.model),
        cwd=str(cwd),
        permissions=args.permissions,
        session_id=adapter.new_session_id(),
        turns=0,
        started_at=time.time(),
    )
    save_state(state)
    print(f"started {adapter.name} session '{state.slot}' | model {state.model} | permissions {state.permissions} | cwd {state.cwd}")


def cmd_send(adapter: Adapter, args) -> None:
    state = load_state(adapter.name, args.slot)
    if not state:
        raise SessionError("not started; use `start --model <model>` first")
    result = adapter.run_turn(state, args.message, args.timeout)
    state.session_id = result.session_id or state.session_id
    state.turns += 1
    save_state(state)
    print(result.reply.strip())


def cmd_status(adapter: Adapter, args) -> None:
    state = load_state(adapter.name, args.slot)
    if not state:
        print("not started")
        return
    print(f"started | model: {state.model} | permissions: {state.permissions} | turns done: {state.turns}")
    print(f"session: {state.session_id or '(created on first send)'} | cwd: {state.cwd}")


def cmd_stop(adapter: Adapter, args) -> None:
    path = state_path(adapter.name, args.slot)
    if path.exists():
        path.unlink()
        print(f"stopped {adapter.name} session '{args.slot}' (history stays in the agent's own store)")
    else:
        print("not started")


COMMANDS = {"start": cmd_start, "send": cmd_send, "status": cmd_status, "stop": cmd_stop, "models": cmd_models}


def build_parser(adapter: Adapter) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog=f"{adapter.name}-session")
    parser.add_argument("--slot", default=os.environ.get("AGENT_SESSION_SLOT", DEFAULT_SLOT),
                        help="name of the session, to keep several side by side")
    sub = parser.add_subparsers(dest="command", required=True)
    start = sub.add_parser("start")
    start.add_argument("--model", help="model id or alias; no default, ask the owner first (see `models`)")
    start.add_argument("--permissions", default=adapter.default_permissions, choices=adapter.permission_levels)
    start.add_argument("--cwd", default=os.getcwd(), help="folder the agent works in (default: current folder)")
    send = sub.add_parser("send")
    send.add_argument("message")
    send.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S, help="seconds to wait for the reply")
    sub.add_parser("status")
    sub.add_parser("stop")
    sub.add_parser("models")
    return parser


def run(adapter: Adapter, argv: list) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s", stream=sys.stderr)
    args = build_parser(adapter).parse_args(argv)
    try:
        COMMANDS[args.command](adapter, args)
    except SessionError as err:
        log.error("error: %s", err)
        return EXIT_ERROR
    return EXIT_OK

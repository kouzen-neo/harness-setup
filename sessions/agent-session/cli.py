"""Entry point: `cli.py <agy|claude|opencode> <command> ...` (used by the agy-session, claude-session, and opencode-session wrappers)."""

import sys

from agy_adapter import AgyAdapter
from claude_adapter import ClaudeAdapter
from common import EXIT_ERROR, run
from opencode_adapter import OpenCodeAdapter

ADAPTERS = {"agy": AgyAdapter, "claude": ClaudeAdapter, "opencode": OpenCodeAdapter}


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ADAPTERS:
        sys.stderr.write(f"usage: cli.py <{'|'.join(ADAPTERS)}> <start|send|status|stop|models> ...\n")
        return EXIT_ERROR
    return run(ADAPTERS[sys.argv[1]](), sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())

# Session wrappers

`agy-session`, `claude-session`, and `opencode-session` let one agent open a session in another and talk to it. They share one core (`sessions/agent-session/common.py`) and one thin adapter per agent.

## Commands

```text
<wrapper> models                                   list models the agent offers
<wrapper> start --model <model> [--permissions LEVEL] [--cwd DIR]
<wrapper> send "<message>" [--timeout SECONDS]     one turn; prints the reply
<wrapper> status
<wrapper> stop
```

`--slot NAME` (before the command) keeps several sessions side by side, for example `claude-session --slot review start ...`.

## Model choice

There is **no default model**: `start` refuses without `--model`. Ask the person you work for which model to use, and list the options with `models`. `agy` accepts short aliases (for example `flash`, `neon`, `hydrogen`) and picks the `-high`, then `-medium` variant.

## Permission levels

| Wrapper | Levels (first is the default) |
|---|---|
| `agy-session` | `yolo`, `accept-edits`, `plan`, `default` |
| `claude-session` | `auto`, `accept-edits`, `plan`, `yolo` |
| `opencode-session` | `auto`, `manual` |

`yolo` skips all permission checks. Use the least permissive level that lets the task finish, and run the session in the project folder. Auto-approval never widens what the delegating agent is allowed to do itself.

## How it works

Each `send` runs one turn of the agent's own CLI and resumes the same conversation (`--conversation`, `--resume`, or `--session`), so context is kept between turns. State (model, folder, conversation id, permission level, turn count) is a small file in `~/.cache/agent-session` (override with `AGENT_SESSION_HOME`), mode 600. The conversation itself stays in the agent's own history. There is no background process and no live viewer: a turn blocks until the reply is ready.

## Tests

```bash
cd sessions/agent-session && python3 -m unittest discover -s tests -t .
```

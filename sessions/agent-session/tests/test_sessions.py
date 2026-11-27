"""Tests for the shared session core and the three adapters. Run: python3 -m unittest discover -s tests -t ."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import agy_adapter
import claude_adapter
import common
import opencode_adapter
from common import EXIT_ERROR, EXIT_OK, SessionError, State, TurnResult

SAMPLE_SESSION_ID = "session-1"
OPENCODE_EVENTS = [
    {"type": "step_start", "sessionID": "ses_1"},
    {"type": "text", "sessionID": "ses_1", "part": {"text": "Hi "}},
    {"type": "text", "sessionID": "ses_1", "part": {"text": "there"}},
]


class FakeAdapter:
    """Minimal adapter that echoes the message, to test the core without any CLI."""

    name = "fake"
    permission_levels = ("auto", "yolo")
    default_permissions = "auto"

    def models(self):
        return [("fake-model", "Fake")]

    def resolve_model(self, requested):
        return requested

    def new_session_id(self):
        return SAMPLE_SESSION_ID

    def run_turn(self, state, message, timeout_s):
        return TurnResult(reply=f"echo:{message}", session_id=state.session_id)


class CoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        patcher = mock.patch.object(common, "STATE_ROOT", Path(self.tmp.name))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)
        self.adapter = FakeAdapter()

    def run_cli(self, *argv):
        return common.run(self.adapter, list(argv))

    def test_start_requires_a_model(self):
        self.assertEqual(self.run_cli("start"), EXIT_ERROR)
        self.assertIsNone(common.load_state("fake", common.DEFAULT_SLOT))

    def test_full_cycle_keeps_state_and_counts_turns(self):
        self.assertEqual(self.run_cli("start", "--model", "fake-model", "--cwd", self.tmp.name), EXIT_OK)
        self.assertEqual(self.run_cli("send", "hello"), EXIT_OK)
        self.assertEqual(self.run_cli("send", "again"), EXIT_OK)
        state = common.load_state("fake", common.DEFAULT_SLOT)
        self.assertEqual((state.turns, state.model, state.session_id), (2, "fake-model", SAMPLE_SESSION_ID))
        self.assertEqual(self.run_cli("stop"), EXIT_OK)
        self.assertIsNone(common.load_state("fake", common.DEFAULT_SLOT))

    def test_state_file_is_private(self):
        self.run_cli("start", "--model", "fake-model", "--cwd", self.tmp.name)
        mode = common.state_path("fake", common.DEFAULT_SLOT).stat().st_mode & 0o777
        self.assertEqual(mode, 0o600)

    def test_second_start_is_refused(self):
        self.run_cli("start", "--model", "fake-model", "--cwd", self.tmp.name)
        self.assertEqual(self.run_cli("start", "--model", "fake-model", "--cwd", self.tmp.name), EXIT_ERROR)

    def test_send_without_start_fails_clearly(self):
        self.assertEqual(self.run_cli("send", "hello"), EXIT_ERROR)

    def test_bad_cwd_is_rejected(self):
        self.assertEqual(self.run_cli("start", "--model", "fake-model", "--cwd", "/no/such/folder"), EXIT_ERROR)

    def test_slots_are_independent(self):
        self.run_cli("--slot", "a", "start", "--model", "fake-model", "--cwd", self.tmp.name)
        self.assertIsNone(common.load_state("fake", "b"))
        self.assertIsNotNone(common.load_state("fake", "a"))

    def test_corrupt_state_gives_a_clear_error(self):
        common.STATE_ROOT.mkdir(parents=True, exist_ok=True)
        common.state_path("fake", common.DEFAULT_SLOT).write_text("{not json", encoding="utf-8")
        self.assertEqual(self.run_cli("status"), EXIT_ERROR)


class ParserTests(unittest.TestCase):
    def test_claude_result(self):
        out = json.dumps({"result": "hello", "session_id": "abc", "is_error": False})
        result = claude_adapter.parse_output(out, "", 0, SAMPLE_SESSION_ID)
        self.assertEqual((result.reply, result.session_id), ("hello", "abc"))

    def test_claude_errors(self):
        with self.assertRaises(SessionError):
            claude_adapter.parse_output("not json", "boom", 1, SAMPLE_SESSION_ID)
        with self.assertRaises(SessionError):
            claude_adapter.parse_output(json.dumps({"result": "denied", "is_error": True}), "", 0, SAMPLE_SESSION_ID)

    def test_opencode_events_join_text_and_read_session(self):
        out = "\n".join(json.dumps(event) for event in OPENCODE_EVENTS)
        result = opencode_adapter.parse_events(out, "", 0, None)
        self.assertEqual((result.reply, result.session_id), ("Hi there", "ses_1"))

    def test_opencode_error_without_text_raises(self):
        out = json.dumps({"type": "error", "error": "bad model"})
        with self.assertRaises(SessionError):
            opencode_adapter.parse_events(out, "", 1, None)

    def test_agy_success_and_failure(self):
        ok = json.dumps({"conversation_id": "c1", "status": "SUCCESS", "response": "ok\n"})
        result = agy_adapter.parse_output("warning line\n" + ok, "", 0, None)
        self.assertEqual((result.reply, result.session_id), ("ok\n", "c1"))
        bad = json.dumps({"status": "ERROR", "error": "authentication failed"})
        with self.assertRaises(SessionError):
            agy_adapter.parse_output(bad, "", 0, None)
        with self.assertRaises(SessionError):
            agy_adapter.parse_output("", "crash", 1, None)


class AdapterContractTests(unittest.TestCase):
    def test_every_default_permission_is_a_valid_level(self):
        for adapter in (agy_adapter.AgyAdapter(), claude_adapter.ClaudeAdapter(), opencode_adapter.OpenCodeAdapter()):
            self.assertIn(adapter.default_permissions, adapter.permission_levels, adapter.name)

    def test_claude_resume_flags(self):
        state = State("claude", "default", "haiku", "/tmp", "auto", SAMPLE_SESSION_ID, 0, 0.0)
        calls = []
        done = mock.Mock(stdout=json.dumps({"result": "x", "session_id": SAMPLE_SESSION_ID}), stderr="", returncode=0)
        with mock.patch.object(claude_adapter.subprocess, "run", side_effect=lambda cmd, **kw: calls.append(cmd) or done):
            adapter = claude_adapter.ClaudeAdapter()
            adapter.run_turn(state, "hi", 5)
            state.turns = 1
            adapter.run_turn(state, "hi", 5)
        self.assertIn("--session-id", calls[0])
        self.assertIn("--resume", calls[1])


if __name__ == "__main__":
    unittest.main()

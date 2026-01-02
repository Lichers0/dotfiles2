"""Runner - executes AI agents and streams output."""

import json
import shlex
import shutil
import signal
import subprocess
import sys
import uuid
from typing import Any

from .agents.base import BaseAgent
from .logger import Logger
from .session import get_log_path, register_child


class Runner:
    """Runs AI agents with logging and interrupt handling."""

    def __init__(
        self,
        agent: BaseAgent,
        prompt: str,
        extra_args: list[str] | None = None,
        parent_id: str | None = None,
        session_id: str | None = None,
        debug: bool = False,
    ):
        self.agent = agent
        self.prompt = prompt
        self.extra_args = extra_args or []
        self.parent_id = parent_id
        self.session_id = session_id  # Existing session to continue
        self.debug = debug

        self.cmd = agent.build_command(prompt, self.extra_args, session_id)
        self.logger = Logger(is_resume=session_id is not None)

        self._process: subprocess.Popen[bytes] | None = None
        self._agent_session_id: str | None = None  # Session ID from agent output
        self._accumulated_result: str = ""

        print("Start agent...", flush=True)

        # Output first JSON with prompt/agent/model and save to log
        model = agent.get_model(self.extra_args)
        first_json = {"type": "aiwr_start", "prompt": prompt, "agent": agent.name, "model": model}
        print(json.dumps(first_json, ensure_ascii=False), flush=True)
        self.logger.append(first_json)

        # Add parent meta entry if this is a child session
        if parent_id:
            self.logger.append({"type": "aiwr_meta", "parent_id": parent_id})

    def run(self) -> int:
        """Run the agent and return exit code."""
        # Print debug command if requested
        if self.debug:
            print(f"[DEBUG] {shlex.join(self.cmd)}", flush=True)

        # Check if agent command exists
        if not shutil.which(self.agent.command):
            print(f"Error: {self.agent.command} not found in PATH", file=sys.stderr)
            return 1

        # Setup interrupt handler
        original_handler = signal.getsignal(signal.SIGINT)
        signal.signal(signal.SIGINT, self._handle_interrupt)

        try:
            return self._execute()
        finally:
            signal.signal(signal.SIGINT, original_handler)

    def _execute(self) -> int:
        """Execute the agent process."""
        self._process = subprocess.Popen(
            self.cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        # Read output in real-time
        while True:
            if self._process.stdout:
                line = self._process.stdout.readline()
                if line:
                    self._handle_stdout(line)
                elif self._process.poll() is not None:
                    break
            else:
                break

        # Drain stderr (don't pass through to terminal)
        if self._process.stderr:
            self._process.stderr.read()

        self._finalize()
        return self._process.returncode

    def _handle_stdout(self, data: bytes) -> None:
        """Handle stdout data."""
        text = data.decode("utf-8", errors="replace")

        # Use agent to parse and validate JSON
        json_data = self.agent.parse_log_entry(text)
        if json_data is None:
            # Not valid JSON - ignore (garbage output)
            return

        # Log the valid JSON entry
        self.logger.append(json_data)

        # Extract session ID from first JSON
        if self._agent_session_id is None:
            agent_session_id = self.agent.extract_session_id(json_data)
            if agent_session_id:
                self._agent_session_id = agent_session_id

                # Output session ID to stdout
                print(json.dumps({"session_id": agent_session_id, "agent": self.agent.name}, ensure_ascii=False), flush=True)

                # Use provided session_id for logging, or agent's session_id for new sessions
                effective_session_id = self.session_id or agent_session_id
                log_path = get_log_path(effective_session_id, self.parent_id)
                self.logger.set_log_path(log_path)

                # Register with parent if applicable (only for new sessions)
                if self.parent_id and not self.session_id:
                    register_child(self.parent_id, effective_session_id)

        # Handle result accumulation
        if self.agent.should_reset_result(json_data):
            self._accumulated_result = ""

        # Extract and accumulate result
        result = self.agent.extract_result(json_data)
        if result:
            self._accumulated_result += result

    def _handle_interrupt(self, signum: int, frame: Any) -> None:
        """Handle Ctrl+C interrupt."""
        if self._process:
            self._process.terminate()
            try:
                self._process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._process.kill()

        self._finalize()
        sys.exit(130)

    def _finalize(self) -> None:
        """Finalize the session - ensure log is saved."""
        # If no session ID was found, generate one or use provided
        if self._agent_session_id is None:
            effective_session_id = self.session_id or str(uuid.uuid4())[:8]
            log_path = get_log_path(effective_session_id, self.parent_id)
            self.logger.set_log_path(log_path)

            if self.parent_id and not self.session_id:
                register_child(self.parent_id, effective_session_id)

        # Output result to stdout
        if self._accumulated_result:
            print(json.dumps({"result": self._accumulated_result, "agent": self.agent.name}, ensure_ascii=False), flush=True)

        self.logger.save()

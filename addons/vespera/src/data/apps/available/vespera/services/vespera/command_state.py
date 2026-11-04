import subprocess
from collections import deque
from dataclasses import dataclass, field
from typing import List


@dataclass
class CommandState:
		request_id: str
		helper_name: str
		helper_path: str
		args: List[str]
		operation_name: str
		process: subprocess.Popen
		output_path: str = ""
		stdout_done: bool = False
		stderr_done: bool = False
		wait_done: bool = False
		finish_scheduled: bool = False
		cancelled: bool = False
		output_queue: deque = field(default_factory=deque)
		_drain_pending:  bool = False
		exit_code: int = 1
		exit_status: int = 1

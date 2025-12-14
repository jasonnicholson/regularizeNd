#!/usr/bin/env python3

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "docs" / "_static" / "examples"
DEFAULT_EXAMPLES_DIR = REPO_ROOT / "Examples"


def main() -> int:
    matlab = os.environ.get("MATLAB", "") or shutil.which("matlab")
    if not matlab:
        print("[publish_examples] MATLAB executable not found on PATH (set $MATLAB to override).", file=sys.stderr)
        return 2

    output_dir = Path(os.environ.get("EXAMPLES_HTML_OUTPUT_DIR", str(DEFAULT_OUTPUT_DIR)))
    examples_dir = Path(os.environ.get("EXAMPLES_DIR", str(DEFAULT_EXAMPLES_DIR)))
    run_examples = os.environ.get("RUN_EXAMPLES", "").strip().lower() in {"1", "true", "yes"}

    output_dir.mkdir(parents=True, exist_ok=True)

    # Use -batch for non-interactive execution.
    matlab_cmd = (
        "cd('" + str(REPO_ROOT).replace("'", "''") + "'); "
        "addpath(fullfile(pwd,'scripts')); "
        "publish_examples(); "
    )

    cmd = [matlab, "-batch", matlab_cmd]
    print("[publish_examples] $ " + " ".join(cmd), flush=True)
    completed = subprocess.run(cmd, cwd=str(REPO_ROOT))
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())

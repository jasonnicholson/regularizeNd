#!/usr/bin/env python

"""Deploy Sphinx HTML documentation to the gh-pages branch.

Steps:
1. Ensure a git worktree exists at docs/_build/html for branch gh-pages.
   - If a worktree exists there for a different branch, exit with error.
   - If no worktree exists, clear the directory and create an orphan
	 gh-pages worktree.
2. Run `make html` in the docs folder.
3. Get the current commit hash from the main repository.
4. In docs/_build/html, commit all changes with message
   "deploy to gh-pages, <hash>".
5. Push the gh-pages branch with `--force` to origin.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / "docs"
BUILD_HTML_DIR = DOCS_DIR / "_build" / "html"
GH_PAGES_BRANCH = "gh-pages"


def run(
	cmd: list[str],
	cwd: Path | None = None,
	check: bool = True,
	env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
	"""Run a command, echoing it first."""

	print(f"[deploy] $ {' '.join(cmd)}", flush=True)
	return subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=check, env=env)


def build_env_with_venv_tools() -> dict[str, str]:
	"""Return an environment that prefers Sphinx tools from .venv.

	This makes deploys reproducible even if the caller didn't activate the venv.
	"""

	env = dict(os.environ)
	venv_bin = REPO_ROOT / ".venv" / "bin"
	if venv_bin.is_dir():
		path = env.get("PATH", "")
		env["PATH"] = f"{venv_bin}{os.pathsep}{path}" if path else str(venv_bin)
		# Makefile uses these variables; set them explicitly to avoid PATH issues.
		sphinx_build = venv_bin / "sphinx-build"
		if sphinx_build.exists():
			env["SPHINXBUILD"] = str(sphinx_build)
		sphinx_autobuild = venv_bin / "sphinx-autobuild"
		if sphinx_autobuild.exists():
			env["SPHINXAUTOBUILD"] = str(sphinx_autobuild)
		# Also ensure the Makefile uses the same python interpreter.
		env["PYTHON"] = str(venv_bin / "python") if (venv_bin / "python").exists() else env.get("PYTHON", "python3")

	return env


def get_worktree_branch(path: Path) -> str | None:
	"""Return the branch name for the worktree at `path`, or None if not a git dir.

	This inspects the HEAD ref rather than parsing `git worktree list` output.
	"""

	git_dir = path / ".git"
	if not git_dir.exists():
		return None

	# `git rev-parse --abbrev-ref HEAD` gives the current branch name.
	try:
		result = subprocess.run(
			["git", "rev-parse", "--abbrev-ref", "HEAD"],
			cwd=str(path),
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
			text=True,
			check=True,
		)
	except subprocess.CalledProcessError:
		return None

	branch = result.stdout.strip()
	# Detached HEAD will show as "HEAD"; treat that as no usable branch.
	if branch == "HEAD" or not branch:
		return None
	return branch


def ensure_gh_pages_worktree() -> None:
	"""Ensure docs/_build/html is a worktree for gh-pages as specified.

	- If a worktree exists there and is on gh-pages: keep it.
	- If a worktree exists there but is on a different branch: error and exit.
	- If the directory exists but is not a git worktree: clear and create orphan.
	- If the directory does not exist: create and create orphan.
	"""

	print(f"[deploy] Ensuring worktree at {BUILD_HTML_DIR} for branch {GH_PAGES_BRANCH}")

	BUILD_HTML_DIR.mkdir(parents=True, exist_ok=True)

	branch = get_worktree_branch(BUILD_HTML_DIR)
	if branch is not None:
		if branch != GH_PAGES_BRANCH:
			sys.exit(
				f"Error: docs/_build/html is a git worktree on branch '{branch}', "
				f"expected '{GH_PAGES_BRANCH}'. Aborting."
			)
		print(f"[deploy] Existing worktree on {GH_PAGES_BRANCH} detected; reusing.")
		return

	# Not a git worktree: we need to clear it and create an orphan worktree.
	print(f"[deploy] No valid git worktree found at {BUILD_HTML_DIR}, recreating as orphan {GH_PAGES_BRANCH} worktree.")

	# Clear directory contents but keep the directory itself.
	for entry in BUILD_HTML_DIR.iterdir():
		if entry.is_dir():
			shutil.rmtree(entry)
		else:
			entry.unlink()

	# Ensure gh-pages exists locally without mutating the main working tree.
	result = subprocess.run(
		["git", "show-ref", "--verify", "--quiet", f"refs/heads/{GH_PAGES_BRANCH}"],
		cwd=str(REPO_ROOT),
	)
	if result.returncode != 0:
		print(f"[deploy] Creating local branch {GH_PAGES_BRANCH} (empty root commit).")
		empty_tree = subprocess.check_output(
			["git", "hash-object", "-t", "tree", "/dev/null"],
			cwd=str(REPO_ROOT),
			text=True,
		).strip()
		commit = subprocess.check_output(
			["git", "commit-tree", empty_tree, "-m", "Initialize gh-pages"],
			cwd=str(REPO_ROOT),
			text=True,
		).strip()
		run(["git", "update-ref", f"refs/heads/{GH_PAGES_BRANCH}", commit], cwd=REPO_ROOT)

	# Now attach the worktree to gh-pages at the build directory.
	run(["git", "worktree", "add", str(BUILD_HTML_DIR), GH_PAGES_BRANCH], cwd=REPO_ROOT)


def build_docs_html() -> None:
	"""Run `make html` in the docs directory."""

	make_env = build_env_with_venv_tools()

	# Optionally publish MATLAB examples into docs/_static/examples so they
	# get bundled into the Sphinx HTML output.
	skip_examples = os.environ.get("SKIP_EXAMPLES_PUBLISH", "").strip() in {"1", "true", "True"}
	if not skip_examples:
		publish_script = REPO_ROOT / "scripts" / "publish_examples.py"
		if publish_script.exists():
			print("[deploy] Publishing MATLAB examples (best effort)")
			proc = subprocess.run([sys.executable, str(publish_script)], cwd=str(REPO_ROOT))
			if proc.returncode == 2:
				print("[deploy] WARNING: MATLAB not found; skipping example publishing.")
			elif proc.returncode != 0:
				raise subprocess.CalledProcessError(proc.returncode, proc.args)

	print("[deploy] Building Sphinx HTML docs (make html)")
	run(["make", "html"], cwd=DOCS_DIR, env=make_env)


def get_current_commit_hash() -> str:
	"""Return the current commit hash (from the main repo)."""

	result = subprocess.run(
		["git", "rev-parse", "HEAD"],
		cwd=str(REPO_ROOT),
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		text=True,
		check=True,
	)
	commit_hash = result.stdout.strip()
	print(f"[deploy] Current repo commit hash: {commit_hash}")
	return commit_hash


def commit_and_push(commit_hash: str) -> None:
	"""Commit built docs in the gh-pages worktree and push to origin."""

	print("[deploy] Preparing commit in gh-pages worktree")
	# Ensure .nojekyll is always present so GitHub Pages serves files as-is.
	nojekyll_path = BUILD_HTML_DIR / ".nojekyll"
	if not nojekyll_path.exists():
		print("[deploy] Creating .nojekyll file")
		nojekyll_path.write_text("# Disable Jekyll for Sphinx docs\n", encoding="utf-8")

	# Stage all changes (including deletions).
	run(["git", "add", "--all"], cwd=BUILD_HTML_DIR)

	# If nothing changed, skip.
	status = subprocess.run(
		["git", "status", "--porcelain"],
		cwd=str(BUILD_HTML_DIR),
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		text=True,
		check=True,
	)
	if not status.stdout.strip():
		print("[deploy] No changes to commit in gh-pages; skipping commit and push.")
		return

	# Create a fresh root commit (no parents) so gh-pages history has exactly one commit.
	message = f"deploy to gh-pages, {commit_hash}"
	tree = subprocess.check_output(
		["git", "write-tree"],
		cwd=str(BUILD_HTML_DIR),
		text=True,
	).strip()
	new_commit = subprocess.check_output(
		["git", "commit-tree", tree, "-m", message],
		cwd=str(BUILD_HTML_DIR),
		text=True,
	).strip()
	# Move the branch ref to the new root commit and update the worktree.
	run(["git", "update-ref", f"refs/heads/{GH_PAGES_BRANCH}", new_commit], cwd=BUILD_HTML_DIR)
	run(["git", "reset", "--hard", new_commit], cwd=BUILD_HTML_DIR)

	print("[deploy] Pushing gh-pages to origin (force)")
	run(["git", "push", "--force", "origin", GH_PAGES_BRANCH], cwd=BUILD_HTML_DIR)


def main() -> int:
	try:
		ensure_gh_pages_worktree()
		build_docs_html()
		commit_hash = get_current_commit_hash()
		commit_and_push(commit_hash)
	except subprocess.CalledProcessError as exc:
		print(f"[deploy] ERROR: command failed with exit code {exc.returncode}", file=sys.stderr)
		return exc.returncode
	except SystemExit as exc:
		# Propagate explicit sys.exit from checks.
		return int(exc.code) if isinstance(exc.code, int) else 1
	return 0


if __name__ == "__main__":  # pragma: no cover
	raise SystemExit(main())


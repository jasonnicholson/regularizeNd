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


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
	"""Run a command, echoing it first."""

	print(f"[deploy] $ {' '.join(cmd)}", flush=True)
	return subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=check)


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

	# Create or reset the gh-pages branch as orphan via worktree add.
	# We first ensure the branch exists as orphan head at root, then
	# attach a worktree to it.

	# If gh-pages doesn't exist, create it as an orphan.
	result = subprocess.run(
		["git", "rev-parse", "--verify", GH_PAGES_BRANCH],
		cwd=str(REPO_ROOT),
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
	)

	if result.returncode != 0:
		# Create orphan branch with an initial empty commit so worktree can be attached.
		print(f"[deploy] Creating orphan branch {GH_PAGES_BRANCH}.")
		run(["git", "checkout", "--orphan", GH_PAGES_BRANCH], cwd=REPO_ROOT)
		# Clear index and working tree content from repo root for the orphan commit.
		run(["git", "reset", "--hard"], cwd=REPO_ROOT)
		# Minimal .gitignore so branch is not completely empty.
		(REPO_ROOT / ".gitignore-gh-pages-placeholder").write_text("# gh-pages placeholder\n")
		run(["git", "add", ".gitignore-gh-pages-placeholder"], cwd=REPO_ROOT)
		run(["git", "commit", "-m", "Initialize gh-pages orphan branch"], cwd=REPO_ROOT)
		# Go back to previous branch (main / default).
		run(["git", "checkout", "-"], cwd=REPO_ROOT)

	# Now attach the worktree to gh-pages at the build directory.
	run(["git", "worktree", "add", str(BUILD_HTML_DIR), GH_PAGES_BRANCH], cwd=REPO_ROOT)


def build_docs_html() -> None:
	"""Run `make html` in the docs directory."""

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
	run(["make", "html"], cwd=DOCS_DIR)


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

	# Create commit if there is anything to commit.
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

	message = f"deploy to gh-pages, {commit_hash}"
	run(["git", "commit", "-m", message], cwd=BUILD_HTML_DIR)

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


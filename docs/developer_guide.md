# Developer Guide

## Prerequisites

Install Node.js using [fnm](https://github.com/Schniz/fnm) (Fast Node Manager).

```bash
# Install fnm (Windows)
winget install --id Schniz.fnm

# Install fnm (macOS)
brew install fnm

# Install fnm (Linux)
curl -fsSL https://fnm.vercel.app/install | bash

# Initialize fnm for your shell (example for bash)
eval "$(fnm env --use-on-cd)"

# Install and use the latest LTS Node.js
fnm install --lts
fnm use --lts

# Verify Node and npm
node -v
npm -v
```

Enable Corepack to manage package managers like pnpm. Note: as of Node.js 25, Corepack is no longer bundled, so install it separately if needed.

```bash
# Install Corepack when it is not bundled with Node.js
npm install -g corepack
```

Then enable Corepack and activate pnpm:

```bash
# Enable Corepack shims
corepack enable

# Ensure pnpm is available via Corepack
corepack install

# Verify pnpm
pnpm -v
```

Use pnpm to install dependencies:

```bash
# Install dependencies and update the lockfile if needed
pnpm i

# Install dependencies without modifying pnpm-lock.yaml
pnpm i --frozen-lockfile
```

- `pnpm i` resolves and installs dependencies; it can update `pnpm-lock.yaml` if versions change.
- `pnpm i --frozen-lockfile` enforces the existing lockfile and fails if it is out of date.

Install and use `uv` for Python dependencies and tooling (docs builds, Sphinx, etc.):

```bash
# Install uv (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create a virtual environment and sync dependencies
uv venv
uv sync

# Run commands inside the uv-managed environment
uv run python -V
uv run sphinx-build --version
```

## Development Workflow

1. Clone the repo.
2. Run `pnpm i` or `pnpm i --frozen-lockfile`. In the `prepare` script, the git hooks are configured. This sets up git-conventional-commits to lint the commit messages. Without this, commit messages are not checked.
3. Run `setupRegularizeNdProjectPath.m` to set up the MATLAB path for this project before running any MATLAB scripts. When you are done, run it again to clean up and remove the project paths.
4. Develop.
5. Commit using conventional commits.
6. Run `matlab -batch "release_workflow_part1()"` for a dry run, or `matlab -batch "release_workflow_part1('DryRun',false)"` to execute part 1.
7. After part 1 completes, manually package the toolbox:
  - Open the `build\regularizeNd.prj`.
  - Click "Package Toolbox".
  - Set the version.
  - Make the Getting Started file is correctly configured.
8. Run `matlab -batch "release_workflow_part2()"` for a dry run, or `matlab -batch "release_workflow_part2('DryRun',false)"` to execute part 2.

Note: other scripts assume the MATLAB path has already been set. The only script that adjusts the path internally is `createPackage`, which adds the build folder briefly for `builddocsearchdb` and removes it immediately.

To run a live-reloading docs server during documentation development, use the Sphinx autobuild target from the docs folder:

```bash
cd docs
make livehtml
```
  

## Release Workflow

`release_workflow_part1` performs the following steps:

1. Determines the next semantic version using `git-conventional-commits`.
2. Updates `package.json`, `pyproject.toml`, and `docs/conf.py` with the next version.
3. Generates `CHANGELOG.md`.
4. Runs `deploy_documentation` with the same DryRun setting; when DryRun is true, it does everything except push.
5. Sets up the `build` directory and toolbox project files using `createPackage(..., "PackageToolbox", false)`.
6. Stops and prints the manual packaging instructions.

After manually packaging the toolbox, `release_workflow_part2` performs:

1. Commits the version/changelog changes as `chore(release): vX.Y.Z` and tags `vX.Y.Z` (skipped in dry run).
2. Creates a GitHub release with notes generated from conventional commits since the previous tag (skipped in dry run).

Dry run behavior:

- In part 1, version/changelog/file updates are skipped, and documentation deploy runs without push.
- In part 2, git commits/tags/push and GitHub release creation are skipped.

## Semantic Versioning

This repo adheres to [Semantic Versioning](https://semver.org/).

Given a version number MAJOR.MINOR.PATCH, increment the:

- **MAJOR** version when you make incompatible API changes (BREAKING CHANGES). Any type of commit.
- **MINOR** version when you add functionality in a backwards compatible manner (`feat` type commit).
- **PATCH** version when you make backwards compatible bug fixes (`fix`/`perf`/`docs`/`chore` type commit).

## Conventional Commits

The commit format used is:

```text
<type>: <subject>

<optional body>

<optional footer>
```

### Commit Types

- **API relevant changes**
  - `feat` - Commits that add a new feature. MINOR version bump.
  - `fix` - Commits that fix a bug. PATCH version bump.

- `perf` - Commits that improve performance. PATCH version bump.
- `docs` - Commits that update internal or external documentation. PATCH version bump.
- `chore` - Miscellaneous commits e.g. modifying `.gitignore`, `tests`, refactoring, etc. This is the catch all type if one of the other types doesn't fit. Note that this type will not show up in the Changelog. PATCH version bump.

### Breaking Changes Modifier: **!**

If you add an exclamation mark to any of the commit types, it signifies BREAKING CHANGES which increments the MAJOR version:

- `fix!: fixed a bug that changed user output`
- `feat!: Changed a feature that changes the user input`

Recommendations when using the `!` modifier:

- Use the exclamation mark when making BREAKING CHANGES even if you have a footer describing the breaking change. The exclamation mark makes it easy to recognize that `type!: subject here` is a BREAKING CHANGE.
- If BREAKING CHANGES can be described by the subject, you may use only the exclamation mark to signify the BREAKING CHANGES, skipping the footer. Due diligence to communicate the BREAKING CHANGES well is recommended, so use the footer if needed.

### Scopes

The commit scope is not used in this repo.

### Subject

The `subject` contains a succinct description of the change:

- Is a **mandatory** part of the format
- Don't capitalize the first letter
- No dot (`.`) at the end

### Body

The `body` shall include the motivation for the change and contrast this with previous behavior:

- Is an **optional** part of the format
- This is the place to mention issue identifiers and their relations

### Footer

- If defining **Breaking Changes** in the footer, it shall start with the word `BREAKING CHANGES:` followed by space or two newlines. The rest of the commit message is then used to describe the breaking change. Note that BREAKING CHANGES can be used with any type and increments the MAJOR version.
  - The `!` mark should be used with the commit type in the commit subject but may be left out. `git-conventional-commits` does not enforce use of the exclamation point.
- **Reference Issues** that this commit refers to.
- Is an **optional** part of the format.
- Optionally reference an issue by its id.

### Example Commit Messages

**fix** - Increments the PATCH (1.0.0 → 1.0.1)

```text
fix: fixed a small bug related to when an exception is thrown
```

**feat** - Increments the MINOR (1.0.0 → 1.1.0)

```text
feat: Added monotonicConstraint.m function

monotonicConstraint.m adds new functionality that works well with regularizeNdMatrices.
```

**fix with BREAKING CHANGES** - Increments MAJOR (1.0.0 → 2.0.0)

```text
fix!: iterative solver now works

pcg and lsqr iterative solvers were not working. pcg is the main iterative solver. lsqr is just a backup in my opinion.

BREAKING CHANGE: Output to the user is now correct.
```

**feat with BREAKING CHANGES** - Using only the exclamation mark. Increments MAJOR (1.0.0 → 2.0.0)

```text
feat!: change of iterative solver
```

**feat with BREAKING CHANGES and footer** - Increments MAJOR (1.0.0 → 2.0.0)

```text
feat!: change of iterative solver

I was able to find a couple of acceptable iterative solvers. pcg and lsqr. pcg is the main iterative solver. lsqr is just a backup in my opinion.

BREAKING CHANGES: removed fmincon solver
```

**perf** - Increments the PATCH (1.0.0 → 1.0.1)

```text
perf: improved performance of pcg iterative solver
```

**docs** - Increments the PATCH (1.0.0 → 1.0.1)

```text
docs: improved the internal and external documentation of regularizeNd

The comments in regularizeNd.m were updated to better communicate the algorithm.

The regularizeNdDoc.m file was updated to better communicate how to use regularizeNd.m.
```

**chore** - Does not show up in the changelog. Increments the PATCH (1.0.0 → 1.0.1)

```text
chore: Updated the git configuration and git-conventional-commits.yaml
```

```text
chore: updated .gitignore with ignore files used in the build
```

```text
chore: updated the .gitattributes for a couple binary files
```

```text
chore: Excluding invalid commits in git-conventional-commits.yaml
```

## Further Reading

- See https://github.com/jasonnicholson/regularizeNd/blob/main/git-conventional-commits.yaml for the configuration of the conventional commits. The tooling used to check and manage conventional commits is [git-conventional-commits](https://github.com/qoomon/git-conventional-commits).
- [More Info on Conventional Commit Messages](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard
- [Semantic Versioning](https://semver.org/) standard

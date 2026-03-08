# Developer Guide

## Prerequisites

Install [nodejs](https://nodejs.org/en). `npm` comes with `nodejs` and is the package manager needed to install a development tool called `git-conventional-commits` in the repo on your computer. I use `NVM` to manage `nodejs`. I do the following to install NVM and then nodejs:

```bash
# Use the package manager to get NVM
# For Windows:
winget install --id CoreyButler.NVMforWindows

# For macOS/Linux:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Installs the Long Term Service version of nodejs
nvm install lts

# Sets the version of nodejs to use
nvm use lts

# Check that npm is available and what version
npm -v
```

## Development Workflow

1. Clone the repo.
2. Run `npm i` or `npm ci`. In the `prepare` script, the git hooks are configured. This sets up git-conventional-commits to lint the commit messages. Without this, commit messages are not checked.
3. Develop.
4. Commit using conventional commits.
5. Run `matlab -batch "release_workflow()"` for a dry run, or `matlab -batch "release_workflow('DryRun',false)"` to execute. This runs the release workflow end-to-end (see below) and uses the same dryRun state for `deploy_documentation`.
  

## Release Workflow

`release_workflow` performs the following steps:

1. Determines the next semantic version using `git-conventional-commits`.
2. Updates `package.json`, `pyproject.toml`, and `docs/conf.py` with the next version.
3. Generates `CHANGELOG.md`.
4. Builds the toolbox artifacts and packages the toolbox using `createPackage`.
5. Commits the version/changelog changes as `chore(release): vX.Y.Z` and tags `vX.Y.Z` (skipped in dry run).
6. Runs `deploy_documentation` with the same DryRun setting; when DryRun is true, it does everything except push.

Dry run behavior: version/changelog updates and changelog generation still run, but git commits/tags are not created and documentation pushes are skipped.

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

- See [git-conventional-commits.yaml](../git-conventional-commits.yaml) for the configuration of the conventional commits. The tooling used to check and manage conventional commits is [git-conventional-commits](https://github.com/qoomon/git-conventional-commits).
- [More Info on Conventional Commit Messages](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard
- [Semantic Versioning](https://semver.org/) standard

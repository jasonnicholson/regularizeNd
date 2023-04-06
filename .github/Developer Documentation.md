# Prereqs
Install [nodejs](https://nodejs.org/en). `npm` comes with `nodejs` and is the package manager needed to install a development tool called `git-conventional-commits` in the repo on your computer. I use `NVM` to manage `nodejs`. I do the following to install NVM and then nodejs:

```cmd
REM Use the windows package manager to get NVM
winget install --id CoreyButler.NVMforWindows

REM Installs the Long Term Service version of nodejs
nvm install lts

REM Sets the version of nodejs to use
nvm use lts

REM Check that npm is available and what version
npm -v
```

# Workflow
1. Clone the repo.
2. Run `post-clone-script.sh`.
3. Develop.
4. Commit using conventional commits.
5. Determine the next version by `git-conventional-commits version`.
6. Generate the Changelog by `git-conventional-commits changelog --release  <version> --file 'CHANGELOG.md'` 
7. Set the version in the `toolbox generation\regularizeNd.prj` in MATLAB. 
8. Run the `toolbox generation\createPackage.m` script. Use `toolbox generation\regularizeNd.prj` to create the toolbox package. 
9. Updating the changelog, version, and `regularizeNd.prj` is a `chore` type commit. Tag the commit with the version number.

# Semantic versioning
This repo adheres to [semantic versioning](https://semver.org/). 

Given a version number MAJOR.MINOR.PATCH, increment the:

* MAJOR version when you make incompatible API changes. BREAKING CHANGES. Any type of commit.
* MINOR version when you add functionality in a backwards compatible manner. feat type commit.
* PATCH version when you make backwards compatible bug fixes. fix/perf/docs/chore type commit.

# Conventional commits

## Commit format
The commit format used is 

<pre>
<b><a href="#types">&lt;type&gt;</a></b>: <b><a href="#subject">&lt;subject&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#body">&lt;optional body&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#footer">&lt;optional footer&gt;</a></b>
</pre>

### Types
* API relevant changes
    * `feat` Commits that adds a new feature. MINOR version bump. 
    * `fix` Commits that fixes a bug. PATCH version bump.
* `perf` Commits that improve performance. PATCH version bump.
* `docs` Commits that update internal or external documention. PATCH version bump.
* `chore` Miscellaneous commits e.g. modifying `.gitignore`, `tests`, refactoring, etc. This is the catch all type if one of the other types doesn't fit. Note, that this type will not show up in the Changelog. PATCH version bump.

### **!** - BREAKING CHANGES modifier

If you add an exclamation mark to any of the commit types, it signifies BREAKING CHANGES which increments the MAJOR version.

* `fix!: fixed a bug that change user output`
* `feat!: Changed a feature that changes the user input`

Recommendations when using the ! modifier:

* Use the exclamation mark when making BREAKING CHANGES even if you have a footer describing the breaking change. The exclamation mark makes it easy to recognize the commit subject `type!: subject here` is a BREAKING CHANGES.
* If BREAKING CHANGES can be described by the subject, you may use only the exclamation mark to signify the BREAKING CHANGES skipping the footer. Due diligence to communicate the BREAKING CHANGES well is recommended so use the footer if needed.


### Scopes
The commit scope is not used in this repo.

### Subject
The `subject` contains a succinct description of the change.
* Is a **mandatory** part of the format
* Don't capitalize the first letter
* No dot (.) at the end

### Body
The `body` shall include the motivation for the change and contrast this with previous behavior.
* Is an **optional** part of the format
* This is the place to mention issue identifiers and their relations

### Footer
* If defining **Breaking Changes** in the footer, it shall start with the word `BREAKING CHANGES:` followed by space or two newlines. The rest of the commit message is then used to describe the breaking change. Note, that BREAKING CHANGES can be used with any type and increments the MAJOR version.
    * The ! mark should be used with the commit type in commit subject but may be left out. `git-conventional-commits` does not enforce this and 
**reference Issues** that this commit refers to.
* Is an **optional** part of the format
* **optionally** reference an issue by its id.


## Example commit message and how they affect the version

* fix. Increments the PATCH 1.0.0 --> 1.0.1
    ```
    fix: fixed a small bug related to when an exception is thrown
    ```
* feat. Increments the MINOR 1.0.0 --> 1.1.0
    ```
    feat: Added monotonicConstraint.m function

    monotonicConstraint.m adds new functionality that works well with regularizeNdMatrices.
    ```
* fix with BREAKING CHANGES. An example of this comes up when output the user expects is different for the same input. Increments MAJOR 1.0.0 --> 2.0.0
    ```
    fix!: iterative solver now works

    pcg and lsqr iterative solvers were not working. pcg is the main iterative solver. lsqr is just a backup in my opinion.

    BREAKING CHANGE: Output to the user is now correct.
    ```
* feat with BREAKING CHANGES. Only the exclamation mark is used to signify the BREAKING CHANGES. The subject describes breaking change succintly. Increments MAJOR 1.0.0 --> 2.0.0
    ```
    feat!: change of iterative solver
    ```
* feat with BREAKING CHANGES. exclamation point and BREAKING CHANGES footer
    ```
    feat!: change of iterative solver

    I was able to find a couple of acceptable iterative solvers. pcg and lsqr. pcg is the main iterative solver. lsqr is just a backup in my opinion.

    BREAKING CHANGES: removed fmincon solver
    ```
* perf. Increments the PATCH 1.0.0 --> 1.0.1
    ```
    perf: improved performance of pcg iterative solver
    ```
* docs. Use this when updating documentation. Increments the PATCH 1.0.0 --> 1.0.1
    ```
    docs: improved the internal and external documentation of regularizeNd

    The comments in regularizeNd.m were updated to better communicate the algorithm.

    The regularizeNdDoc.m file was updated to better communicate how to use regulareNd.m.
    ```
* chore. Does not show up in the changelog. Increments the PATCH 1.0.0 --> 1.0.1
    ```
    chore: Updated the git configuration and git-conventional-commits.yaml
    ```
    ```
    chore: updated .gitignore with ignore files used in the build
    ```
    ```
    chore: updated the .gitattributes for a couple binary files
    ```
    ```
    chore: Excluding invalid commits in git-conventional-commits.yaml
    ```

## Further reading links
* See [../git-conventional-commits.yaml](../git-conventional-commits.yaml) for the configuration of the conventional commits. The tooling used to check and manage conventional commits is [git-conventional-commits](https://github.com/qoomon/git-conventional-commits).
* [More Info on Conventional Commit Messages here](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)
* [Conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) standard
* [semantic versioning](https://semver.org/) standard
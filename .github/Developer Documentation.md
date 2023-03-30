# Prereqs
You will need to install [nodejs](https://nodejs.org/en). `npm` comes with `nodejs` and is the package manager needed to install a development tool called `git-conventional-commits` in the repo on your computer. I use `NVM` to manage `nodejs`. I do the following to install NVM and then nodejs:

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

# Setup 
1. Clone the repo.
2. Run `post-clone-script.sh`.
3. Develop.
4. Commit using conventional commits.

# Conventional commits
This repos uses conventional commits. The format is 

<pre>
<b><a href="#types">&lt;type&gt;</a></b>: <b><a href="#subject">&lt;subject&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#body">&lt;optional body&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#footer">&lt;optional footer&gt;</a></b>
</pre>

See [../git-conventional-commits.yaml](../git-conventional-commits.yaml) for the configuration of the conventional commits. The important thing to find in the configuration is the commit `type`. The configuration was generate using the [git-conventional-commits](https://github.com/qoomon/git-conventional-commits) tool.

Example commit message:

```
chore: adding conventional commits
```


[More Info on Conventional Commit Messages here](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)

function deploy_documentation(options)
% deploy_documentation Deploy Sphinx HTML docs to the gh-pages branch.
%
% Usage:
%   deploy_documentation
%   deploy_documentation("DryRun", true)
%   deploy_documentation("DryRun", false)
%   deploy_documentation("SkipExamplesPublish", true)

% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root
%

arguments
    options.SkipExamplesPublish (1,1) logical = false
    options.DryRun (1,1) logical = true
end

skipExamplesPublish = options.SkipExamplesPublish;
dryRun = options.DryRun;

repoRoot = fileparts(fileparts(mfilename("fullpath")));
docsDir = fullfile(repoRoot, "docs");
buildHtmlDir = fullfile(docsDir, "_build", "html");
ghPagesBranch = "gh-pages";

if dryRun
    fprintf("[deploy_documentation] DRY RUN enabled: all steps run except push.\n");
end

ensure_gh_pages_worktree(repoRoot, buildHtmlDir, ghPagesBranch, false);
build_docs_html(repoRoot, docsDir, buildHtmlDir, skipExamplesPublish, false);

commitHash = strtrim(run_cmd_capture("git rev-parse HEAD", repoRoot, "deploy_documentation", false));
fprintf("[deploy_documentation] Current repo commit hash: %s\n", commitHash);

commit_and_push(buildHtmlDir, ghPagesBranch, commitHash, dryRun);
end

function ensure_gh_pages_worktree(repoRoot, buildHtmlDir, ghPagesBranch, dryRun)
fprintf("[deploy_documentation] Ensuring worktree at %s for branch %s\n", buildHtmlDir, ghPagesBranch);

if ~isfolder(buildHtmlDir)
    mkdir(buildHtmlDir);
end

branch = get_worktree_branch(buildHtmlDir);
if strlength(branch) > 0
    if branch ~= ghPagesBranch
        error("docs/_build/html is a git worktree on branch '%s', expected '%s'.", branch, ghPagesBranch);
    end
    fprintf("[deploy_documentation] Existing worktree on %s detected; reusing.\n", ghPagesBranch);
    return;
end

fprintf("[deploy_documentation] No valid git worktree found at %s, recreating as orphan %s worktree.\n", buildHtmlDir, ghPagesBranch);
cleanup_stale_worktree(repoRoot, buildHtmlDir, dryRun);
clear_directory_contents(buildHtmlDir);

showRefCmd = sprintf('git show-ref --verify --quiet refs/heads/%s', ghPagesBranch);
status = run_cmd(showRefCmd, repoRoot, "deploy_documentation", true, dryRun);
if status ~= 0
    fprintf("[deploy_documentation] Creating local branch %s (empty root commit).\n", ghPagesBranch);
    emptyTree = strtrim(run_cmd_capture('git hash-object -t tree /dev/null', repoRoot, "deploy_documentation", dryRun));
    commit = strtrim(run_cmd_capture(sprintf('git commit-tree %s -m "Initialize gh-pages"', emptyTree), repoRoot, "deploy_documentation", dryRun));
    run_cmd(sprintf('git update-ref refs/heads/%s %s', ghPagesBranch, commit), repoRoot, "deploy_documentation", false, dryRun);
end

run_cmd(sprintf('git worktree add "%s" %s', buildHtmlDir, ghPagesBranch), repoRoot, "deploy_documentation", false, dryRun);
end

function cleanup_stale_worktree(repoRoot, buildHtmlDir, dryRun)
fprintf("[deploy_documentation] Cleaning up stale worktree registrations (if any)\n");
run_cmd("git worktree repair", repoRoot, "deploy_documentation", true, dryRun);
run_cmd(sprintf('git worktree remove --force "%s"', buildHtmlDir), repoRoot, "deploy_documentation", true, dryRun);
run_cmd("git worktree prune", repoRoot, "deploy_documentation", true, dryRun);
end

function build_docs_html(repoRoot, docsDir, buildHtmlDir, skipExamplesPublish, dryRun)
if ~skipExamplesPublish
    publishExamplesScript = fullfile(repoRoot, "scripts", "publish_examples.m");
    if isfile(publishExamplesScript)
        fprintf("[deploy_documentation] Publishing MATLAB examples (best effort)\n");
        try
            publish_examples();
        catch ME
            warning(ME.identifier, '%s', ME.message);
        end
    end
end

venvBin = fullfile(repoRoot, ".venv", "bin");
if isfolder(venvBin)
    currentPath = getenv("PATH");
    if strlength(currentPath) > 0
        setenv("PATH", sprintf("%s:%s", venvBin, currentPath));
    else
        setenv("PATH", venvBin);
    end

    sphinxBuild = fullfile(venvBin, "sphinx-build");
    if isfile(sphinxBuild)
        setenv("SPHINXBUILD", sphinxBuild);
    end

    pythonExe = fullfile(venvBin, "python");
    if isfile(pythonExe)
        setenv("PYTHON", pythonExe);
    end
end

fprintf("[deploy_documentation] Building Sphinx HTML docs (uv run sphinx-build)\n");
run_cmd(sprintf('uv run sphinx-build -b html "%s" "%s"', docsDir, buildHtmlDir), docsDir, "deploy_documentation", false, dryRun);
end

function commit_and_push(buildHtmlDir, ghPagesBranch, commitHash, skipPush)
fprintf("[deploy_documentation] Preparing commit in gh-pages worktree\n");

nojekyllPath = fullfile(buildHtmlDir, ".nojekyll");
if ~isfile(nojekyllPath)
    fprintf("[deploy_documentation] Creating .nojekyll file\n");
    write_text_file(nojekyllPath, "# Disable Jekyll for Sphinx docs\n");
end

run_cmd("git add --all", buildHtmlDir, "deploy_documentation", false, false);
statusOutput = strtrim(run_cmd_capture("git status --porcelain", buildHtmlDir, "deploy_documentation", false));
if strlength(statusOutput) == 0
    fprintf("[deploy_documentation] No changes to commit in gh-pages; skipping commit and push.\n");
    return;
end

message = sprintf("chore: deploy to gh-pages, %s", commitHash);
tree = strtrim(run_cmd_capture("git write-tree", buildHtmlDir, "deploy_documentation", false));
newCommit = strtrim(run_cmd_capture(sprintf('git commit-tree %s -m "%s"', tree, message), buildHtmlDir, "deploy_documentation", false));

run_cmd(sprintf('git update-ref refs/heads/%s %s', ghPagesBranch, newCommit), buildHtmlDir, "deploy_documentation", false, false);
run_cmd(sprintf('git reset --hard %s', newCommit), buildHtmlDir, "deploy_documentation", false, false);

if skipPush
    fprintf("[deploy_documentation] Dry run enabled: skipping push.\n");
    return;
end

fprintf("[deploy_documentation] Pushing gh-pages to origin (force)\n");
run_cmd(sprintf('git push --force origin %s', ghPagesBranch), buildHtmlDir, "deploy_documentation", false, false);
end

function branch = get_worktree_branch(pathToWorktree)
branch = "";
gitDir = fullfile(pathToWorktree, ".git");
if ~exist(gitDir, "dir") && ~exist(gitDir, "file")
    return;
end

try
    out = strtrim(run_cmd_capture("git rev-parse --abbrev-ref HEAD", pathToWorktree, "deploy_documentation", false));
    if out ~= "HEAD"
        branch = string(out);
    end
catch
    branch = "";
end
end

function clear_directory_contents(pathToDir)
items = dir(pathToDir);
for k = 1:numel(items)
    name = items(k).name;
    if name == "." || name == ".."
        continue;
    end

    fullPath = fullfile(pathToDir, name);
    if items(k).isdir
        rmdir(fullPath, "s");
    else
        delete(fullPath);
    end
end
end

function status = run_cmd(cmd, cwd, prefix, allowFailure, dryRun)
if nargin < 4 || isempty(allowFailure)
    allowFailure = false;
end
if nargin < 5
    dryRun = false;
end

fprintf("[%s] $ %s\n", prefix, cmd);
if dryRun
    status = 0;
    return;
end

fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
status = system(fullCmd, "-echo");
if status ~= 0 && ~allowFailure
    error("[%s] Command failed with status %d: %s", prefix, status, cmd);
end
end

function out = run_cmd_capture(cmd, cwd, prefix, dryRun)
if nargin < 4
    dryRun = false;
end

fprintf("[%s] $ %s\n", prefix, cmd);
if dryRun
    out = "DRY_RUN";
    return;
end

fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
[status, out] = system(fullCmd);
if status ~= 0
    error("[%s] Command failed with status %d: %s", prefix, status, cmd);
end
end

function write_text_file(pathToFile, text)
fid = fopen(pathToFile, "w");
if fid == -1
    error("Unable to open file for writing: %s", pathToFile);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", text);
end

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
PREFIX = "[deploy_documentation]";

repoRoot = fileparts(fileparts(mfilename("fullpath")));
docsDir = fullfile(repoRoot, "docs");
buildHtmlDir = fullfile(docsDir, "_build", "html");
ghPagesBranch = "gh-pages";

if dryRun
    fprintf("%s DRY RUN enabled: all steps run except push.\n", PREFIX);
end

ensure_gh_pages_worktree(repoRoot, buildHtmlDir, ghPagesBranch, PREFIX);
build_docs_html(repoRoot, docsDir, buildHtmlDir, skipExamplesPublish, PREFIX);

commitHash = strtrim(run_cmd_capture("git rev-parse HEAD", repoRoot, PREFIX));
fprintf("%s Current repo commit hash: %s\n", PREFIX, commitHash);

commit_and_push(buildHtmlDir, ghPagesBranch, commitHash, dryRun, PREFIX);
end

function ensure_gh_pages_worktree(repoRoot, buildHtmlDir, ghPagesBranch, prefix)
fprintf("%s Ensuring worktree at %s for branch %s\n", prefix, buildHtmlDir, ghPagesBranch);

if ~isfolder(buildHtmlDir)
    mkdir(buildHtmlDir);
end

branch = get_worktree_branch(buildHtmlDir, prefix);
if strlength(branch) > 0
    if branch ~= ghPagesBranch
        error("docs/_build/html is a git worktree on branch '%s', expected '%s'.", branch, ghPagesBranch);
    end
    fprintf("%s Existing worktree on %s detected; reusing.\n", prefix, ghPagesBranch);
    return;
end

fprintf("%s No valid git worktree found at %s, recreating as orphan %s worktree.\n", prefix, buildHtmlDir, ghPagesBranch);
cleanup_stale_worktree(repoRoot, buildHtmlDir, prefix);
clear_directory_contents(buildHtmlDir);

showRefCmd = sprintf('git show-ref --verify --quiet refs/heads/%s', ghPagesBranch);
status = run_cmd(showRefCmd, repoRoot, prefix, true);
if status ~= 0
    fprintf("%s Creating local branch %s (empty root commit).\n", prefix, ghPagesBranch);
    emptyTree = strtrim(run_cmd_capture('git hash-object -t tree /dev/null', repoRoot, prefix));
    commit = strtrim(run_cmd_capture(sprintf('git commit-tree %s -m "Initialize gh-pages"', emptyTree), repoRoot, prefix));
    run_cmd(sprintf('git update-ref refs/heads/%s %s', ghPagesBranch, commit), repoRoot, prefix, false);
end

run_cmd(sprintf('git worktree add "%s" %s', buildHtmlDir, ghPagesBranch), repoRoot, prefix, false);
end

function cleanup_stale_worktree(repoRoot, buildHtmlDir, prefix)
fprintf("%s Cleaning up stale worktree registrations (if any)\n", prefix);
run_cmd("git worktree repair", repoRoot, prefix, true);
run_cmd(sprintf('git worktree remove --force "%s"', buildHtmlDir), repoRoot, prefix, true);
run_cmd("git worktree prune", repoRoot, prefix, true);
end

function build_docs_html(repoRoot, docsDir, buildHtmlDir, skipExamplesPublish, prefix)
if ~skipExamplesPublish
    publishExamplesScript = fullfile(repoRoot, "scripts", "publish_examples.m");
    if isfile(publishExamplesScript)
        fprintf("%s Publishing MATLAB examples (best effort)\n", prefix);
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

fprintf("%s Building Sphinx HTML docs (uv run sphinx-build)\n", prefix);
run_cmd(sprintf('uv run sphinx-build -b html "%s" "%s"', docsDir, buildHtmlDir), docsDir, prefix, false);
end

function commit_and_push(buildHtmlDir, ghPagesBranch, commitHash, skipPush, prefix)
fprintf("%s Preparing commit in gh-pages worktree\n", prefix);

nojekyllPath = fullfile(buildHtmlDir, ".nojekyll");
if ~isfile(nojekyllPath)
    fprintf("%s Creating .nojekyll file\n", prefix);
    write_text_file(nojekyllPath, "# Disable Jekyll for Sphinx docs\n");
end

run_cmd("git add --all", buildHtmlDir, prefix, false);
statusOutput = strtrim(run_cmd_capture("git status --porcelain", buildHtmlDir, prefix));
if strlength(statusOutput) == 0
    fprintf("%s No changes to commit in gh-pages; skipping commit and push.\n", prefix);
    return;
end

message = sprintf("chore: deploy to gh-pages, %s", commitHash);
tree = strtrim(run_cmd_capture("git write-tree", buildHtmlDir, prefix));
newCommit = strtrim(run_cmd_capture(sprintf('git commit-tree %s -m "%s"', tree, message), buildHtmlDir, prefix));

run_cmd(sprintf('git update-ref refs/heads/%s %s', ghPagesBranch, newCommit), buildHtmlDir, prefix, false);
run_cmd(sprintf('git reset --hard %s', newCommit), buildHtmlDir, prefix, false);

if skipPush
    fprintf("%s Dry run enabled: skipping push.\n", prefix);
    return;
end

fprintf("%s Pushing gh-pages to origin (force)\n", prefix);
run_cmd(sprintf('git push --force origin %s', ghPagesBranch), buildHtmlDir, prefix, false);
end

function branch = get_worktree_branch(pathToWorktree, prefix)
branch = "";
gitDir = fullfile(pathToWorktree, ".git");
if ~exist(gitDir, "dir") && ~exist(gitDir, "file")
    return;
end

try
    out = strtrim(run_cmd_capture("git rev-parse --abbrev-ref HEAD", pathToWorktree, prefix));
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

function status = run_cmd(cmd, cwd, prefix, allowFailure)
if nargin < 4 || isempty(allowFailure)
    allowFailure = false;
end

fprintf("%s $ %s\n", prefix, cmd);

fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
status = system(fullCmd, "-echo");
if status ~= 0 && ~allowFailure
    error("%s Command failed with status %d: %s", prefix, status, cmd);
end
end

function out = run_cmd_capture(cmd, cwd, prefix)
fprintf("%s $ %s\n", prefix, cmd);

fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
[status, out] = system(fullCmd);
if status ~= 0
    error("%s Command failed with status %d: %s", prefix, status, cmd);
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

function release_workflow(options)
% release_workflow Automates release workflow steps in MATLAB.
%
% Usage:
%   release_workflow
%   release_workflow("DryRun", true)
%   release_workflow("DryRun", false)
%   matlab -batch "release_workflow('DryRun',true)"

% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root
%
arguments
    options.DryRun (1,1) logical = true
end

dryRun = options.DryRun;

projectRoot = fileparts(fileparts(mfilename("fullpath")));

assert_clean_changelog(projectRoot);

if dryRun
    fprintf("[release] DRY RUN enabled: version/changelog updates run; packaging is skipped; docs deploy runs without push.\n");
end

fprintf("[release] Determining next semantic version\n");
nextVersionRaw = run_cmd_capture("pnpm exec git-conventional-commits version", projectRoot, "release", false);
nextVersion = parse_semver(nextVersionRaw);
fprintf("[release] Next version: %s\n", nextVersion);

update_package_json_version(fullfile(projectRoot, "package.json"), nextVersion, false);
update_conf_py_version(fullfile(projectRoot, "docs", "conf.py"), nextVersion, false);
update_pyproject_version(fullfile(projectRoot, "pyproject.toml"), nextVersion, false);

fprintf("[release] Generating CHANGELOG.md\n");
run_cmd("pnpm exec git-conventional-commits changelog --file CHANGELOG.md", projectRoot, "release", false);

fprintf("[release] Running createPackage\n");
if ~dryRun
    scriptsDir = fullfile(projectRoot, "scripts");
    addpath(scriptsDir);
    cleanupObj = onCleanup(@() rmpath(scriptsDir));
    createPackage("ToolboxVersion", nextVersion);
end

fprintf("[release] Committing and tagging release\n");
commit_and_tag_release(projectRoot, nextVersion, dryRun);

fprintf("[release] Creating GitHub release\n");
create_github_release(projectRoot, nextVersion, dryRun);

fprintf("[release] Deploying documentation\n");
deploy_documentation("DryRun", dryRun);
end

function run_cmd(cmd, cwd, prefix, dryRun)
fprintf("[%s] $ %s\n", prefix, cmd);
if dryRun
    return;
end

fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
status = system(fullCmd, "-echo");
if status ~= 0
    error("[%s] Command failed with status %d: %s", prefix, status, cmd);
end
end

function out = run_cmd_capture(cmd, cwd, prefix, dryRun)
fprintf("[%s] $ %s\n", prefix, cmd);
if dryRun
    out = "3.0.0";
    return;
end
fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
[status, out] = system(fullCmd);
if status ~= 0
    error("[%s] Command failed with status %d: %s", prefix, status, cmd);
end
end

function assert_clean_changelog(repoRoot)
statusOutput = strtrim(run_cmd_capture("git status --porcelain CHANGELOG.md", repoRoot, "release", false));
if strlength(statusOutput) > 0
    error("CHANGELOG.md has local modifications. Commit or discard them before running release_workflow.");
end
end

function version = parse_semver(raw)
    raw = string(raw);
    raw = strtrim(raw);
    tokens = regexp(raw, 'v?(\d+\.\d+\.\d+)', 'tokens', 'once');
    if isempty(tokens)
        error("Unable to parse semantic version from command output: %s", raw);
    end
    version = tokens{1};
end

function update_package_json_version(filePath, newVersion, dryRun)
content = fileread(filePath);
pattern = '"version"\\s*:\\s*"[^"]+"';
replacement = sprintf('"version": "%s"', newVersion);
updated = regexprep(content, pattern, replacement, 'once');

if strcmp(content, updated)
    fprintf("[release] package.json already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release] DRY RUN: would set package.json version to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release] Updated package.json version to %s\n", newVersion);
end

function update_conf_py_version(filePath, newVersion, dryRun)
content = fileread(filePath);
updated = regexprep(content, "^version\\s*=\\s*'.*'$", sprintf("version = '%s'", newVersion), 'lineanchors', 'once');
updated = regexprep(updated, "^release\\s*=\\s*'.*'$", sprintf("release = '%s'", newVersion), 'lineanchors', 'once');

if strcmp(content, updated)
    fprintf("[release] docs/conf.py already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release] DRY RUN: would set docs/conf.py version and release to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release] Updated docs/conf.py version and release to %s\n", newVersion);
end

function update_pyproject_version(filePath, newVersion, dryRun)
content = fileread(filePath);
pattern = '^version\s*=\s*"[^"]+"';
replacement = sprintf('version = "%s"', newVersion);
updated = regexprep(content, pattern, replacement, 'lineanchors', 'once');

if strcmp(content, updated)
    fprintf("[release] pyproject.toml already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release] DRY RUN: would set pyproject.toml version to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release] Updated pyproject.toml version to %s\n", newVersion);
end

function commit_and_tag_release(repoRoot, newVersion, dryRun)
run_cmd("git add package.json docs/conf.py pyproject.toml CHANGELOG.md", repoRoot, "release", dryRun);
statusOutput = strtrim(run_cmd_capture("git status --porcelain", repoRoot, "release", false));
if strlength(statusOutput) == 0
    fprintf("[release] No changes to commit; skipping commit and tag.\n");
    return;
end

message = sprintf("chore(release): v%s", newVersion);
run_cmd(sprintf('git commit -m "%s"', message), repoRoot, "release", dryRun);

tagName = sprintf("v%s", newVersion);
run_cmd(sprintf("git tag %s", tagName), repoRoot, "release", dryRun);
end

function create_github_release(repoRoot, newVersion, dryRun)
tagName = sprintf("v%s", newVersion);
title = sprintf("v%s", newVersion);
notesFile = build_release_notes(repoRoot, newVersion);

cmd = sprintf('gh release create %s --title "%s" --notes-file "%s"', tagName, title, notesFile);
run_cmd(cmd, repoRoot, "release", dryRun);

cleanup_temp_file(notesFile);
end

function notesFile = build_release_notes(repoRoot, newVersion)
cmd = 'pnpm exec git-conventional-commits changelog';

notes = run_cmd_capture(cmd, repoRoot, "release", false);
notes = string(notes);
if strlength(strtrim(notes)) == 0
    notes = sprintf("# v%s\n\nNo changes.\n", newVersion);
end

notesFile = tempname + ".md";
write_text_file(notesFile, notes);
end

function cleanup_temp_file(filePath)
if isfile(filePath)
    try
        delete(filePath);
    catch
    end
end
end

function write_text_file(filePath, textContent)
fid = fopen(filePath, "w");
if fid == -1
    error("Unable to open file for writing: %s", filePath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textContent);
end

function release_workflow_part2(options)
% release_workflow_part2 Completes the release workflow after manual toolbox packaging.
%
% Run this after release_workflow_part1 and after manually packaging the
% toolbox in MATLAB (Package Toolbox dialog).
%
% Usage:
%   release_workflow_part2
%   release_workflow_part2("DryRun", true)
%   release_workflow_part2("DryRun", false)
%   matlab -batch "release_workflow_part2('DryRun',true)"

% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root
%
arguments
    options.DryRun (1,1) logical = true
end

dryRun = options.DryRun;

projectRoot = fileparts(fileparts(mfilename("fullpath")));

if dryRun
    fprintf("[release_workflow_part2] DRY RUN enabled: git release actions are printed.\n");
end

nextVersionRaw = run_cmd_capture("pnpm exec git-conventional-commits version", projectRoot, "release_workflow_part2", false);
nextVersion = parse_semver(nextVersionRaw);
fprintf("[release_workflow_part2] Version: %s\n", nextVersion);

fprintf("[release_workflow_part2] Committing and tagging release\n");
commit_and_tag_release(projectRoot, nextVersion, dryRun);

fprintf("[release_workflow_part2] Creating GitHub release\n");
artifactPath = get_toolbox_artifact_path(projectRoot);
create_github_release(projectRoot, nextVersion, artifactPath, dryRun);

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

function version = parse_semver(raw)
    raw = string(raw);
    raw = strtrim(raw);
    tokens = regexp(raw, 'v?(\d+\.\d+\.\d+)', 'tokens', 'once');
    if isempty(tokens)
        error("Unable to parse semantic version from command output: %s", raw);
    end
    version = tokens{1};
end

function commit_and_tag_release(repoRoot, newVersion, dryRun)
run_cmd("git add package.json docs/conf.py pyproject.toml CHANGELOG.md uv.lock", repoRoot, "release_workflow_part2", dryRun);
statusOutput = strtrim(run_cmd_capture("git status --porcelain", repoRoot, "release_workflow_part2", false));
if strlength(statusOutput) == 0
    fprintf("[release_workflow_part2] No changes to commit; skipping commit and tag.\n");
    return;
end

message = sprintf("chore(release): %s", newVersion);
run_cmd(sprintf('git commit -m "%s"', message), repoRoot, "release_workflow_part2", dryRun);

tagName = sprintf("%s", newVersion);
run_cmd(sprintf("git tag %s", tagName), repoRoot, "release_workflow_part2", dryRun);

if ~dryRun
    fprintf("[release_workflow_part2] Pushing commits and tags\n");
    run_cmd("git push", repoRoot, "release_workflow_part2", false);
    run_cmd(sprintf("git push origin refs/tags/%s", tagName), repoRoot, "release_workflow_part2", false);
end
end

function create_github_release(repoRoot, newVersion, artifactPath, dryRun)
tagName = sprintf("%s", newVersion);
title = sprintf("%s", newVersion);
notesFile = build_release_notes(repoRoot, newVersion);

cmd = sprintf('gh release create %s --title "%s" --notes-file "%s"', tagName, title, notesFile);
if strlength(artifactPath) > 0
    cmd = sprintf('%s "%s"', cmd, artifactPath);
else
    fprintf("[release_workflow_part2] Toolbox artifact not found; creating release without attachment.\n");
end
run_cmd(cmd, repoRoot, "release_workflow_part2", dryRun);

cleanup_temp_file(notesFile);
end

function artifactPath = get_toolbox_artifact_path(projectRoot)
artifactPath = "";
candidate = fullfile(projectRoot, "build", "release", "regularizeNd-toolbox.mltbx");
if isfile(candidate)
    artifactPath = string(candidate);
end
end

function notesFile = build_release_notes(repoRoot, newVersion)
cmd = 'pnpm exec git-conventional-commits changelog';

notes = run_cmd_capture(cmd, repoRoot, "release_workflow_part2", false);
notes = string(notes);
if strlength(strtrim(notes)) == 0
    notes = sprintf("# %s\n\nNo changes.\n", newVersion);
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

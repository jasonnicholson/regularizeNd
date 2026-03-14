function release_workflow_part1(options)
% release_workflow_part1 Automates the first part of the release workflow.
%
% Run this first. After it completes, follow the printed instructions to
% manually package the toolbox in MATLAB, then run release_workflow_part2.
%
% Usage:
%   release_workflow_part1
%   release_workflow_part1("DryRun", true)
%   release_workflow_part1("DryRun", false)
%   matlab -batch "release_workflow_part1('DryRun',true)"

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
    fprintf("[release_workflow_part1] DRY RUN enabled: version/changelog/file updates are skipped; git release actions are skipped; docs deploy runs without push.\n");
end

fprintf("[release_workflow_part1] Determining next semantic version\n");
nextVersionRaw = run_cmd_capture("pnpm exec git-conventional-commits version", projectRoot, "release_workflow_part1", false);
nextVersion = parse_semver(nextVersionRaw);
fprintf("[release_workflow_part1] Next version: %s\n", nextVersion);

update_package_json_version(fullfile(projectRoot, "package.json"), nextVersion, dryRun);
update_conf_py_version(fullfile(projectRoot, "docs", "conf.py"), nextVersion, dryRun);
update_pyproject_version(fullfile(projectRoot, "pyproject.toml"), nextVersion, dryRun);

fprintf("[release_workflow_part1] Generating CHANGELOG.md\n");
run_cmd("pnpm exec git-conventional-commits changelog --file CHANGELOG.md", projectRoot, "release_workflow_part1", false);

fprintf("[release_workflow_part1] Deploying documentation\n");
deploy_documentation("DryRun", dryRun);

fprintf("[release_workflow_part1] Setting up build directory\n");
createPackage("ToolboxVersion", nextVersion, "PackageToolbox", false);

fprintf("\n");
fprintf("[release_workflow_part1] Part 1 complete. Before running release_workflow_part2, do the following manually:\n");
fprintf("\n");
fprintf("  1. Open the build\\regularizeNd.prj.\n");
fprintf('  2. Click "Package Toolbox".\n');
fprintf("  3. Set the version.\n");
fprintf("  4. Make the Getting Started file is correctly configured.\n");
fprintf("\n");
fprintf("Then run: release_workflow_part2('DryRun', %s)\n", mat2str(dryRun));
fprintf("\n");

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
statusOutput = strtrim(run_cmd_capture("git status --porcelain CHANGELOG.md", repoRoot, "release_workflow", false));
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
    fprintf("[release_workflow] package.json already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release_workflow] DRY RUN: would set package.json version to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release_workflow] Updated package.json version to %s\n", newVersion);
end

function update_conf_py_version(filePath, newVersion, dryRun)
content = fileread(filePath);
updated = regexprep(content, "^version\\s*=\\s*'.*'$", sprintf("version = '%s'", newVersion), 'lineanchors', 'once');
updated = regexprep(updated, "^release\\s*=\\s*'.*'$", sprintf("release = '%s'", newVersion), 'lineanchors', 'once');

if strcmp(content, updated)
    fprintf("[release_workflow] docs/conf.py already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release_workflow] DRY RUN: would set docs/conf.py version and release to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release_workflow] Updated docs/conf.py version and release to %s\n", newVersion);
end

function update_pyproject_version(filePath, newVersion, dryRun)
content = fileread(filePath);
pattern = '^version\s*=\s*"[^"]+"';
replacement = sprintf('version = "%s"', newVersion);
updated = regexprep(content, pattern, replacement, 'lineanchors', 'once');

if strcmp(content, updated)
    fprintf("[release_workflow] pyproject.toml already at version %s\n", newVersion);
    return;
end

if dryRun
    fprintf("[release_workflow] DRY RUN: would set pyproject.toml version to %s\n", newVersion);
    return;
end

write_text_file(filePath, updated);
fprintf("[release_workflow] Updated pyproject.toml version to %s\n", newVersion);
end

function write_text_file(filePath, textContent)
fid = fopen(filePath, "w");
if fid == -1
    error("Unable to open file for writing: %s", filePath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textContent);
end

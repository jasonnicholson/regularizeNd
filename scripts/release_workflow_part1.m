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
  PREFIX = "[release_workflow_part1]";

  projectRoot = fileparts(fileparts(mfilename("fullpath")));

  assert_clean_changelog(projectRoot, PREFIX);

  if dryRun
    fprintf("%s DRY RUN enabled: version/changelog/file updates are skipped; git release actions are skipped; docs deploy runs without push.\n", PREFIX);
  end

  fprintf("%s Determining next semantic version\n",PREFIX);
  nextVersionRaw = run_cmd_capture("pnpm exec git-conventional-commits version", projectRoot, PREFIX);
  nextVersion = parse_semver(nextVersionRaw);
  fprintf("%s Next version: %s\n", PREFIX, nextVersion);

  update_package_json_version(fullfile(projectRoot, "package.json"), nextVersion, dryRun, PREFIX);
  update_conf_py_version(fullfile(projectRoot, "docs", "conf.py"), nextVersion, dryRun, PREFIX);
  update_pyproject_version(fullfile(projectRoot, "pyproject.toml"), nextVersion, dryRun, PREFIX);

  fprintf("%s Generating CHANGELOG.md\n", PREFIX);
  run_cmd("pnpm exec git-conventional-commits changelog --file CHANGELOG.md", projectRoot, PREFIX);

  fprintf("%s Deploying documentation\n", PREFIX);
  deploy_documentation("DryRun", dryRun);

  fprintf("%s Setting up build directory\n", PREFIX);
  createPackage("ToolboxVersion", nextVersion, "PackageToolbox", false);

  fprintf("\n");
  fprintf("%s Part 1 complete. Before running release_workflow_part2, do the following manually:\n", PREFIX);
  fprintf("\n");
  fprintf("  1. Open the build\\regularizeNd_project.prj.\n");
  fprintf('  2. Click "Package Toolbox".\n');
  fprintf("  3. Set the version.\n");
  fprintf("  4. Make the Getting Started file is correctly configured.\n");
  fprintf("  5. Click ""Package Toolbox"".\n");
  fprintf("\n");
  fprintf("Then run: release_workflow_part2('DryRun', %s)\n", mat2str(dryRun));
  fprintf("\n");

end

function run_cmd(cmd, cwd, prefix)
  fprintf("%s $ %s\n", prefix, cmd);

  fullCmd = sprintf('cd "%s" && %s', cwd, cmd);
  status = system(fullCmd, "-echo");
  if status ~= 0
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

function assert_clean_changelog(repoRoot, prefix)
  statusOutput = strtrim(run_cmd_capture("git status --porcelain CHANGELOG.md", repoRoot, prefix));
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

function update_package_json_version(filePath, newVersion, dryRun, prefix)
  content = fileread(filePath);
  pattern = '"version"\s*:\s*"[^"]+"';
  replacement = sprintf('"version": "%s"', newVersion);
  updated = regexprep(content, pattern, replacement, 'once');

  if strcmp(content, updated)
    fprintf("%s package.json already at version %s\n", prefix, newVersion);
    return;
  end

  if dryRun
    fprintf("%s DRY RUN: would set package.json version to %s\n", prefix, newVersion);
    return;
  end

  write_text_file(filePath, updated);
  fprintf("%s Updated package.json version to %s\n", prefix, newVersion);
end

function update_conf_py_version(filePath, newVersion, dryRun, prefix)
  content = fileread(filePath);
  updated = regexprep(content, "version = '\d+\.\d+\.\d+'", sprintf("version = '%s'", newVersion), 'lineanchors', 'once');
  updated = regexprep(updated, "release = '\d+\.\d+\.\d+'", sprintf("release = '%s'", newVersion), 'lineanchors', 'once');

  if strcmp(content, updated)
    fprintf("%s docs/conf.py already at version %s\n", prefix, newVersion);
    return;
  end

  if dryRun
    fprintf("%s DRY RUN: would set docs/conf.py version and release to %s\n", prefix, newVersion);
    return;
  end

  write_text_file(filePath, updated);
  fprintf("%s Updated docs/conf.py version and release to %s\n", prefix, newVersion);
end

function update_pyproject_version(filePath, newVersion, dryRun, prefix)
  content = fileread(filePath);
  pattern = '^version\s*=\s*"[^"]+"';
  replacement = sprintf('version = "%s"', newVersion);
  updated = regexprep(content, pattern, replacement, 'lineanchors', 'once');

  if strcmp(content, updated)
    fprintf("%s pyproject.toml already at version %s\n", prefix, newVersion);
    return;
  end

  if dryRun
    fprintf("%s DRY RUN: would set pyproject.toml version to %s\n", prefix, newVersion);
    return;
  end

  write_text_file(filePath, updated);
  fprintf("%s Updated pyproject.toml version to %s\n", prefix, newVersion);
end

function write_text_file(filePath, textContent)
  fid = fopen(filePath, "w");
  if fid == -1
    error("Unable to open file for writing: %s", filePath);
  end
  cleanupObj = onCleanup(@() fclose(fid));
  fprintf(fid, "%s", textContent);
end

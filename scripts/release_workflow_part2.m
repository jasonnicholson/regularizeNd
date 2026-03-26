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
  PREFIX = "[release_workflow_part2]";

  projectRoot = fileparts(fileparts(mfilename("fullpath")));

  if dryRun
    fprintf("%s DRY RUN enabled: git release actions are printed.\n", PREFIX);
  end

  nextVersionRaw = run_cmd_capture("pnpm exec git-conventional-commits version", projectRoot, PREFIX);
  nextVersion = parse_semver(nextVersionRaw);
  fprintf("%s Version: %s\n", PREFIX, nextVersion);

  fprintf("%s Committing and tagging release\n", PREFIX);
  commit_and_tag_release(projectRoot, nextVersion, dryRun, PREFIX);

  fprintf("%s Creating GitHub release\n", PREFIX);
  artifactPath = get_toolbox_artifact_path(projectRoot);
  create_github_release(projectRoot, nextVersion, artifactPath, dryRun, PREFIX);

end

function run_cmd(cmd, cwd, prefix, dryRun)
  fprintf("%s $ %s\n", prefix, cmd);
  if dryRun
    return;
  end

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

function version = parse_semver(raw)
  raw = string(raw);
  raw = strtrim(raw);
  tokens = regexp(raw, 'v?(\d+\.\d+\.\d+)', 'tokens', 'once');
  if isempty(tokens)
    error("Unable to parse semantic version from command output: %s", raw);
  end
  version = tokens{1};
end

function commit_and_tag_release(repoRoot, newVersion, dryRun, prefix)
  run_cmd("git add package.json docs/conf.py pyproject.toml CHANGELOG.md uv.lock", repoRoot, prefix, dryRun);
  statusOutput = strtrim(run_cmd_capture("git status --porcelain", repoRoot, prefix));
  if strlength(statusOutput) == 0
    fprintf("%s No changes to commit; skipping commit and tag.\n", prefix);
    return;
  end

  message = sprintf("chore(release): %s", newVersion);
  run_cmd(sprintf('git commit -m "%s"', message), repoRoot, prefix, dryRun);

  tagName = sprintf("%s", newVersion);
  run_cmd(sprintf("git tag %s", tagName), repoRoot, prefix, dryRun);

  if ~dryRun
    fprintf("%s Pushing commits and tags\n", prefix);
    run_cmd("git push", repoRoot, prefix, false);
    run_cmd(sprintf("git push origin refs/tags/%s", tagName), repoRoot, prefix, false);
  end
end

function create_github_release(repoRoot, newVersion, artifactPath, dryRun, prefix)
  tagName = sprintf("%s", newVersion);
  title = sprintf("%s", newVersion);
  notesFile = build_release_notes(repoRoot, newVersion, prefix);

  cmd = sprintf('gh release create %s --title "%s" --notes-file "%s"', tagName, title, notesFile);
  if strlength(artifactPath) > 0
    cmd = sprintf('%s "%s"', cmd, artifactPath);
  else
    fprintf("%s Toolbox artifact not found; creating release without attachment.\n", prefix);
  end
  run_cmd(cmd, repoRoot, prefix, dryRun);

  cleanup_temp_file(notesFile);
end

function artifactPath = get_toolbox_artifact_path(projectRoot)
  artifactPath = "";
  candidate = fullfile(projectRoot, "build", "release", "regularizeNd-toolbox.mltbx");
  if isfile(candidate)
    artifactPath = string(candidate);
  end
end

function notesFile = build_release_notes(repoRoot, newVersion, prefix)
  cmd = 'pnpm exec git-conventional-commits changelog';

  notes = run_cmd_capture(cmd, repoRoot, prefix);
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

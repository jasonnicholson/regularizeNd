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

  remove_legacy_worktree(repoRoot, buildHtmlDir, PREFIX);
  build_docs_html(repoRoot, docsDir, buildHtmlDir, skipExamplesPublish, PREFIX);

  commitHash = strtrim(run_cmd_capture("git rev-parse HEAD", repoRoot, PREFIX));
  fprintf("%s Current repo commit hash: %s\n", PREFIX, commitHash);

  publish_with_ghp_import(repoRoot, buildHtmlDir, ghPagesBranch, commitHash, dryRun, PREFIX);
end

function remove_legacy_worktree(repoRoot, buildHtmlDir, prefix)
  % Older versions of this script checked out gh-pages at docs/_build/html.
  if isfile(fullfile(buildHtmlDir, ".git"))
    fprintf("%s Removing legacy gh-pages worktree at %s\n", prefix, buildHtmlDir);
    run_cmd(sprintf('git worktree remove --force "%s"', buildHtmlDir), repoRoot, prefix, false);
  end
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

  % Doctrees default to <outdir>/.doctrees; keep them out of the published folder.
  doctreeDir = fullfile(docsDir, "_build", "doctrees");
  fprintf("%s Building Sphinx HTML docs (uv run --group docs python -m sphinx)\n", prefix);
  run_cmd(sprintf('uv run --group docs python -m sphinx -b html -d "%s" "%s" "%s"', doctreeDir, docsDir, buildHtmlDir), docsDir, prefix, false);
end

function publish_with_ghp_import(repoRoot, buildHtmlDir, ghPagesBranch, commitHash, dryRun, prefix)
  message = sprintf("chore: deploy to gh-pages, %s", commitHash);

  % --no-jekyll adds .nojekyll; --force overwrites the branch history.
  cmd = sprintf('uv run --group publish ghp-import --no-jekyll --force --branch %s --remote origin --message "%s"', ghPagesBranch, message);
  if dryRun
    fprintf("%s Dry run enabled: committing to local %s only, skipping push.\n", prefix, ghPagesBranch);
  else
    cmd = cmd + " --push";
    fprintf("%s Publishing to origin/%s (force)\n", prefix, ghPagesBranch);
  end

  run_cmd(sprintf('%s "%s"', cmd, buildHtmlDir), repoRoot, prefix, false);
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

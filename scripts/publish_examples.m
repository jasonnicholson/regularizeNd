function publish_examples()
% publish_examples Publish MATLAB example scripts as HTML for Sphinx.
%
% This publishes all .m scripts under the repo's Examples/ folder into:
%   docs/_static/examples/
%
% Usage:
%   publish_examples


thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));

outputRoot = fullfile(repoRoot, "docs", "_static", "examples");
examplesDir = fullfile(repoRoot, "Examples");

assetsDir = fullfile(outputRoot, "assets");

if ~isfolder(examplesDir)
    error("Examples directory not found: %s", examplesDir);
end

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
if ~isfolder(assetsDir)
    mkdir(assetsDir);
end

fprintf("[publish_examples] ExamplesDir: %s\n", examplesDir);
fprintf("[publish_examples] OutputDir:   %s\n", outputRoot);

% Export all .m live scripts/functions to HTML (excluding any /html/ folders)
mFiles = dir(fullfile(examplesDir, "**", "*.m"));
for k = 1:numel(mFiles)
    src = fullfile(mFiles(k).folder, mFiles(k).name);

    relFolder = extractAfter(string(mFiles(k).folder), strlength(examplesDir));
    if startsWith(relFolder,filesep)
      relFolder = extractAfter(relFolder,1);
    end

    outSub = fullfile(outputRoot, sanitize_relpath(relFolder));
    if ~isfolder(outSub)
        mkdir(outSub);
    end

    [~, base, ~] = fileparts(src);
    outFile = fullfile(outSub, base + ".html");

    fprintf("[publish_examples] Exporting %s -> %s\n", src, outFile);
    try
        % NOTE: Running examples can be expensive; default is Run=false.
        export(src, outFile, Format="html");

        % Reduce memory/figure accumulation between exports.
        close all force;
        clearvars -except repoRoot examplesDir outputRoot assetsDir mFiles k;
    catch ME
        fprintf(2, "[publish_examples] ERROR exporting %s\n", src);
        rethrow(ME);
    end
end

fprintf("[publish_examples] Done.\n");
end

function rel = sanitize_relpath(relFolder)
% Replace spaces with underscores for web-friendly paths.
if relFolder == ""
    rel = "";
    return;
end
parts = split(relFolder, filesep);
for i = 1:numel(parts)
    p = parts(i);
    p = replace(p, " ", "_");
    parts(i) = p;
end
rel = fullfile(parts{:});
end


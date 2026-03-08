function createPackage(options)
% createPackage Build toolbox artifacts and package with ToolboxOptions.
%
% Usage:
%   createPackage
%   createPackage("ToolboxVersion", "3.0.4")

arguments
    options.ToolboxVersion (1,1) string = ""
    options.PackageToolbox (1,1) logical = true
    options.DryRun (1,1) logical = false
end

projectRoot = fileparts(fileparts(mfilename("fullpath")));

if options.DryRun
    fprintf("[package] DRY RUN enabled: build and package steps are skipped.\n");
    return;
end

%% Setup directory
% build folder is always on level up in the folder structure
BUILD_FOLDER_NAME = fullfile(projectRoot, "build");
BUILD_FOLDER_BASE = fullfile(projectRoot, "build_base");

% clean up previous builds
if exist(BUILD_FOLDER_NAME,'dir')
    rmdir(BUILD_FOLDER_NAME,'s');
end

% create build folder
copyfile(BUILD_FOLDER_BASE, BUILD_FOLDER_NAME)

%% Copy source code
sourceCodeFolder = fullfile(projectRoot, "source","*");
copyfile(sourceCodeFolder, BUILD_FOLDER_NAME);

%% Setup documentation
documentationFolder = fullfile(BUILD_FOLDER_NAME, "doc");

% Copy the sphinx site files
sphinxDocFolder = fullfile(projectRoot, "docs");
[status, cmdout] = system(sprintf('cd "%s" && source ../.venv/bin/activate && make html', sphinxDocFolder),'-echo');
if status ~= 0
    error("Error building documentation with Sphinx:\n%s", cmdout);
end
copyfile(fullfile(sphinxDocFolder, "_build", "html"), documentationFolder);

% copy the changelog
copyfile(fullfile(projectRoot, "CHANGELOG.md"), BUILD_FOLDER_NAME);

% build the documentation search database
% use try-catch to make sure path is restored
try
    addpath(BUILD_FOLDER_NAME); % builddocsearchdb needs this
    builddocsearchdb(documentationFolder)
    rmpath(BUILD_FOLDER_NAME);
catch exception
    rmpath(BUILD_FOLDER_NAME);
    rethrow(exception)
end

%% Setup Examples
copyfile(fullfile(projectRoot, "Examples"), fullfile(BUILD_FOLDER_NAME, "Examples"));

%% Package Toolbox

if options.PackageToolbox
    projectFile = fullfile(BUILD_FOLDER_NAME, "regularizeNd.prj");
    opts = matlab.addons.toolbox.ToolboxOptions(projectFile);
    if strlength(options.ToolboxVersion) > 0
        opts.ToolboxVersion = options.ToolboxVersion;
    end
    matlab.addons.toolbox.packageToolbox(opts);
    fprintf("[package] Toolbox packaged using %s\n", projectFile);
else
    fprintf("[package] Packaging skipped by request.\n");
end

% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root

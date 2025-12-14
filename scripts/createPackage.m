clc; clear; close all;

projectRoot = fileparts(fileparts(mfilename("fullpath")));

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
copyfile(fullfile(projectRoot, "CHANGELOG.md"),BUILD_FOLDER_NAME);

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

% cannot automatically package the toolbox
beep;
fprintf("Open the package toolbox with the prj file. Fill out the form and create the toolbox.\n");

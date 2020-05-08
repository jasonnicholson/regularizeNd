clc; clear; close all;

%% Setup directory
% build folder is always on level up in the folder structure
BUILD_FOLDER_NAME = "..\build";

% clean up previous builds
if exist(BUILD_FOLDER_NAME,'dir')
    rmdir(BUILD_FOLDER_NAME,'s');
end

% create build folder
mkdir(BUILD_FOLDER_NAME);

%% Setup top level of toolbox
copyfile("info.xml", BUILD_FOLDER_NAME);
copyfile('..\source', BUILD_FOLDER_NAME);

%% Setup documentation
documentationFolder = BUILD_FOLDER_NAME + "\doc";
mkdir(documentationFolder);

% Copy getting started live script to doc folder
copyfile("..\doc\GettingStarted.mlx", documentationFolder);

% copy published documentation pages and helptoc.xml
copyfile("..\doc\html", documentationFolder);

% build the documentation search database
% use try-catch to make sure path is restored
try
    addpath(BUILD_FOLDER_NAME); % builddocsearchdb needs this
    builddocsearchdb(fullfile(pwd,documentationFolder))
    rmpath(BUILD_FOLDER_NAME);
catch exception
    rmpath(BUILD_FOLDER_NAME);
    rethrow(exception)
end

%% Setup Examples
copyfile("..\Examples\", BUILD_FOLDER_NAME + "\Examples");

%% Package Toolbox
PROJECT_FILE = "regularizeNd.prj";
matlab.addons.toolbox.packageToolbox(PROJECT_FILE)
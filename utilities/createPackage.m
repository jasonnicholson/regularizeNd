clc;clear;close all;

% build folder is always on level up in the folder structure
BUILD_FOLDER_NAME = "..\build";

% clean up previous builds
if exist(BUILD_FOLDER_NAME,'dir')
    rmdir(BUILD_FOLDER_NAME,'s');
end

% create build folder
mkdir(BUILD_FOLDER_NAME);

% setup help file structure
copyfile("..\doc",BUILD_FOLDER_NAME + "\doc");
movefile(BUILD_FOLDER_NAME + "\doc\info.xml", BUILD_FOLDER_NAME);
% movefile(BUILD_FOLDER_NAME + "\doc\helptoc.xml", BUILD_FOLDER_NAME);
copyfile('..\Examples\', BUILD_FOLDER_NAME + "\Examples");
copyfile('..\source\*', BUILD_FOLDER_NAME);

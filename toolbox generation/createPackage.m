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

% check that documentation is up to date
checkHtmlFilesAreUpToDate("..\doc", "publish");

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
% check that the examples are up to date
checkHtmlFilesAreUpToDate("..\Examples", "error");

copyfile("..\Examples\", BUILD_FOLDER_NAME + "\Examples");

%% Package Toolbox
% PROJECT_FILE = "regularizeNd.prj";
% matlab.addons.toolbox.packageToolbox(PROJECT_FILE)

% cannot manually package the toolbox
beep;
fprintf("Open the package toolbox with the prj file. Then modify the demos.xml file manually. Use demos.xml template as a starting point.\n");

function checkHtmlFilesAreUpToDate(sourceFileDirectory, whatToDoFlag)
% checkHtmlFilesAreUpToDate checks that html files exist and are up to date that were generated from mlx files


sourceFiles = struct2table(dir(fullfile(sourceFileDirectory, "**/*.mlx")));

for iFile = 1:height(sourceFiles)
    fileNameWithExtension = sourceFiles.name{iFile};
    [~,fileName,~] = fileparts(fileNameWithExtension);
    
    % skip readme files
    if strcmpi(fileName,"Readme")
        continue;
    end
    
    % check that html folder exists
    htmlFolder = fullfile(sourceFiles.folder{iFile},"html");
    if exist( htmlFolder, "dir")
        
        % check for an html file
        htmlFile = fullfile(htmlFolder,fileName + ".html");
        htmlFileAttributes = dir(htmlFile);
        if isempty(htmlFileAttributes)
            publishLiveScript(sourceFiles.folder{iFile}, fileNameWithExtension, whatToDoFlag);
        else
            % check that the html file is always newer than the source file
            if htmlFileAttributes.datenum < sourceFiles.datenum(iFile)
                publishLiveScript(sourceFiles.folder{iFile}, fileNameWithExtension, whatToDoFlag);
            end
        end
    else
        % create the html folder and publish the file
        mkdir(fullfile(sourceFiles.folder{iFile}, "html"));
        publishLiveScript(sourceFiles.folder{iFile},fileNameWithExtension, whatToDoFlag);
    end
end

end

function publishLiveScript(folder,file, whatToDoFlag)

switch lower(whatToDoFlag)
    case "publish"
        htmlFolder = fullfile(folder,"html");
        try
            addpath(folder);
            publish(fullfile(folder,file),"outputDir", htmlFolder);
            rmpath(folder);
        catch e
            rmpath(folder);
            rethrow(e);
        end
    case "error"
        error("createPackage:HTMLisOutOfDate", "%s is out of date or missing.", fullfile(folder,file));
    otherwise
        error("createPackage:badSwitchStatement", "Something is wrong with the switch statement. Code should not reach this.");
end
end
function createPackage()

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

% files to publish for documentation
FILES_TO_PUBLISH = {"GettingStarted.mlx", "Getting Started"; ...
    "regularizeNdDoc.mlx", "regularizeNd"; ...
    "regularizeNdMatricesDoc.mlx", "regularizeNdMatrices"};

% Publish documentation and generate helptoc.xml
% use try-catch to make sure file gets closed. 
try
    nFiles = size(FILES_TO_PUBLISH,1);
    fileId = setupHelpTocXml(documentationFolder);
    addpath("..\doc","..\source"); % publish function needs this
    for iFile = 1:nFiles
        publishedFile = publish(FILES_TO_PUBLISH{iFile,1});
        [~,fileName,extension] = fileparts(publishedFile);
        fprintf(fileId, "    <tocitem target=""%s"">%s</tocitem>\n", horzcat(fileName,extension), FILES_TO_PUBLISH{iFile,2});
        
    end
    movefile("..\doc\html\*", documentationFolder);
    rmdir("..\doc\html");
    fprintf(fileId,"</toc>\n");
    fclose(fileId);
    close('all');
    rmpath("..\doc","..\source");
catch exception
    fclose(fileId);
    close("all");
    rmdir("..\doc\html");
    rmpath("..\doc","..\source");
    rethrow(exception);
end

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
copyfile('..\Examples\', BUILD_FOLDER_NAME + "\Examples");

%%

end

function fileId = setupHelpTocXml(documentationFolder)
fileId = fopen(documentationFolder + "\helptoc.xml","w");
line1 = "<?xml version='1.0' encoding=""utf-8""?>";
line2 = "<toc version=""2.0"">";
fprintf(fileId,"%s\n%s\n", line1, line2);
end
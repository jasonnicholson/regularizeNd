function setupRegularizeNdProjectPath(setuPath)
  arguments
    setuPath (1,1) logical  = true;
  end

  basePath = fileparts(mfilename("fullpath"));
  FOLDERS = ["source"]; %#ok<NBRAK2>
  folderFullPath = fullfile(basePath, FOLDERS);

  if setuPath
    addpath(folderFullPath);
  else
    rmpath(folderFullPath);
  end
end
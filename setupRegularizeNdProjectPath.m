function setupRegularizeNdProjectPath(setuPath)
  %
  arguments
    setuPath (1,1) logical  = true;
  end
  
  % Copyright (c) 2016-2026 Jason Nicholson
  % Licensed under the MIT License
  % See LICENSE file in project root

  basePath = fileparts(mfilename("fullpath"));
  FOLDERS = ["source"]; %#ok<NBRAK2>
  folderFullPath = fullfile(basePath, FOLDERS);

  if setuPath
    addpath(folderFullPath);
  else
    rmpath(folderFullPath);
  end
end
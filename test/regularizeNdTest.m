classdef regularizeNdTest < matlab.unittest.TestCase

  methods (TestClassSetup)

    % Shared setup for the entire test class
  end

  methods (Test)
    % Test methods
    function testValidInput(testCase)
     [x,y,xGrid,smoothness] = setup2dData1();

      errorToCheck1 = "regularizeNd:dimensionMismatch";
      testCase.verifyError(@() regularizeNd(x, y, xGrid(1)), errorToCheck1, errorToCheck1);
      errorToCheck2 = "regularizeNd:smoothnessDimensionMismatch";
      testCase.verifyError(@() regularizeNd(x, y, xGrid, [1 1 1]), errorToCheck2, errorToCheck2);
      errorToCheck3 = "regularizeNd:numberOfPointsMismatch";
      testCase.verifyError(@() regularizeNd(x(1:end-1,:), y, xGrid), errorToCheck3,errorToCheck3);
      badGrid = {xGrid{1}, 0:1:2};
      errorToCheck4 = "regularizeNd:pointsNotWithinRange";
      testCase.verifyError(@() regularizeNd(x, y, badGrid), errorToCheck4, errorToCheck4);
      badGrid2 = {xGrid{1}, [10 0 1]};
      errorToCheck5 = "regularizeNd:gridVectorsNotMonotonicIncreasing";
      testCase.verifyError(@() regularizeNd(x, y, badGrid2), errorToCheck5,errorToCheck5);
      badGrid3 = {xGrid{1}, [0 10]};
      errorToCheck6 = "regularizeNd:notEnoughGridPointsInDimension";
      testCase.verifyError(@() regularizeNd(x, y, badGrid3), errorToCheck6, errorToCheck6);
      
      testCase.verifyNoError(@() regularizeNd(x, y, xGrid, smoothness), "check regularizeNd with good inputs")
    end


    function testInterpMethods(testCase)
      [x,y,xGrid,smoothness] = setup2dData1();

      interpMethods = ["nearest"; "linear";"cubic"];
      diagnosticMessage = @(x) "Check interp method " + interpMethods(x);
      for i=1:numel(interpMethods)
        testCase.verifyNoError(@() regularizeNd(x,y,xGrid, smoothness, interpMethods(i)),diagnosticMessage(i));
      end
    end


    function testSolvers(testCase)
      % [x,y,xGrid,smoothness] = setup2dData2();
      [x,y,xGrid,smoothness] = setup1dData1("fine");
      interpMethod = "linear";

      solvers = ["\", "lsqr", "normal", "pcg", "symmlq"];
      diagnosticMessage = @(i) "Check solver " + solvers(i);
      for i=1:numel(solvers)
        testCase.verifyNoError(@() regularizeNd(x,y,xGrid, smoothness, interpMethod, solvers(i)), diagnosticMessage(i));
      end % end for

      % Check no preconditioner
      smoothness2 = 0;
      solvers2 = ["lsqr", "pcg", "symmlq"];
      diagnosticMessage2 = @(i) "Check iterative solver " + solvers2(i) + " with or without preconditioner";
      for i=1:numel(solvers2)
        testCase.verifyNoError(@() regularizeNd(x,y,xGrid, smoothness2, interpMethod, solvers2(i)), diagnosticMessage2(i));
      end % end for
    end % end testSolvers
  end % methods (Test)

  methods
    function verifyNoError(testCase, functionHandle, diagnostic)
      errorThrown = false;
      try
        functionHandle();
      catch e
        errorThrown = true;
        testCase.verifyFail(diagnostic);
      end
      if ~errorThrown
        testCase.verifyTrue(true,diagnostic);
      end % end try-catch-block
    end % verifyNoError
  end % methods
end % end class

function [x,y,xGrid,smoothness] = setup2dData1()
  xScale = 100;

  xx = 0.5:0.1:4.5;
  yy = 0.5:0.1:5.5;
  [xx,yy] = ndgrid(xx,yy);
  z = tanh(xx-3).*sin(2*pi/6*yy);
  noise = (rand(size(xx))-0.5).*xx.*yy/30;
  zNoise = z + noise;
  xx = xScale*xx;
  gridX = linspace(0,6,210);
  gridX = xScale*gridX;
  gridY = linspace(0,6.6,195);

  x = [xx(:) yy(:)];
  y = zNoise(:);
  xGrid = {gridX, gridY};
  smoothness = [1e-6 1e-7];
end

% function [xx,yy,xGrid,smoothness] = setup2dData2()
%   p = fileparts(fileparts(mfilename("fullpath")));
%   load(fullfile(p,"Examples", "seamount.mat"),"x","y","z");
% 
%   xx = [x y];
%   yy = z;
%   xLimits = [min(x), max(x)];
%   yLimits = [min(y), max(y)];
% 
%   xGrid = {linspace(xLimits(1) - eps(xLimits(1)), xLimits(2) + eps(xLimits(2)), 50), ...
%     linspace(yLimits(1) - eps(yLimits(1)), yLimits(2) + eps(yLimits(2)), 51)};
% 
%   smoothness = 0.0001;
% end

function [x,y,xGrid,smoothness] = setup1dData1(grid)

  arguments
    grid (1,1) string {mustBeMember(grid,["course","fine"])}
  end
  x = [0;0.55;1.1;2.6;2.99];
  y = [1;1.1;1.5;2.5;1.9];

  switch grid
    case "course"
      xGrid = {[-0.50,0,0.50,1,1.50,2,2.50,3,3.30,3.60]};
    case "fine"
      xGrid = {-0.5:0.1:3.6};
  end

  smoothness = 5e-3;
end
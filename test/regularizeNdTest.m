classdef regularizeNdTest < matlab.unittest.TestCase

  properties
    x
    y
    xGrid
    smoothness
  end

  methods (TestClassSetup)
    function classSetup(testCase)
      % Set up shared state for all tests.
      oldpath = addpath('../source');
      testCase.addTeardown(@() path(oldpath));

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

      testCase.x = [xx(:) yy(:)];
      testCase.y = zNoise(:);
      testCase.xGrid = {gridX, gridY};
      testCase.smoothness = [1e-6 1e-7];

      % Tear down with testCase.addTeardown.
    end
    % Shared setup for the entire test class
  end

  methods (Test)
    % Test methods
    function testValidInput(testCase)
      x = testCase.x; %#ok<*PROP>
      y = testCase.y; %#ok<*PROP>
      xGrid = testCase.xGrid; %#ok<*PROP>
      smoothness = testCase.smoothness; %#ok<*PROP>

      testCase.verifyError(@() regularizeNd(x, y, xGrid(1)), "regularizeNd:dimensionMismatch");
      testCase.verifyError(@() regularizeNd(x, y, xGrid, [1 1 1]), "regularizeNd:smoothnessDimensionMismatch");
      testCase.verifyError(@() regularizeNd(x(1:end-1,:), y, xGrid), "regularizeNd:numberOfPointsMismatch");
      badGrid = {xGrid{1}, 0:1:2};
      testCase.verifyError(@() regularizeNd(x, y, badGrid), "regularizeNd:pointsNotWithinRange");
      badGrid2 = {xGrid{1}, [10 0 1]};
      testCase.verifyError(@() regularizeNd(x, y, badGrid2), "regularizeNd:gridVectorsNotMonotonicIncreasing");
      badGrid3 = {xGrid{1}, [0 10]};
      testCase.verifyError(@() regularizeNd(x, y, badGrid3), "regularizeNd:notEnoughGridPointsInDimension");
      errorThrown = false;
      try
        regularizeNd(x, y, xGrid, smoothness);
      catch
        errorThrown = true;
      end
      testCase.verifyFalse(errorThrown,"regularizeNd threw an error with good inputs.");
    end


    function testInterpMethods(testCase)

    end

  end


end
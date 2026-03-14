classdef TestRegularizeNdCore < matlab.unittest.TestCase

  methods (Test)
    function validatesInputErrors(testCase)
      [x, y, xGrid] = localData2D();

      testCase.verifyError(@() regularizeNd(x, y, xGrid(1)), "regularizeNd:dimensionMismatch");
      testCase.verifyError(@() regularizeNd(x, y, xGrid, [1, 2, 3]), "regularizeNd:smoothnessDimensionMismatch");
      testCase.verifyError(@() regularizeNd(x(1:end-1,:), y, xGrid), "regularizeNd:numberOfPointsMismatch");

      badGridRange = {xGrid{1}, 0:0.2:0.8};
      testCase.verifyError(@() regularizeNd(x, y, badGridRange), "regularizeNd:pointsNotWithinRange");

      badGridOrder = {xGrid{1}, [0 2 1 3]};
      testCase.verifyError(@() regularizeNd(x, y, badGridOrder), "regularizeNd:gridVectorsNotMonotonicIncreasing");

      badGridShort = {xGrid{1}, [0 3]};
      testCase.verifyError(@() regularizeNd(x, y, badGridShort), "regularizeNd:notEnoughGridPointsInDimension");
    end

    function solvesAllInterpolationMethods(testCase)
      [x, y, xGrid] = localData2D();

      for interpMethod = ["nearest", "linear", "cubic"]
        yGrid = regularizeNd(x, y, xGrid, 5e-3, interpMethod, "normal");
        testCase.verifySize(yGrid, [numel(xGrid{1}), numel(xGrid{2})]);
        testCase.verifyTrue(all(isfinite(yGrid), "all"));
      end
    end

    function solvesAllSupportedSolvers(testCase)
      [x, y, xGrid] = localData1D();

      solvers = ["\", "lsqr", "normal", "pcg", "symmlq"];
      for solver = solvers
        yGrid = regularizeNd(x, y, xGrid, 1e-3, "linear", solver);
        testCase.verifySize(yGrid, [numel(xGrid{1}), 1]);
        testCase.verifyTrue(all(isfinite(yGrid), "all"));
      end
    end

    function matrixFormMatchesRegularizeSolve(testCase)
      [x, y, xGrid] = localData2D();
      smoothness = [1e-3, 2e-3];

      [Afidelity, Lreg] = regularizeNdMatrices(x, xGrid, smoothness, "linear");
      A = vertcat(Afidelity, Lreg{:});
      b = vertcat(y, zeros(size(A,1) - numel(y), 1));

      yVectorFromMatrices = A \ b;
      yGridFromMatrices = reshape(yVectorFromMatrices, cellfun(@numel, xGrid));
      yGridFromApi = regularizeNd(x, y, xGrid, smoothness, "linear", "\");

      testCase.verifyEqual(yGridFromMatrices, yGridFromApi, "AbsTol", 1e-10);
    end

    function monotonicConstraintHasExpectedStructure(testCase)
      xGrid = {1:6};
      [A, b] = monotonicConstraint(xGrid, 1, 0.25);

      testCase.verifySize(A, [5, 6]);
      testCase.verifyEqual(full(sum(A ~= 0, 2)), 2 * ones(5,1));
      testCase.verifyEqual(full(A(1,1:2)), [1, -1]);
      testCase.verifyEqual(b, -0.25 * ones(5,1));
    end

    function constrainedAlternativeReturnsFeasibleResult(testCase)
      C = [0.95, 0.76, 0.61, 0.40;
           0.23, 0.45, 0.79, 0.93;
           0.60, 0.02, 0.92, 0.91;
           0.48, 0.82, 0.73, 0.41;
           0.89, 0.44, 0.18, 0.89];
      d = [0.06; 0.35; 0.81; 0.01; 0.14];
      Aineq = [0.20, 0.27, 0.74, 0.46;
               0.19, 0.20, 0.45, 0.42;
               0.60, 0.02, 0.93, 0.85];
      bineq = [0.53; 0.21; 0.68];

      x = lsqConstrainedAlternative(C, d, Aineq, bineq);

      testCase.verifySize(x, [4,1]);
      testCase.verifyTrue(all(isfinite(x), "all"));
      testCase.verifyLessThanOrEqual(max(Aineq * x - bineq), 1e-10);
    end

    function zeroSmoothnessSkipsRegularizationDimension(testCase)
      % Covers the smoothness==0 branch in regularizeNdMatrices (lines 395-402):
      % when smoothness for a dimension is 0, Lreg{dim} must be set to [].
      [x, ~, xGrid] = localData2D();
      smoothness = [0, 1e-3];

      [Afidelity, Lreg] = regularizeNdMatrices(x, xGrid, smoothness, "linear");

      testCase.verifyEmpty(Lreg{1});
      testCase.verifyNotEmpty(Lreg{2});
      testCase.verifySize(Afidelity, [size(x,1), numel(xGrid{1}) * numel(xGrid{2})]);
    end

    function zeroSmoothnessSolvesSuccessfully(testCase)
      % Verifies that regularizeNd produces a finite output when smoothness is
      % zero in one dimension (no regularization applied along that axis).
      [x, y, xGrid] = localData2D();

      yGrid = regularizeNd(x, y, xGrid, [0, 1e-3], "linear", "\");

      testCase.verifySize(yGrid, [numel(xGrid{1}), numel(xGrid{2})]);
      testCase.verifyTrue(all(isfinite(yGrid), "all"));
    end

    function solvesThreeDimensionalData(testCase)
      % Covers the nDimensions > 1 reshape path in regularizeNd for 3-D input.
      [x, y, xGrid] = localData3D();

      yGrid = regularizeNd(x, y, xGrid, 5e-3, "linear", "normal");

      testCase.verifySize(yGrid, [numel(xGrid{1}), numel(xGrid{2}), numel(xGrid{3})]);
      testCase.verifyTrue(all(isfinite(yGrid), "all"));
    end

    function iterativeSolversWithCustomParameters(testCase)
      % Covers the maxIterations and solverTolerance code paths for iterative solvers.
      [x, y, xGrid] = localData1D();

      for solver = ["lsqr", "pcg", "symmlq"]
        yGrid = regularizeNd(x, y, xGrid, 1e-3, "linear", solver, 500, 1e-8);
        testCase.verifySize(yGrid, [numel(xGrid{1}), 1]);
        testCase.verifyTrue(all(isfinite(yGrid), "all"));
      end
    end

    function lsqrWarnsWhenMaxIterationsTooSmall(testCase)
      % Covers solverExitFlag==1 warning path in regularizeNd for iterative solvers.
      [x, y, xGrid] = localData1D();

      lastwarn("");
      yGrid = regularizeNd(x, y, xGrid, 1e-3, "linear", "lsqr", 1, 1e-16); %#ok<NASGU>
      [warnMsg, ~] = lastwarn();

      testCase.verifyNotEmpty(warnMsg);
      testCase.verifyTrue(contains(warnMsg, "did not converge"));
    end

    function lsqrFallsBackToNoPreconditionerOnSingularNormalMatrix(testCase)
      % Forces A'*A to be singular (many unused grid nodes, smoothness=0),
      % which exercises calculatePreconditioner fallback to preconditioner='none'.
      x = [0; 1; 2];
      y = [1; 2; 3];
      xGrid = {linspace(0, 10, 40)};

      yGrid = regularizeNd(x, y, xGrid, 0, "linear", "lsqr", 2, 1e-12);

      testCase.verifySize(yGrid, [numel(xGrid{1}), 1]);
      testCase.verifyTrue(all(isfinite(yGrid), "all"));
    end
  end
end

function [x, y, xGrid] = localData2D()
  rng(42);
  x1 = linspace(0.5, 3.5, 9);
  x2 = linspace(0.2, 2.8, 8);
  [xx, yy] = ndgrid(x1, x2);

  z = tanh(xx - 1.5) .* sin(2*pi/3 * yy);
  noise = 0.01 * (rand(size(z)) - 0.5);

  x = [xx(:), yy(:)];
  y = z(:) + noise(:);

  xGrid = {
    linspace(min(x(:,1)) - 0.1, max(x(:,1)) + 0.1, 14), ...
    linspace(min(x(:,2)) - 0.1, max(x(:,2)) + 0.1, 13)
  };
end

function [x, y, xGrid] = localData1D()
  x = (0:0.3:2.7)';
  y = sin(2*x) + 0.1 * x;
  xGrid = {linspace(-0.1, 2.8, 25)};
end

function [x, y, xGrid] = localData3D()
  rng(42);
  x1 = linspace(0.5, 2.5, 5);
  x2 = linspace(0.2, 1.8, 4);
  x3 = linspace(0.1, 1.9, 4);
  [xx, yy, zz] = ndgrid(x1, x2, x3);

  values = sin(xx) .* cos(yy) .* exp(-0.2*zz);
  noise = 0.01 * (rand(size(values)) - 0.5);

  x = [xx(:), yy(:), zz(:)];
  y = values(:) + noise(:);

  xGrid = {
    linspace(0.4, 2.6, 7), ...
    linspace(0.1, 1.9, 6), ...
    linspace(0.0, 2.0, 6)
  };
end

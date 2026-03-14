function [warningMessage, warningId] = handleIterativeSolverExitFlag(flag, solver, maxIterations)
  % Convert iterative solver exit flag to a warning message/id pair.

  warningMessage = '';
  warningId = '';

  switch flag
    case 0
      % converged: no warning
    case 1
      warningId = 'regularizeNd:iterativeDidNotConverge';
      warningMessage = sprintf('%s iterated %d times but did not converge.', solver, maxIterations);
    case 2
      warningId = 'regularizeNd:iterativePreconditionerIllConditioned';
      warningMessage = sprintf('The %s preconditioner was ill-conditioned.', solver);
    case 3
      warningId = 'regularizeNd:iterativeStagnated';
      warningMessage = sprintf('%s stagnated. (Two consecutive iterates were the same.)', solver);
    case 4
      warningId = 'regularizeNd:iterativeScalarBreakdown';
      warningMessage = sprintf('During %s solving, one of the scalar quantities calculated during pcg became too small or too large to continue computing.', solver);
    otherwise
      error('regularizeNd:invalidIterativeSolverExitFlag', ...
        'Unknown iterative solver exit flag: %d', flag);
  end
end

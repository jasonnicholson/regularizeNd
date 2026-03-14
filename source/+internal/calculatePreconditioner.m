function [M, preconditioner] = calculatePreconditioner(AA)
  % Calculate incomplete Cholesky preconditioner where M*M' approximates AA.
  % Falls back to diagonal compensation when the initial factorization fails.

  preconditioner = 'none';
  M = [];

  try
    M = ichol(AA);
    preconditioner = 'ichol';
  catch
    diagonalCompensation0 = full(max(sum(abs(AA),2)./diag(AA)));

    if ~isfinite(diagonalCompensation0)
      % No valid diagonal compensation estimate.
    else
      diagonalCompensationNew = diagonalCompensation0;
      diagonalCompensationFailure = [];
      diagonalCompensationSuccess = [];

      MAX_PRECONDITIONER_BOUNDS_RECALCULATIONS = 20;
      for iDiagonalCompensation = 1:MAX_PRECONDITIONER_BOUNDS_RECALCULATIONS
        try
          M = ichol(AA, struct('diagcomp', diagonalCompensationNew));
          diagonalCompensationSuccess = diagonalCompensationNew;
          diagonalCompensationNew = diagonalCompensationNew/10;
        catch
          diagonalCompensationFailure = diagonalCompensationNew;
          diagonalCompensationNew = diagonalCompensationNew*10;
        end

        if ~isempty(diagonalCompensationFailure) && ~isempty(diagonalCompensationSuccess)
          break;
        end
      end

      if ~isempty(diagonalCompensationFailure) && ~isempty(diagonalCompensationSuccess)
        MAX_PRECONDITIONER_BINARY_RECALCULATIONS = 3;
        for iDiagonalCompensation = 1:MAX_PRECONDITIONER_BINARY_RECALCULATIONS
          diagonalCompensationNew = (diagonalCompensationFailure + diagonalCompensationSuccess)/2;
          try
            M = ichol(AA, struct('diagcomp', diagonalCompensationNew));
            diagonalCompensationSuccess = diagonalCompensationNew;
          catch
            diagonalCompensationFailure = diagonalCompensationNew;
          end

          if diagonalCompensationFailure + 1000*eps(diagonalCompensationFailure) > diagonalCompensationSuccess
            break;
          end
        end

        if ~isempty(M)
          preconditioner = 'ichol';
        end
      end
    end
  end
end

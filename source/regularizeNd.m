function yGrid = regularizeNd(x, y, xGrid, smoothness, interpMethod, solver, maxIter)
% regularizeNd  Produces a smooth nD surface from scattered input data.
%
%   yGrid = regularizeNd(x, y, xGrid)
%   yGrid = regularizeNd(x, y, xGrid, smoothness)
%   yGrid = regularizeNd(x, y, xGrid, smoothness, interpMethod)
%   yGrid = regularizeNd(x, y, xGrid, smoothness, interpMethod, solver)
%   yGrid = regularizeNd(x, y, xGrid, smoothness, interpMethod, solver, maxiter)
%
%% Inputs
%      x - matrix, containing arbitrary scattered data. Each row contains
%          one point. Each column corresponds to a dimension.
%
%      y - vector or matrix, containing containing the corresponds values
%          to x. y has the same number of rows as x.
%
%  xGrid - cell array containg vectors defining the nodes in the grid in
%          each dimension. The grid vectors need not be equally spaced. The
%          grid vectors must completely span the data. If it does not, an
%          error is thrown.
%
%  smoothness - scalar or vector. - the ratio of smoothness to fidelity of
%          the output surface, a.k.a. ration of smoothness to "goodness of
%          fit." This must be a positive real number. If it is a vector, it
%          must have same number of elements as columns in x.
%
%          A smoothness of 1 gives equal weight to fidelity (goodness of fit)
%          and smoothness of the output surface.  This results in noticeable
%          smoothing.  If your input data has little or no noise, use
%          0.01 to give smoothness 1% as much weight as goodness of fit.
%          0.1 applies a little bit of smoothing to the output surface.
%
%          If this parameter is a vector, then it defines the relative
%          smoothing to be associated with each dimension. This allows the
%          user to apply a different amount of smoothing in the each
%          dimension.
%
%          DEFAULT: 0.01
%
%   interpMethod - character, denotes the interpolation scheme used
%          to interpolate the data.
%
%          'cubic' - uses cubic interpolation within the grid
%                     This is the most accurate because it accounts
%                     for the fact that the output surface is not flat.
%                     In some cases it may be slower than the other methods.
%
%          'linear' - use bilinear interpolation within the grid
%
%          'nearest' - nearest neighbor interpolation. This will
%                     rarely be a good choice, but I included it
%                     as an option for completeness.
%
%          DEFAULT: 'linear'
%
%   solver - character flag - denotes the solver used for the
%          resulting linear system. Different solvers will have
%          different solution times depending upon the specific
%          problem to be solved. Up to a certain size grid, the
%          direct \ solver will often be speedy, until memory
%          swaps causes problems.
%
%          What solver should you use? Problems with a significant
%          amount of extrapolation should avoid lsqr. \ may be
%          best numerically for small smoothnesss parameters and
%          high extents of extrapolation.
%
%          Large numbers of points will slow down the direct
%          \, but when applied to the normal equations, \ can be
%          quite fast. Since the equations generated by these
%          methods will tend to be well conditioned, the normal
%          equations are not a bad choice of method to use. Beware
%          when a small smoothing parameter is used, since this will
%          make the equations less well conditioned.
%
%          '\' - uses matlab's backslash operator to solve the sparse
%                     system. 'backslash' is an alternate name.
%
%          'lsqr' - uses matlab's iterative lsqr solver
%
%          DEFAULT: '\'
%
%   'maxIter' - only applies to lsqr solvers - defines the maximum number
%          of iterations for an iterative solver.
%
%          DEFAULT: min(1e4, nTotalGridPoints)
%
%
%% Output
%  yGrid   - array containing the fitted surface correspond to the grid
%            points xGrid.
%
%% Description
% Speed considerations:
%  Remember that a LARGE system of linear equations needs solved. There
%  will be as many unknowns as the total number of nodes in the final
%  lattice. While these equations may be sparse, solving a system of 10000
%  equations may take a second or so. Very large problems may benefit from
%  the iterative solver lsqr.
%
%
%% Example
%
%  x = rand(100,2);
%  y = exp(x(:,1)+2*x(:,2));
%  xGrid = {0:.1:1, 0:.1:1};
%
%  g = regularizeNd(x, y, xGrid);
%
%  % Note: this is equivalent to the following call:
%
%  g = regularizeNd(x, y, xGrid, 0.01, 'linear', '\');
%



%% Input Checking and Default Values
narginchk(3, 7);
nargoutchk(0,1);

% helper function used mostly for when variables are renamed
getname = @(x) inputname(1);

% Set default smoothness or check smoothness
if nargin() < 4 || isempty(smoothness)
    smoothness = 0.01;
else
    assert(all(smoothness>0), '%s must be positive in all components.', getname(smoothness));
end

% calculate the number of dimension
nDimensions = size(x,2);

% Check if smoothness is a scalar. If it is convert it to a vector
if isscalar(smoothness)
    smoothness = ones(nDimensions,1).*smoothness;
end

% Set default interp method or check method
interpMethodsPossible = {'cubic', 'triangle', 'linear', 'nearest'};
if nargin() < 5 || isempty(interpMethod)
    interpMethod = 'linear';
else
    assert(any(strcmpi(interpMethod, interpMethodsPossible)), '%s is not a possible interpolation method. Check your spelling.', interpMethod);
    interpMethod = lower(interpMethod);
end

% Set default solver or check the solver
solversPossible = {'\', 'lsqr'};
if nargin() < 6 || (nargin()==6 && isempty(solver))
    solver = '\';
elseif nargin() == 7 && isempty(solver) && ~isempty(maxIter)
    solver = 'lsqr';
elseif nargin() == 7 && isempty(solver) && isempty(maxIter)
    solver = '\';
else
    assert(any(strcmpi(solver, solversPossible)), '%s is not an acceptable %s. Check spelling and try again.', solver, getname(solver));
end

% Check y rows matches the number in x
nScatteredPoints = size(x,1);
assert( nScatteredPoints == size(y, 1), '%s must have same number of rows as %s',getname(x), getname(y));

% Check the grid vectors is a cell array
assert(iscell(xGrid), '%s must be a cell array where the ith cell contains  nodes for ith dimension', getname(xGrid));

% arrange xGrid as a row cell array. This helps with cellfun and arrayfun
% later because the shape is always the same. From here on, the shape is
% known.
xGrid = reshape(xGrid,1,[]);

% arrange the grid vector as column vectors. This is helpful with arrayfun
% and cellfun calls because the shape is always the same. From here on the
% grid vectors shape is a known.
xGrid = cellfun(@(u) reshape(u,[],1), xGrid, 'UniformOutput', false);

% calculate the number of points in each dimension of the grid
nGrid = cellfun(@(u) length(u), xGrid);
nTotalGridPoints = prod(nGrid);

% Set maxIter or check it otherwise
if nargin()>6 && isempty(maxIter)
    maxIter = min(1e4, nTotalGridPoints);
elseif nargin()==7
    assert(maxIter == fix(maxIter) & maxIter > 0, '%s must a positive integer.', getname(maxIter));
end

% Check input points are within min and max of grid.
xGridMin = cellfun(@(u) min(u), xGrid);
xGridMax = cellfun(@(u) max(u), xGrid);
assert(all(all(bsxfun(@ge, x, xGridMin))) & all(all(bsxfun(@le, x, xGridMax))), 'All %s points must be within the range of %s to %s', getname(x), getname(xGridMin), getname(xGridMax));

% calcuate the difference between grid points for each dimension
dx = cellfun(@(uGrid) diff(uGrid), xGrid, 'UniformOutput', false);

% Check for monotonic increasing grid points in each dimension
assert(all(cellfun(@(du) ~any(du<=0), dx)), 'All grid points in %s must be monotonicaly increasing.', getname(xGrid));

% Check that there are enough points to form an output surface Cubic
% interpolation requires 4 points in each output grid dimension.  Other
% types require a 3 points in the output grid dimension.
% TODO rewrite this function to accept a user specificied interpolation function. Get rid of the hard coded interpolation types
switch interpMethod
    case 'cubic'
        minGridVectorLength = 4;
    case 'linear'
        minGridVectorLength = 3;
    case 'nearest'
        minGridVectorLength = 3;
end
assert(all(nGrid > minGridVectorLength), 'Not enough grid points in each dimension. %s interpolation method requires %d points.', interpMethod, minGridVectorLength);


%% Find cell index
% determine the cell the x-points lie in the xGrid

% loop over the dimensions/columns, calculating cell index
xIndex = arrayfun(@(iDimension) findDimensionIndex(x(:,iDimension), xGrid{iDimension}, nGrid(iDimension)), 1:nDimensions, 'UniformOutput',false);

%% Calculate Fidelity Equations

% Calcuate the cell fraction. This corresponds to a value between 0 and 1.
% 0 corresponds to the beggining of the cell. 1 corresponds to the end of
% the cell. The min and max functions help ensure the output is always
% between 0 and 1.
cellFraction = arrayfun(@(iDimension) min(1,max(0,(x(:,iDimension) - xGrid{iDimension}(xIndex{iDimension}))./dx{iDimension}(xIndex{iDimension}))), 1:nDimensions, 'UniformOutput', false);

switch interpMethod
    case 'nearest' % nearest neighbor interpolation in a cell
        % calculate the index of nearest point
        xWeightIndex = cellfun(@(fraction, index) round(fraction)+index, cellFraction, xIndex, 'UniformOutput', false);
        
        % calculate linear index
        xWeightIndex = sub2ind(nGrid, xWeightIndex{:});
        
        % the weight for nearest interpolation is just 1
        weight  = 1;
        
        % Form the sparse A matrix for fidelity equations
        A = sparse((1:nScatteredPoints)', xWeightIndex, weight, nScatteredPoints, nTotalGridPoints);
        
    case 'linear'  % linear interpolation in a cell
        % In linear interpolation, there is two weights per dimension
        %                                      weight 1    weight 2
        weights = cellfun(@(fraction) [1-fraction, fraction], cellFraction, 'UniformOutput', false);
        
        % Each cell has 2^nDimension points. Each dimension has two points, 1 or 2.
        % The local index has 1 or 2 for each dimension. For instance, cell in 2d
        % has 4 points with the folling indexes:
        % point 1  2  3  4
        %      [1, 1, 2, 2;
        %       1, 2, 1, 2]
        localCellIndex = (arrayfun(@(digit) str2double(digit), dec2bin(0:2^nDimensions-1))+1)';
        
        % preallocate before loop
        weight = ones(nScatteredPoints, 2^nDimensions);
        xWeightIndex = cell(1, nDimensions);
        
        % Calculate weight for each point in the cell
        % After the for loop finishes, the rows of weight sum to 1 as a check.
        for iDimension = 1:nDimensions
            % multiply the weights from each dimension
            weight = weight.*weights{iDimension}(:, localCellIndex(iDimension,:));
            % compute the index corresponding to the weight
            xWeightIndex{iDimension} = bsxfun(@plus, xIndex{iDimension}, localCellIndex(iDimension,:)-1);
        end
        
        % calculate linear index
        xWeightIndex = sub2ind(nGrid, xWeightIndex{:});
        
        % Form the sparse A matrix for fidelity equations
        A = sparse(repmat((1:nScatteredPoints)',1,2^nDimensions), xWeightIndex, weight, nScatteredPoints, nTotalGridPoints);
        
    case 'cubic'
        error('Not read yet.');
%         A = sparse(AllRows(:), AllColumns(:), AllCoefficients(:), n, nGridPoints);
end

%% Calculate Smoothness Equations

% Minimizes the sum of the squares of the second derivatives (wrt x and y) across the grid
[i,j] = meshgrid(1:nx,2:(ny-1));
ind = j(:) + ny*(i(:)-1);
dy1 = dy(j(:)-1);
dy2 = dy(j(:));

Areg = sparse(repmat(ind,1,3),[ind-1,ind,ind+1], smoothness(2)*[-2./(dy1.*(dy1+dy2)), 2./(dy1.*dy2), -2./(dy2.*(dy1+dy2))],nGridPoints,nGridPoints);

[i,j] = meshgrid(2:(nx-1),1:ny);
ind = j(:) + ny*(i(:)-1);
dx1 = dx(i(:) - 1);
dx2 = dx(i(:));

Areg = [Areg;sparse(repmat(ind,1,3),[ind-ny,ind,ind+ny], smoothness(1)*[-2./(dx1.*(dx1+dx2)), 2./(dx1.*dx2), -2./(dx2.*(dx1+dx2))],nGridPoints,nGridPoints)];
nreg = size(Areg, 1);

nFidelityEquation = nScatteredPoints;
% Number of the second derivative equations in the matrix
RegularizerEquationCount = nx * (ny - 2) + ny * (nx - 2);
% We are minimizing the sum of squared errors, so adjust the magnitude of the squared errors to make second-derivative
% squared errors match the fidelity squared errors.  Then multiply by smoothparam.
NewSmoothnessScale = sqrt(nFidelityEquation / RegularizerEquationCount);

% Second derivatives scale with z exactly because d^2(K*z) / dx^2 = K * d^2(z) / dx^2.
% That means we've taken care of the z axis.
% The square root of the point/derivative ratio takes care of the grid density.
% We also need to take care of the size of the dataset in x and y.

% The scaling up to this point applies to local variation.  Local means within a domain of [0, 1] or [10, 11], etc.
% The smoothing behavior needs to work for datasets that are significantly larger or smaller than that.
% For example, if x and y span [0 10,000], smoothing local to [0, 1] is insufficient to influence the behavior of
% the whole surface.  For the same reason there would be a problem applying smoothing for [0, 1] to a small surface
% spanning [0, 0.01].  Multiplying the smoothing constant by SurfaceDomainScale compensates for this, producing the
% expected behavior that a smoothing constant of 1 produces noticeable smoothing (when looking at the entire surface
% profile) and that 1% does not produce noticeable smoothing.
SurfaceDomainScale = (max(max(xGrid)) - min(min(xGrid))) * (max(max(ynodes)) - min(min(ynodes)));
NewSmoothnessScale = NewSmoothnessScale *	SurfaceDomainScale;

A = [A; Areg * NewSmoothnessScale];

y = [y;zeros(nreg,1)];
% solve the full system, with regularizer attached
switch solver
    case {'\' 'backslash'}
        yGrid = reshape(A\y,ny,nx);
    case 'lsqr'
        % iterative solver - lsqr. No preconditioner here.
        tol = abs(max(y)-min(y))*1.e-13;
        
        [yGrid,flag] = lsqr(A,y,tol,maxIter);
        yGrid = reshape(yGrid,ny,nx);
        
        % display a warning if convergence problems
        switch flag
            case 0
                % no problems with convergence
            case 1
                % lsqr iterated MAXIT times but did not converge.
                warning('GRIDFIT:solver',['Lsqr performed ', ...
                    num2str(maxIter),' iterations but did not converge.'])
            case 3
                % lsqr stagnated, successive iterates were the same
                warning('GRIDFIT:solver','Lsqr stagnated without apparent convergence.')
            case 4
                warning('GRIDFIT:solver',['One of the scalar quantities calculated in',...
                    ' LSQR was too small or too large to continue computing.'])
        end
        
end  % switch solver

end %

%%
function index = findDimensionIndex(u, uGrid, uGridLength)
% calculates the 1 based cell index of the points u in uGrid as edges

[~, index] = histc(u, uGrid);

% For points that lie ON the max value of uGrid (i.e. the last value),
% histc returns an index that is equal to the length of uGrid. uGrid
% describes uGridLength-1 cells. Therefore, we need to find when a cell has
% an index equal to the length of uGridLength and reduce the index by 1.
index(index==uGridLength) = uGridLength-1;

end
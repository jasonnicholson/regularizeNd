function [A,b] = monotonicConstraint(xGrid,dimension,dxMin)
% monotonicConstraint generates matrices for a monotonic increasing constraint of :math:`Ax\leq b` ::
%
%
%   [A,b] = monotonicConstraint(xGrid)
%   [A,b] = monotonicConstraint(xGrid,dimension)
%   [A,b] = monotonicConstraint(xGrid,dimension,dxMin)
%
%% Inputs
%   xGrid (cell array): cell array of grid vectors
%
%   dimension ((1,1), default=1): The monotonic constraint is formed across this dimension.
%
%   dxMin (default=0): The minimum difference between different elements of x. :math:`x(i+l) >= x(i) + \Delta x_{min}`
%
%% Outputs
%   A: A matrix in :math:`Ax\leq b`
%
%   b: b vector in :math:`Ax\leq b`
%
%% Description
%   This function is mainly used in conjunction with regularizeNdMatrices to create monotonic increasing constraints.
%   Monotonically decreasing constraints are just the negative of A, Aneg = -A and bneg = b. 
%
%   The main point of this function is to setup a monotonic increasing constraint in the form :math:`Ax\leq b` that can be used
%   in lsqlin or similar. To formulate this we start with 
%
%   .. math::
%      \begin{aligned}
%      x_2 &\ge x_1 + \Delta x_{\min} \\
%      x_2 - x_1 &\ge \Delta x_{\min} \\
%      x_1 - x_2 &\le -\Delta x_{\min}
%      \end{aligned}
%
%   Then generalize this to a matrix form: :math:`Ax\leq b`
%
%   .. math::
%      A =
%      \begin{bmatrix}
%      1 & -1 & 0 & 0 & \dots & 0 \\
%      0 & 1 & -1 & 0 & \dots & 0 \\
%      0 & 0 & 1 & -1 & \dots & 0 \\
%      \vdots & \vdots & \vdots & \vdots & \ddots & \vdots \\
%      0 & 0 & 0 & 0 & 1 & -1
%      \end{bmatrix}, \qquad
%      b =
%      \begin{bmatrix}
%      -\Delta x_{\min} \\
%      -\Delta x_{\min} \\
%      \vdots \\
%      -\Delta x_{\min}
%      \end{bmatrix}.
%
%   Then we need to generalize this to expanding across an n-dimensional grid at the m dimension. This will produce a
%   different structure in A. i.e. The 1 and -1 in a row mat not be adjacent to each other.
%
%% Example
%  ::
%
%   xGrid = {1:10};
%   [A,b] = monotonicConstraint(xGrid)
%   full(A)
%   
%   % 2d example 
%   xGrid2 = {1:5, 10:15};
%   dimension = 2;
%   bMax = 1e-3;
%   [A,b] = monotonicConstraint(xGrid2,dimension, bMax)
%   full(A)
%   
%   % monotonic decreasing
%   Aneg = -A;
%   bneg = b;
%   full(Aneg)
%

narginchk(1,3);
if nargin < 3
    dxMin =0;
    if nargin <2
        dimension =1;
    end
end

% We want xGrid as a row vector
xGrid = reshape(xGrid,1,[]);

% makes sure we are dealing with column vectors 
xGrid = cellfun(@(x) x(:),xGrid,"UniformOutput",false);

% calculate position in A matrix for lower points 
subGrid = xGrid;
subGrid{dimension} = xGrid{dimension}(1:end-1);
A1 = helper(subGrid,xGrid);

% calculate position in A matrix for upper points 
subGrid{dimension} = xGrid{dimension}(2:end);
A2 = helper(subGrid,xGrid);

% the difference between A1 and A2 is A 
A = A1 - A2;

% Calculate b
b = -dxMin*ones(size(A,1),1);
end

function [A] = helper(subGrid,xGrid)

% expand the grid 
x = cell(size(subGrid));
[x{:}] = ndgrid(subGrid{:});

% reshape all the matrices to vectors and then horizontally concatenate them. 
x = cellfun(@(u) u(:), x,"UniformOutput",false); x = horzcat(x{:});

% run the points through regularizeNdMatrices to locate their index in the A matrix
A = regularizeNdMatrices(x, xGrid);
end
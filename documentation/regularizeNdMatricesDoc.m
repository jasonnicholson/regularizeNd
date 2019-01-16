%% regularizeNdMatrices
% Returns the needed matrices used in the regulareNd problem. Often used for constrained problems.
%
%   [Afidelity, Lreg] = regularizeNdMatrices(x, xGrid)
%   [Afidelity, Lreg] = regularizeNdMatrices(x, xGrid, smoothness)
%   [Afidelity, Lreg] = regularizeNdMatrices(x, xGrid, smoothness, interpMethod)
%
%% Inputs
% *x* - column vector or matrix of column vectors, containing scattered data. Each row contains one point. Each column corresponds to a dimension.
%%%
% *xGrid* - cell array containing vectors defining the nodes in the grid in each dimension. xGrid{1} corresponds with x(:,1) for instance. Unequal spacing in
% the grid vectors is allowed. The grid vectors must completely span x. For instance the values of x(:,1) must be within the bounds of xGrid{1}. If xGrid does
% not span x, an error is thrown.
%%%
% *smoothness* - scalar or vector. - The numerical "measure" of what we want to achieve along an axis/dimension, regardless of the resolution, the aspect ratio
% between axes, or the scale of the overall problem. The ratio of smoothness to fidelity of the output surface, i.e. ratio of smoothness to "goodness of fit."
% This must be a positive real number. If it is a vector, it must have same number of elements as columns in x.
% 
% A smoothness of 1 gives equal weight to fidelity (goodness of fit) and smoothness of the output surface.  This results in noticeable smoothing.  If your input
% data has little or no noise, use 0.01 to give smoothness 1% as much weight as goodness of fit. 0.1 applies a little bit of smoothing to the output surface.
% 
% If this parameter is a vector, then it defines the relative smoothing to be associated with each axis/dimension. This allows the user to apply a different
% amount of smoothing in the each axis/dimension.
%
%   DEFAULT: 0.01
%%%
% *interpMethod* - character, denotes the interpolation scheme used to interpolate the data.
%
% Even though there is a computational complexity difference between linear, nearest, and cubic interpolation methods, the interpolation method is not the
% dominant factor in the calculation time in regularizeNd. The dominant factor in calculation time is the size of the grid and the solver used. So in general,
% do not choose your interpolation method based on computational complexity. Choose your interpolation method because of the accuracty and shape that you are
% looking to obtain.
%
% * 'linear' - Uses linear interpolation within the grid. linear interpolation requires that extrema occur at the grid points. linear should be smoother than
% nearest for the same grid. As the number of dimension grows, the number of grid points used to interpolate at a query point grows with 2^nDimensions. i.e. 2d
% needs 4 points, 3d needs 8 points, 4d needs 16 points per query point. In general, linear can use smaller smoothness values than cubic and still be well
% conditioned.
%
% * 'nearest' - Nearest neighbor interpolation. Nearest should be the least complex but least smooth.
%
% * 'cubic' - Uses Lagrange cubic interpolation. Cubic interpolation allows extrema to occur at other locations besides the grid points. Cubic should provide
% the most flexible relationship for a given xGrid. As the number of dimension grows, the number of grid points used to interpolate at a query point grows with
% 4^nDimensions. i.e. 2d needs 16 points, 3d needs 64 points, 4d needs 256 points per query point. cubic has good properties of accuracy and smoothness but is
% the most complex interpMethod to calculate.
%
%   DEFAULT: 'linear'
%
%% Output
% *Afidelity*   - matirx. contains the fidelity equations. size(A,1) == size(x,1) == size(y,1). The number of rows in A corresponds to the number of points in
% x,y. The number of columns corresponds to the number points in the grid.
%
% *Lreg* - Cell array. L{i} corresponds to the scaled 2nd derivative regularization of the ith dimension.
%
%% Description
% regularizeNdMatrices is most often is used for adding contraints to what regularizeNd would produce. The matrices output from regularizeNdMatrices are used
% with constraint matrices in a linear least squares constrained optimization problem. % For an example of how to do constrained optimization with
% regularizeNdMatrices, see "constraint_and_Mapping_Example" example.
% 
% regularizeNdMatrices outputs the matrices used in regularizeNd. There are two parts: the fidelity part and the regularization part. The fidelity controls the
% accuracy of the fitted lookup table. The regularization part controls the smoothness of the lookup table.
%
%
% For an introduction on how regularization works, start here:
%  https://mathformeremortals.wordpress.com/2013/01/29/introduction-to-regularizing-with-2d-data-part-1-of-3/
%
%% Acknowledgement
% Special thanks to Peter Goldstein, author of RegularizeData3D, for his
% coaching and help through writing regularizeNd.
%
%% Iterative Solver Example
clc; clear; close all;

%% Data Description
% This is a 5d example. The number of points in the grid is 117,600. This
% means that the rank of the linear system equations solved is 117,600. I
% would classify this as a medium size problem. In my experiments, MATLAB
% is using 3500MB of RAM at just before regularizeNd tries to solve the
% system of linear equations. The direct solvers ('\' and 'normal') both
% fail because of a bug in MATLAB 2016b x64. It turns out this is a bug in
% the underlying libraries. With the same A and b matrices in the Julia
% Language, I get the same errors. Therefore, the direct solvers are just
% not usuable currently with this problem. In future versions of MATLAB, I
% would expect this gets fixed but who knows when. I wrote this on
% 2017-Nov-17.
load('Iterative Solver Data.mat');

%% Try the Direct Solvers
% Try the 'normal' solver. This will throw an error as of MATLAB 2016b x64. In
% future versions of MATLAB, this error may or may not be an error.

smoothness = [0.001 0.01 0.01 0.001 0.01];

try
    tic;
    [~] = regularizeNd(inputs, output, xGrid, smoothness);
    % Note this call is the same as
    % yGrid = regularizeNd(inputs, output, xGrid, smoothness,'linear', 'normal');
    
    fprintf('No error thrown. Mathworks fixed this bug.\n');
    toc;
catch exception
   fprintf(['While using the ''normal'' solver in regularizeNd,\n' ...
       'MATLAB threw the following error:\n%s\n%s\n\n'], exception.identifier, exception.message);
end

%%
% Try the '\' solver. This will throw an error as of MATLAB 2016b x64. In
% future versions of MATLAB, this error may or may not be an error.
try
    tic;
    [~] = regularizeNd(inputs, output, xGrid, smoothness,[],'\');
    % Note this call is the same as
    % yGrid = regularizeNd(inputs, output, xGrid, smoothness,'linear', '\');
    
    fprintf('No error thrown. Mathworks fixed this bug.\n');
    toc;
catch exception
      fprintf(['While using the ''\\'' solver in regularizeNd,\n' ...
       'MATLAB threw the following error:\n%s\n%s\n'], exception.identifier, exception.message);
end

%% Try the Iterative Solvers
% Solve using the 'pcg' solver. The pcg solver solves the normal equation
% iteratively for x, (A'*A)*x = A'*b. Note that the condition number of
% (A'*A) is square of the condition number of A. This means that solving
% the problem is more numerically unstable than solving A*x = b in the
% least squares sense. However, regularizeNd generally produces well
% conditioned matrices so this issue is most often irrelevant. If you need
% an iterative solver and are struggling with accuracy, try 'lsqr'.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness,[], 'pcg');
toc;

%%
% Solving using the 'symmlq' solver. The symmlq solver is very similar to
% the pcg solver; see the MATLAB documentation to see the similarities. The
% similarities between the solvers are beyond the scope of this example.
% The symmlq solver solves the normal equation iteratively for x, (A'*A)*x
% = A'*b.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness, [], 'symmlq');
toc;

%%
% Solving using the 'lsqr' solver. The lsqr solver solves A*x = b in the
% least squares sense iteratively. Use this solver as a last resort with
% regularizeNd. There is probably a rare case where '\' and 'normal' fail,
% and 'pcg' and 'symmlq' do not produce adequate results. Thus, lsqr would
% be the last resort and may produce adequately accurate results at the
% cost of long solve times.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness, [], 'lsqr');
toc;
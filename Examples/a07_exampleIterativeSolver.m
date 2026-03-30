%[text] # Iterative Solver Example
clc; clear; close all;
%%
%[text] ## Data Description
%[text] This is a 5D example. The underlying regularization grid is **25 × 7 × 7 × 12 × 8 = 117,600 nodes**. The system matrix A is 499,748 × 117,600 with 2,582,568 nonzeros (42 MB). The right-hand side b is 499,748 × 1. A has two row types: 37,356 rows with 32 nonzeros (data-fit rows from 2⁵-node multilinear interpolation stencils) and 462,392 rows with 3 nonzeros (regularization rows from second-order finite-difference stencils along each grid dimension).
%[text] ## Why Direct Solvers Fail: The Cholesky Fill Catastrophe
%[text] Direct solvers (Cholesky, LDL, QR) all fail on this problem not because of a software bug, but because of a **fundamental structural property** of the 5D grid that makes the factorization unavoidably large. The analysis below was performed on 2026-Mar-29.
%[text] ### The Strides
%[text] When n = 117,600 grid nodes are laid out in a flat array using column-major (Fortran) order on the 25 × 7 × 7 × 12 × 8 grid, the index distance between adjacent nodes along each dimension — the *stride* — is:
%[text:table]{"ignoreHeader":true}
%[text] | **Dimension** | **Grid Size** | **Stride** |
%[text] | --- | --- | --- |
%[text] | 1 | 25 | 1 |
%[text] | 2 | 7 | 25 |
%[text] | 3 | 7 | 175 |
%[text] | 4 | 12 | 1225 |
%[text] | 5 | 8 | 14700 |
%[text:table]
%[text] ### The Long-Range Connections
%[text] The second-order finite-difference regularization along dimension 5 uses the stencil `[1, −2, 1]` applied at node indices `[j, j+14700, j+29400]`. This means columns `j` and `j+29400` appear together in the same regularization row of A, creating a **direct edge** in the A′A graph at distance **29,400 = n/4**. This is confirmed in the data: all 88,200 long-range connections in A′A fall at exactly bandwidth 29,400 — a sharp discrete spike.
%[text] ### Why No Reordering Helps
%[text] Because these long-range connections are *direct graph edges* (not fill-in), no permutation or reordering (AMD, COLAMD, nested dissection) can reduce the matrix bandwidth below 29,400. This yields an inescapable theoretical lower bound on the Cholesky factor:
%[text] 
%[text]     NNZ(L) ≥ n × bandwidth / 2 ≈ 117,600 × 29,400 / 2 ≈ 1.73 × 10⁹
%[text] 
%[text] Symbolic analysis confirms the AMD-ordered Cholesky L has **1.81 × 10⁹ nonzeros** — essentially at the floor. Storing L requires ~14.5 GB (double, sparse). Peak RAM during numerical factorization is ~44 GB (L plus working storage). This is the fill ratio:
%[text] 
%[text] NNZ(L) / NNZ(A′A) = 799×    
%[text] NNZ(L) / NNZ(A)    = 701×
%[text] 
%[text] QR factorization shares this fate: the R factor has the same sparsity pattern as L.
%[text] ### Why Iterative Solvers Are Fine
%[text] LSQR, CGLS, PCG, and SYMMLQ only perform matrix-vector products with A and A′. They **never form A′A** and never compute a factorization. Total working memory is the 42 MB for A plus a few length-117,600 vectors — roughly 40 MB total. Each iteration costs 2.58 M multiply-adds, which is fast.
%[text] 
%[text] **Because of the large stride in higher dimensions, the best method to solve higher dimensional problems is iterative methods.**
%[text] 
%[text] ## **Load Data**
load('a07_iterative_solver_data.mat');
%%
%[text] ## Try the Direct Solvers
%[text] Try the 'normal' solver. I don't recommend this. Skip it.
smoothness = [0.001 0.01 0.01 0.001 0.01];
interpMethod = "linear";

try %[output:group:270971a5]
    tic;
    [~] = regularizeNd(inputs, output, xGrid, smoothness);
    % Note this call is the same as
    % yGrid = regularizeNd(inputs, output, xGrid, smoothness,'linear', 'normal');
    
    fprintf('No error thrown. Mathworks fixed this bug.\n'); %[output:610c760f]
    toc; %[output:0409e3cd]
catch exception
   fprintf(['While using the ''normal'' solver in regularizeNd,\n' ...
       'MATLAB threw the following error:\n%s\n%s\n\n'], exception.identifier, exception.message);
end %[output:group:270971a5]
%%
%[text] Try the '\\' solver. I don't recommend this either. Skip it.
try %[output:group:5a4bdef0]
    tic;
    [~] = regularizeNd(inputs, output, xGrid, smoothness, interpMethod,'\');
    
    fprintf('No error thrown. Mathworks fixed this bug.\n'); %[output:07ad6f10]
    toc; %[output:531f0d3f]
catch exception
      fprintf(['While using the ''\\'' solver in regularizeNd,\n' ...
       'MATLAB threw the following error:\n%s\n%s\n'], exception.identifier, exception.message);
end %[output:group:5a4bdef0]
%%
%[text] ## Try the Iterative Solvers
%[text] Solve using the 'pcg' solver. The pcg solver solves the normal equation iteratively for x, (A'\*A)\*x = A'\*b. Note that the condition number of (A'\*A) is square of the condition number of A. This means that solving the problem is more numerically unstable than solving A\*x = b in the least squares sense. However, regularizeNd generally produces well conditioned matrices so this issue is most often irrelevant. If you need an iterative solver and are struggling with accuracy, try 'lsqr'.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness, interpMethod, 'pcg');
toc; %[output:3c791c80]
%%
%[text] Solving using the 'symmlq' solver. The symmlq solver is very similar to the pcg solver; see the MATLAB documentation to see the similarities. The similarities between the solvers are beyond the scope of this example. The symmlq solver solves the normal equation iteratively for x, (A'\*A)\*x = A'\*b.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness, interpMethod, 'symmlq');
toc; %[output:31e5ee93]
%%
%[text] Solving using the 'lsqr' solver. The lsqr solver solves A\*x = b in the least squares sense iteratively. Use this solver as a last resort with regularizeNd. There is probably a rare case where '\\' and 'normal' fail, and 'pcg' and 'symmlq' do not produce adequate results. Thus, lsqr would be the last resort and may produce adequately accurate results at the cost of long solve times.
tic;
[~] = regularizeNd(inputs, output, xGrid, smoothness, interpMethod, 'lsqr');
toc; %[output:79763852]
% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
%[output:610c760f]
%   data: {"dataType":"text","outputData":{"text":"No error thrown. Mathworks fixed this bug.\n","truncated":false}}
%---
%[output:0409e3cd]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 930.022098 seconds.\n","truncated":false}}
%---
%[output:07ad6f10]
%   data: {"dataType":"text","outputData":{"text":"No error thrown. Mathworks fixed this bug.\n","truncated":false}}
%---
%[output:531f0d3f]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 8266.395394 seconds.\n","truncated":false}}
%---
%[output:3c791c80]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 53.382053 seconds.\n","truncated":false}}
%---
%[output:31e5ee93]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 52.895435 seconds.\n","truncated":false}}
%---
%[output:79763852]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 377.954214 seconds.\n","truncated":false}}
%---

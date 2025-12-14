%[text] # Iterative Solver Example
clc; clear; close all;
%%
%[text] ## Data Description
%[text] This is a 5d example. The number of points in the grid is 117,600. This means that the rank of the linear system equations solved is 117,600. I would classify this as a medium size problem. In my experiments, MATLAB is using 3500MB of RAM at just before regularizeNd tries to solve the system of linear equations. The direct solvers ('\\' and 'normal') both fail because of a bug in MATLAB 2016b x64. It turns out this is a bug in the underlying libraries. With the same A and b matrices in the Julia Language, I get the same errors. Therefore, the direct solvers are not usuable currently with this problem. In future versions of MATLAB, I would expect this gets fixed but who knows when. I wrote this on 2017-Nov-17.
%[text] **Update 2019-Jan-15**
%[text] The direct solver no longer run out of memory as of 2018b but instead lock up the computer! 2019-Jan-15. This is bad. Therefore, the code is commented out.
%[text] **Update 2020-July-16**
%[text] In 2020b this example runs without error. Maximum memory request was higher than the 32GB on my computer but it did not stop the solvers. The 'normal' solver is 10x faster than the '\\' solver. The iterative 'pcg' and 'symmlq' solvers have the advantage because they are more than 12x faster than the 'normal'. The 'lsqr' is still the last resort if the 'pcg' or 'symmlq' fail. 
%[text] 
load('Iterative Solver Data.mat');
%%
%[text] ## Try the Direct Solvers
%[text] Try the 'normal' solver. This will throw an error as of MATLAB 2016b x64. In future versions of MATLAB, this error may or may not be an error.
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
%[text] Try the '\\' solver. This will throw an error as of MATLAB 2016b x64. In future versions of MATLAB, this error may or may not be an error.
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

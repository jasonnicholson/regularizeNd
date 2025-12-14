%[text] # Difference in Solve Time Between Solvers
%[text] This example shows the difference between the '\\' and the 'normal' solver. The gist is use the '\\' for accuracy or ill conditioned problems otherwise use 'normal' for speed. 'normal' is 2-3 times faster than '\\' on this data set.
% setup some input points, output points, and noise
x = 0.5:0.1:4.5;
y = 0.5:0.1:5.5;
[xx,yy] = ndgrid(x,y);
z = tanh(xx-3).*sin(2*pi/6*yy);
noise = (rand(size(xx))-0.5).*xx.*yy/30;
zNoise = z + noise;

% setup the grid for lookup table
xGrid = linspace(0,6,600);
yGrid = linspace(0,6.6,1950);
gridPoints = {xGrid, yGrid};

% setup some difference in scale between the different dimensions/axes to
% just show the effectiveness of regularizeNd's capability of handling
% different scales in different dimensions.
xScale = 100;
x = xScale*x;
xx=xScale*xx;
xGrid = xScale*xGrid;
gridPoints{1} = xGrid; 

% smoothness parameter. i.e. fit is weighted 1000 times greater than
% smoothness.
smoothness = 0.001;
%%
%[text] ## 'normal' Solver
tic;
zGrid1 = regularizeNd([xx(:), yy(:)], zNoise(:), gridPoints, smoothness);
toc; %[output:778abc0e]
% Note this s the same as 
% zGrid = regularizeNd([xx(:), yy(:)], zNoise(:), gridPoints, smoothness, 'linear');
% zGrid = regularizeNd([xx(:), yy(:)], zNoise(:), gridPoints, smoothness, 'linear', 'normal');
%%
%[text] ## '\\' Solver
tic;
zGrid2 = regularizeNd([xx(:), yy(:)], zNoise(:), gridPoints, smoothness,'linear', '\');
toc; %[output:80a52427]

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":40}
%---
%[output:778abc0e]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 11.916050 seconds.\n","truncated":false}}
%---
%[output:80a52427]
%   data: {"dataType":"text","outputData":{"text":"Elapsed time is 37.869379 seconds.\n","truncated":false}}
%---

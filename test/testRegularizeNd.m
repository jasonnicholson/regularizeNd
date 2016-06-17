% clc;close all; clear;
% xx = 0.5:0.01:4.5;
% yy = 0.5:0.01:5.5;
% [xx,yy] = ndgrid(xx,yy);
% z = tanh(xx-3).*sin(2*pi/6*yy);
% noise = (rand(size(xx))-0.5).*xx.*yy/30;
% zNoise = z + noise;
% surf(xx,yy,z, 'FaceColor', 'g')
% hold all;
% surf(xx,yy,zNoise)
% xGrid = -5:0.1:10;
% yGrid = -5:0.1:10;
% 
% zGrid = RegularizeData3D(xx(:), yy(:), zNoise(:) ,xGrid, yGrid, 'smoothness', 0.00025, 'interp', 'bicubic');
% 
% surf(xGrid, yGrid, zGrid, 'FaceColor', 'r')
% 

clc;close all; clear;
addpath('../source')
addpath('../legacy/');
xx = 0.49:4.5;
yy = 0.49:5.5;
[xx,yy] = ndgrid(xx,yy);
x = [xx(:), yy(:)];
z = tanh(xx-3).*sin(2*pi/6*yy);
xGrid = {0:5; 0:6};

% zGrid = regularizeNd(x, z(:), xGrid, 0.00025, 'linear');
zGrid = RegularizeData3D(xx(:), yy(:), z, xGrid{1}, xGrid{2});

% surf(xGrid, yGrid, zGrid, 'FaceColor', 'r')

clc;close all; clear;
addpath('../source')
addpath('../legacy/');

xx = 0.5:0.1:4.5;
yy = 0.5:0.1:5.5;
[xx,yy] = ndgrid(xx,yy);
z = tanh(xx-3).*sin(2*pi/6*yy);
noise = (rand(size(xx))-0.5).*xx.*yy/30;
zNoise = z + noise;
surf(xx,yy,z, 'FaceColor', 'g')
hold all;
surf(xx,yy,zNoise)
xGrid = 0.4:0.1:5;
yGrid = 0.4:0.1:5.6;
smoothness = 1e-13;

zGrid = RegularizeData3D(xx(:), yy(:), zNoise(:) ,xGrid, yGrid, 'smoothness', smoothness, 'interp', 'bilinear','solver', '\');
zGrid2 = regularizeNd([xx(:), yy(:)], zNoise(:), {xGrid, yGrid}, smoothness, 'linear');

surf(xGrid, yGrid, zGrid, 'FaceColor', 'r')
surf(xGrid, yGrid, zGrid2', 'FaceColor', 'b')

% xp = 0.49:4.5;
% yp = 0.49:5.5;
% [xp,yp] = ndgrid(xp,yp);
% x = [xp(:), yp(:)];
% z = tanh(xp-3).*sin(2*pi/6*yp);
% xGrid = {0:5; 0:6};
% smoothness = 0.00025;
% 
% zGrid = regularizeNd(x, z(:), xGrid, smoothness, 'linear');
% zGrid2 = RegularizeData3D(xp(:), yp(:), z, xGrid{1}, xGrid{2}, 'smoothness', smoothness, 'interp', 'bilinear');
% zGrid2 = zGrid2';
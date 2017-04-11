% 4D Examples
% This example demonstrates the use of regularizeNd with a 4D input and 1D
% output dataset. Note, that selecting the smoothness isn't always obvious
% until you have gained experience using regularizeNd. Often the best
% choice is to change the smoothness by a factor of 10 until you have
% reached the smooth hyper surface that you want or reduce the smoothness
% until you have reached the fidelity you want. Even if my first guess of
% the smoothness is adequate, I change the smoothness by factors of 10
% until it isn't smooth to see the effect of the smoothness parameter.
%%%
% Note that 

clc; clear; close all;

%% Load Data
% convert to double because I saved them as single to save space.
load('dataset_4d_1.mat')

% inputs.
x1 = double(x1);
y1 = double(y1);
z1 = double(z1);
t1 = double(t1);

% ouput
w1 = double(w1);

%% Look at the Input and Output Vectors
% The main point is there is a lot of points and the input space well
% filled.
figure;
histogram(x1)
figure;
histogram(y1)
figure;
histogram(z1)
figure;
histogram(t1)

figure
histogram(w1)

figure;
scatter3(x1,y1,z1, [], t1, 'filled');

%% Creating the regularized hypersurface
% Note with regularizeNd, the grid vectors must always span the input data.
% The reason for this is that calculating the weights for a given query
% point is well defined for interpolation and it not well defined for
% extrapolation. Understand though, that the fact that the grid vectors can
% far exceed the expanses of the fitted data and the fitted surface is
% guaranteed to change close to linearly far away from fitted data is of
% great advantage over other fitting technieques. It allows extrapolation
% away from the fitted data in a known way. In polynomial fitting, there is
% no guarantee how the polynomial will behave outside of the test data set.






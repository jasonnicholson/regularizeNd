clc; clear; close all;

%%
% Create a radial distribution of points spaced 10 degrees apart around 10
% concentric circles. Use |bsxfun| to compute the coordinates, $x =
% \cos{\theta}$ and $y = \sin{\theta}$.
theta = 0:10:350;
c = cosd(theta);
s = sind(theta);
r = 1:10;

x1 = bsxfun(@times,r.',c);
y1 = bsxfun(@times,r.',s);

figure
plot(x1,y1,'*b')
axis equal

%%
% Create a second, more coarsely distributed set of points. Use the
% |gallery| function to create random samplings in the range, [-10, 10].
x2 = -10 + 20*gallery('uniformdata',[25 1],0);
y2 = -10 + 20*gallery('uniformdata',[25 1],1);
figure
plot(x2,y2,'*')

%%
% Sample a parabolic function, |v(x,y)|, at both sets of points.
v1 = x1.^2 + y1.^2;
v2 = x2.^2 + y2.^2;

%%
% Create a |scatteredInterpolant| for each sampling of |v(x,y)|.
F1 = scatteredInterpolant(x1(:),y1(:),v1(:));
F2 = scatteredInterpolant(x2(:),y2(:),v2(:));


%%
% Create a grid of query points that extend beyond each domain.
xGrid = {-25:25, -25:26};
[xq,yq] = ndgrid(xGrid{:});

%% 
% Create regularized surface
zGrid1 = regularizeNd([x1(:), y1(:)], v1(:), xGrid, 0.0001);
zGrid2 = regularizeNd([x2(:), y2(:)], v2(:), xGrid, 0.0001);

%%
% Evaluate |F1| and plot the results.
figure
vq1 = F1(xq,yq);
surf(xq,yq,vq1)
hold all;
surf(xq,yq, zGrid1, 'FaceColor', 'r')

%%
% Evaluate |F2| and plot the results.
figure
vq2 = F2(xq,yq);
surf(xq,yq,vq2)
hold all;
surf(xq,yq,zGrid2, 'FaceColor', 'r')

%%
% The quality of the extrapolation is not as good for |F2| because of the
% coarse sampling of points in |v2|.
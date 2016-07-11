% This demonstrates that the coarse mesh and the fine mesh produce the same surface profile for a given smoothness.

% Pick some input points.  There is nothing special about these and there can be as many or as few as you want.
InputPoints =[
	0, 0, 0;
	0, 1, 0;
	1, 0, 0;
	1, 1, 0;
	0.5, 0.5, 1];

% Change the spacing to test each axis or both axes.
% You get the same surface profile whether the spacing is 0.5 or 0.01 on either or both axes.
x = 0 : 0.1 : 1;
y = 0 : 0.1 : 1;

% Set the smoothness.  See the documentation for details about the smoothness setting.
% This demonstration shows that the surfaces are equivalent when they have the same smoothing.
Smoothness = 0.05;

% Set a constant for scaling.
K = 1;

% Scale the dataset.
x = x * K;
y = y * K;
InputPoints = InputPoints * K;

z_Old = RegularizeData3D_Old(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), x, y, 'interp', 'bicubic', 'smoothness', Smoothness);


% Plot this figure in the top row.
subplot1 = subplot(2, 2, 1, 'Parent', figure);
set(gcf, 'color', 'white');
view(subplot1,[-74.5, 14]);
grid(subplot1, 'on');
hold(subplot1, 'all');
% View the surface.
surf(x, y, z_Old, 'facealpha', 0.75);
% Add the input points to see how well the surface matches them.
% The smoothness value is the only thing that controls this property of the surface.
scatter3(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), 'fill');

xlabel('x');
ylabel('y');
zlabel('z');
title({'(Old) There should be a gap between the tent and the top point.'});
set(get(gca,'XLabel'),'FontSize', 12)
set(get(gca,'YLabel'),'FontSize', 12)
set(get(gca, 'Title'), 'FontSize', 8)

% Set a constant for scaling.
K = 1000;

% Scale the dataset.
x = x * K;
y = y * K;
InputPoints = InputPoints * K;

z_Old_Wide = RegularizeData3D_Old(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), x, y, 'interp', 'bicubic', 'smoothness', Smoothness);

% Plot this figure in the top row.
subplot2 = subplot(2, 2, 2);
set(gcf, 'color', 'white');
view(subplot2,[-74.5, 14]);
grid(subplot2, 'on');
hold(subplot2, 'all');
% View the surface.
surf(x, y, z_Old_Wide, 'facealpha', 0.75);
% Add the input points to see how well the surface matches them.
% The smoothness value is the only thing that controls this property of the surface.
scatter3(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), 'fill');

xlabel('x');
ylabel('y');
zlabel('z');
title({'(Old) There should be a gap between the tent and the top point.'});
set(get(gca,'XLabel'),'FontSize', 12)
set(get(gca,'YLabel'),'FontSize', 12)
set(get(gca, 'Title'), 'FontSize', 8)





% Change everything back so we can start over.
% Change everything back so we can start over.
% Change everything back so we can start over.
x = x / K;
y = y / K;
InputPoints = InputPoints / K;

% This time we'll use the new version with the domain-influenced scaling.





% Set a constant for scaling.
K = 1;

% Scale the dataset.
x = x * K;
y = y * K;
InputPoints = InputPoints * K;

z = RegularizeData3D(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), x, y, 'interp', 'bicubic', 'smoothness', Smoothness);

% Plot this figure in the top row.
subplot2 = subplot(2, 2, 3);
set(gcf, 'color', 'white');
view(subplot2,[-74.5, 14]);
grid(subplot2, 'on');
hold(subplot2, 'all');
% View the surface.
surf(x, y, z, 'facealpha', 0.75);
% Add the input points to see how well the surface matches them.
% The smoothness value is the only thing that controls this property of the surface.
scatter3(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), 'fill');

xlabel('x');
ylabel('y');
zlabel('z');
title({'(New) There should be a gap between the tent and the top point.'});
set(get(gca,'XLabel'),'FontSize', 12)
set(get(gca,'YLabel'),'FontSize', 12)
set(get(gca, 'Title'), 'FontSize', 8)

% Set a constant for scaling.
K = 1000;

% Scale the dataset.
x = x * K;
y = y * K;
InputPoints = InputPoints * K;

z_Wide = RegularizeData3D(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), x, y, 'interp', 'bicubic', 'smoothness', Smoothness);

% Plot this figure in the top row.
subplot2 = subplot(2, 2, 4);
set(gcf, 'color', 'white');
view(subplot2,[-74.5, 14]);
grid(subplot2, 'on');
hold(subplot2, 'all');
% View the surface.
surf(x, y, z_Wide, 'facealpha', 0.75);
% Add the input points to see how well the surface matches them.
% The smoothness value is the only thing that controls this property of the surface.
scatter3(InputPoints(:, 1), InputPoints(:, 2), InputPoints(:, 3), 'fill');

xlabel('x');
ylabel('y');
zlabel('z');
title({'(New) There should be a gap between the tent and the top point.'});
set(get(gca,'XLabel'),'FontSize', 12)
set(get(gca,'YLabel'),'FontSize', 12)
set(get(gca, 'Title'), 'FontSize', 8)


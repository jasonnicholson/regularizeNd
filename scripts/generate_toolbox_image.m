%% Enhanced toolbox image for regularizeNd
% Generates a compact preview image for styling iterations and an optional
% final PNG render.
% Uses ETOPO bathymetry centred on Kamaʻehuakanaloa Seamount (Loihi),
% Big Island of Hawaii – scattered depth points over a smooth regularized
% submarine surface.
clc; clear; close all;

%% Paths
scriptPath = mfilename('fullpath');
scriptDir = fileparts(scriptPath);
repoRoot  = fileparts(scriptDir);

dataFile   = fullfile(scriptDir, 'a01_etopo_loihi_10k.mat');
outputFile = fullfile(repoRoot, 'build_base', 'toolbox_image.png');
previewFile = fullfile(repoRoot, 'build_base', 'toolbox_image_preview.jpg');
assert(isfile(dataFile), 'Missing: %s\nRun scripts/download_etopo_loihi.py first.', dataFile);

% Preview workflow for rapid visual iteration in chat context.
previewMode      = false;
maxPreviewBytes  = 100 * 1024;
previewScale     = 0.78;
previewQuality0  = 72;

%% Load ETOPO points
d   = load(dataFile);           % x = lon, y = lat, z = depth (m, negative)
lon = double(d.x(:));
lat = double(d.y(:));
h   = double(d.z(:));
fprintf('Using data file: %s\n', dataFile);

lonLim = [min(lon), max(lon)];
latLim = [min(lat), max(lat)];

%% Regularize onto a grid
gridRes   = 440;   % nodes per axis (coarse preview with smoother surfaces)
xGrid = {linspace(lonLim(1), lonLim(2), gridRes), ...
         linspace(latLim(1), latLim(2), gridRes+1)};
smoothness = 1e-6;
fprintf('Running regularizeNd on %d ETOPO points...\n', numel(lon));
tic;
zGrid = regularizeNd([lon, lat], h, xGrid, smoothness, 'cubic');
toc;

% Upsample grid since we are using cubic interpolation
zFunction = griddedInterpolant(xGrid, zGrid);
xGrid2= {linspace(lonLim(1) - eps(lonLim(1)), lonLim(2) + eps(lonLim(2)), 2000), ...
         linspace(latLim(1) - eps(latLim(1)), latLim(2) + eps(latLim(2)), 2001)};
xGrid2Expanded = cell(2,1);
[xGrid2Expanded{:}] = ndgrid(xGrid2{:});
zGrid2 = zFunction(xGrid2Expanded{1}, xGrid2Expanded{2});


%% Figure
bgColor = [0.04, 0.05, 0.10];
WIDTH = 1080;
HEIGHT = 810;
fig = figure('Color', bgColor, 'Position', [50, 50, WIDTH, HEIGHT], 'InvertHardcopy', 'off');
ax  = axes('Parent', fig, 'Color', bgColor, 'FontSize', 13, 'FontName', 'Helvetica');
ax.PositionConstraint = 'outerposition';
ax.Position = [0.20116,0.12794,0.63234,0.72654];

%% Regularized surface
hSurf = surf(ax, xGrid2{:}, zGrid2', 'FaceColor', 'interp', ...
             'EdgeColor', 'none', 'FaceLighting', 'gouraud');
hold(ax, 'on');
contour3(ax, xGrid2{1}, xGrid2{2}, zGrid2', 18, ...
       'LineColor', 'k', 'LineWidth', 0.45);

colormap(ax, turbo(256));
clim(ax, [-5400, -900]);

%% Scattered input points
trackColor = [0.5, 0.5, 0.5];
nPts = numel(lon);
keepN = min(1e4, nPts);
idx = round(linspace(1, nPts, keepN));
scatter3(ax, lon(idx), lat(idx), h(idx), 10, trackColor, 'filled', ...
       'MarkerEdgeColor', 'none');

%% Lighting
material(hSurf, 'dull');
light('Parent', ax, 'Style', 'infinite', 'Position', [ 1.6, -2.2, 2.8], 'Color', [0.96, 0.94, 1.00]);
light('Parent', ax, 'Style', 'infinite', 'Position', [-1.2,  1.0, 0.6], 'Color', [0.24, 0.36, 0.66]);
camlight(ax, 'headlight');

%% Camera
view(ax, 19.2, 36);
camproj(ax, 'perspective');
axis(ax, 'tight');
camzoom(ax, 1.22);

%% Axis styling: example-like labels/grid on dark background

tickColor  = [0.55, 0.58, 0.68];
labelColor = [0.80, 0.82, 0.90];
set(ax, 'Box', 'off', 'XGrid', 'off', 'YGrid', 'off', 'ZGrid', 'off', ...
        'XColor', tickColor, 'YColor', tickColor, 'ZColor', tickColor);
grid(ax, 'on');
% Hide 3-D backdrop panes when available to avoid bright wall artifacts.
if isprop(ax, 'Backdrop')
    ax.Backdrop.Visible   = 'off';
    ax.Backdrop.FaceColor = bgColor;
end
xlabel(ax, 'Longitude', 'Color', labelColor, 'FontSize', 14);
ylabel(ax, 'Latitude',  'Color', labelColor, 'FontSize', 14);
zlabel(ax, 'Depth (m)', 'Color', labelColor, 'FontSize', 14);

%% Colorbar
cb = colorbar(ax);
set(cb, 'Color', labelColor, 'FontSize', 11);
cb.Label.String   = 'Depth (m)';
cb.Label.Color    = labelColor;
cb.Label.FontSize = 12;

%% Title / branding
title(ax, '3D bathymetry view', ...
      'Color', [1, 1, 1], 'FontSize', 28, 'FontWeight', 'bold', 'FontName', 'Helvetica');
subtitle(ax, 'regularizeNd example fit', ...
         'Color', [0.78, 0.84, 0.96], 'FontSize', 13);

%% Export
ax.Toolbar.Visible = 'off';   % prevent axes toolbar appearing in exported PNG
disableDefaultInteractivity(ax);
drawnow;

if previewMode
    % Use JPEG for context-friendly iterative previews and enforce size cap.
    frame = getframe(fig);
    rgb = frame.cdata;
    if previewScale < 1
        rgb = imresize(rgb, previewScale, 'bilinear');
    end

    quality = previewQuality0;
    imwrite(rgb, previewFile, 'jpg', 'Quality', quality);
    fileInfo = dir(previewFile);
    while fileInfo.bytes > maxPreviewBytes && quality > 28
        quality = quality - 6;
        imwrite(rgb, previewFile, 'jpg', 'Quality', quality);
        fileInfo = dir(previewFile);
    end

    fprintf('Preview exported to %s (%0.1f KB, Q=%d)\n', previewFile, fileInfo.bytes / 1024, quality);
else
    fprintf('Exporting to %s\n', outputFile);
    exportgraphics(fig, outputFile, 'BackgroundColor', bgColor,'Width', WIDTH,'Height', HEIGHT);
    fprintf('Done.\n');
end

%%
rotate3d(ax, 'on');

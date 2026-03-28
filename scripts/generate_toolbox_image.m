%% Enhanced toolbox image for regularizeNd
% Generates build_base/toolbox_image.png
% Uses ICESat-2 ATL08 terrain heights over the Big Island of Hawaii
% (Mauna Kea / Mauna Loa / Kilauea) – 6 coloured laser beams over a
% smooth regularized terrain surface.
clc; clear; close all;

%% Paths
repoRoot   = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'source'));
dataFile   = fullfile(repoRoot, 'data', 'external', 'atl08_hawaii', 'hawaii_atl08_points.mat');
outputFile = fullfile(repoRoot, 'build_base', 'toolbox_image.png');
assert(isfile(dataFile), 'Missing: %s\nRun scripts/download_atl08_hawaii.py first.', dataFile);

%% Load ATL08 points
d    = load(dataFile);           % lon, lat, h (m), beam (1-6)
lon  = double(d.lon(:));
lat  = double(d.lat(:));
h    = double(d.h(:));
beam = double(d.beam(:));

lonLim  = [min(lon), max(lon)];
latLim  = [min(lat), max(lat)];

% % Crop to the central mountain core (removes flat coastal plains)
lonLimView  = [-156.05, -155.20];
latLimView  = [ 19.35,   20.25];

%% Regularize onto a grid
gridRes   = 480;   % nodes per axis
xGrid = {linspace(lonLim(1), lonLim(2), gridRes), ...
         linspace(latLim(1), latLim(2), gridRes+1)};
smoothness = 0.0000008;   % low = tight fit to data
fprintf('Running regularizeNd on %d ATL08 points...\n', numel(lon));
tic;
zGrid = regularizeNd([lon, lat], h, xGrid, smoothness, 'linear','\');
toc;

%% Figure
bgColor = [0.04, 0.05, 0.10];
fig = figure('Color', bgColor, 'Position', [50, 50, 1400, 1050], 'InvertHardcopy', 'off');
ax  = axes('Parent', fig, 'Color', bgColor, 'FontSize', 13, 'FontName', 'Helvetica');

%% Regularized surface
hSurf = surf(ax, xGrid{:}, zGrid', 'FaceColor', 'interp', ...
             'EdgeColor', 'none', 'FaceLighting', 'gouraud');
hold(ax, 'on');

%% Colormap: dark foothills → green mid-slopes → ochre → warm summit
n   = 512;
t   = linspace(0, 1, n)';
r   = 0.04 + 0.72 .* max(0, t - 0.22).^0.72;
g   = 0.12 + 0.52 .* t.^0.52 .* (1 - 0.38 .* t.^2);
b2  = 0.40 + 0.44 .* (1 - t).^1.1 - 0.24 .* max(0, t - 0.52);
cmap = max(0, min(1, [r, g, b2]));
colormap(ax, cmap);
clim(ax, [min(zGrid(:), [], 'omitnan'), max(zGrid(:), [], 'omitnan')]);

%% ICESat-2 tracks
trackColor = [0.98, 0.86, 0.20];  % warm gold for high contrast
% Plot original ATL08 heights directly.
scatter3(ax, lon, lat, h,10,trackColor,'filled');

%% Lighting
material(hSurf, 'dull');
light('Parent', ax, 'Style', 'infinite', 'Position', [ 2, -3, 2],  'Color', [0.90, 0.90, 1.00]);
light('Parent', ax, 'Style', 'infinite', 'Position', [-1,  1, 0.4],'Color', [0.18, 0.28, 0.55]);
camlight(ax, 'headlight');

%% Camera
view(ax, -155, 38);
camproj(ax, 'perspective');

%% Axis styling: no grid/box, dark pane faces, dark ticks
xlim(ax, lonLimView);
ylim(ax, latLimView);

tickColor  = [0.55, 0.58, 0.68];
labelColor = [0.80, 0.82, 0.90];
set(ax, 'Box', 'off', 'XGrid', 'off', 'YGrid', 'off', 'ZGrid', 'off', ...
        'XColor', tickColor, 'YColor', tickColor, 'ZColor', tickColor);
% Hide 3-D backdrop panes when available to avoid bright wall artifacts.
if isprop(ax, 'Backdrop')
    ax.Backdrop.Visible   = 'off';
    ax.Backdrop.FaceColor = bgColor;
end
xlabel(ax, 'Longitude',       'Color', labelColor, 'FontSize', 14);
ylabel(ax, 'Latitude',        'Color', labelColor, 'FontSize', 14);
zlabel(ax, 'Elevation (m)',  'Color', labelColor, 'FontSize', 14);

%% Colorbar
cb = colorbar(ax);
set(cb, 'Color', labelColor, 'FontSize', 11);
cb.Label.String   = 'Elevation (m)';
cb.Label.Color    = labelColor;
cb.Label.FontSize = 12;

%% Title / branding
title(ax,    'regularizeNd', ...
      'Color', [1, 1, 1], 'FontSize', 26, 'FontWeight', 'bold', 'FontName', 'Helvetica');
subtitle(ax, 'ICESat-2 tracks  \rightarrow  smooth regularized surface', ...
         'Color', [0.70, 0.72, 0.80], 'FontSize', 13);

%% Export to PNG
ax.Toolbar.Visible = 'off';   % prevent axes toolbar appearing in exported PNG
disableDefaultInteractivity(ax);
fprintf('Exporting to %s\n', outputFile);
exportgraphics(fig, outputFile, 'Resolution', 200, 'BackgroundColor', bgColor);
fprintf('Done.\n');

%%
rotate3d(ax, 'on');

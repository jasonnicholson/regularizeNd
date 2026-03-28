%% Generate three promotional images for regularizeNd — real Greenland data
% Data sources:
%   Wide  ETOPO: data/external/etopo/etopo_greenland_wide_30s_bed.nc  (58-73N, 60-15W)
%   Narrow ETOPO: data/external/etopo/etopo_greenland_30s_bed.nc       (65-72N, 50-40W)
%   ICESat-2 ATL06: data/external/icesat2/ATL06_*.h5
%
% Concept A: Full-bleed wide Greenland hero -- ocean, fjords, ice sheet, coloured tracks
% Concept B: Side-by-side before/after -- sparse tracks vs regularized surface
% Concept C: Cinematic 3D -- smooth regularized ice surface + coloured track ribbons above

clear; close all; clc;
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot,'source'));
etopoWide   = fullfile(repoRoot,'data','external','etopo','etopo_greenland_wide_30s_bed.nc');
etopoNarrow = fullfile(repoRoot,'data','external','etopo','etopo_greenland_30s_bed.nc');
icesatDir   = fullfile(repoRoot,'data','external','icesat2');
outDir      = fullfile(repoRoot,'build_base','promo_concepts');
if ~exist(outDir,'dir'), mkdir(outDir); end
assert(isfile(etopoWide),   'Missing: %s', etopoWide);
assert(isfile(etopoNarrow), 'Missing: %s', etopoNarrow);
h5files = dir(fullfile(icesatDir,'ATL06_*.h5'));
assert(~isempty(h5files),'No ATL06 files in %s',icesatDir);

%% Load wide ETOPO
fprintf('Loading wide ETOPO...\n');
lonW=double(ncread(etopoWide,'lon')); latW=double(ncread(etopoWide,'lat'));
zRawW=double(ncread(etopoWide,'z'));
if size(zRawW,1)==numel(lonW)&&size(zRawW,2)==numel(latW); zWide=zRawW.'; else; zWide=zRawW; end

%% Load narrow ETOPO
fprintf('Loading narrow ETOPO...\n');
lonN=double(ncread(etopoNarrow,'lon')); latN=double(ncread(etopoNarrow,'lat'));
zRawN=double(ncread(etopoNarrow,'z'));
if size(zRawN,1)==numel(lonN)&&size(zRawN,2)==numel(latN); zNarrow=zRawN.'; else; zNarrow=zRawN; end

%% Load ICESat-2
fprintf('Loading ICESat-2...\n');
[lonAll,latAll,hAll,beamAll]=loadAtl06Points(icesatDir,h5files(1:min(20,numel(h5files))));
inBox=lonAll>=min(lonN)&lonAll<=max(lonN)&latAll>=min(latN)&latAll<=max(latN);
validH=isfinite(hAll)&hAll>0&hAll<4000;
keep=inBox&validH;
lonAll=lonAll(keep); latAll=latAll(keep); hAll=hAll(keep); beamAll=beamAll(keep);
fprintf('  Valid points: %d\n',numel(lonAll));

%% Sub-region
rLon=[-47.5,-41.5]; rLat=[68.0,71.5];
inR=lonAll>=rLon(1)&lonAll<=rLon(2)&latAll>=rLat(1)&latAll<=rLat(2);
lonR=lonAll(inR); latR=latAll(inR); hR=hAll(inR); beamR=beamAll(inR);
fprintf('  Sub-region points: %d\n',numel(lonR));
rng(42); maxPts=200000;
if numel(lonR)>maxPts
    idx=randperm(numel(lonR),maxPts); lonR=lonR(idx); latR=latR(idx); hR=hR(idx); beamR=beamR(idx);
end

%% Narrow ETOPO sub-tile
lonMask=lonN>=rLon(1)&lonN<=rLon(2); latMask=latN>=rLat(1)&latN<=rLat(2);
lonSub=lonN(lonMask); latSub=latN(latMask); zSub=zNarrow(latMask,lonMask);

%% regularizeNd (shared)
nxB=round((rLon(2)-rLon(1))/0.04); nyB=round((rLat(2)-rLat(1))/0.04);
xgB=linspace(rLon(1),rLon(2),nxB); ygB=linspace(rLat(1),rLat(2),nyB);
fprintf('Running regularizeNd: %d pts, grid %dx%d...\n',numel(lonR),nxB,nyB);
ZndB=regularizeNd([lonR,latR],hR,{xgB,ygB},0.00035,'cubic');
ZregB=ZndB.'; clo=quantile(hR,0.02); chi=quantile(hR,0.98);

%% ====== CONCEPT A ======
fprintf('\nRendering Concept A...\n');
dxW=mean(diff(lonW)); dyW=mean(diff(latW));
shW=hillshade(zWide,330,38,dxW,dyW);
cmapT=geoTerrainMap(1024);
nC=size(cmapT,1); zMin=min(zWide(:)); zMax=max(zWide(:));
zi=max(1,min(nC,round((zWide-zMin)/(zMax-zMin)*(nC-1))+1));
rgbA=reshape(cmapT(zi(:),:),[size(zWide,1),size(zWide,2),3]);
shMat=repmat(shW,1,1,3);
rgbA=max(0,min(1,rgbA.*(0.20+0.80*shMat)));
figA=figure('Color','k','Position',[50 50 1900 1100]);
axA=axes(figA,'Position',[0 0 1 1]);
image(axA,lonW,latW,rgbA); set(axA,'YDir','normal'); axis(axA,'image','off'); hold(axA,'on');
beamColorA=[1.00 0.64 0.08;0.94 0.28 0.04;0.12 0.88 0.95;0.10 0.52 0.96;0.96 0.92 0.16;0.86 0.68 0.06];
step=5;
for b=1:6
    bm=beamAll(1:step:end)==b; lo=lonAll(1:step:end); la=latAll(1:step:end);
    scatter(axA,lo(bm),la(bm),2,repmat(beamColorA(b,:),nnz(bm),1),'filled','MarkerFaceAlpha',0.55,'MarkerEdgeAlpha',0);
end
tx=min(lonW)+0.5; ty=max(latW)-0.8;
text(axA,tx+0.07,ty-0.07,'regularizeNd','Color',[0 0 0 0.60],'FontSize',65,'FontWeight','bold','Interpreter','none');
text(axA,tx,ty,'regularizeNd','Color',[0.97 1.00 1.00],'FontSize',65,'FontWeight','bold','Interpreter','none');
text(axA,tx+0.04,ty-0.78,'Greenland  |  ICESat-2 tracks \rightarrow regularized surface','Color',[0.86 0.93 1.00],'FontSize',20);
drawnow;
exportgraphics(figA,fullfile(outDir,'concept_A_etopo_relief.png'),'Resolution',200);
fprintf('  Saved concept_A\n'); close(figA);

%% ====== CONCEPT B ======
fprintf('Rendering Concept B...\n');
bgCol=[0.06 0.07 0.10];
figB=figure('Color',bgCol,'Position',[50 50 1940 920]);
topGap=0.11; botGap=0.10; midGap=0.025; sideL=0.075; sideR=0.105;
panW=(1-sideL-sideR-midGap)/2; panH=1-topGap-botGap;
axB1=axes(figB,'Position',[sideL,botGap,panW,panH]);
axB2=axes(figB,'Position',[sideL+panW+midGap,botGap,panW,panH]);

shB1=hillshade(zSub,310,35,mean(diff(lonSub)),mean(diff(latSub)));
imagesc(axB1,lonSub,latSub,shB1); colormap(axB1,repmat(linspace(0.06,0.26,256)',1,3));
set(axB1,'YDir','normal'); hold(axB1,'on');
beamColorB=[1.00 0.60 0.08;0.95 0.28 0.05;0.14 0.86 0.92;0.10 0.54 0.96;0.97 0.93 0.18;0.88 0.70 0.06];
for b=1:6
    bsel=beamR==b; if ~any(bsel), continue; end
    scatter(axB1,lonR(bsel),latR(bsel),5,repmat(beamColorB(b,:),nnz(bsel),1),'filled','MarkerFaceAlpha',0.65,'MarkerEdgeAlpha',0);
end
axis(axB1,'image'); set(axB1,'XLim',rLon,'YLim',rLat);
styleAxisDark(axB1,bgCol);
xlabel(axB1,'Longitude','Color',[0.80 0.88 0.96],'FontSize',14);
ylabel(axB1,'Latitude','Color',[0.80 0.88 0.96],'FontSize',14);
title(axB1,'Sparse ICESat-2 ATL06 tracks  (input)','Color',[0.92 0.96 1.00],'FontSize',15,'FontWeight','normal');

imagesc(axB2,xgB,ygB,ZregB); set(axB2,'YDir','normal'); hold(axB2,'on');
colormap(axB2,iceHeightMap(256)); clim(axB2,[clo chi]);
contour(axB2,xgB,ygB,ZregB,clo:100:chi,'LineColor',[1 1 1]*0.22,'LineWidth',0.7);
axis(axB2,'image'); set(axB2,'XLim',rLon,'YLim',rLat);
styleAxisDark(axB2,bgCol);
xlabel(axB2,'Longitude','Color',[0.80 0.88 0.96],'FontSize',14);
ylabel(axB2,'Latitude','Color',[0.80 0.88 0.96],'FontSize',14);
title(axB2,'regularizeNd cubic surface  (output)','Color',[0.92 0.96 1.00],'FontSize',15,'FontWeight','normal');

cbPos=get(axB2,'Position');
cbAx=axes(figB,'Position',[cbPos(1)+cbPos(3)+0.012,cbPos(2),0.018,cbPos(4)]);
imagesc(cbAx,1,linspace(clo,chi,256)',(1:256)'); colormap(cbAx,iceHeightMap(256));
set(cbAx,'XTick',[],'YDir','normal','YAxisLocation','right','YColor',[0.78 0.86 0.96],'FontSize',12,'Box','off','YLim',[1 256]);
ticks=linspace(1,256,5); vals=linspace(clo,chi,5);
set(cbAx,'YTick',ticks,'YTickLabel',arrayfun(@(v)sprintf('%d m',round(v)),vals,'Uni',false));
ylabel(cbAx,'Surface height  h_{li}','Color',[0.78 0.86 0.96],'FontSize',13);

annotation(figB,'textbox',[0 0.90 1 0.09],'String','regularizeNd:  sparse altimetry  \rightarrow  continuous ice surface','HorizontalAlignment','center','VerticalAlignment','middle','Color',[0.94 0.97 1.0],'FontSize',21,'FontWeight','bold','EdgeColor','none','BackgroundColor','none','Interpreter','tex');
drawnow;
exportgraphics(figB,fullfile(outDir,'concept_B_sparse_to_regularized.png'),'Resolution',200);
fprintf('  Saved concept_B\n'); close(figB);

%% ====== CONCEPT C ======
fprintf('Rendering Concept C...\n');
figC=figure('Color',[0.02 0.03 0.06],'Position',[50 50 1700 1000]);
axC=axes(figC,'Position',[0 0 1 1]);
[XG,YG]=meshgrid(xgB,ygB);
surf(axC,XG,YG,ZregB,ZregB,'EdgeColor','none','FaceAlpha',1.0);
shading(axC,'interp'); colormap(axC,iceHeightMap(512)); clim(axC,[clo chi]);
hold(axC,'on');
light(axC,'Position',[rLon(1)-8,rLat(2)+4,12000],'Style','infinite','Color',[0.95 0.97 1.0]);
light(axC,'Style','infinite','Position',[rLon(2)+3,rLat(1)-3,6000],'Color',[0.45 0.55 0.75]);
material(axC,[0.25 0.70 0.12 6 0.5]);
beamColorC=[1.00 0.62 0.08;0.96 0.26 0.04;0.12 0.90 0.95;0.08 0.52 0.96;0.98 0.93 0.18;0.88 0.68 0.05];
rng(13); maxPtsC=min(numel(lonR),100000); idxC=randperm(numel(lonR),maxPtsC);
for b=1:6
    bsel=beamR(idxC)==b; if ~any(bsel), continue; end
    scatter3(axC,lonR(idxC(bsel)),latR(idxC(bsel)),hR(idxC(bsel))+60,3,repmat(beamColorC(b,:),nnz(bsel),1),'filled','MarkerFaceAlpha',0.55,'MarkerEdgeAlpha',0);
end
view(axC,38,28); axis(axC,'tight','off'); set(axC,'ZLim',[clo-100,chi+500]); grid(axC,'off');
txC=rLon(1)+0.2; tyC=rLat(2)-0.05; tzC=chi+390;
text(axC,txC+0.06,tyC-0.06,tzC-20,'regularizeNd','Color',[0 0 0 0.55],'FontSize',52,'FontWeight','bold','Interpreter','none');
text(axC,txC,tyC,tzC,'regularizeNd','Color',[0.97 1.00 1.00],'FontSize',52,'FontWeight','bold','Interpreter','none');
text(axC,txC+0.04,tyC,tzC-330,'ICESat-2 tracks  \rightarrow  smooth regularized surface','Color',[0.80 0.90 1.00],'FontSize',17);
drawnow;
exportgraphics(figC,fullfile(outDir,'concept_C_hybrid_cinematic.png'),'Resolution',200);
fprintf('  Saved concept_C\n'); close(figC);
fprintf('\nAll done. Images in: %s\n',outDir);

%% ====== HELPERS ======

function [lonPts,latPts,hPts,beamPts]=loadAtl06Points(icesatDir,fileStruct)
beams={'gt1l','gt1r','gt2l','gt2r','gt3l','gt3r'};
lonPts=[]; latPts=[]; hPts=[]; beamPts=[];
for i=1:numel(fileStruct)
    fpath=fullfile(icesatDir,fileStruct(i).name);
    fprintf('  [%2d/%2d] %s\n',i,numel(fileStruct),fileStruct(i).name);
    for b=1:numel(beams)
        grp=['/' beams{b} '/land_ice_segments/'];
        try; lat=double(h5read(fpath,[grp 'latitude'])); lon=double(h5read(fpath,[grp 'longitude'])); h=double(h5read(fpath,[grp 'h_li'])); catch; continue; end
        v=isfinite(lat)&isfinite(lon)&isfinite(h)&h<1e10&h>-500;
        if any(v); lonPts=[lonPts;lon(v)]; latPts=[latPts;lat(v)]; hPts=[hPts;h(v)]; beamPts=[beamPts;repmat(b,nnz(v),1)]; end %#ok<AGROW>
    end
end
end

function hs=hillshade(z,azDeg,elDeg,dx,dy)
[dzdx,dzdy]=gradient(z,dx,dy);
slope=atan(sqrt(dzdx.^2+dzdy.^2)); aspect=atan2(dzdy,-dzdx);
hs=max(0,sin(deg2rad(elDeg)).*cos(slope)+cos(deg2rad(elDeg)).*sin(slope).*cos(deg2rad(azDeg)-aspect));
hs=(hs-min(hs(:)))./max(max(hs(:))-min(hs(:)),eps);
end

function styleAxisDark(ax,bgCol)
set(ax,'Color',bgCol,'XColor',[0.70 0.80 0.90],'YColor',[0.70 0.80 0.90],'FontSize',13,'Box','off','TickDir','out','TickLength',[0.010 0.010],'LineWidth',0.8);
end

function cmap=geoTerrainMap(n)
if nargin<1, n=256; end
stops=[
   0.000  0.002  0.018  0.090;
   0.200  0.008  0.060  0.220;
   0.380  0.030  0.180  0.440;
   0.460  0.080  0.320  0.600;
   0.480  0.200  0.440  0.680;
   0.490  0.600  0.560  0.420;
   0.500  0.450  0.380  0.280;
   0.520  0.360  0.300  0.240;
   0.580  0.480  0.420  0.340;
   0.640  0.720  0.680  0.580;
   0.720  0.860  0.880  0.910;
   0.840  0.920  0.940  0.970;
   1.000  0.970  0.985  1.000];
xi=stops(:,1); col=stops(:,2:4); xq=linspace(0,1,n)';
cmap=max(0,min(1,interp1(xi,col,xq,'pchip')));
end

function cmap=iceHeightMap(n)
if nargin<1, n=256; end
stops=[0.04 0.08 0.20;0.10 0.22 0.50;0.18 0.42 0.76;0.46 0.70 0.90;0.82 0.88 0.92;0.95 0.88 0.66;0.84 0.66 0.34;0.62 0.40 0.18];
xi=linspace(0,1,size(stops,1)); xq=linspace(0,1,n);
cmap=max(0,min(1,interp1(xi,stops,xq,'pchip')));
end

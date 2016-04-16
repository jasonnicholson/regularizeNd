function [index, weight] = linear(x, xGridMin, xGridMax, nGrid)
dx = (xGridMax - xGridMin)./nGrid;
fractionalIndex = bsxfunbsxfun(@rdivide,  bsxfun(@minus, x, xGridMin), dx);
lowerIndex = fix(fractionalIndex);
fraction = fractionalIndex - lowerIndex;
w = cat(3, 1-fraction, fraction);
weights = mat2cell(w(:,1,1:2), 


end
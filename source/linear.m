function [index, weight] = linear(x, xGridMin, xGridMax, nGrid, nDimensions)
dx = (xGridMax - xGridMin)./nGrid;
fractionalIndex = bsxfunbsxfun(@rdivide,  bsxfun(@minus, x, xGridMin), dx);
lowerIndex = fix(fractionalIndex);
fraction = fractionalIndex - lowerIndex;
clear fractionalIndex
% save weight in each dimensional direction, for linear interpolation,
% there is 2 weights per dimension. w1, w2
w = cat(3, 1-fraction, fraction);

% subscript for the 3rd dimensions of w
index3 = cell(nDimensions, 1);
nodeNumber = (1:2^nDimensions);
[index3{:}] = ind2sub(2*ones(1,nDimensions), nodeNumber');
index3 = [index3{:}];
% subscript of 2nd dimension w
index2 = repmat(1:nDimensions, 2^nDimensions, 1);
% compute the linear index for the combined subscript of the 2nd and 3rd
% dimensions of w. transpose for later use with the prod function so that
% it operates along the columns.
index23 = sub2ind([nDimensions, 2], index2, index3)';
% compute the index offset
indexOffset = index3'-1;

% preallocate before looping
weight = nan(size(x,1),2^nDimensions);
index = weight;

for iPoint = 1:size(x,1)
    localDimensionalWeights = w(iPoint, :,:);
    localLowerIndex = lowerIndex(iPoint,:);
    % compute the weight for each point by computing the product of the
    % corresponding dimensional weights
    weight(iPoint, :) = prod(localDimensionalWeights(index23));
    % compute the index of each point in current cell. index is stored in
    % columns
    localIndexes = bsxfun(@pluss, indexOffset, localLowerIndex');
    index(iPoint, :) = 
end

end
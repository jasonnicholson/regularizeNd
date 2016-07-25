# regularizeNd
Creates a gridded lookup table from scattered data in n dimensions.

regularizeNd is function written in MATLAB that extends functionality of RegularizeData3d from 2-D input to n-D output. More background can be found here:
https://mathformeremortals.wordpress.com/2013/09/02/regularizedata3d-the-excel-spreadsheet-function-to-regularize-3d-data-to-a-smooth-surface/

The basic idea is that a lookup table is fitted to the scattered data while a required level of smoothness. The smoothness parameter trades between goodness of fit and smoothness of the curve (1-D), surface (2-D), or hypersurface (n-D).

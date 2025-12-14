[![View regularizeNd on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend)

# regularizeNd
Creates a gridded lookup table from scattered data in n dimensions.

regularizeNd is function written in MATLAB that extends functionality of RegularizeData3d from 2-D input to n-D input. More background can be found [here](https://mathformeremortals.wordpress.com/2013/01/29/introduction-to-regularizing-with-2d-data-part-1-of-3/) and [here](https://mathformeremortals.wordpress.com/2013/09/02/regularizedata3d-the-excel-spreadsheet-function-to-regularize-3d-data-to-a-smooth-surface/)


The basic idea is that a lookup table is fitted to the scattered data with a required level of smoothness. The smoothness parameter trades between goodness of fit and smoothness of the curve (1-D), surface (2-D), or hypersurface (n-D).

On the MathWorks File Exchange, checkout the Examples tab: [regularizeNd at MathWorks File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend)

## Screenshot

![regularizeNd fit](img/START_HERE_example1_01.png)

## Getting Started

- General usage. Install from the [MathWorks File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend).
- Developing
  - Take a look at the [Developer Documentation](.github/Developer_Documentation.md) for more details. 
  - Clone. Run the post-clone-scripth.sh. 
  - Use setupRegularizeNdProjectPath.m to setup and breakdown the project path.
  - Run scripts/createPackage.m to create the toolbox package.
- Documentation - The documentation can be found 
  - Linked on the repo on the right.
  - Directly at [regularizeNd Documentation](https://jasonhnicholson.com/regularizeNd/)
  - Or packaged with the toolbox.
- Examples are in the Example folder at the project root either from installing or cloning. Examples are packaged with the documentation but without the
needed data. Running the Examples from the Example folder will have all the needed data.
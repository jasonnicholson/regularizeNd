[![View regularizeNd on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend)

# regularizeNd
Creates a gridded lookup table from scattered data in n dimensions. 

regularizeNd is a MATLAB function inspired by RegularizeData3D and gridfit. It generalizes the same regularization approach from 2-D input to n-D input. regularizeNd was originally started as a rewrite of those tools, but has since evolved into a completely independent implementation with no shared code. More background on the underlying regularization technique can be found [here](https://mathformeremortals.wordpress.com/2013/01/29/introduction-to-regularizing-with-2d-data-part-1-of-3/) and [here](https://mathformeremortals.wordpress.com/2013/09/02/regularizedata3d-the-excel-spreadsheet-function-to-regularize-3d-data-to-a-smooth-surface/)


The basic idea is that a lookup table is fitted to the scattered data with a required level of smoothness. The smoothness parameter trades between goodness of fit and smoothness of the curve (1-D), surface (2-D), or hypersurface (n-D).

On the MathWorks File Exchange, check out the Examples tab: [regularizeNd at MathWorks File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend)

## Screenshot

![regularizeNd fit](build_base/toolbox_image.png)

## Getting Started

- General usage: install from the [MathWorks File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/61436-regularizend).
- Developing
  - See the [Developer Guide](docs/developer_guide.md) for prerequisites, development workflow, and release steps.
  - Clone the repository.
  - Run `pnpm i` (or `pnpm i --frozen-lockfile`) to install dependencies and configure git hooks.
  - Run `setupRegularizeNdProjectPath.m` before running MATLAB scripts. Run it again when done to clean up project paths.
  - Use `scripts/createPackage.m` to build toolbox artifacts and package the toolbox.
- Documentation
  - Linked from this repository.
  - Available online at [regularizeNd Documentation](https://jasonhnicholson.com/regularizeNd/).
  - Packaged with the toolbox.
- Examples are in the `Examples` folder at the project root (for both installed and cloned copies).
  - Examples packaged with documentation do not include all data files.
  - Run examples from the project `Examples` folder when data files are required.

## License

regularizeNd is licensed under the MIT License. See the [LICENSE](LICENSE) file for the full license text.
# Generate \_targets.R file from bakepipe scripts

Parses all R scripts in the project and generates a \_targets.R file
that defines targets for the targets package. This allows bakepipe to
use targets as a backend for pipeline execution.

## Usage

``` r
generate_targets_file()
```

## Value

Invisibly returns the path to the generated \_targets.R file

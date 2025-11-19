# Mark a file as external input to the script

Mark a file as external input to the script. This function simply
returns the path and is used for static analysis to determine script
dependencies. Unlike file_in(), external_in() is used for files that are
provided by the user and are not produced by any other script in the
pipeline. This helps distinguish between pipeline-internal dependencies
and external data sources.

## Usage

``` r
external_in(path)
```

## Arguments

- path:

  Character string specifying the path to the external input file

## Value

The file path (unchanged)

## Examples

``` r
# In a bakepipe script, mark a file as external input and use it directly
csv_file <- system.file("extdata", "sample-project", "input.csv",
                        package = "bakepipe")
user_data <- read.csv(external_in(csv_file))
#> Warning: incomplete final line found by readTableHeader on '/home/runner/work/_temp/Library/bakepipe/extdata/sample-project/input.csv'
```

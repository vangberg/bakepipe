# Mark a file as input to the script

Mark a file as input to the script. This function simply returns the
path and is used for static analysis to determine script dependencies.
It can be used directly when reading files.

## Usage

``` r
file_in(path)
```

## Arguments

- path:

  Character string specifying the path to the input file

## Value

The file path (unchanged)

## Examples

``` r
# In a bakepipe script, mark a file as input and use it directly when reading
csv_file <- system.file("extdata", "sample-project", "input.csv",
                        package = "bakepipe")
data <- read.csv(file_in(csv_file))
#> Warning: incomplete final line found by readTableHeader on '/home/runner/work/_temp/Library/bakepipe/extdata/sample-project/input.csv'

# The function simply returns the path unchanged
file_path <- file_in("data.csv")
print(file_path)  # "data.csv"
#> [1] "data.csv"
```

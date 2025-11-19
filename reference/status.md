# Show pipeline status

Display the current state of all scripts in the pipeline (fresh/stale)

## Usage

``` r
status(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. If TRUE (default), prints status information to console.

## Value

NULL (invisibly). This function is called for its side effect of
displaying pipeline status information to the console.

## Examples

``` r
# Copy sample project to temp directory  
temp_dir <- tempfile()
dir.create(temp_dir)
sample_proj <- system.file("extdata", "sample-project", package = "bakepipe")
file.copy(sample_proj, temp_dir, recursive = TRUE)
#> [1] TRUE

# Change to the sample project directory
old_wd <- getwd()
setwd(file.path(temp_dir, "sample-project"))

# Display current pipeline status
status()
#> 
#> [STATUS] Bakepipe Status
#>    0 fresh scripts
#>  - 2 stale scripts
#> 
#> [!] 01_process.R   (stale)
#> [!] 02_summarize.R (stale)
#> 

# This will show which scripts are fresh (up-to-date) 
# and which are stale (need to be re-run)

# Restore working directory and clean up
setwd(old_wd)
unlink(temp_dir, recursive = TRUE)
```

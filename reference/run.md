# Run pipeline

Execute scripts in the pipeline graph in topological order. Only runs
scripts that are stale (have changed or have stale dependencies) for
incremental execution.

## Usage

``` r
run(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. If TRUE (default), prints progress messages to console.

## Value

Character vector of files that were created or updated

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

# Execute the pipeline
created_files <- run()
#> 
#> [PIPELINE] Bakepipe Pipeline
#>    Running 2 scripts
#> 
#> [OK] 01_process.R   (240ms)
#> [OK] 02_summarize.R (243ms)
#> 
#> [SUMMARY]
#>    Executed 2 scripts in 483ms
#>    Created/updated 2 files:
#>      - processed.csv
#>      - summary.csv
#> 

# The function returns paths of files that were created or updated
print(created_files)
#> [1] "processed.csv" "summary.csv"  

# Restore working directory and clean up
setwd(old_wd)
unlink(temp_dir, recursive = TRUE)
```

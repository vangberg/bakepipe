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
#> + script_02_summarize_r dispatched
#> ✔ script_02_summarize_r completed [0ms, 266 B]
#> + input_csv dispatched
#> ✔ input_csv completed [0ms, 14 B]
#> + script_01_process_r dispatched
#> ✔ script_01_process_r completed [0ms, 204 B]
#> + output_01_process_r dispatched
#> ✔ output_01_process_r completed [268ms, 36 B]
#> + output_02_summarize_r dispatched
#> ✔ output_02_summarize_r completed [261ms, 22 B]
#> ✔ ended pipeline [718ms, 5 completed, 0 skipped]
#> 

# The function returns paths of files that were created or updated
print(created_files)
#> [1] "processed.csv" "summary.csv"  

# Restore working directory and clean up
setwd(old_wd)
unlink(temp_dir, recursive = TRUE)
```

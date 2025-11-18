# Targets frontend

I think the Bakepipe API is really nice, but I don't think it is sensible
to reinvent the wheel when it comes to defining targets and their dependencies. Could we make Bakepipe a simple frontend for
the targets package instead?

## Approach

**Keep Bakepipe's API**, use targets as backend:
- Users still write scripts with `file_in()`, `file_out()`, `external_in()`
- Generate `_targets.R` from parsed dependencies
- Wrap targets functions in `bakepipe::run()`, `status()`, `clean()`

## Generated Target Structure

Fine-grained dependencies inferred from `file_in()` calls:

```r
# Script 1: 01_process.R
# data <- read.csv(external_in("input.csv"))
# write.csv(subset_a, file_out("output_a.csv"))
# write.csv(subset_b, file_out("output_b.csv"))

tar_target(script_01_process_r, "01_process.R", format = "file")
tar_target(input_csv, "input.csv", format = "file")

# Execution target - runs script once
tar_target(
  run_01_process,
  {
    script_01_process_r
    input_csv
    source("01_process.R")
    TRUE
  }
)

# Individual output targets
tar_target(output_a_csv, { run_01_process; "output_a.csv" }, format = "file")
tar_target(output_b_csv, { run_01_process; "output_b.csv" }, format = "file")

# Script 2: 02_analyze.R
# data <- read.csv(file_in("output_a.csv"))  # Only uses output_a!
# write.csv(results, file_out("analysis.csv"))

tar_target(script_02_analyze_r, "02_analyze.R", format = "file")
tar_target(
  run_02_analyze,
  {
    script_02_analyze_r
    output_a_csv  # ONLY output_a - inferred from file_in() call!
    source("02_analyze.R")
    TRUE
  }
)
tar_target(analysis_csv, { run_02_analyze; "analysis.csv" }, format = "file")
```

**Key design**:
- Script runs once via `run_*` target
- Each output is separate target
- Dependencies inferred from `file_in()` calls - script 2 only depends on `output_a_csv`
- Changes to `output_b.csv` won't trigger script 2 rerun

## Implementation

- New `generate_targets_file()` - uses existing `parse()` to create `_targets.R`
- Modify `run()` → call `targets::tar_make()`
- Modify `status()` → call `targets::tar_outdated()` + pretty print
- Modify `clean()` → call `targets::tar_destroy()`
- Regenerate `_targets.R` before each operation

## Benefits

- Leverage targets' mature dependency tracking
- Reduce ~1100 lines to ~200 line translation layer
- Gain targets ecosystem (parallel execution, visualization, etc.)
- Users can graduate to native targets if needed

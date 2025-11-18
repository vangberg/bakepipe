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

Minimal targets: one per script + external inputs

```r
# Script 1: 01_process.R
# data <- read.csv(external_in("input.csv"))
# write.csv(subset_a, file_out("output_a.csv"))
# write.csv(subset_b, file_out("output_b.csv"))

tar_target(input_csv, "input.csv", format = "file")

tar_target(
  output_01_process,
  {
    input_csv
    source("01_process.R")
    c("output_a.csv", "output_b.csv")
  },
  format = "file"
)

# Script 2: 02_analyze.R
# data <- read.csv(file_in("output_a.csv"))
# write.csv(results, file_out("analysis.csv"))

tar_target(
  output_02_analyze,
  {
    output_01_process
    source("02_analyze.R")
    c("analysis.csv")
  },
  format = "file"
)
```

**Key design**:
- One target per script, returns vector of output files
- Dependencies listed explicitly at top of target
- No separate script/run/output targets
- Manual edits to any output file invalidate the target

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

# Targets Backend Migration

This document describes the migration to using the `targets` package as bakepipe's execution backend.

## Backward Compatibility

### API Compatibility - MAINTAINED

All user-facing functions maintain their original API:

- **`file_in(path)`** - No changes. Same behavior.
- **`file_out(path)`** - No changes. Same behavior.
- **`external_in(path)`** - No changes. Same behavior.
- **`run(verbose = TRUE)`** - Same signature. Returns character vector of created files.
- **`status(verbose = TRUE)`** - Same signature. Displays pipeline status.
- **`clean(verbose = TRUE)`** - Same signature. Returns character vector of removed files.
- **`parse()`** - No changes. Same return structure.

### Behavior Compatibility - MAINTAINED

- Incremental execution still works the same way
- File dependency tracking remains unchanged
- Error messages maintain similar quality
- Script execution order follows same topological sort
- Output file creation patterns identical
- Fine-grained dependencies via `file_in()` work as before

## Breaking Changes

The following changes require user action:

### 1. New Generated Files

**`_targets.R`** is now generated automatically:
- Created by `run()` and `status()`
- Should be added to `.gitignore`
- Regenerated on each run to reflect current pipeline structure

**`_targets/`** directory stores targets metadata:
- Created by targets package
- Contains execution metadata and caching information
- Should be added to `.gitignore`

**Recommended `.gitignore` additions:**
```gitignore
_targets.R
_targets/
```

### 2. Execution Backend Change

Scripts are now executed using `callr::r()` instead of direct `source()`:
- Provides better process isolation
- Same environment variables and working directory
- Slightly different error stack traces

### 3. Dependencies

The `targets` package is now required:
- Added to `Imports` in `DESCRIPTION`
- Must be installed for bakepipe to work
- Install with: `install.packages("targets")`

## Migration Guide

### For Existing Projects

1. **Add to `.gitignore`:**
   ```bash
   echo "_targets.R" >> .gitignore
   echo "_targets/" >> .gitignore
   ```

2. **Clean existing metadata** (if migrating from old bakepipe):
   ```r
   # Remove old bakepipe state files if they exist
   if (file.exists(".bakepipe.state")) {
     file.remove(".bakepipe.state")
   }
   ```

3. **Run pipeline as usual:**
   ```r
   library(bakepipe)
   run()  # Will generate _targets.R automatically
   ```

### For New Projects

No changes needed! Use bakepipe exactly as documented:

```r
library(bakepipe)

# In your R script (e.g., process.R):
data <- read.csv(external_in("input.csv"))
data$doubled <- data$x * 2
write.csv(data, file_out("output.csv"), row.names = FALSE)

# Run the pipeline:
run()
```

## Advantages of Targets Backend

1. **Better Performance**: Targets uses efficient caching and dependency tracking
2. **More Reliable**: Battle-tested execution engine used by many R projects
3. **Better Debugging**: Targets provides detailed execution logs and metadata
4. **Process Isolation**: Scripts run in isolated R processes via `callr`
5. **Future Features**: Opens door to parallel execution and cloud backends

## Testing

All tests include `skip_if_not_installed("targets")` guards for graceful degradation during development.

Test coverage includes:
- Unit tests for each modified function
- Integration tests for complete workflows
- Backward compatibility verification
- Fine-grained dependency testing

## Implementation Details

### Generated `_targets.R` Structure

The generated file creates targets for:
- Script file targets (monitored for changes)
- External input file targets (via `external_in()`)
- Script execution targets (run via `callr::r()`)
- Output file targets (produced by scripts)

### Dependency Resolution

Fine-grained dependencies are preserved:
- `file_in("specific_output.csv")` only depends on that specific file
- Not all outputs from the producing script
- Minimizes unnecessary reruns

### Target Naming

File paths are converted to valid R identifiers:
- `process.R` → `process_r` (script target)
- `process.R` → `run_process_r` (execution target)
- `output.csv` → `out_output_csv` (output target)

## Rollback

If you need to roll back to the previous version:

```bash
git checkout <previous-commit>
```

The old bakepipe version used internal state tracking in `.bakepipe.state`.

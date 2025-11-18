# Implementation Plan: Targets Backend with File Vector Returns

**Updated Design**: Each script target returns a vector of output files, so manual edits to any output invalidate the target.

## Phase 1: Core Target Generation

### 1.1 Enhance `parse()` to track output files
- Modify existing `parse_script()` to collect all `file_out()` calls
- Store as `outputs` vector in dependency structure
- Test: Verify `parse()` correctly extracts multiple outputs

### 1.2 Create `generate_targets_file()`
- Input: Parsed dependencies
- Output: `_targets.R` with vector-returning targets
- For each script, generate:
  ```r
  tar_target(
    output_<script_name>,
    {
      <dependencies>
      source("<script>")
      c(<outputs>)  # Vector of files
    },
    format = "file"
  )
  ```
- Test: Generated `_targets.R` is valid and runnable

### 1.3 Update `run()` wrapper
- Call `generate_targets_file()` before each run
- Call `targets::tar_make()`
- Handle targets output/errors
- Test: Simple pipeline runs end-to-end

## Phase 2: Status & Clean

### 2.1 Update `status()` wrapper
- Call `generate_targets_file()` before checking
- Call `targets::tar_outdated()` to get outdated targets
- Map target names back to script names for display
- Pretty-print human-readable status
- Test: Status correctly reflects dirty/clean state

### 2.2 Update `clean()` wrapper
- Call `targets::tar_destroy()` to remove cache
- Test: Clean removes all outputs and cache

## Phase 3: Validation & Testing

### 3.1 Integration tests
- Multi-script pipelines with dependencies
- Manual file edits trigger rerun
- No-op runs skip everything
- Partial updates work correctly

### 3.2 Edge cases
- Scripts with no outputs
- Scripts with no inputs
- Circular dependency detection (should error)
- Missing external_in() files

### 3.3 Performance baseline
- Generate targets for 10, 50, 100 scripts
- Time status checks
- Verify no significant slowdown

## Phase 4: Migration & Examples

### 4.1 Sample project
- Create complete example demonstrating:
  - Multiple scripts with dependencies
  - Fine-grained dependency tracking
  - Manual file edits detected
  - targets visualization (tar_visnetwork)

### 4.2 Documentation updates
- README: Explain targets backend
- Function docs: Note targets is used
- Migration guide: From old bakepipe to new

## Implementation Checklist

- [ ] Phase 1.1: Enhance parse() for outputs
- [ ] Phase 1.2: Create generate_targets_file()
- [ ] Phase 1.3: Update run() wrapper
- [ ] Phase 2.1: Update status() wrapper
- [ ] Phase 2.2: Update clean() wrapper
- [ ] Phase 3.1: Integration tests
- [ ] Phase 3.2: Edge case tests
- [ ] Phase 3.3: Performance baseline
- [ ] Phase 4.1: Sample project
- [ ] Phase 4.2: Documentation

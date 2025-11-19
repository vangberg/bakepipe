# Write pipeline state to disk

Writes the current state of all files in the pipeline to a CSV file.
This includes scripts and all their input/output files with their
current checksums and timestamps.

## Usage

``` r
write_state(state_file, parse_data)
```

## Arguments

- state_file:

  Path to the state file to write (typically ".bakepipe.state")

- parse_data:

  List from parse() function with 'scripts', 'inputs', 'outputs'

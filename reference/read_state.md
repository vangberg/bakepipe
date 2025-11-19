# Read pipeline state from disk

Reads the .bakepipe.state file and computes current checksums to
determine which files are stale. A file is considered stale if its
current checksum differs from the stored checksum.

## Usage

``` r
read_state(state_file)
```

## Arguments

- state_file:

  Path to the state file (typically ".bakepipe.state")

## Value

Data frame with columns 'file' and 'stale' (logical)

# Build file nodes from graph structure and parse data

Creates nodes for all files with types determined from parse data:

- Scripts: script file names

- Inputs: files only in inputs (external inputs)

- Outputs: files in outputs (includes intermediates)

## Usage

``` r
build_file_nodes(parse_data, edges, state_obj = NULL)
```

## Arguments

- parse_data:

  Parse result with scripts, inputs, outputs

- edges:

  Data frame with 'from' and 'to' columns

- state_obj:

  Optional state object from read_state()

## Value

Data frame with 'file', 'type', and 'stale' columns

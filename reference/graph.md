# Create dependency graph from parsed script data

Builds a Directed Acyclic Graph (DAG) where all files are nodes. Node
types are determined from parse data:

- Inputs: files only in parse_data\$inputs (external inputs)

- Outputs: files in parse_data\$outputs (includes intermediates)

- Scripts: script file names

## Usage

``` r
graph(parse_data, state_obj = NULL)
```

## Arguments

- parse_data:

  List from parse() function with 'scripts', 'inputs', 'outputs'

- state_obj:

  Optional. Data frame from read_state() function with 'file' and
  'stale' columns. If provided, will mark nodes as stale/fresh.

## Value

List containing:

- nodes: Data frame with 'file', 'type', and 'stale' columns

- edges: Data frame with 'from' and 'to' columns

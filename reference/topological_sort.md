# Topological sort of the dependency graph

Returns files in topological order using Kahn's algorithm. Files will
appear in an order where all dependencies come before the file. Only
returns scripts in execution order when filtering by type.

## Usage

``` r
topological_sort(graph_obj, scripts_only = FALSE)
```

## Arguments

- graph_obj:

  Graph object from graph() function

- scripts_only:

  Logical. If TRUE, returns only script nodes in order

## Value

Character vector of file names in topological order

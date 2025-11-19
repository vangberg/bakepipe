# Find all descendants of a file in the dependency graph

Returns all files that depend on the given file by following the
directed edges. Useful for marking files as stale when an upstream
dependency changes.

## Usage

``` r
find_descendants(graph_obj, node, scripts_only = FALSE)
```

## Arguments

- graph_obj:

  Graph object from graph() function

- node:

  Starting file to find descendants from

- scripts_only:

  Logical. If TRUE, returns only script descendants

## Value

Character vector of all descendant file names

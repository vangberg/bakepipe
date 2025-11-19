# Propagate staleness through the dependency graph

Implements the logic:

- If node is stale AND output: mark parent + descendants as stale

- If node is stale otherwise: mark self + descendants as stale

## Usage

``` r
propagate_staleness(graph_obj)
```

## Arguments

- graph_obj:

  Graph object with nodes and edges data frames

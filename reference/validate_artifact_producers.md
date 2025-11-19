# Validate that each artifact has exactly one producer

Ensures that every artifact (file referenced by file_in()) has exactly
one producer. This means each artifact should have exactly one script
that produces it - not zero (orphaned) and not more than one (multiple
producers).

## Usage

``` r
validate_artifact_producers(graph_obj, parse_data)
```

## Arguments

- graph_obj:

  Graph object from graph() function

- parse_data:

  Parse result with scripts, inputs, outputs

# Convert file path to valid R target name

Converts a file path to a valid R identifier for use as a target name.
Special characters are replaced with underscores.

## Usage

``` r
path_to_target_name(path, prefix = "")
```

## Arguments

- path:

  File path

- prefix:

  Prefix to add (e.g., "script", "run", or "")

## Value

Valid R identifier

# Extract file_in, file_out, or external_in calls from an expression

Extract file_in, file_out, or external_in calls from an expression

## Usage

``` r
extract_file_calls(expr, func_name)
```

## Arguments

- expr:

  Parsed R expression

- func_name:

  Either "file_in", "file_out", or "external_in"

## Value

Character vector of file paths found

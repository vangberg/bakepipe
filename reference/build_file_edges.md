# Build edges between files for the new graph structure

Creates edges directly between files: input -\> script -\> output This
creates a linear chain for each script's file dependencies.

## Usage

``` r
build_file_edges(scripts_data)
```

## Arguments

- scripts_data:

  Named list of scripts from parse()\$scripts

## Value

Data frame with 'from' and 'to' columns

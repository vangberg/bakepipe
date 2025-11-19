# Parse R scripts to extract file dependencies

Finds all R scripts in the project and parses them to detect file_in()
and file_out() calls. Only string literals are supported as arguments to
these functions.

## Usage

``` r
parse()
```

## Value

List with four elements:

- scripts: Named list where each element represents a script with
  'inputs', 'outputs', and 'externals'

- inputs: Character vector of all files used as inputs across all
  scripts

- outputs: Character vector of all files produced as outputs across all
  scripts

- externals: Character vector of all external files referenced across
  all scripts

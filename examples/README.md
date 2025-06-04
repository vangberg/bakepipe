# Bakepipe Examples

This directory contains example scripts demonstrating the usage of the `bakepipe` library.

## Files

- `data.csv`: Sample raw data.
- `analysis.R`: Script that takes `data.csv` as input, performs an analysis, and outputs `analysis.csv`.
- `plots.R`: Script that takes `analysis.csv` as input and generates `plot1.png`.

## Running the Example

1.  **Ensure Bakepipe is accessible**:
    *   If you have built and installed the `bakepipe` package, you can load it using `library(bakepipe)`.
    *   If you are running from the source repository, you can use `devtools::load_all()` from the package root directory.
    *   The scripts also have a fallback to try and `source()` the `bakepipe.R` file directly if run from the `examples` directory or the project root, but this is mainly for quick ad-hoc testing.

2.  **Navigate to this directory**:
    Open your R console and set your working directory to this `examples` folder:
    ```R
    setwd("path/to/bakepipe/examples")
    ```

3.  **Run the pipeline**:
    Execute the `run()` command from `bakepipe`:
    ```R
    # If bakepipe is loaded via library() or devtools::load_all()
    bakepipe::run()

    # Or, if you sourced bakepipe.R directly and it's in the global environment:
    # run()
    ```
    This will:
    - Detect `analysis.R` and `plots.R`.
    - Determine that `analysis.R` must run before `plots.R` because `plots.R` uses `analysis.csv` which is produced by `analysis.R`.
    - Execute the scripts in the correct order.
    - You should see messages indicating which scripts are run and which files are generated.

4.  **Check the outputs**:
    - `analysis.csv`: Will contain the processed data.
    - `plot1.png`: Will be the generated plot.

5.  **Show dependencies**:
    You can also visualize the dependencies:
    ```R
    bakepipe::show()
    ```

# Bakepipe Sample Project

This sample project demonstrates how to use bakepipe to manage a simple data analysis pipeline with three scripts that process data sequentially.

## Project Structure

```
sample-project/
├── .Rprofile                 # Automatic bakepipe setup
├── _bakepipe.R               # Project root marker
├── raw_data.csv              # Initial dataset
├── 01_clean_data.R           # Data cleaning script
├── 02_analyze_data.R         # Data analysis script
└── 03_generate_report.R      # Report generation script
```

## Pipeline Flow

1. **01_clean_data.R**: Reads `raw_data.csv` → Creates `cleaned_data.csv`
2. **02_analyze_data.R**: Reads `cleaned_data.csv` → Creates `analysis_results.rds`
3. **03_generate_report.R**: Reads `analysis_results.rds` → Creates `report.txt`

## Loading and Testing

### Option 1: Using devtools::load_all() (Recommended)

From the bakepipe root directory, start R and run:

```r
# Load the bakepipe package in development mode
devtools::load_all()

# Change to the sample project directory
setwd("sample-project")

# Test the pipeline functions
status()  # View pipeline structure
run()     # Execute the pipeline
```

### Option 2: Using the .Rprofile (Simplest)

Just navigate to the sample-project directory and start R:

```bash
cd sample-project
R
```

The `.Rprofile` will automatically load bakepipe and set up the environment.

## Manual Testing

You can also run individual scripts manually to test bakepipe functions:

```r
# Load bakepipe
devtools::load_all()

# Change to sample project
setwd("sample-project")

# Run individual scripts
source("01_clean_data.R")
source("02_analyze_data.R") 
source("03_generate_report.R")

# Check generated files
list.files(pattern = "cleaned")
list.files(pattern = "\\.(rds|txt)$")
```

## Expected Output

After running the pipeline, you should see:

- `cleaned_data.csv` - Cleaned dataset with age groups
- `analysis_results.rds` - R data structure with analysis results
- `report.txt` - Human-readable summary report
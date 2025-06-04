# analysis.R
# Ensure bakepipe is loaded, assuming it's installed or devtools::load_all() has been run
# If running standalone, you might need library(bakepipe)
# If using devtools, it should be available.
# For testing directly, one might use source("../R/bakepipe.R") if not installed.

# When the package is loaded (e.g. by library(bakepipe) or devtools::load_all()),
# the functions should be available.

# Check if functions are available, if not, try to source them (for ad-hoc running)
if (!exists("file_in", mode="function")) {
  # This is a fallback for running example directly without package being fully loaded
  # In a real scenario, library(bakepipe) or devtools::load_all() would handle this.
  if(file.exists("../R/bakepipe.R")) { # Path relative to examples/
    source("../R/bakepipe.R")
    message("Sourced bakepipe.R for direct example run.")
  } else if (file.exists("R/bakepipe.R")) { # Path relative to project root
     source("R/bakepipe.R")
     message("Sourced bakepipe.R for direct example run from project root.")
  } else {
    stop("bakepipe functions not found. Please load the package or ensure R/bakepipe.R is accessible.")
  }
}

data_path <- file.path("data.csv") # Assuming data.csv is in the same dir as the script, or run() is called from examples/
analysis_path <- file.path("analysis.csv")

message("analysis.R: Reading from ", data_path)
data_in <- read.csv(file_in(data_path)) # file_in marks dependency

# Simple analysis: count occurrences of categories
stats <- as.data.frame(table(data_in$category))
colnames(stats) <- c("category", "count")

message("analysis.R: Writing stats to ", analysis_path)
write.csv(stats, file_out(analysis_path), row.names = FALSE) # file_out marks output

message("analysis.R: Done.")

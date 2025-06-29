% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/clean.R
\name{clean}
\alias{clean}
\title{Remove all artifacts generated by scripts}
\usage{
clean(verbose = TRUE)
}
\arguments{
\item{verbose}{Logical. If TRUE (default), prints progress messages to console.}
}
\value{
Character vector of file paths that were actually removed
}
\description{
Removes all output files generated by scripts in the pipeline, including
intermediate files. This provides a complete clean of generated artifacts.
The pipeline can be regenerated by running run() again.
}
\examples{
# Copy sample project to temp directory
temp_dir <- tempfile()
dir.create(temp_dir)
sample_proj <- system.file("extdata", "sample-project", package = "bakepipe")
file.copy(sample_proj, temp_dir, recursive = TRUE)

# Change to the sample project directory
old_wd <- getwd()
setwd(file.path(temp_dir, "sample-project"))

# Run the pipeline first to create output files
run(verbose = FALSE)

# Now clean up the generated files
removed_files <- clean()
print(removed_files)

# Restore working directory and clean up
setwd(old_wd)
unlink(temp_dir, recursive = TRUE)
}

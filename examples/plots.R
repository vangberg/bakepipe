# plots.R
# Ensure bakepipe is loaded (see comments in analysis.R)
if (!exists("file_in", mode="function")) {
  if(file.exists("../R/bakepipe.R")) {
    source("../R/bakepipe.R")
    message("Sourced bakepipe.R for direct example run.")
  } else if (file.exists("R/bakepipe.R")) {
     source("R/bakepipe.R")
     message("Sourced bakepipe.R for direct example run from project root.")
  } else {
    stop("bakepipe functions not found. Please load the package or ensure R/bakepipe.R is accessible.")
  }
}

# ggplot2 is required for this script.
# In a real package, this would be in Imports in DESCRIPTION.
# For the example, users must have it installed.
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 package is required for plots.R. Please install it.", call. = FALSE)
}

analysis_path <- file.path("analysis.csv") # Assuming analysis.csv is in the same dir or run() is called from examples/
plot1_path <- file.path("plot1.png")
# The README mentions plot2.png, but the example ggplot code only creates one plot.
# For simplicity, we'll stick to one plot unless specific instructions for plot2 are given.
# Let's assume plot2.png was a typo or for a more complex example. We'll make one plot.

message("plots.R: Reading from ", analysis_path)
data_for_plot <- read.csv(file_in(analysis_path)) # file_in marks dependency

message("plots.R: Creating plot and saving to ", plot1_path)
p <- ggplot2::ggplot(data_for_plot, ggplot2::aes(x = category, y = count)) +
     ggplot2::geom_bar(stat = "identity") +
     ggplot2::ggtitle("Category Counts")

ggplot2::ggsave(file_out(plot1_path), plot = p, width = 6, height = 4) # file_out marks output

message("plots.R: Done.")

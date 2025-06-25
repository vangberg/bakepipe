library(bakepipe)

# Read input data
data <- read.csv(external_in("input.csv"))

# Process data
data$doubled <- data$value * 2

# Write output
write.csv(data, file_out("processed.csv"), row.names = FALSE)
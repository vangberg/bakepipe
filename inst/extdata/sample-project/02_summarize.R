library(bakepipe)

# Read processed data
data <- read.csv(file_in("processed.csv"))

# Create summary
summary_data <- data.frame(
  total = sum(data$doubled),
  count = nrow(data)
)

# Write summary
write.csv(summary_data, file_out("summary.csv"), row.names = FALSE)
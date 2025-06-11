library(bakepipe)

cleaned_data <- read.csv(file_in("cleaned_data.csv"))

age_summary <- aggregate(age ~ age_group, data = cleaned_data, FUN = function(x) c(mean = mean(x), count = length(x)))
city_counts <- table(cleaned_data$city)

analysis_results <- list(
  age_summary = age_summary,
  city_counts = city_counts,
  total_records = nrow(cleaned_data)
)

saveRDS(analysis_results, file_out("analysis_results.rds"))

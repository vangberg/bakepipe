library(bakepipe)

raw_data <- read.csv(external_in("raw_data.csv"))

cleaned_data <- raw_data[!is.na(raw_data$age), ]
cleaned_data$age_group <- ifelse(cleaned_data$age < 30, "young", "older")

# Output both cleaned data and data dictionary
write.csv(cleaned_data, file_out("cleaned_data.csv"), row.names = FALSE)
write.csv(
  data.frame(column = names(cleaned_data), type = sapply(cleaned_data, class)),
  file_out("data_dictionary.csv"),
  row.names = FALSE
)

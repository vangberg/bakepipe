library(bakepipe)

analysis_results <- readRDS(file_in("analysis_results.rds"))

report_content <- paste(
  "Data Analysis Report",
  "===================",
  "",
  paste("Total records processed:", analysis_results$total_records),
  "",
  "Age Group Summary:",
  paste("- Young (< 30):", analysis_results$age_summary[analysis_results$age_summary[,1] == "young", 2][1], "people, avg age:", round(analysis_results$age_summary[analysis_results$age_summary[,1] == "young", 2][2], 1)),
  paste("- Older (>= 30):", analysis_results$age_summary[analysis_results$age_summary[,1] == "older", 2][1], "people, avg age:", round(analysis_results$age_summary[analysis_results$age_summary[,1] == "older", 2][2], 1)),
  "",
  "City Distribution:",
  paste("-", names(analysis_results$city_counts), ":", analysis_results$city_counts, collapse = "\n"),
  "",
  paste("Report generated on:", Sys.Date()),
  sep = "\n"
)

writeLines(report_content, file_out("report.txt"))
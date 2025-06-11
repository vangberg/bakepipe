#' Show pipeline status
#'
#' Display a textual representation of the input/output relationships
#' between files in the console
#'
#' @export
status <- function() {
  # Parse the pipeline to get script dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data) == 0) {
    cat("No R scripts found in the pipeline.\n")
    return(invisible(NULL))
  }

  # Prepare data for table display
  scripts <- names(pipeline_data)
  inputs_list <- lapply(pipeline_data, function(x) {
    paste(x$inputs, collapse = ", ")
  })
  outputs_list <- lapply(pipeline_data, function(x) {
    paste(x$outputs, collapse = ", ")
  })

  # Convert to character vectors
  inputs_vec <- sapply(inputs_list, function(x) if (x == "") "(none)" else x)
  outputs_vec <- sapply(outputs_list, function(x) if (x == "") "(none)" else x)

  # Create data frame for easier formatting
  df <- data.frame(
    Script = scripts,
    Inputs = inputs_vec,
    Outputs = outputs_vec,
    stringsAsFactors = FALSE
  )

  # Calculate column widths for proper alignment
  col_widths <- c(
    max(nchar(df$Script), nchar("Script")),
    max(nchar(df$Inputs), nchar("Inputs")),
    max(nchar(df$Outputs), nchar("Outputs"))
  )

  # Print header
  cat(sprintf("%-*s | %-*s | %-*s\n",
              col_widths[1], "Script",
              col_widths[2], "Inputs",
              col_widths[3], "Outputs"))

  # Print separator line
  cat(paste(rep("-", col_widths[1]), collapse = ""), "-|-",
      paste(rep("-", col_widths[2]), collapse = ""), "-|-",
      paste(rep("-", col_widths[3]), collapse = ""), "\n")

  # Print each row
  for (i in seq_len(nrow(df))) {
    cat(sprintf("%-*s | %-*s | %-*s\n",
                col_widths[1], df$Script[i],
                col_widths[2], df$Inputs[i],
                col_widths[3], df$Outputs[i]))
  }

  invisible(NULL)
}

#' Show pipeline status
#'
#' Display a textual representation of the input/output relationships
#' between scripts in the pipeline, including their current state (fresh/stale)
#'
#' @export
status <- function() {
  # Parse the pipeline to get script dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    cat("No R scripts found in the pipeline.\n")
    return(invisible(NULL))
  }

  # Display header
  cat("Pipeline Status\n")
  cat("===============\n\n")

  # Display Scripts table with state information
  cat("Scripts:\n")
  display_scripts_table(pipeline_data)

  invisible(NULL)
}

#' Display the scripts table
#' @param pipeline_data Parsed pipeline data
display_scripts_table <- function(pipeline_data) {
  # Read state information
  state_obj <- read_state(file.path(root(), ".bakepipe.state"))

  # Create graph with state information
  graph_obj <- graph(pipeline_data, state_obj)
  topo_order <- topological_sort(graph_obj, scripts_only = TRUE)

  # Scripts are already in the correct order
  scripts <- topo_order

  # Prepare data for table display
  inputs_list <- lapply(scripts, function(script) {
    paste(pipeline_data$scripts[[script]]$inputs, collapse = ", ")
  })
  outputs_list <- lapply(scripts, function(script) {
    paste(pipeline_data$scripts[[script]]$outputs, collapse = ", ")
  })

  # Determine state for each script
  state_list <- lapply(scripts, function(script) {
    script_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == script]
    if (length(script_stale) > 0 && script_stale) {
      "Stale"
    } else {
      "Fresh"
    }
  })

  # Convert to character vectors
  inputs_vec <- sapply(inputs_list, function(x) if (x == "") "(none)" else x)
  outputs_vec <- sapply(outputs_list, function(x) if (x == "") "(none)" else x)
  state_vec <- unlist(state_list)

  # Create data frame for easier formatting
  df <- data.frame(
    Script = scripts,
    Inputs = inputs_vec,
    Outputs = outputs_vec,
    State = state_vec,
    stringsAsFactors = FALSE
  )

  # Calculate column widths for proper alignment
  col_widths <- c(
    max(nchar(df$Script), nchar("Script")),
    max(nchar(df$Inputs), nchar("Inputs")),
    max(nchar(df$Outputs), nchar("Outputs")),
    max(nchar(df$State), nchar("State"))
  )

  # Print header
  cat(sprintf("%-*s | %-*s | %-*s | %-*s\n",
              col_widths[1], "Script",
              col_widths[2], "Inputs",
              col_widths[3], "Outputs",
              col_widths[4], "State"))

  # Print separator line with proper alignment
  cat(sprintf("%s-+-%s-+-%s-+-%s\n",
              paste(rep("-", col_widths[1]), collapse = ""),
              paste(rep("-", col_widths[2]), collapse = ""),
              paste(rep("-", col_widths[3]), collapse = ""),
              paste(rep("-", col_widths[4]), collapse = "")))

  # Print each row
  for (i in seq_len(nrow(df))) {
    cat(sprintf("%-*s | %-*s | %-*s | %-*s\n",
                col_widths[1], df$Script[i],
                col_widths[2], df$Inputs[i],
                col_widths[3], df$Outputs[i],
                col_widths[4], df$State[i]))
  }
}

#' Show pipeline status
#'
#' Display a textual representation of the input/output relationships
#' between files and artifacts in the console
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

  # Display header
  cat("Pipeline Status\n")
  cat("===============\n\n")

  # Display Scripts table
  cat("Scripts:\n")
  display_scripts_table(pipeline_data)
  
  cat("\n")
  
  # Display Artifacts table
  cat("Artifacts:\n")
  display_artifacts_table(pipeline_data)

  invisible(NULL)
}

#' Display the scripts table
#' @param pipeline_data Parsed pipeline data
display_scripts_table <- function(pipeline_data) {
  # Create graph and get topological order
  graph_obj <- graph(pipeline_data)
  topo_order <- topological_sort(graph_obj)
  
  # Filter to get only scripts in topological order
  scripts <- intersect(topo_order, names(pipeline_data))
  
  # Prepare data for table display
  inputs_list <- lapply(scripts, function(script) {
    paste(pipeline_data[[script]]$inputs, collapse = ", ")
  })
  outputs_list <- lapply(scripts, function(script) {
    paste(pipeline_data[[script]]$outputs, collapse = ", ")
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

  # Print separator line with proper alignment
  cat(sprintf("%s-+-%s-+-%s\n",
              paste(rep("-", col_widths[1]), collapse = ""),
              paste(rep("-", col_widths[2]), collapse = ""),
              paste(rep("-", col_widths[3]), collapse = "")))

  # Print each row
  for (i in seq_len(nrow(df))) {
    cat(sprintf("%-*s | %-*s | %-*s\n",
                col_widths[1], df$Script[i],
                col_widths[2], df$Inputs[i],
                col_widths[3], df$Outputs[i]))
  }
}

#' Display the artifacts table
#' @param pipeline_data Parsed pipeline data
display_artifacts_table <- function(pipeline_data) {
  # Create graph and get topological order
  graph_obj <- graph(pipeline_data)
  topo_order <- topological_sort(graph_obj)
  
  # Collect all unique artifacts from inputs and outputs
  all_artifacts <- character(0)
  
  for (script_data in pipeline_data) {
    all_artifacts <- c(all_artifacts, script_data$inputs, script_data$outputs)
  }
  
  # Get unique artifacts in topological order
  unique_artifacts <- intersect(topo_order, unique(all_artifacts))
  
  if (length(unique_artifacts) == 0) {
    cat("(No artifacts found)\n")
    return(invisible(NULL))
  }
  
  # Check file existence for each artifact
  artifact_status <- sapply(unique_artifacts, function(artifact) {
    if (file.exists(artifact)) {
      "✓ Present"
    } else {
      "✗ Missing"
    }
  })
  
  # Create data frame for artifacts table
  artifacts_df <- data.frame(
    Artifact = unique_artifacts,
    Status = artifact_status,
    stringsAsFactors = FALSE
  )
  
  # Calculate column widths
  col_widths <- c(
    max(nchar(artifacts_df$Artifact), nchar("File")),
    max(nchar(artifacts_df$Status), nchar("Status"))
  )

  # Print header
  cat(sprintf("%-*s | %-*s\n",
              col_widths[1], "File",
              col_widths[2], "Status"))

  # Print separator line with proper alignment
  cat(sprintf("%s-+-%s\n",
              paste(rep("-", col_widths[1]), collapse = ""),
              paste(rep("-", col_widths[2]), collapse = "")))

  # Print each row
  for (i in seq_len(nrow(artifacts_df))) {
    cat(sprintf("%-*s | %-*s\n",
                col_widths[1], artifacts_df$Artifact[i],
                col_widths[2], artifacts_df$Status[i]))
  }

  # Add summary
  present_count <- sum(grepl("Present", artifacts_df$Status))
  missing_count <- sum(grepl("Missing", artifacts_df$Status))
  total_count <- nrow(artifacts_df)

  cat(sprintf("\n%d files total: %d present, %d missing\n",
              total_count, present_count, missing_count))
}

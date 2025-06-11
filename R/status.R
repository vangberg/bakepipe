#' Show pipeline status
#'
#' Display a textual representation of the input/output relationships
#' between files and artifacts in the console, including Fresh/Stale status
#' for incremental builds.
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

  # Get cache information for stale/fresh status
  cache_obj <- read_cache()

  # Display header
  cat("Pipeline Status\n")
  cat("===============\n\n")

  # Display Scripts table
  cat("Scripts:\n")
  display_scripts_table(pipeline_data, cache_obj)
  
  cat("\n")
  
  # Display Artifacts table
  cat("Artifacts:\n")
  display_artifacts_table(pipeline_data, cache_obj)

  invisible(NULL)
}

#' Display the scripts table
#' @param pipeline_data Parsed pipeline data
#' @param cache_obj Cache object for stale/fresh status
display_scripts_table <- function(pipeline_data, cache_obj = NULL) {
  # Create graph and get topological order
  graph_obj <- graph(pipeline_data, cache_obj)
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

  # Determine cache status for each script
  cache_status <- sapply(scripts, function(script) {
    if (!is.null(cache_obj) && script %in% names(cache_obj)) {
      if ("stale_nodes" %in% names(graph_obj) && script %in% graph_obj$stale_nodes) {
        "Stale"
      } else {
        "Fresh"
      }
    } else {
      "Unknown"
    }
  })

  # Create data frame for easier formatting
  df <- data.frame(
    Script = scripts,
    Inputs = inputs_vec,
    Outputs = outputs_vec,
    Status = cache_status,
    stringsAsFactors = FALSE
  )

  # Calculate column widths for proper alignment
  col_widths <- c(
    max(nchar(df$Script), nchar("Script")),
    max(nchar(df$Inputs), nchar("Inputs")),
    max(nchar(df$Outputs), nchar("Outputs")),
    max(nchar(df$Status), nchar("Status"))
  )

  # Print header
  cat(sprintf("%-*s | %-*s | %-*s | %-*s\n",
              col_widths[1], "Script",
              col_widths[2], "Inputs",
              col_widths[3], "Outputs",
              col_widths[4], "Status"))

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
                col_widths[4], df$Status[i]))
  }
}

#' Display the artifacts table
#' @param pipeline_data Parsed pipeline data
#' @param cache_obj Cache object for stale/fresh status
display_artifacts_table <- function(pipeline_data, cache_obj = NULL) {
  # Create graph and get topological order
  graph_obj <- graph(pipeline_data, cache_obj)
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
  
  # Determine cache status for each artifact
  cache_status <- sapply(unique_artifacts, function(artifact) {
    if (!is.null(cache_obj) && artifact %in% names(cache_obj)) {
      if ("stale_nodes" %in% names(graph_obj) && artifact %in% graph_obj$stale_nodes) {
        "Stale"
      } else {
        "Fresh"
      }
    } else {
      "Unknown"
    }
  })
  
  # Create data frame for artifacts table
  artifacts_df <- data.frame(
    Artifact = unique_artifacts,
    Status = artifact_status,
    Cache = cache_status,
    stringsAsFactors = FALSE
  )
  
  # Calculate column widths
  col_widths <- c(
    max(nchar(artifacts_df$Artifact), nchar("File")),
    max(nchar(artifacts_df$Status), nchar("Status")),
    max(nchar(artifacts_df$Cache), nchar("Cache"))
  )

  # Print header
  cat(sprintf("%-*s | %-*s | %-*s\n",
              col_widths[1], "File",
              col_widths[2], "Status",
              col_widths[3], "Cache"))

  # Print separator line with proper alignment
  cat(sprintf("%s-+-%s-+-%s\n",
              paste(rep("-", col_widths[1]), collapse = ""),
              paste(rep("-", col_widths[2]), collapse = ""),
              paste(rep("-", col_widths[3]), collapse = "")))

  # Print each row
  for (i in seq_len(nrow(artifacts_df))) {
    cat(sprintf("%-*s | %-*s | %-*s\n",
                col_widths[1], artifacts_df$Artifact[i],
                col_widths[2], artifacts_df$Status[i],
                col_widths[3], artifacts_df$Cache[i]))
  }

  # Add summary
  present_count <- sum(grepl("Present", artifacts_df$Status))
  missing_count <- sum(grepl("Missing", artifacts_df$Status))
  fresh_count <- sum(artifacts_df$Cache == "Fresh")
  stale_count <- sum(artifacts_df$Cache == "Stale")
  total_count <- nrow(artifacts_df)

  cat(sprintf("\n%d files total: %d present, %d missing | %d fresh, %d stale\n",
              total_count, present_count, missing_count, fresh_count, stale_count))
}

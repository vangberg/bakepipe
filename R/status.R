#' Show pipeline status
#'
#' Display a tree-style representation of the pipeline showing inputs,
#' scripts, and their outputs with Fresh/Stale status for incremental builds.
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

  # Get state information for stale/fresh status
  cache_obj <- read_state()
  graph_obj <- graph(pipeline_data, cache_obj)
  
  # Display tree-style status
  display_tree_status(pipeline_data, cache_obj, graph_obj)

  invisible(NULL)
}

#' Display tree-style pipeline status
#' @param pipeline_data Parsed pipeline data
#' @param cache_obj Cache object for stale/fresh status
#' @param graph_obj Graph object with dependency information
display_tree_status <- function(pipeline_data, cache_obj = NULL,
                                graph_obj = NULL) {
  # Get topological order
  topo_order <- topological_sort(graph_obj)
  scripts <- intersect(topo_order, names(pipeline_data))

  # Get status for files/scripts
  get_status <- function(item) {
    if (!is.null(cache_obj) && item %in% names(cache_obj)) {
      if ("stale_nodes" %in% names(graph_obj) &&
            item %in% graph_obj$stale_nodes) {
        "Stale"
      } else {
        "Fresh"
      }
    } else {
      "Unknown"
    }
  }

  # Find input files (files that are not outputs of any script)
  all_outputs <- character(0)
  for (script_data in pipeline_data) {
    all_outputs <- c(all_outputs, script_data$outputs)
  }

  all_inputs <- character(0)
  for (script_data in pipeline_data) {
    all_inputs <- c(all_inputs, script_data$inputs)
  }

  # Input files are those that are inputs but not outputs of any script
  input_files <- setdiff(unique(all_inputs), unique(all_outputs))

  # Calculate max width for alignment
  all_items <- c(input_files, scripts)
  for (script in scripts) {
    all_items <- c(all_items, pipeline_data[[script]]$outputs)
  }
  max_width <- max(nchar(all_items), na.rm = TRUE)
  output_max_width <- 0
  if (length(scripts) > 0) {
    for (script in scripts) {
      if (length(pipeline_data[[script]]$outputs) > 0) {
        output_widths <- nchar(paste0("├── ", pipeline_data[[script]]$outputs))
        output_max_width <- max(output_max_width, max(output_widths))
      }
    }
  }
  input_max_width <- 0
  if (length(input_files) > 0) {
    input_widths <- nchar(paste0("└── ", input_files))
    input_max_width <- max(input_widths)
  }
  total_max_width <- max(max_width, output_max_width, input_max_width)

  # Display Inputs section
  if (length(input_files) > 0) {
    cat("(Inputs)\n")
    for (i in seq_along(input_files)) {
      file <- input_files[i]
      status <- get_status(file)
      is_last <- i == length(input_files)
      prefix <- if (is_last) "└── " else "├── "
      line_content <- paste0(prefix, file)
      padding <- total_max_width - nchar(line_content) + 1
      cat(sprintf("%s%s%s(%s)\n", prefix, file,
                  paste(rep(" ", padding), collapse = ""), status))
    }
    cat("\n")
  }

  # Display Scripts & Their Outputs section
  if (length(scripts) > 0) {
    for (script in scripts) {
      script_status <- get_status(script)
      outputs <- pipeline_data[[script]]$outputs

      padding <- total_max_width - nchar(script) + 1
      cat(sprintf("%s%s(%s)\n", script,
                  paste(rep(" ", padding), collapse = ""), script_status))

      if (length(outputs) > 0) {
        for (i in seq_along(outputs)) {
          output <- outputs[i]
          output_status <- get_status(output)
          is_last <- i == length(outputs)
          prefix <- if (is_last) "└── " else "├── "
          line_content <- paste0(prefix, output)
          padding <- total_max_width - nchar(line_content) + 1
          cat(sprintf("%s%s%s(%s)\n", prefix, output,
                      paste(rep(" ", padding), collapse = ""), output_status))
        }
      }
    }
  }
}

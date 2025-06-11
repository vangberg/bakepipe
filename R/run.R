#' Run pipeline
#'
#' Execute all scripts in the pipeline graph in topological order
#'
#' @return Character vector of files that were created or updated
#' @export
run <- function() {
  # Parse scripts to get dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data) == 0) {
    return(character(0))
  }

  # Create dependency graph
  graph_obj <- graph(pipeline_data)

  # Get scripts in topological order
  topo_order <- topological_sort(graph_obj)

  # Filter to only script files (not artifacts)
  script_names <- names(pipeline_data)
  scripts_to_run <- topo_order[topo_order %in% script_names]

  # Track files created during execution
  created_files <- character(0)

  # Execute each script in order
  for (script_name in scripts_to_run) {
    # Get script info
    script_info <- pipeline_data[[script_name]]

    # Check if all input files exist
    for (input_file in script_info$inputs) {
      if (!file.exists(input_file)) {
        stop("Input file '", input_file, "' required by '", script_name,
             "' does not exist")
      }
    }

    # Store output files to track what gets created
    output_files <- script_info$outputs

    # Execute the script
    cat("Running script:", script_name, "\n")
    tryCatch({
      source(script_name, local = TRUE)
    }, error = function(e) {
      stop("Error executing script '", script_name, "': ", e$message)
    })

    # Check that expected output files were created
    for (output_file in output_files) {
      if (file.exists(output_file)) {
        created_files <- c(created_files, output_file)
      } else {
        warning("Script '", script_name, "' was expected to create '",
                output_file, "' but file does not exist")
      }
    }
  }

  # Return unique list of created files
  unique(created_files)
}
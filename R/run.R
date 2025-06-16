#' Run pipeline
#'
#' Execute scripts in the pipeline graph in topological order. Only runs
#' scripts that are stale (have changed or have stale dependencies) for
#' incremental execution.
#'
#' @return Character vector of files that were created or updated
#' @export
run <- function() {
  # Parse scripts to get dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    return(character(0))
  }

  # Read current state
  state_file <- file.path(root(), ".bakepipe.state")
  state_obj <- read_state(state_file)

  # Create dependency graph with state information
  graph_obj <- graph(pipeline_data, state_obj)

  # Get scripts in topological order
  topo_order <- topological_sort(graph_obj, scripts_only = TRUE)

  # All files in topo_order are already scripts
  script_names <- names(pipeline_data$scripts)
  all_scripts <- topo_order[topo_order %in% script_names]

  # Only run stale scripts for incremental execution
  # Get stale scripts from the nodes data frame
  stale_scripts <- graph_obj$nodes$file[graph_obj$nodes$stale]
  scripts_to_run <- all_scripts[all_scripts %in% stale_scripts]
  scripts_to_skip <- all_scripts[!all_scripts %in% stale_scripts]

  # Calculate max script name width for alignment
  max_width <- max(nchar(all_scripts))

  # Print messages about scripts being skipped
  for (script_name in scripts_to_skip) {
    cat(sprintf("%-*s : skipping (fresh)\n", max_width, script_name))
  }

  # Track files created during execution
  created_files <- character(0)

  # Execute each script in order
  for (script_name in scripts_to_run) {
    # Get script info
    script_info <- pipeline_data$scripts[[script_name]]

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
    cat(sprintf("%-*s : running\n", max_width, script_name))
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

  # Update state file after execution
  write_state(state_file, pipeline_data)

  # Return unique list of created files
  unique(created_files)
}
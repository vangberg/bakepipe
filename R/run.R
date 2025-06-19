#' Run pipeline
#'
#' Execute scripts in the pipeline graph in topological order. Only runs
#' scripts that are stale (have changed or have stale dependencies) for
#' incremental execution.
#'
#' @return Character vector of files that were created or updated
#' @examples
#' \dontrun{
#' # Execute the pipeline
#' created_files <- bakepipe::run()
#' 
#' # The function returns paths of files that were created or updated
#' print(created_files)
#' }
#' @export
run <- function() {
  # Parse scripts to get dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    cat("\n🥖 \033[1;36mBakepipe Pipeline\033[0m\n")
    cat("\033[33m   No scripts found in pipeline\033[0m\n\n")
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

  # Print header
  cat("\n🥖 \033[1;36mBakepipe Pipeline\033[0m\n")
  if (length(scripts_to_run) > 0) {
    cat(paste0("\033[32m   Running ", length(scripts_to_run), " script",
               if(length(scripts_to_run) > 1) "s" else "", "\033[0m\n"))
  }
  if (length(scripts_to_skip) > 0) {
    cat(paste0("\033[33m   Skipping ", length(scripts_to_skip), " fresh script",
               if(length(scripts_to_skip) > 1) "s" else "", "\033[0m\n"))
  }
  cat("\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(all_scripts))

  # Print messages about scripts being skipped
  for (script_name in scripts_to_skip) {
    cat(sprintf("\033[90m✓ %-*s \033[2m(fresh)\033[0m\n", max_width, script_name))
  }

  # Track files created during execution
  created_files <- character(0)
  script_times <- numeric(0)

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

    # Execute the script with timing
    start_time <- Sys.time()
    
    tryCatch({
      # Run script in isolated R process using callr
      result <- callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_name),
        show = FALSE,
        stderr = "2>&1"
      )
    }, error = function(e) {
      # Extract the actual error message from the callr error
      if (inherits(e, "callr_error") && !is.null(e$stderr)) {
        # Parse stderr to find the actual error message
        stderr_lines <- strsplit(e$stderr, "\n")[[1]]
        error_line <- stderr_lines[grepl("Error:", stderr_lines)]
        if (length(error_line) > 0) {
          actual_error <- sub(".*Error: ", "", error_line[1])
          stop("Error executing script '", script_name, "': ", actual_error)
        }
      }
      # Fallback to original error message
      stop("Error executing script '", script_name, "': ", e$message)
    })
    
    end_time <- Sys.time()
    elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
    script_times <- c(script_times, elapsed)
    names(script_times)[length(script_times)] <- script_name
    
    # Show completion with timing
    if (elapsed < 1) {
      time_str <- sprintf("%.0fms", elapsed * 1000)
    } else {
      time_str <- sprintf("%.1fs", elapsed)
    }
    cat(sprintf("\033[32m✓ %-*s \033[2m(%s)\033[0m\n", max_width, script_name, time_str))

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

  # Print summary
  if (length(scripts_to_run) > 0 || length(created_files) > 0) {
    cat("\n\033[1;36m📊 Summary\033[0m\n")
    
    if (length(scripts_to_run) > 0) {
      total_time <- sum(script_times)
      if (total_time < 1) {
        time_str <- sprintf("%.0fms", total_time * 1000)
      } else {
        time_str <- sprintf("%.1fs", total_time)
      }
      cat(sprintf("\033[32m   Executed %d script%s in %s\033[0m\n", 
                  length(scripts_to_run),
                  if(length(scripts_to_run) > 1) "s" else "",
                  time_str))
    }
    
    if (length(created_files) > 0) {
      cat(sprintf("\033[36m   Created/updated %d file%s:\033[0m\n", 
                  length(created_files),
                  if(length(created_files) > 1) "s" else ""))
      for (file in sort(unique(created_files))) {
        cat(sprintf("\033[2m     • %s\033[0m\n", file))
      }
    }
    cat("\n")
  } else {
    cat("\n\033[32m✨ All scripts are up to date!\033[0m\n\n")
  }

  # Update state file after execution
  write_state(state_file, pipeline_data)

  # Return unique list of created files
  unique(created_files)
}
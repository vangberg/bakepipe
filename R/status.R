#' Show pipeline status
#'
#' Display the current state of all scripts in the pipeline (fresh/stale)
#'
#' @param verbose Logical. If TRUE (default), prints status information to console.
#' @return NULL (invisibly). This function is called for its side effect of
#'   displaying pipeline status information to the console.
#' @examples
#' # Copy sample project to temp directory  
#' temp_dir <- tempfile()
#' dir.create(temp_dir)
#' sample_proj <- system.file("extdata", "sample-project", package = "bakepipe")
#' file.copy(sample_proj, temp_dir, recursive = TRUE)
#' 
#' # Change to the sample project directory
#' old_wd <- getwd()
#' setwd(file.path(temp_dir, "sample-project"))
#' 
#' # Display current pipeline status
#' status()
#' 
#' # This will show which scripts are fresh (up-to-date) 
#' # and which are stale (need to be re-run)
#' 
#' # Restore working directory and clean up
#' setwd(old_wd)
#' unlink(temp_dir, recursive = TRUE)
#' @export
status <- function(verbose = TRUE) {
  pipeline_data <- parse()

  if (length(pipeline_data$scripts) == 0) {
    if (verbose) {
      message("No scripts found")
    }
    return(invisible(NULL))
  }

  generate_targets_file()

  if (verbose) {
    display_scripts_table_targets(pipeline_data)
  }

  invisible(NULL)
}

#' Display the scripts table using targets backend
#' @param pipeline_data Parsed pipeline data
display_scripts_table_targets <- function(pipeline_data) {
  # Print header
  message("Bakepipe Status")
  message("")
  
  # Get outdated targets from targets package
  outdated <- tryCatch(
    {
      targets::tar_outdated(callr_function = NULL)
    },
    error = function(e) {
      # If targets hasn't run yet, all are outdated
      character(0)
    }
  )

  # Get script names in order they appear in pipeline_data
  script_names <- names(pipeline_data$scripts)
  
  # Create a map from output target names back to script names
  target_to_script <- setNames(script_names, sapply(script_names, function(s) {
    path_to_target_name(s, "output")
  }))

  # Determine state for each script based on output target
  state_vec <- character(length(script_names))
  for (i in seq_along(script_names)) {
    script <- script_names[i]
    # Convert script name to output target name
    target_name <- path_to_target_name(script, "output")

    # Check if this output target is outdated
    if (target_name %in% outdated) {
      state_vec[i] <- "stale"
    } else {
      state_vec[i] <- "fresh"
    }
  }

  # Count scripts by state
  fresh_count <- sum(state_vec == "fresh")
  stale_count <- sum(state_vec == "stale")

  # Display summary
  if (stale_count > 0) {
    message(sprintf("\033[32m%d fresh\033[0m, \033[33m%d stale\033[0m", fresh_count, stale_count))
  } else {
    message(sprintf("\033[32m✓ %d script%s up to date\033[0m", fresh_count, if (fresh_count != 1) "s" else ""))
  }
  message("")

  # Display each script with status
  for (i in seq_along(script_names)) {
    script <- script_names[i]
    state <- state_vec[i]
    script_info <- pipeline_data$scripts[[script]]
    
    if (state == "fresh") {
      message(sprintf("\033[32m✓\033[0m %s \033[32m(fresh)\033[0m", script))
    } else {
      message(sprintf("\033[33m!\033[0m %s \033[33m(stale)\033[0m", script))
    }
    
    # Show inputs, externals, outputs on separate lines if they exist
    if (length(script_info$inputs) > 0) {
      message(sprintf("    inputs: %s", paste(script_info$inputs, collapse = ", ")))
    }
    
    if (length(script_info$externals) > 0) {
      message(sprintf("    externals: %s", paste(script_info$externals, collapse = ", ")))
    }
    
    if (length(script_info$outputs) > 0) {
      message(sprintf("    outputs: %s", paste(script_info$outputs, collapse = ", ")))
    }
  }
}

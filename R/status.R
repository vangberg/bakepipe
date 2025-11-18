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
  # Parse the pipeline to get script dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    if (verbose) {
      message("\n[STATUS] \033[1;36mBakepipe Status\033[0m")
      message("\033[33m   No scripts found in pipeline\033[0m\n")
    }
    return(invisible(NULL))
  }

  # Generate _targets.R file
  generate_targets_file()

  # Display header and Scripts table with state information
  if (verbose) {
    message("\n[STATUS] \033[1;36mBakepipe Status\033[0m")
    display_scripts_table_targets(pipeline_data)
  }

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

  # Determine state for each script
  state_list <- lapply(scripts, function(script) {
    script_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == script]
    if (length(script_stale) > 0 && script_stale) {
      "stale"
    } else {
      "fresh"
    }
  })

  state_vec <- unlist(state_list)
  
  # Count scripts by state
  fresh_count <- sum(state_vec == "fresh")
  stale_count <- sum(state_vec == "stale")
  
  # Display summary
  message(paste0("\033[32m   ", fresh_count, " fresh script", if(fresh_count != 1) "s" else "", "\033[0m"), appendLF = FALSE)
  if (stale_count > 0) {
    message(paste0(" - \033[33m", stale_count, " stale script", if(stale_count != 1) "s" else "", "\033[0m"), appendLF = FALSE)
  }
  message("\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(scripts))

  # Display each script with status indicator
  for (i in seq_along(scripts)) {
    script <- scripts[i]
    state <- state_vec[i]
    
    if (state == "fresh") {
      message(sprintf("\033[90m[OK] %-*s \033[2m(fresh)\033[0m", max_width, script))
    } else {
      message(sprintf("\033[33m[!] %-*s \033[2m(stale)\033[0m", max_width, script))
    }
  }
  
  message("")
}

#' Display the scripts table using targets backend
#' @param pipeline_data Parsed pipeline data
display_scripts_table_targets <- function(pipeline_data) {
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
  message(paste0(
    "\033[32m   ", fresh_count, " fresh script",
    if (fresh_count != 1) "s" else "", "\033[0m"
  ), appendLF = FALSE)
  if (stale_count > 0) {
    message(paste0(
      " - \033[33m", stale_count, " stale script",
      if (stale_count != 1) "s" else "", "\033[0m"
    ), appendLF = FALSE)
  }
  message("\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(script_names))

  # Display each script with status indicator, inputs, and outputs
  for (i in seq_along(script_names)) {
    script <- script_names[i]
    state <- state_vec[i]
    script_info <- pipeline_data$scripts[[script]]
    
    # Format inputs (both external and from other scripts)
    all_inputs <- c(script_info$externals, script_info$inputs)
    inputs_str <- if (length(all_inputs) > 0) {
      paste0("inputs: ", paste(all_inputs, collapse = ", "))
    } else {
      "inputs: (none)"
    }
    
    outputs_str <- if (length(script_info$outputs) > 0) {
      paste0("outputs: ", paste(script_info$outputs, collapse = ", "))
    } else {
      "outputs: (none)"
    }

    if (state == "fresh") {
      message(sprintf(
        "\033[90m[OK] %-*s \033[2m(fresh)\033[0m",
        max_width, script
      ))
    } else {
      message(sprintf(
        "\033[33m[!] %-*s \033[2m(stale)\033[0m",
        max_width, script
      ))
    }
    message(sprintf("     \033[2m  %s\033[0m", inputs_str))
    message(sprintf("     \033[2m  %s\033[0m", outputs_str))
  }

  message("")
}

# R/bakepipe.R

# Internal environment to store pipeline state
.bakepipe_env <- new.env(parent = emptyenv())
.bakepipe_env$scripts <- list() # To store info about each script: path -> list(inputs=c(), outputs=c())
.bakepipe_env$current_script_path <- NULL # Path of the script currently being parsed or run

#' Mark a file as an input dependency for the current R script.
#'
#' This function is used within an R script to declare that it consumes a specific
#' file as an input. Bakepipe uses these declarations to determine the dependencies
#' between scripts. The function simply returns the path, allowing it to be used
#' directly in file reading functions like \code{read.csv(file_in("my_data.csv"))}.
#'
#' @param path A string representing the path to the input file.
#'             The path can be relative to the script's location or absolute.
#' @return The input \code{path}, unchanged.
#' @export
#' @examples
#' \dontrun{
#' # In your R script:
#' # data <- read.csv(file_in("input_data.csv"))
#' # config <- jsonlite::fromJSON(file_in("project_config.json"))
#' }
file_in <- function(path) {
  if (is.null(.bakepipe_env$current_script_path)) {
    warning("file_in() called outside of a script run by bakepipe::run() or context set by bakepipe. Current script context is unknown. Dependency tracking for this file may not work as expected.")
    return(path)
  }

  script_path <- .bakepipe_env$current_script_path

  if (!script_path %in% names(.bakepipe_env$scripts)) {
    .bakepipe_env$scripts[[script_path]] <- list(inputs = c(), outputs = c())
  }

  # Ensure path is normalized for consistent tracking
  normalized_path <- normalizePath(path, mustWork = FALSE, winslash = "/")
  .bakepipe_env$scripts[[script_path]]$inputs <- unique(c(.bakepipe_env$scripts[[script_path]]$inputs, normalized_path))

  return(path) # Return the original path as user provided it
}

#' Mark a file as an output of the current R script.
#'
#' This function is used within an R script to declare that it produces a specific
#' file as an output. Bakepipe uses these declarations to determine the dependencies
#' between scripts. The function simply returns the path, allowing it to be used
#' directly in file writing functions like \code{write.csv(my_data, file_out("output_data.csv"))}.
#'
#' @param path A string representing the path to the output file.
#'             The path can be relative to the script's location or absolute.
#' @return The input \code{path}, unchanged.
#' @export
#' @examples
#' \dontrun{
#' # In your R script:
#' # write.csv(processed_data, file_out("processed_output.csv"))
#' # saveRDS(model_object, file_out("final_model.rds"))
#' }
file_out <- function(path) {
  if (is.null(.bakepipe_env$current_script_path)) {
    warning("file_out() called outside of a script run by bakepipe::run() or context set by bakepipe. Current script context is unknown. Dependency tracking for this file may not work as expected.")
    return(path)
  }

  script_path <- .bakepipe_env$current_script_path

  if (!script_path %in% names(.bakepipe_env$scripts)) {
    .bakepipe_env$scripts[[script_path]] <- list(inputs = c(), outputs = c())
  }

  # Ensure path is normalized for consistent tracking
  normalized_path <- normalizePath(path, mustWork = FALSE, winslash = "/")
  .bakepipe_env$scripts[[script_path]]$outputs <- unique(c(.bakepipe_env$scripts[[script_path]]$outputs, normalized_path))

  return(path) # Return the original path
}

#' Reset the internal state of the Bakepipe environment.
#'
#' This function is primarily intended for testing purposes. It clears all stored
#' script dependency information and resets the current script path context.
#' Exported for access during testing, not typically for user workflows.
#'
#' @return Invisible NULL.
#' @export # Exporting for testthat access primarily
reset_bakepipe_state <- function() {
  .bakepipe_env$scripts <- list()
  .bakepipe_env$current_script_path <- NULL
  invisible(NULL)
}

#' Run the Bakepipe pipeline.
#'
#' Discovers R scripts (\*.R) in the specified directory (or current working
#' directory if not specified). It first parses these scripts to identify
#' \code{file_in()} and \code{file_out()} declarations to build a dependency graph.
#' Then, it executes the scripts in an order determined by a topological sort of
#' this graph.
#'
#' Scripts are sourced in their own local environment, which has the global
#' environment as its parent.
#'
#' @param path A string, path to the directory containing the R scripts for the pipeline.
#'             Defaults to the current working directory (".").
#' @return A character vector containing the paths to all declared output files
#'         from the scripts that were executed, invisibly. Paths are normalized.
#' @export
#' @examples
#' \dontrun{
#' # Assuming you have R scripts with file_in/file_out calls in your current directory:
#' # generated_files <- bakepipe::run()
#' # print(generated_files)
#'
#' # To run on scripts in a specific 'my_pipeline_scripts/' directory:
#' # bakepipe::run("./my_pipeline_scripts")
#' }
run <- function(path = ".") {
  reset_bakepipe_state()

  # Ensure path is normalized
  normalized_run_path <- normalizePath(path, mustWork = TRUE, winslash = "/")

  script_files <- list.files(normalized_run_path, pattern = "\\.R$", full.names = TRUE)
  # Normalize script_files paths immediately for consistency
  script_files <- normalizePath(script_files, mustWork = TRUE, winslash = "/")

  if (length(script_files) == 0) {
    message("No .R scripts found in ", normalized_run_path)
    return(invisible(character(0)))
  }

  for (script_file in script_files) {
    .bakepipe_env$current_script_path <- script_file # Already normalized
    tryCatch({
      suppressMessages(suppressWarnings(source(script_file, local = new.env())))
    }, error = function(e) {
      warning("Error parsing script '", script_file, "': ", e$message)
    })
  }
  .bakepipe_env$current_script_path <- NULL

  script_names <- names(.bakepipe_env$scripts)
  if (length(script_names) == 0) {
    message("No bakepipe declarations (file_in, file_out) found in any scripts within ", normalized_run_path, ".")
    return(invisible(character(0)))
  }

  adj <- matrix(0, nrow = length(script_names), ncol = length(script_names), dimnames = list(script_names, script_names))

  for (i in seq_along(script_names)) {
    script_i_path <- script_names[i]
    script_i_info <- .bakepipe_env$scripts[[script_i_path]]
    outputs_i <- script_i_info$outputs
    if (length(outputs_i) == 0) next

    for (j in seq_along(script_names)) {
      if (i == j) next
      script_j_path <- script_names[j]
      script_j_info <- .bakepipe_env$scripts[[script_j_path]]
      inputs_j <- script_j_info$inputs
      if (length(inputs_j) == 0) next

      if (any(inputs_j %in% outputs_i)) {
        adj[i, j] <- 1
      }
    }
  }

  in_degree <- colSums(adj)
  queue_indices <- which(in_degree == 0)

  if (length(queue_indices) == 0 && length(script_names) > 0) {
    if (all(adj == 0)) {
        message("No dependencies found between scripts. Running in alphabetical order of script names.")
        # Sort script_names alphabetically to define order for queue_indices
        queue_indices <- order(script_names)
    } else {
        stop("Circular dependency detected! Cannot determine execution order. Use bakepipe::show() to inspect dependencies.")
    }
  } else if (length(queue_indices) > 0 && all(adj==0)) {
    # If all in_degrees are 0 because no dependencies, run alphabetically
    message("No dependencies found between scripts. Running in alphabetical order of script names.")
    queue_indices <- order(script_names[queue_indices]) # Make sure queue processes in this order
  }


  execution_order_indices <- integer(0)
  processed_nodes_count <- 0

  temp_queue <- queue_indices # Use a temporary queue for processing

  while(length(temp_queue) > 0) {
    # For alphabetical tie-breaking among current queue items:
    # Sort the current items in temp_queue by their script names before picking one
    if(length(temp_queue) > 1) {
        temp_queue <- temp_queue[order(script_names[temp_queue])]
    }

    script_idx <- temp_queue[1]
    temp_queue <- temp_queue[-1]

    execution_order_indices <- c(execution_order_indices, script_idx)
    processed_nodes_count <- processed_nodes_count + 1

    neighbors_indices <- which(adj[script_idx, ] == 1)
    for (neighbor_idx in neighbors_indices) {
      in_degree[neighbor_idx] <- in_degree[neighbor_idx] - 1
      if (in_degree[neighbor_idx] == 0) {
        temp_queue <- c(temp_queue, neighbor_idx)
      }
    }
  }

  if (processed_nodes_count != length(script_names)) {
     stop("Could not determine a valid execution order for all scripts. Possible circular dependency or disconnected graph components not handled. Use bakepipe::show() to inspect dependencies.")
  }

  execution_order <- script_names[execution_order_indices]

  all_output_files <- character(0)
  message("Starting Bakepipe run in directory: ", normalized_run_path)
  for (script_to_run in execution_order) {
    message("Running script: ", script_to_run)
    .bakepipe_env$current_script_path <- script_to_run
    tryCatch({
      source(script_to_run, local = TRUE)
      if (!is.null(.bakepipe_env$scripts[[script_to_run]]$outputs)) {
        all_output_files <- c(all_output_files, .bakepipe_env$scripts[[script_to_run]]$outputs)
      }
    }, error = function(e) {
      warning("Error running script '", script_to_run, "': ", e$message)
    })
  }
  .bakepipe_env$current_script_path <- NULL

  all_output_files <- unique(all_output_files)
  message("Bakepipe run finished.")
  if (length(all_output_files) > 0) {
    message("Declared output files from executed scripts:")
    for(f in sort(all_output_files)) message("- ", f) # Sort for consistent display
  } else {
    message("No output files were declared by the executed scripts.")
  }

  return(invisible(all_output_files))
}

#' Show the Bakepipe pipeline dependencies.
#'
#' Parses R scripts (\*.R) in the specified directory to identify \code{file_in()}
#' and \code{file_out()} declarations. It then prints a textual representation of
#' these dependencies, showing which scripts consume which files and which scripts
#' produce them.
#'
#' If \code{bakepipe::run()} has been called and its internal state includes scripts
#' from the specified \code{path}, this function may use that cached information.
#' To force a fresh parse of the directory for \code{show()}, call
#' \code{reset_bakepipe_state()} before \code{show()}.
#'
#' @param path A string, path to the directory containing the R scripts for the pipeline.
#'             Defaults to the current working directory (".").
#' @return Invisible NULL. The function prints dependency information to the console.
#' @export
#' @examples
#' \dontrun{
#' # To show dependencies for scripts in the current directory:
#' # bakepipe::show()
#'
#' # To show dependencies for scripts in 'my_pipeline_scripts/':
#' # bakepipe::show("./my_pipeline_scripts")
#'
#' # To force a re-parse for the current directory:
#' # bakepipe::reset_bakepipe_state()
#' # bakepipe::show()
#' }
show <- function(path = ".") {
  normalized_show_path <- normalizePath(path, mustWork = TRUE, winslash = "/")

  # Determine if a re-parse is needed.
  # If scripts list is empty, or if the scripts seem to be from a different context.
  # A simple heuristic: if the first script's path doesn't start with normalized_show_path,
  # assume it's a different context. This isn't perfect but better than nothing.
  needs_reparse <- TRUE
  if (length(.bakepipe_env$scripts) > 0) {
      first_script_dir <- dirname(names(.bakepipe_env$scripts)[1])
      # Check if the existing scripts' directory is a sub-path of the requested show path,
      # or vice-versa. This is still a heuristic.
      # A simpler rule: if .bakepipe_env$scripts is not empty, assume it's relevant.
      # User can call reset_bakepipe_state() to force.
      # For this implementation, let's stick to: parse if empty.
      needs_reparse <- FALSE
  }

  if (needs_reparse || length(.bakepipe_env$scripts) == 0) { # Always parse if empty
    message("Parsing scripts in '", normalized_show_path, "' to detect dependencies...")

    original_current_script_path <- .bakepipe_env$current_script_path
    # Reset scripts for "show" if it's doing its own parse, to not mix with old state.
    # This means show() after run() will show run's state. show() alone parses fresh for path.
    # If we want show() to *always* parse the given path fresh unless run() was *just* called for *same* path:
    # The logic here is if .bakepipe_env is empty, it parses. Otherwise, it shows existing.
    # This is the behavior from the prompt.
    if (length(.bakepipe_env$scripts) == 0) { # Only reset if truly empty and parsing now
        .bakepipe_env$scripts <- list()
    }

    script_files <- list.files(normalized_show_path, pattern = "\\.R$", full.names = TRUE)
    script_files <- normalizePath(script_files, mustWork = TRUE, winslash = "/")

    if (length(script_files) == 0) {
      message("No .R scripts found in ", normalized_show_path)
      .bakepipe_env$current_script_path <- original_current_script_path
      return(invisible(NULL))
    }

    for (script_file in script_files) {
      .bakepipe_env$current_script_path <- script_file # Already normalized
      tryCatch({
        suppressMessages(suppressWarnings(source(script_file, local = new.env())))
      }, error = function(e) {
        warning("Error parsing script '", script_file, "' for show(): ", e$message)
      })
    }
    .bakepipe_env$current_script_path <- original_current_script_path

    if (length(.bakepipe_env$scripts) == 0) {
        message("No bakepipe declarations (file_in, file_out) found in any scripts within ", normalized_show_path, ".")
        return(invisible(NULL))
    }
    message("Dependencies based on fresh parse of '", normalized_show_path, "':")
  } else {
    message("Dependencies based on last `run()` or previous `show()` parse:")
  }

  sorted_script_names <- sort(names(.bakepipe_env$scripts))

  for (script_path in sorted_script_names) {
    info <- .bakepipe_env$scripts[[script_path]]
    message("\nScript: ", script_path)

    if (length(info$inputs) > 0) {
      message("  Inputs:")
      for (input_file in sort(info$inputs)) {
        message("    - ", input_file)
      }
    } else {
      message("  Inputs: None")
    }

    if (length(info$outputs) > 0) {
      message("  Outputs:")
      for (output_file in sort(info$outputs)) {
        message("    - ", output_file)
      }
    } else {
      message("  Outputs: None")
    }
  }

  return(invisible(NULL))
}
